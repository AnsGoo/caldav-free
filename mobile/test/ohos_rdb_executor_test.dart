import 'dart:convert';

import 'package:drift/backends.dart';
import 'package:drift/drift.dart' show OpeningDetails;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldav_free/data/db/ohos_rdb_database.dart';

/// 记录收到的通道调用，并按方法名返回预设结果。
class _Recorder {
  final List<MethodCall> calls = <MethodCall>[];

  List<String> get methods =>
      calls.map((call) => call.method).toList(growable: false);

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'open':
        return true;
      case 'query':
        final args = (call.arguments as Map)['args'] as List;
        if ((call.arguments as Map)['sql'] == 'PRAGMA user_version') {
          return <String, Object?>{
            'columns': <String>['user_version'],
            'types': <String>['INTEGER'],
            'rows': <List<Object?>>[
              <Object?>[6],
            ],
          };
        }
        return <String, Object?>{
          'columns': <String>['id', 'title', 'ratio', 'payload'],
          'types': <String>['INTEGER', 'STRING', 'DOUBLE', 'BLOB'],
          'rows': <List<Object?>>[
            <Object?>[7, 'demo', 0.25, <String, Object?>{r'$b': base64Encode(base64Blob)}],
          ],
          'echoArgs': args.length,
        };
      case 'execute':
        return <String, Object?>{'changes': 2, 'lastId': 42};
      default:
        return null;
    }
  }

  static final List<int> base64Blob = <int>[1, 2, 3];
}

class _FakeUser implements QueryExecutorUser {
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}

  @override
  int get schemaVersion => 6;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('caldav_free/rdb');
  late _Recorder recorder;

  setUp(() {
    recorder = _Recorder();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, recorder.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('open 用数据库名建库并下发 PRAGMA', () async {
    final db = OhosRdbDelegate();
    await db.open(_FakeUser());

    expect(recorder.calls.first.method, 'open');
    expect((recorder.calls.first.arguments as Map)['name'], 'caldav_free');
    expect(await db.isOpen, isTrue);
    expect(
      recorder.calls.where((call) => call.method == 'execute').length,
      3,
    );
  });

  test('runSelect 按列类型还原 int/double/string/blob', () async {
    final db = OhosRdbDelegate();
    await db.open(_FakeUser());

    final result = await db.runSelect('SELECT * FROM tasks', <Object?>[]);

    expect(result.columnNames, <String>['id', 'title', 'ratio', 'payload']);
    final row = result.rows.single;
    expect(row[0], 7);
    expect(row[0], isA<int>());
    expect(row[1], 'demo');
    expect(row[2], 0.25);
    expect(row[3], Uint8List.fromList(_Recorder.base64Blob));
  });

  test('blob 参数以 base64 底座过通道', () async {
    final db = OhosRdbDelegate();
    await db.open(_FakeUser());

    await db.runUpdate(
      'UPDATE tasks SET payload = ? WHERE id = ?',
      <Object?>[Uint8List.fromList(<int>[9, 8]), 3],
    );

    final call = recorder.calls.last;
    final args = (call.arguments as Map)['args'] as List;
    expect(args.first, <String, Object?>{r'$b': base64Encode(<int>[9, 8])});
    expect(args.last, 3);
  });

  test('runInsert 返回 lastId，runUpdate 返回影响行数', () async {
    final db = OhosRdbDelegate();
    await db.open(_FakeUser());

    expect(await db.runInsert('INSERT INTO tasks (id) VALUES (?)', <Object?>[1]), 42);
    expect(await db.runUpdate('UPDATE tasks SET a = 1', <Object?>[]), 2);
  });

  test('事务按 begin → 语句 → commit 顺序下发', () async {
    final db = OhosRdbDelegate();
    await db.open(_FakeUser());
    recorder.calls.clear();

    final delegate = db.transactionDelegate as SupportedTransactionDelegate;
    await delegate.startTransaction((QueryDelegate tx) async {
      await tx.runCustom('UPDATE tasks SET title = ?', <Object?>['x']);
    });

    expect(recorder.methods, <String>['begin', 'execute', 'commit']);
  });

  test('事务内抛错时回滚且不提交', () async {
    final db = OhosRdbDelegate();
    await db.open(_FakeUser());
    recorder.calls.clear();

    final delegate = db.transactionDelegate as SupportedTransactionDelegate;
    await expectLater(
      delegate.startTransaction((QueryDelegate tx) async {
        throw StateError('boom');
      }),
      throwsStateError,
    );

    expect(recorder.methods, <String>['begin', 'rollback']);
  });
}
