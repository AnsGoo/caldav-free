import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/countdowns/countdown_api.dart';
import 'package:caldav_free/data/habits/habit_api.dart';
import 'package:caldav_free/data/reminders/reminder_plan.dart';
import 'package:flutter_test/flutter_test.dart';

TaskItem task({
  String id = 'task-1',
  DateTime? due,
  List<int> reminders = const [0],
  DateTime? completedAt,
  bool deleted = false,
}) {
  return TaskItem(
    id: id,
    listId: 'list-1',
    title: '任务 $id',
    dueAt: due,
    reminderOffsets: reminders,
    completedAt: completedAt,
    deleted: deleted,
    updatedAt: DateTime.utc(2026, 10, 1),
  );
}

void main() {
  final now = DateTime.utc(2026, 10, 25, 10);

  test('builds one notification per offset, earliest first', () {
    final due = DateTime.utc(2026, 10, 25, 12);
    final plan = buildReminderPlan(
      [task(due: due, reminders: const [60, 0, 30])],
      now: now,
    );
    expect(plan.map((item) => item.at).toList(), [
      DateTime.utc(2026, 10, 25, 11),
      DateTime.utc(2026, 10, 25, 11, 30),
      DateTime.utc(2026, 10, 25, 12),
    ]);
    expect(plan.map((item) => item.offsetMinutes).toList(), [60, 30, 0]);
    expect(plan.every((item) => item.payload == 'task:task-1'), true);
  });

  test('skips past, completed, deleted, missing-due and note rows', () {
    final past = task(id: 'past', due: DateTime.utc(2026, 10, 25, 9));
    final completed = task(
      id: 'done',
      due: DateTime.utc(2026, 10, 25, 12),
      completedAt: DateTime.utc(2026, 10, 25, 9),
    );
    final deleted = task(
      id: 'trash',
      due: DateTime.utc(2026, 10, 25, 12),
      deleted: true,
    );
    final noDue = task(id: 'nodue');
    final note = TaskItem(
      id: 'note',
      listId: 'list-1',
      title: 'note',
      kind: TaskKind.note,
      dueAt: DateTime.utc(2026, 10, 25, 12),
      reminderOffsets: const [0],
      updatedAt: now,
    );
    final plan = buildReminderPlan(
      [past, completed, deleted, noDue, note],
      now: now,
    );
    expect(plan, isEmpty);
  });

  test('skips reminders outside the scheduling window', () {
    final plan = buildReminderPlan(
      [
        task(
          due: now.add(const Duration(days: 91)),
          reminders: const [0],
        ),
      ],
      now: now,
    );
    expect(plan, isEmpty);
  });

  test('notification ids are stable, positive and offset-specific', () {
    final a = reminderNotificationId('task:task-1:0');
    final b = reminderNotificationId('task:task-1:0');
    final c = reminderNotificationId('task:task-1:5');
    expect(a, b);
    expect(a, isNot(c));
    expect(a, greaterThan(0));
    expect(a, lessThanOrEqualTo(0x7fffffff));
  });

  test('caps the plan at max earliest items', () {
    final due = DateTime.utc(2026, 10, 25, 12);
    final plan = buildReminderPlan(
      [task(due: due, reminders: const [0, 1, 2, 3, 4, 5])],
      now: now,
      max: 2,
    );
    expect(plan.length, 2);
    expect(plan.first.offsetMinutes, 5);
  });

  test('countdown reminders fire N days before at the reminder clock', () {
    final item = CountdownItem.fromJson({
      'id': 7,
      'name': '发布日',
      'type': 'countdown',
      'repeat': 'none',
      'occurrenceDate': 20261110,
      'reminders': [0, 3],
      'reminderTime': '08:30',
    });
    final plan = buildCountdownPlan(
      [item],
      now: DateTime(2026, 11, 1, 9),
    );

    expect(plan.length, 2);
    expect(plan.first.at, DateTime(2026, 11, 7, 8, 30));
    expect(plan.first.body, '距离「发布日」还有 3 天');
    expect(plan.last.at, DateTime(2026, 11, 10, 8, 30));
    expect(plan.last.body, '今天是「发布日」');
    expect(plan.every((entry) => entry.payload == 'countdown:7'), true);
  });

  test('habit reminders repeat daily at the chosen time', () {
    final habit = HabitItem.fromJson({
      'id': 3,
      'name': '喝水',
      'reminders': ['08:00'],
      'status': 0,
    });
    final plan = buildHabitPlan([habit], now: DateTime(2026, 11, 5, 12));

    expect(plan.length, 1);
    expect(plan.single.at, DateTime(2026, 11, 6, 8));
    expect(plan.single.repeat, ReminderRepeat.daily);
    expect(plan.single.payload, 'habit:3');
    expect(plan.single.body, '喝水 今天还没有打卡');
  });

  test('archived habits are skipped', () {
    final habit = HabitItem.fromJson({
      'id': 4,
      'name': '旧习惯',
      'reminders': ['08:00'],
      'status': 1,
    });
    expect(buildHabitPlan([habit], now: DateTime(2026, 11, 5)), isEmpty);
  });

  test('missed plan only covers the window since the last heartbeat', () {
    final since = DateTime.utc(2026, 10, 25, 9);
    final inWindow = task(id: 'a', due: DateTime.utc(2026, 10, 25, 9, 30));
    final beforeWindow = task(id: 'b', due: DateTime.utc(2026, 10, 25, 8, 30));
    final future = task(id: 'c', due: DateTime.utc(2026, 10, 25, 12));
    final plan = buildMissedPlan(
      [inWindow, beforeWindow, future],
      const <CountdownItem>[],
      now: now,
      since: since,
    );
    expect(plan.map((item) => item.payload).toList(), ['task:a']);
    expect(plan.single.at, DateTime.utc(2026, 10, 25, 9, 30));
    expect(plan.single.title, '任务提醒');
  });

  test('missed plan skips completed and deleted tasks', () {
    final since = DateTime.utc(2026, 10, 25, 9);
    final done = task(
      id: 'done',
      due: DateTime.utc(2026, 10, 25, 9, 30),
      completedAt: DateTime.utc(2026, 10, 25, 9, 40),
    );
    final trash = task(
      id: 'trash',
      due: DateTime.utc(2026, 10, 25, 9, 30),
      deleted: true,
    );
    expect(
      buildMissedPlan([done, trash], const <CountdownItem>[], now: now, since: since),
      isEmpty,
    );
  });

  test('missed plan covers countdowns, habits never take part', () {
    final item = CountdownItem.fromJson({
      'id': 7,
      'name': '发布日',
      'type': 'countdown',
      'repeat': 'none',
      'occurrenceDate': 20261105,
      'reminders': [0],
      'reminderTime': '08:00',
    });
    final plan = buildMissedPlan(
      const <TaskItem>[],
      [item],
      now: DateTime(2026, 11, 5, 12),
      since: DateTime(2026, 11, 5, 6),
    );
    expect(plan.single.payload, 'countdown:7');
    expect(plan.single.at, DateTime(2026, 11, 5, 8));
    expect(plan.single.body, '今天是「发布日」');
  });

  test('missed plan skips reminders that were already queued in the OS', () {
    final since = DateTime.utc(2026, 10, 25, 9);
    final at = DateTime.utc(2026, 10, 25, 9, 30);
    // a 在退出前已经排进系统队列，系统会自己送达；b 从未排期。
    final queued = task(id: 'a', due: at);
    final neverQueued = task(id: 'b', due: at);
    final slot = reminderSlotKey(
      ReminderPlanItem(
        id: reminderNotificationId('task:a:0'),
        payload: 'task:a',
        title: '任务提醒',
        body: '',
        at: at,
      ),
    );
    final plan = buildMissedPlan(
      [queued, neverQueued],
      const <CountdownItem>[],
      now: now,
      since: since,
      alreadyScheduled: {slot},
    );
    expect(plan.map((item) => item.payload).toList(), ['task:b']);
  });

  test('labels common offsets in Chinese', () {
    expect(reminderLabel(0), '准时');
    expect(reminderLabel(5), '提前 5 分钟');
    expect(reminderLabel(60), '提前 1 小时');
    expect(reminderLabel(90), '提前 90 分钟');
    expect(reminderLabel(1440), '提前 1 天');
    expect(reminderLabel(10080), '提前 7 天');
  });

  group('badgeCount', () {
    final today = DateTime(2026, 11, 5, 21, 30);

    test('counts overdue and same-day open tasks', () {
      final count = badgeCount([
        task(id: 'a', due: DateTime(2026, 11, 5, 9)),
        task(id: 'b', due: DateTime(2026, 11, 5, 23, 59)),
        task(id: 'c', due: DateTime(2026, 11, 1, 8)),
      ], now: today);
      expect(count, 3);
    });

    test('ignores tomorrow, completed, deleted and undated rows', () {
      final count = badgeCount([
        task(id: 'later', due: DateTime(2026, 11, 6, 9)),
        task(id: 'done', due: DateTime(2026, 11, 5, 9), completedAt: DateTime(2026, 11, 5, 10)),
        task(id: 'gone', due: DateTime(2026, 11, 5, 9), deleted: true),
        task(id: 'note', due: null),
      ], now: today);
      expect(count, 0);
    });

    test('is zero for an empty list', () {
      expect(badgeCount(const <TaskItem>[], now: today), 0);
    });
  });
}
