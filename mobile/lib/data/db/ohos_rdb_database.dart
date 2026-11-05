import 'dart:async';
import 'dart:convert';

import 'package:drift/backends.dart';
import 'package:flutter/services.dart';

/// 鸿蒙侧的关系型数据库通道名，对应
/// `ohos/entry/src/main/ets/rdb/RdbBridge.ets`。
const String _kChannelName = 'caldav_free/rdb';

/// 用鸿蒙系统自带的 `RelationalStore`（底层就是 SQLite）实现 drift 的
/// [DatabaseDelegate]。
///
/// 为什么不用 `sqlite3` + `sqlite3_flutter_libs`：这两个包都没有 ohos 实现。
/// 更要紧的是，鸿蒙版 Flutter 的 FFI 构建钩子会把 targetOS 伪装成 `linux`，
/// 于是 `sqlite3` 会下载 **glibc 版** 预编译库打进 HAP，运行期加载必然失败。
/// 与其自己交叉编译一份 libsqlite3.so，不如直接用系统 RDB：它就是 SQLite，
/// 由系统维护、免打包、免签名。
///
/// 代价：每条语句都要过一次平台通道（微秒级），对本地任务列表够用；批量写
/// 入走 drift 的 batch，已经合并成一次调用。
class OhosRdbDelegate extends DatabaseDelegate {
  OhosRdbDelegate({this.name = 'caldav_free', MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_kChannelName);

  /// RDB 里的数据库名（不是文件路径）。RDB 自己把它放在应用沙箱里。
  final String name;
  final MethodChannel _channel;

  bool _open = false;
  int _savepointDepth = 0;

  @override
  DbVersionDelegate get versionDelegate => _RdbVersionDelegate(this);

  @override
  TransactionDelegate get transactionDelegate => _RdbTransactionDelegate(this);

  @override
  Future<bool> get isOpen async => _open;

  @override
  Future<void> open(QueryExecutorUser db) async {
    await _channel.invokeMethod<bool>('open', <String, Object?>{'name': name});
    // 打开即启用 WAL，和服务端 SQLite 的 DSN 保持一致。
    await runCustom('PRAGMA journal_mode = WAL', const <Object?>[]);
    await runCustom('PRAGMA busy_timeout = 5000', const <Object?>[]);
    await runCustom('PRAGMA synchronous = NORMAL', const <Object?>[]);
    _open = true;
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    try {
      await _channel.invokeMethod<void>('close');
    } on PlatformException {
      // 关闭失败不影响退出流程。
    }
  }

  @override
  Future<QueryResult> runSelect(String statement, List<Object?> args) async {
    final reply = await _channel.invokeMapMethod<String, Object?>(
      'query',
      <String, Object?>{
        'sql': statement,
        'args': args.map(_encodeValue).toList(growable: false),
      },
    );
    final columns = (reply?['columns'] as List?)?.cast<String>() ?? const [];
    final types = (reply?['types'] as List?)?.cast<String>() ?? const [];
    final rows = (reply?['rows'] as List?) ?? const [];
    return QueryResult(columns, <List<Object?>>[
      for (final row in rows)
        <Object?>[
          for (var i = 0; i < (row as List).length; i++)
            _decodeValue(row[i], i < types.length ? types[i] : ''),
        ],
    ]);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    final reply = await _execute(statement, args);
    return (reply['changes'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    final reply = await _execute(statement, args);
    return (reply['lastId'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> runCustom(String statement, List<Object?> args) async {
    await _execute(statement, args);
  }

  Future<Map<String, Object?>> _execute(
    String statement,
    List<Object?> args,
  ) async {
    final reply = await _channel.invokeMapMethod<String, Object?>(
      'execute',
      <String, Object?>{
        'sql': statement,
        'args': args.map(_encodeValue).toList(growable: false),
      },
    );
    return reply ?? const <String, Object?>{};
  }

  Future<void> _begin() => _channel.invokeMethod<void>('begin');
  Future<void> _commit() => _channel.invokeMethod<void>('commit');
  Future<void> _rollback() => _channel.invokeMethod<void>('rollback');

  Future<void> _savepoint() async {
    _savepointDepth++;
    await _channel.invokeMethod<void>('savepoint', <String, Object?>{
      'name': 's$_savepointDepth',
    });
  }

  Future<void> _release() async {
    final name = 's$_savepointDepth';
    _savepointDepth--;
    await _channel.invokeMethod<void>('release', <String, Object?>{'name': name});
  }

  Future<void> _rollbackTo() async {
    final name = 's$_savepointDepth';
    _savepointDepth--;
    await _channel.invokeMethod<void>('rollbackTo', <String, Object?>{
      'name': name,
    });
  }
}

/// 通道只走 JSON 可表达的标量，blob 用 base64 中转（`{'$b': '...'}`），
/// 避免依赖 ArkTS 与 Dart 之间的 typed array 编解码细节。
Object? _encodeValue(Object? value) {
  if (value == null) return null;
  if (value is Uint8List) {
    return <String, Object?>{r'$b': base64Encode(value)};
  }
  if (value is int || value is double || value is String || value is bool) {
    return value;
  }
  if (value is BigInt) return value.toInt();
  if (value is DateTime) return value.millisecondsSinceEpoch;
  return value.toString();
}

Object? _decodeValue(Object? raw, String columnType) {
  if (raw == null) return null;
  if (raw is Map && raw.containsKey(r'$b')) {
    return base64Decode(raw[r'$b'] as String);
  }
  if (raw is num) {
    // ArkTS 侧只有 double，整数列按列类型还原成 int，否则 drift 读 bool/int
    // 列时会拿到 1.0 这种值。
    if (columnType == 'INTEGER' || columnType == 'BOOLEAN') {
      return raw.toInt();
    }
    return raw.toDouble();
  }
  return raw;
}

class _RdbVersionDelegate extends DynamicVersionDelegate {
  _RdbVersionDelegate(this._db);

  final OhosRdbDelegate _db;

  @override
  Future<int> get schemaVersion async {
    final result = await _db.runSelect('PRAGMA user_version', const []);
    if (result.rows.isEmpty || result.rows.first.isEmpty) return 0;
    final value = result.rows.first.first;
    return value is num ? value.toInt() : 0;
  }

  @override
  Future<void> setSchemaVersion(int version) async {
    // PRAGMA 不接受参数占位符，version 来自 schemaVersion 常量，安全。
    await _db.runCustom('PRAGMA user_version = $version', const []);
  }
}

/// RDB 自己管理事务，所以用 [SupportedTransactionDelegate]；
/// `managesLockInternally = false` 让 drift 负责串行化，避免事务期间
/// 别的语句插进来（RDB 的写连接只有一个）。
class _RdbTransactionDelegate extends SupportedTransactionDelegate {
  _RdbTransactionDelegate(this._db);

  final OhosRdbDelegate _db;

  @override
  bool get managesLockInternally => false;

  @override
  Future<void> startTransaction(Future Function(QueryDelegate) run) async {
    await _db._begin();
    try {
      await run(_db);
      await _db._commit();
    } catch (_) {
      try {
        await _db._rollback();
      } catch (_) {
        // 回滚失败时把原始异常抛出去更有用。
      }
      rethrow;
    }
  }

  @override
  FutureOr<void> Function(QueryDelegate, Future<void> Function(QueryDelegate))?
  get startNested => (QueryDelegate outer, Future<void> Function(QueryDelegate) block) async {
    await _db._savepoint();
    try {
      await block(outer);
      await _db._release();
    } catch (_) {
      try {
        await _db._rollbackTo();
      } catch (_) {
        // 同上：保留原始异常。
      }
      rethrow;
    }
  };
}
