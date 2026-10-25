import '../../core/models.dart';

/// One notification we want Android to deliver.
class ReminderPlanItem {
  const ReminderPlanItem({
    required this.id,
    required this.taskId,
    required this.body,
    required this.at,
    required this.offsetMinutes,
  });

  final int id;
  final String taskId;
  final String body;
  final DateTime at;
  final int offsetMinutes;
}

/// Builds the desired notification set from local tasks.
///
/// Pure Dart: no plugin, no platform channels, so the date math and ID
/// stability are unit-testable.
///
/// Rules:
/// - only open task rows (`kind=task`, not deleted, not completed);
/// - require a due time and at least one reminder offset;
/// - skip reminders whose fire time is at or before [now] (or outside the
///   scheduling window);
/// - stable ID = FNV-1a of `taskId:offset`, positive 31-bit;
/// - at most [max] future notifications, earliest first.
List<ReminderPlanItem> buildReminderPlan(
  Iterable<TaskItem> tasks, {
  required DateTime now,
  int max = 120,
  Duration window = const Duration(days: 90),
}) {
  final cutoff = now.toUtc();
  final until = cutoff.add(window);
  final byId = <int, ReminderPlanItem>{};

  for (final task in tasks) {
    if (task.kind != TaskKind.task ||
        task.deleted ||
        task.completed ||
        task.dueAt == null ||
        task.reminderOffsets.isEmpty) {
      continue;
    }
    for (final offset in task.reminderOffsets) {
      if (offset < 0 || offset > 10080) continue;
      final at = task.dueAt!.toUtc().subtract(Duration(minutes: offset));
      if (!at.isAfter(cutoff) || at.isAfter(until)) continue;
      final id = reminderNotificationId(task.id, offset);
      byId[id] = ReminderPlanItem(
        id: id,
        taskId: task.id,
        body: task.title,
        at: at,
        offsetMinutes: offset,
      );
    }
  }

  final plan = byId.values.toList()
    ..sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
  if (plan.length <= max) return plan;
  return plan.sublist(0, max);
}

/// Stable positive 31-bit ID for (taskId, offset).
int reminderNotificationId(String taskId, int offsetMinutes) {
  var hash = 0x811c9dc5;
  for (final code in '$taskId:$offsetMinutes'.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final id = hash & 0x7fffffff;
  return id == 0 ? 1 : id;
}

String reminderLabel(int minutes) {
  if (minutes <= 0) return '准时';
  if (minutes < 60) return '提前 $minutes 分钟';
  if (minutes == 60) return '提前 1 小时';
  if (minutes % 1440 == 0) {
    final days = minutes ~/ 1440;
    return '提前 $days 天';
  }
  if (minutes % 60 == 0) {
    return '提前 ${minutes ~/ 60} 小时';
  }
  return '提前 $minutes 分钟';
}
