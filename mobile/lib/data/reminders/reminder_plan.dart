import '../../core/models.dart';
import '../countdowns/countdown_api.dart';
import '../habits/habit_api.dart';

/// 通知的重复方式。日程/倒数日/任务都是一次性，习惯是每天固定时间。
enum ReminderRepeat { none, daily }

/// One native notification we want the OS to deliver.
class ReminderPlanItem {
  const ReminderPlanItem({
    required this.id,
    required this.payload,
    required this.title,
    required this.body,
    required this.at,
    this.offsetMinutes = 0,
    this.repeat = ReminderRepeat.none,
  });

  final int id;

  /// `task:12` / `countdown:3` / `habit:7`，点击通知时用来跳转。
  final String payload;
  final String title;
  final String body;
  final DateTime at;
  final int offsetMinutes;
  final ReminderRepeat repeat;
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
/// - stable ID = FNV-1a of the payload, positive 31-bit;
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
      final payload = 'task:${task.id}';
      final id = reminderNotificationId('$payload:$offset');
      byId[id] = ReminderPlanItem(
        id: id,
        payload: payload,
        title: '任务提醒',
        body: task.title,
        at: at,
        offsetMinutes: offset,
      );
    }
  }

  return _sortedCapped(byId.values, max);
}

/// 倒数日：在「发生日 - 偏移天数」当天的 reminderTime 提醒，和 Web 端一致。
List<ReminderPlanItem> buildCountdownPlan(
  Iterable<CountdownItem> countdowns, {
  required DateTime now,
  int max = 60,
  Duration window = const Duration(days: 366),
}) {
  final cutoff = now;
  final until = now.add(window);
  final byId = <int, ReminderPlanItem>{};

  for (final item in countdowns) {
    if (item.reminders.isEmpty) continue;
    final day = _countdownDay(item.occurrenceDate);
    if (day == null) continue;
    final clock = _parseClock(item.reminderTime) ?? (9, 0);
    for (final offset in item.reminders) {
      if (offset < 0 || offset > 3650) continue;
      final at = DateTime(
        day.year,
        day.month,
        day.day - offset,
        clock.$1,
        clock.$2,
      );
      if (!at.isAfter(cutoff) || at.isAfter(until)) continue;
      final payload = 'countdown:${item.id}';
      final id = reminderNotificationId(
        '$payload:${item.occurrenceDate}:$offset',
      );
      byId[id] = ReminderPlanItem(
        id: id,
        payload: payload,
        title: '倒数日提醒',
        body: offset == 0
            ? '今天是「${item.name}」'
            : '距离「${item.name}」还有 $offset 天',
        at: at,
        offsetMinutes: offset,
      );
    }
  }

  return _sortedCapped(byId.values, max);
}

/// 一条「具体投递」的唯一标识：通知 id + 触发时刻（秒级）。
///
/// 任务改了截止时间后通知 id 不变（id 只由 payload 和偏移算出），但投递时刻
/// 会变，所以必须两者一起才代表这一条通知。
///
/// 时刻取到秒：`due_at` 在本地库里是以秒为单位的 Unix 时间戳，重启后从库里
/// 读回来的时间戳毫秒位为 0，如果这里带上毫秒就会和排期时算出的值对不上。
String reminderSlotKey(ReminderPlanItem item) =>
    '${item.id}@${item.at.toUtc().millisecondsSinceEpoch ~/ 1000}';

