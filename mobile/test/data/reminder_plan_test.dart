import 'package:caldav_free/core/models.dart';
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
    expect(plan.every((item) => item.taskId == 'task-1'), true);
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
    final a = reminderNotificationId('task-1', 0);
    final b = reminderNotificationId('task-1', 0);
    final c = reminderNotificationId('task-1', 5);
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

  test('labels common offsets in Chinese', () {
    expect(reminderLabel(0), '准时');
    expect(reminderLabel(5), '提前 5 分钟');
    expect(reminderLabel(60), '提前 1 小时');
    expect(reminderLabel(90), '提前 90 分钟');
    expect(reminderLabel(1440), '提前 1 天');
    expect(reminderLabel(10080), '提前 7 天');
  });
}
