import 'dart:convert';
import 'dart:io';

import 'package:caldav_free/data/countdowns/countdown_write_queue.dart';
import 'package:caldav_free/data/db/local_database.dart';
import 'package:caldav_free/data/habits/habit_write_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('habit queue ops survive reopening the database, in order', () async {
    final directory = await Directory.systemTemp.createTemp('caldav-queue');
    final dbPath = '${directory.path}/caldav_free.db';
    final queue = HabitWriteQueue.forPath(dbPath);
    await queue.add(
      HabitPendingOp(
        opId: 'op-1',
        action: 'create',
        habitId: -5,
        payload: const {'name': '跑步'},
        createdAt: DateTime.utc(2026, 10, 1),
      ),
    );
    await queue.add(
      HabitPendingOp(
        opId: 'op-2',
        action: 'checkin',
        habitId: -5,
        stamp: 20261001,
        createdAt: DateTime.utc(2026, 10, 2),
      ),
    );
    await queue.replaceHabitId(-5, 9);
    await queue.close();

    final reopened = HabitWriteQueue.forPath(dbPath);
    final items = await reopened.items();
    expect(items.map((op) => op.opId), ['op-1', 'op-2']);
    expect(items.first.habitId, 9);
    expect(items.first.payload, {'name': '跑步'});
    expect(items.last.stamp, 20261001);

    await reopened.remove('op-1');
    await reopened.close();
    final third = HabitWriteQueue.forPath(dbPath);
    expect((await third.items()).single.opId, 'op-2');
    await third.close();
    await directory.delete(recursive: true);
  });

  test('the legacy habit JSON queue is imported once', () async {
    final directory = await Directory.systemTemp.createTemp('caldav-queue');
    final dbPath = '${directory.path}/caldav_free.db';
    final legacy = File('${directory.path}/caldav_habit_queue.json');
    legacy.writeAsStringSync(
      jsonEncode({
        'ops': [
          {
            'opId': 'op-9',
            'action': 'update',
            'habitId': 3,
            'payload': {'name': '旧打卡'},
            'createdAt': '2026-10-03T00:00:00Z',
          },
        ],
      }),
    );
    final queue = HabitWriteQueue.forPath(dbPath, legacyFile: legacy);
    expect((await queue.items()).single.opId, 'op-9');
    await queue.close();

    expect(legacy.existsSync(), isFalse);
    expect(File('${legacy.path}.migrated.bak').existsSync(), isTrue);
    final reopened = HabitWriteQueue.forPath(dbPath);
    expect((await reopened.items()).single.opId, 'op-9');
    await reopened.close();
    await directory.delete(recursive: true);
  });

  test('countdown queue writes land in the shared database', () async {
    final directory = await Directory.systemTemp.createTemp('caldav-queue');
    final dbPath = '${directory.path}/caldav_free.db';
    final queue = CountdownWriteQueue.forPath(dbPath, ownsDatabase: false);
    final database = sharedAppDatabase(dbPath);
    await queue.add(
      CountdownPendingOp(
        opId: 'op-1',
        action: 'create',
        countdownId: -7,
        payload: const {'name': '生日'},
        createdAt: DateTime.utc(2026, 10, 1),
      ),
    );
    expect(await database.select(database.countdownOutbox).get(), hasLength(1));

    await queue.replaceCreatePayload(-7, const {'name': '纪念日'});
    await queue.replaceCountdownId(-7, 4);
    final rows = await database.select(database.countdownOutbox).get();
    expect(rows.single.countdownId, 4);
    expect(
      (await queue.items()).single.payload,
      {'name': '纪念日'},
      reason: 'queue rows are rewritten in place, not re-inserted',
    );

    await closeSharedAppDatabase();
    await directory.delete(recursive: true);
  });
}