/// 应用不在运行期间到点、没能送达的提醒。
///
/// 补发窗口由 [since] 决定（通常是上一次进程存活的心跳时间），只取
/// `since < at <= now` 的提醒；习惯是每天重复、错过一次不影响下一次，
/// 因此不参与补发。
///
/// [alreadyScheduled] 是上一进程退出前已经排进系统队列的槽位（见
/// [reminderSlotKey]）。这些提醒到点后系统会照常投递，不能再算「错过」，
/// 否则用户会同时收到系统通知和这条补发汇总。
List<ReminderPlanItem> buildMissedPlan(
  Iterable<TaskItem> tasks,
  Iterable<CountdownItem> countdowns, {
  required DateTime now,
  required DateTime since,
  int max = 50,
  Set<String> alreadyScheduled = const <String>{},
}) {
  final cutoff = now.toUtc();
  final floor = since.toUtc();
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
      if (!at.isAfter(floor) || at.isAfter(cutoff)) continue;
      final payload = 'task:${task.id}';
      final id = reminderNotificationId('$payload:$offset');
      final item = ReminderPlanItem(
        id: id,
        payload: payload,
        title: '任务提醒',
        body: task.title,
        at: at,
        offsetMinutes: offset,
      );
      // 退出前已经排进系统队列的，系统会自己送达，这里不再补。
      if (alreadyScheduled.contains(reminderSlotKey(item))) continue;
      byId[id] = item;
    }
  }

  for (final item in countdowns) {
    if (item.reminders.isEmpty) continue;
    final day = _countdownDay(item.occurrenceDate);
    if (day == null) continue;
    final clock = _parseClock(item.reminderTime) ?? (9, 0);
    for (final offset in item.reminders) {
      if (offset < 0 || offset > 3650) continue;
      final at = DateTime(
        day.year,
        day.month,
        day.day - offset,
        clock.$1,
        clock.$2,
      );
      if (!at.isAfter(since) || at.isAfter(now)) continue;
      final payload = 'countdown:${item.id}';
      final id = reminderNotificationId(
        '$payload:${item.occurrenceDate}:$offset',
      );
      final planItem = ReminderPlanItem(
        id: id,
        payload: payload,
        title: '倒数日提醒',
        body: offset == 0
            ? '今天是「${item.name}」'
            : '距离「${item.name}」还有 $offset 天',
        at: at,
        offsetMinutes: offset,
      );
      if (alreadyScheduled.contains(reminderSlotKey(planItem))) continue;
      byId[id] = planItem;
    }
  }

  return _sortedCapped(byId.values, max);
}

/// 应用图标角标数：今天到期或已经逾期、但仍未完成的任务数。
///
/// 只算任务，不把习惯和倒数日算进去——角标是“还有几件待办压着”的提示，
/// 每天重复的习惯会让数字永远降不下来。
int badgeCount(Iterable<TaskItem> tasks, {required DateTime now}) {
  final local = now.toLocal();
  final endOfDay = DateTime(
    local.year,
    local.month,
    local.day,
  ).add(const Duration(days: 1));
  var count = 0;
  for (final task in tasks) {
    if (task.kind != TaskKind.task || task.deleted || task.completed) continue;
    final due = task.dueAt?.toLocal();
    if (due == null) continue;
    if (due.isBefore(endOfDay)) count++;
  }
  return count;
}

/// 习惯：每天在设定的时间提醒（和 Web 端一致，按天重复，不区分频率）。
List<ReminderPlanItem> buildHabitPlan(
  Iterable<HabitItem> habits, {
  required DateTime now,
  int max = 60,
}) {
  final byId = <int, ReminderPlanItem>{};

  for (final habit in habits) {
    if (habit.archived || habit.reminders.isEmpty) continue;
    for (final raw in habit.reminders) {
      final clock = _parseClock(raw);
      if (clock == null) continue;
      var at = DateTime(now.year, now.month, now.day, clock.$1, clock.$2);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      final payload = 'habit:${habit.id}';
      final id = reminderNotificationId('$payload:${clock.$1}:${clock.$2}');
      byId[id] = ReminderPlanItem(
        id: id,
        payload: payload,
        title: '习惯提醒',
        body: '${habit.name} 今天还没有打卡',
        at: at,
        repeat: ReminderRepeat.daily,
      );
    }
  }

  return _sortedCapped(byId.values, max);
}

List<ReminderPlanItem> _sortedCapped(
  Iterable<ReminderPlanItem> items,
  int max,
) {
  final plan = items.toList()
    ..sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
  if (plan.length <= max) return plan;
  return plan.sublist(0, max);
}

/// `occurrenceDate` 是 YYYYMMDD 形式的整数。
DateTime? _countdownDay(int stamp) {
  if (stamp <= 0) return null;
  final raw = stamp.toString().padLeft(8, '0');
  if (raw.length != 8) return null;
  final year = int.tryParse(raw.substring(0, 4));
  final month = int.tryParse(raw.substring(4, 6));
  final day = int.tryParse(raw.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

(int, int)? _parseClock(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour, minute);
}

/// Stable positive 31-bit ID for a notification key.
int reminderNotificationId(String key) {
  var hash = 0x811c9dc5;
  for (final code in key.codeUnits) {
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
