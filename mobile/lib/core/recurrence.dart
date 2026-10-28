const Map<String, int> _weekdays = {
  'MO': DateTime.monday,
  'TU': DateTime.tuesday,
  'WE': DateTime.wednesday,
  'TH': DateTime.thursday,
  'FR': DateTime.friday,
  'SA': DateTime.saturday,
  'SU': DateTime.sunday,
};

/// 离线展开重复任务：[anchor] 是第一次出现的日期（服务端取截止日期），返回落在
/// [from, to] 闭区间内的日期，最多 [limit] 条，且不早于 [anchor]。
///
/// 服务端用 Go 的 rrule-go 展开（internal/tasks/recur.go），客户端没有等价依赖，
/// 这里只覆盖编辑器预设的规则。带其它部件的自定义规则退回"仅在锚点当天出现一次"，
/// 宁可不展开，也不给出和服务端不一致的日期。
List<DateTime> occurrencesBetween(
  String rule,
  DateTime anchor,
  DateTime from,
  DateTime to, {
  int limit = 500,
}) {
  if (to.isBefore(from)) return const [];
  final parsed = _Rule.parse(rule);
  if (parsed == null) {
    return _inside(anchor, from, to) ? [anchor] : const [];
  }
  final until = parsed.until;
  final bound = until != null && until.isBefore(to) ? until : to;
  final out = <DateTime>[];
  var emitted = 0;
  for (final occurrence in parsed.sequence(anchor, bound)) {
    if (occurrence.isBefore(anchor)) continue;
    emitted++;
    final count = parsed.count;
    if (count != null && emitted > count) break;
    if (!_inside(occurrence, from, to)) continue;
    out.add(occurrence);
    if (out.length >= limit) break;
  }
  return out;
}

/// 规则文字对应的中文说法，编辑器用它把"截止日期就是重复起点"讲清楚。
String recurrenceLabel(String rule) {
  final parsed = _Rule.parse(rule);
  if (parsed == null) return rule.trim();
  final every = parsed.interval > 1 ? '每 ${parsed.interval} ' : '每';
  return switch (parsed.freq) {
    'DAILY' => '$every天',
    'WEEKLY' => parsed.byDay.isEmpty
        ? '$every周'
        : '$every周 ${parsed.byDay.map(_weekdayLabel).join('、')}',
    'MONTHLY' => '$every月',
    _ => '$every年',
  };
}

String _weekdayLabel(int weekday) => const [
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
][weekday - 1];

bool _inside(DateTime value, DateTime from, DateTime to) =>
    !value.isBefore(from) && !value.isAfter(to);

DateTime _shiftDays(DateTime base, int days) => DateTime(
  base.year,
  base.month,
  base.day + days,
  base.hour,
  base.minute,
  base.second,
);

/// 目标月份没有这一天（2 月 30 日、平年 2 月 29 日）时返回 null，跳过该次。
DateTime? _at(int year, int month, int day, DateTime time) {
  final candidate = DateTime(
    year,
    month,
    day,
    time.hour,
    time.minute,
    time.second,
  );
  return candidate.year == year &&
      candidate.month == month &&
      candidate.day == day
      ? candidate
      : null;
}

class _Rule {
  const _Rule({
    required this.freq,
    required this.interval,
    required this.byDay,
    this.count,
    this.until,
  });

  final String freq;
  final int interval;
  final List<int> byDay;
  final int? count;
  final DateTime? until;

