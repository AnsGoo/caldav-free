import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import MethodChannel, {
  MethodCallHandler,
  MethodResult,
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import { util } from '@kit.ArkTS';

const CHANNEL_NAME: string = 'caldav_free/rdb';

/// 把鸿蒙系统自带的 RelationalStore（底层就是 SQLite）暴露给 Dart 侧。
///
/// 对端实现是 `lib/data/db/ohos_rdb_database.dart` 里的 drift
/// DatabaseDelegate：drift 只发 SQL + 参数，这里负责执行和结果序列化。
///
/// API 26 的 relationalStore 有几个坑，改代码时注意：
///   - `ResultSet.getColumnType()` 返回 Promise，同步场景要用 `getColumnTypeSync()`
///   - `ColumnType` 只有 NULL/INTEGER/REAL/TEXT/BLOB，没有 DOUBLE/STRING/BOOLEAN/UNLIMITED_INT
///   - `MethodCall.argument()` 不是泛型，只能 `call.argument('k') as string`
///   - `RdbStore.execute()` 返回的是 `ValueType`，不是 number
///
/// 为什么要绕这一层：`sqlite3` / `sqlite3_flutter_libs` 都没有 ohos 实现，
/// 而鸿蒙版 Flutter 的 FFI 钩子会把 targetOS 报成 linux，下载到 glibc 版
/// 原生库在鸿蒙上加载不了。系统 RDB 是官方推荐的 SQLite 用法，免打包。
///
/// 通道协议（两端必须一致，见 test/ohos_rdb_executor_test.dart）：
///   open   {name}                 -> true
///   execute{sql, args}            -> {changes, lastId}
///   query  {sql, args}            -> {columns, types, rows}
///   begin/commit/rollback         -> null
///   savepoint/release/rollbackTo  {name} -> null
///   close                         -> null
/// blob 一律用 base64 中转（`{'$b': '...'}`），避免 typed array 的编解码差异。
export class RdbBridge {
  private context: common.UIAbilityContext;
  private store: relationalStore.RdbStore | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  attach(messenger: BinaryMessenger): void {
    const channel: MethodChannel = new MethodChannel(messenger, CHANNEL_NAME);
    const handler: MethodCallHandler = {
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.dispatch(call, result);
      },
    };
    channel.setMethodCallHandler(handler);
  }

  private dispatch(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'open':
        this.open(call, result);
        break;
      case 'execute':
        this.execute(call, result);
        break;
      case 'query':
        this.query(call, result);
        break;
      case 'begin':
        this.begin(result);
        break;
      case 'commit':
        this.commit(result);
        break;
      case 'rollback':
        this.rollback(result);
        break;
      case 'savepoint':
        this.runSql(`SAVEPOINT ${this.stringArg(call, 'name', 's1')}`, result);
        break;
      case 'release':
        this.runSql(`RELEASE ${this.stringArg(call, 'name', 's1')}`, result);
        break;
      case 'rollbackTo':
        this.runSql(`ROLLBACK TO ${this.stringArg(call, 'name', 's1')}`, result);
        break;
      case 'close':
        this.close(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /// MethodCall.argument 的返回类型是 ESObject，ArkTS 严格模式不允许隐式使用，
  /// 这里统一在边界上转成具体类型。
  private stringArg(call: MethodCall, key: string, fallback: string): string {
    const value: ESObject = call.argument(key);
    if (typeof value === 'string') {
      return value as string;
    }
    return fallback;
  }

  private async ensureStore(name: string): Promise<relationalStore.RdbStore> {
    const existing = this.store;
    if (existing !== null) {
      return existing;
    }
    const config: relationalStore.StoreConfig = {
      name: name,
      securityLevel: relationalStore.SecurityLevel.S1,
    };
    const store = await relationalStore.getRdbStore(this.context, config);
    this.store = store;
    return store;
  }

  private async open(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const name: string = this.stringArg(call, 'name', 'caldav_free');
      await this.ensureStore(name);
      result.success(true);
    } catch (error) {
      result.error('rdb_open', `${error}`, null);
    }
  }

  private async execute(call: MethodCall, result: MethodResult): Promise<void> {
    let sql: string = '';
    try {
      const store = await this.currentStore();
      sql = this.stringArg(call, 'sql', '');
      const args = this.bindArgs(call);
      const changes = await store.execute(sql, args);
      // RDB 的 execute 返回受影响行数；插入语句再补一次 last_insert_rowid。
      const lastId: number = await this.lastInsertRowId(store);
      const reply: Map<string, ESObject> = new Map<string, ESObject>();
      reply.set('changes', this.toNumber(changes));
      reply.set('lastId', lastId);
      result.success(reply);
    } catch (error) {
      console.error(`[RdbBridge] execute FAILED sql=${sql} err=${error}`);
      result.error('rdb_execute', `${error}`, null);
    }
  }

  private async query(call: MethodCall, result: MethodResult): Promise<void> {
    let step: string = 'enter';
    let sql: string = '';
    try {
      const store = await this.currentStore();
      sql = this.stringArg(call, 'sql', '');
      const args = this.bindArgs(call);
      step = 'querySql';
      const rs = await store.querySql(sql, args);
      const count: number = rs.columnCount;
      // 列名走 getColumnNames()：它是纯元数据，不要求结果集先定位到某一行。
      // （getColumnName(i) / getColumnTypeSync(i) 都要求指针在有效行上，直接调用会抛
      //   "ResultSet is empty or pointer index is out of bounds."）
      const columns: string[] = rs.getColumnNames();
      const types: string[] = [];
      for (let i = 0; i < count; i++) {
        types.push('');
      }
      const rows: Array<Array<ESObject>> = [];
      try {
        step = 'goToFirstRow';
        let more: boolean = rs.goToFirstRow();
        while (more) {
          const row: Array<ESObject> = [];
          for (let i = 0; i < count; i++) {
            if (types[i] === '' && !rs.isColumnNull(i)) {
              // 列类型按该列第一个非 NULL 值推断，避免首行为 NULL 的整数列被当成字符串
              types[i] = this.columnTypeName(rs.getColumnTypeSync(i));
            }
            step = `read row${rows.length} col${i}`;
            row.push(this.readValue(rs, i));
          }
          rows.push(row);
          step = 'goToNextRow';
          more = rs.goToNextRow();
        }
      } finally {
        rs.close();
      }
      // 全空结果集（或整列都是 NULL）拿不到列类型，给个不影响 values 的占位
      for (let i = 0; i < count; i++) {
        if (types[i] === '') {
          types[i] = 'STRING';
        }
      }
      const reply: Map<string, ESObject> = new Map<string, ESObject>();
      reply.set('columns', columns);
      reply.set('types', types);
      reply.set('rows', rows);
      result.success(reply);
    } catch (error) {
      // 只在失败时打日志：正常查询太频繁，逐条打会淹没 hilog
      console.error(`[RdbBridge] query FAILED at ${step} sql=${sql} err=${error}`);
      result.error('rdb_query', `${error}`, null);
    }
  }

  private async currentStore(): Promise<relationalStore.RdbStore> {
    const store = this.store;
    if (store === null) {
      throw new Error('RDB 尚未打开，请先调用 open');
    }
    return store;
  }

  private readValue(rs: relationalStore.ResultSet, index: number): ESObject {
    if (rs.isColumnNull(index)) {
      return null;
    }
    const type: relationalStore.ColumnType = rs.getColumnTypeSync(index);
    if (type === relationalStore.ColumnType.BLOB) {
      const blob: Uint8Array = rs.getBlob(index);
      const encoded: Map<string, ESObject> = new Map<string, ESObject>();
      encoded.set('$b', new util.Base64Helper().encodeToStringSync(blob));
      return encoded;
    }
    return rs.getValue(index) as ESObject;
  }

  /// API 26 的列类型枚举是 SQLite 原生的几种（NULL/INTEGER/REAL/TEXT/BLOB），
  /// 没有老文档里的 UNLIMITED_INT / DOUBLE / STRING / BOOLEAN，这里映射成
  /// Dart 侧认识的字符串，保持与 drift 的类型推断一致。
  private columnTypeName(type: relationalStore.ColumnType): string {
    switch (type) {
      case relationalStore.ColumnType.INTEGER:
        return 'INTEGER';
      case relationalStore.ColumnType.REAL:
        return 'DOUBLE';
      case relationalStore.ColumnType.BLOB:
        return 'BLOB';
      case relationalStore.ColumnType.TEXT:
        return 'STRING';
      case relationalStore.ColumnType.NULL:
        return 'NULL';
      default:
        return 'STRING';
    }
  }

  /// 参数只走 JSON 标量。blob 在 Dart 侧会编码成 `{'$b': base64}` 的 Map，
  /// 但当前 schema（local_database.dart）没有任何 blob 列，这里就不再为它保留
  /// 动态 Map 分支 —— ArkTS 的 arkts-no-any-unknown 不允许对 ESObject 做泛型断言。
  /// 将来真加了 blob 列，改成"参数按 index 走二进制通道"比在这里绕更干净。
  private bindArgs(call: MethodCall): relationalStore.ValueType[] {
    const out: relationalStore.ValueType[] = [];
    const raw: ESObject = call.argument('args');
    if (raw === null || raw === undefined) {
      return out;
    }
    const items: Array<ESObject> = raw as Array<ESObject>;
    for (let i = 0; i < items.length; i++) {
      const item: ESObject = items[i];
      if (item === null || item === undefined) {
        out.push(null);
      } else if (typeof item === 'boolean') {
        // SQLite 没有布尔类型，drift 用 INTEGER 存，这里跟着转
        out.push((item as boolean) ? 1 : 0);
      } else if (typeof item === 'number' || typeof item === 'string') {
        out.push(item as relationalStore.ValueType);
      } else {
        // 未知类型按字符串兜底，好过静默丢参数
        out.push(item.toString());
      }
    }
    return out;
  }

  private toNumber(value: ESObject): number {
    if (typeof value === 'number') {
      return value as number;
    }
    if (typeof value === 'bigint') {
      return Number(value);
    }
    return 0;
  }

  private async lastInsertRowId(store: relationalStore.RdbStore): Promise<number> {
    try {
      const rs = await store.querySql('SELECT last_insert_rowid() AS id');
      try {
        if (rs.goToFirstRow()) {
          return rs.getLong(rs.getColumnIndex('id'));
        }
      } finally {
        rs.close();
      }
    } catch (error) {
      return 0;
    }
    return 0;
  }

  private async begin(result: MethodResult): Promise<void> {
    try {
      const store = await this.currentStore();
      store.beginTransaction();
      result.success(null);
    } catch (error) {
      result.error('rdb_begin', `${error}`, null);
    }
  }

  private async commit(result: MethodResult): Promise<void> {
    try {
      const store = await this.currentStore();
      store.commit();
      result.success(null);
    } catch (error) {
      result.error('rdb_commit', `${error}`, null);
    }
  }

  private async rollback(result: MethodResult): Promise<void> {
    try {
      const store = await this.currentStore();
      store.rollBack();
      result.success(null);
    } catch (error) {
      result.error('rdb_rollback', `${error}`, null);
    }
  }

  private async runSql(sql: string, result: MethodResult): Promise<void> {
    try {
      const store = await this.currentStore();
      await store.executeSql(sql);
      result.success(null);
    } catch (error) {
      result.error('rdb_sql', `${error}`, null);
    }
  }

  private async close(result: MethodResult): Promise<void> {
    try {
      const store = this.store;
      this.store = null;
      if (store !== null) {
        await store.close();
      }
      result.success(null);
    } catch (error) {
      result.error('rdb_close', `${error}`, null);
    }
  }
}
