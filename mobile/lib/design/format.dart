import 'package:flutter/material.dart';

import '../core/models.dart';

Color colorFromHex(String raw, {Color fallback = const Color(0xFF5B6CFF)}) {
  var value = raw.trim();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

/// Same palette as `web/src/tag-colors.ts`, so a tag keeps one color on every
/// client.
const _tagPalette = <Color>[
  Color(0xFF4772FA),
  Color(0xFFE5484D),
  Color(0xFFF76B15),
  Color(0xFFF5B301),
  Color(0xFF30A46C),
  Color(0xFF12A594),
  Color(0xFF00A2C7),
  Color(0xFF6E56CF),
  Color(0xFFD6409F),
  Color(0xFF8E4EC6),
  Color(0xFF64748B),
  Color(0xFFAB6400),
];

/// Stable color for a tag name, matching the web admin's hash.
Color tagColorForName(String name) {
  var hash = 0;
  for (final code in name.codeUnits) {
    hash = (hash * 31 + code) & 0xFFFFFFFF;
  }
  return _tagPalette[hash % _tagPalette.length];
}

String formatDue(DateTime? due, {required bool allDay}) {
  if (due == null) return '';
  final local = due.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = day.difference(today).inDays;
  final time = allDay
      ? ''
      : ' ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  switch (diff) {
    case 0:
      return '今天$time';
    case 1:
      return '明天$time';
    case -1:
      return '昨天$time';
    default:
      if (local.year == now.year) {
        return '${local.month}月${local.day}日$time';
      }
      return '${local.year}/${local.month}/${local.day}$time';
  }
}

String relativeTime(DateTime? at) {
  if (at == null) return '从未';
  final diff = DateTime.now().toUtc().difference(at.toUtc());
  if (diff.inSeconds < 30) return '刚刚';
  if (diff.inMinutes < 1) return '${diff.inSeconds} 秒前';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  return '${diff.inDays} 天前';
}

bool isOverdue(TaskItem task) {
  final due = task.dueAt;
  if (due == null || task.completed) return false;
  return due.isBefore(DateTime.now().toUtc());
}