  static _Rule? parse(String rule) {
    var body = rule.trim();
    if (body.toUpperCase().startsWith('RRULE:')) {
      body = body.substring(6).trim();
    }
    if (body.isEmpty) return null;
    var freq = '';
    var interval = 1;
    var byDay = const <int>[];
    int? count;
    DateTime? until;
    for (final part in body.split(';')) {
      final eq = part.indexOf('=');
      if (eq <= 0) return null;
      final key = part.substring(0, eq).trim().toUpperCase();
      final value = part.substring(eq + 1).trim().toUpperCase();
      switch (key) {
        case 'FREQ':
          freq = value;
        case 'INTERVAL':
          interval = int.tryParse(value) ?? 0;
        case 'COUNT':
          count = int.tryParse(value);
        case 'UNTIL':
          until = _parseUntil(value);
          if (until == null) return null;
        case 'BYDAY':
          final days = <int>[];
          for (final code in value.split(',')) {
            final weekday = _weekdays[code.trim()];
            if (weekday == null) return null;
            days.add(weekday);
          }
          byDay = [...days]..sort();
        default:
          // BYMONTHDAY、BYSETPOS、WKST 等留给服务端展开。
          return null;
      }
    }
    if (interval < 1) return null;
    final known =
        freq == 'DAILY' ||
        freq == 'WEEKLY' ||
        freq == 'MONTHLY' ||
        freq == 'YEARLY';
    if (!known) return null;
    if (byDay.isNotEmpty && freq != 'WEEKLY') return null;
    return _Rule(
      freq: freq,
      interval: interval,
      byDay: byDay,
      count: count,
      until: until,
    );
  }

  /// 从 [anchor] 起按升序产出日期，超过 [bound] 就停。
  Iterable<DateTime> sequence(DateTime anchor, DateTime bound) sync* {
    switch (freq) {
      case 'DAILY':
        for (
          var cursor = anchor;
          !cursor.isAfter(bound);
          cursor = _shiftDays(cursor, interval)
        ) {
          yield cursor;
        }
      case 'WEEKLY':
        if (byDay.isEmpty) {
          for (
            var cursor = anchor;
            !cursor.isAfter(bound);
            cursor = _shiftDays(cursor, 7 * interval)
          ) {
            yield cursor;
          }
        } else {
          final monday = DateTime(
            anchor.year,
            anchor.month,
            anchor.day - (anchor.weekday - DateTime.monday),
            anchor.hour,
            anchor.minute,
            anchor.second,
          );
          for (var week = 0;; week++) {
            final base = _shiftDays(monday, 7 * interval * week);
            if (base.isAfter(bound)) break;
            for (final weekday in byDay) {
              final occurrence = _shiftDays(base, weekday - DateTime.monday);
              if (occurrence.isAfter(bound)) break;
              yield occurrence;
            }
          }
        }
      case 'MONTHLY':
        var year = anchor.year;
        var month = anchor.month;
        while (!DateTime(year, month).isAfter(bound)) {
          final occurrence = _at(year, month, anchor.day, anchor);
          if (occurrence != null && !occurrence.isAfter(bound)) {
            yield occurrence;
          }
          month += interval;
          year += (month - 1) ~/ 12;
          month = (month - 1) % 12 + 1;
        }
      case 'YEARLY':
        var year = anchor.year;
        while (!DateTime(year, anchor.month).isAfter(bound)) {
          final occurrence = _at(year, anchor.month, anchor.day, anchor);
          if (occurrence != null && !occurrence.isAfter(bound)) {
            yield occurrence;
          }
          year += interval;
        }
    }
  }
}

DateTime? _parseUntil(String value) {
  final zulu = value.endsWith('Z');
  final body = zulu ? value.substring(0, value.length - 1) : value;
  if (body.length != 8 && body.length != 15) return null;
  if (body.length == 15 && body[8] != 'T') return null;
  final date = int.tryParse(body.substring(0, 8));
  if (date == null) return null;
  final year = date ~/ 10000;
  final month = date ~/ 100 % 100;
  final day = date % 100;
  var hour = 0;
  var minute = 0;
  var second = 0;
  if (body.length == 15) {
    final time = int.tryParse(body.substring(9));
    if (time == null) return null;
    hour = time ~/ 10000;
    minute = time ~/ 100 % 100;
    second = time % 100;
  }
  return zulu
      ? DateTime.utc(year, month, day, hour, minute, second).toLocal()
      : DateTime(year, month, day, hour, minute, second);
}
