import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../design/format.dart';

enum TimelineScale { day, week, month }

/// Day/week/month timeline. Tasks can be dragged between buckets to reschedule.
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onReschedule,
    required this.scale,
    this.anchor,
  });

  final List<TaskItem> tasks;
  final void Function(TaskItem task) onOpenTask;
  final void Function(TaskItem task) onToggleTask;
  final void Function(TaskItem task, DateTime? due) onReschedule;
  final TimelineScale scale;
  final DateTime? anchor;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final anchorDay = anchor == null
        ? today
        : DateTime(anchor!.year, anchor!.month, anchor!.day);
    final start = switch (scale) {
      TimelineScale.day => anchorDay,
      TimelineScale.week => anchorDay.subtract(
        Duration(days: anchorDay.weekday - 1),
      ),
      TimelineScale.month => DateTime(anchorDay.year, anchorDay.month),
    };
    final count = switch (scale) {
      TimelineScale.day => 14,
      TimelineScale.week => 8,
      TimelineScale.month => 3,
    };
    final end = switch (scale) {
      TimelineScale.day => start.add(Duration(days: count)),
      TimelineScale.week => start.add(Duration(days: count * 7)),
      TimelineScale.month => DateTime(start.year, start.month + count),
    };
    final buckets = <String, List<TaskItem>>{};
    final undated = <TaskItem>[];
    final farFuture = <TaskItem>[];
    for (final task in tasks) {
      final due = task.dueAt?.toLocal();
      if (due == null) {
        undated.add(task);
        continue;
      }
      final day = DateTime(due.year, due.month, due.day);
      if (day.isBefore(start)) {
        buckets.putIfAbsent('earlier', () => <TaskItem>[]).add(task);
      } else if (day.isBefore(end)) {
        buckets.putIfAbsent(_bucketKey(day), () => <TaskItem>[]).add(task);
      } else {
        farFuture.add(task);
      }
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _TimelineColumn(
          title: '无日期',
          subtitle: '拖入设置日期',
          tasks: undated,
          acceptsDrop: true,
          onDrop: (task) => onReschedule(task, null),
          onOpenTask: onOpenTask,
          onToggleTask: onToggleTask,
        ),
        if (buckets['earlier']?.isNotEmpty == true)
          _TimelineColumn(
            title: anchorDay == today ? '已逾期' : '更早',
            subtitle: '${buckets['earlier']!.length} 项',
            tasks: buckets['earlier']!,
            acceptsDrop: false,
            onDrop: null,
            onOpenTask: onOpenTask,
            onToggleTask: onToggleTask,
            accent: const Color(0xFFEF4444),
          ),
        for (var i = 0; i < count; i++)
          _TimelineColumn(
            width: scale == TimelineScale.day ? 196 : 220,
            title: _bucketTitle(start, i),
            subtitle: _bucketSubtitle(start, i),
            tasks: buckets[_bucketKey(_bucketStart(start, i))] ?? const [],
            acceptsDrop: true,
            onDrop: (task) =>
                onReschedule(task, _dropDate(task, _bucketStart(start, i))),
            onOpenTask: onOpenTask,
            onToggleTask: onToggleTask,
            today: _isToday(_bucketStart(start, i)),
          ),
        _TimelineColumn(
          title: '以后',
          subtitle: '${farFuture.length} 项',
          tasks: farFuture,
          acceptsDrop: false,
          onDrop: null,
          onOpenTask: onOpenTask,
          onToggleTask: onToggleTask,
        ),
      ],
    );
  }

  DateTime _bucketStart(DateTime start, int index) => switch (scale) {
    TimelineScale.day => start.add(Duration(days: index)),
    TimelineScale.week => start.add(Duration(days: index * 7)),
    TimelineScale.month => DateTime(start.year, start.month + index),
  };

  String _bucketKey(DateTime day) => switch (scale) {
    TimelineScale.day => _dayKey(day),
    TimelineScale.week => _dayKey(
      day.subtract(Duration(days: day.weekday - 1)),
    ),
    TimelineScale.month => '${day.year}-${day.month}',
  };

  String _bucketTitle(DateTime start, int index) {
    final target = _bucketStart(start, index);
    switch (scale) {
      case TimelineScale.day:
        if (index == 0) return '今天';
        if (index == 1) return '明天';
        return '${target.month}月${target.day}日';
      case TimelineScale.week:
        if (index == 0) return '本周';
        if (index == 1) return '下周';
        return '${target.month}月${target.day}日周';
      case TimelineScale.month:
        if (index == 0) return '${target.month}月';
        return '${target.year}年${target.month}月';
    }
  }

  String _bucketSubtitle(DateTime start, int index) {
    final target = _bucketStart(start, index);
    switch (scale) {
      case TimelineScale.day:
        return _weekday(target);
      case TimelineScale.week:
        final end = target.add(const Duration(days: 6));
        return '${target.month}/${target.day} - ${end.month}/${end.day}';
      case TimelineScale.month:
        return index == 0 ? '本月' : '${target.month}月';
    }
  }

  DateTime? _dropDate(TaskItem task, DateTime bucketStart) {
    final existing = task.dueAt?.toLocal();
    switch (scale) {
      case TimelineScale.day:
        if (task.allDay || existing == null) {
          return DateTime(bucketStart.year, bucketStart.month, bucketStart.day);
        }
        return DateTime(
          bucketStart.year,
          bucketStart.month,
          bucketStart.day,
          existing.hour,
          existing.minute,
        );
      case TimelineScale.week:
        final weekday = existing?.weekday ?? DateTime.monday;
        final date = bucketStart.add(Duration(days: weekday - 1));
        if (task.allDay || existing == null) {
          return DateTime(date.year, date.month, date.day);
        }
        return DateTime(
          date.year,
          date.month,
          date.day,
          existing.hour,
          existing.minute,
        );
      case TimelineScale.month:
        final day = existing?.day ?? 1;
        final last = DateTime(bucketStart.year, bucketStart.month + 1, 0).day;
        final date = DateTime(
          bucketStart.year,
          bucketStart.month,
          day > last ? last : day,
        );
        if (task.allDay || existing == null) return date;
        return DateTime(
          date.year,
          date.month,
          date.day,
          existing.hour,
          existing.minute,
        );
    }
  }

  static bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  static String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  static String _weekday(DateTime day) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[day.weekday - 1];
  }
}

class _TimelineColumn extends StatelessWidget {
  const _TimelineColumn({
    required this.title,
    required this.subtitle,
    required this.tasks,
    required this.acceptsDrop,
    required this.onDrop,
    required this.onOpenTask,
    required this.onToggleTask,
    this.width = 196,
    this.accent,
    this.today = false,
  });

  final String title;
  final String subtitle;
  final List<TaskItem> tasks;
  final bool acceptsDrop;
  final void Function(TaskItem task)? onDrop;
  final void Function(TaskItem task) onOpenTask;
  final void Function(TaskItem task) onToggleTask;
  final double width;
  final Color? accent;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = accent ?? scheme.primary;
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: today
            ? scheme.primary.withValues(alpha: 0.045)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: today
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: today || accent != null ? color : null,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${tasks.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _withDrop(
              context,
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        acceptsDrop ? '拖入任务' : '暂无任务',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return LongPressDraggable<TaskItem>(
                          data: task,
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: 180,
                              child: _TimelineCard(
                                task: task,
                                onTap: null,
                                onToggle: null,
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.35,
                            child: _TimelineCard(
                              task: task,
                              onTap: null,
                              onToggle: null,
                            ),
                          ),
                          child: _TimelineCard(
                            task: task,
                            onTap: () => onOpenTask(task),
                            onToggle: () => onToggleTask(task),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _withDrop(BuildContext context, {required Widget child}) {
    if (!acceptsDrop || onDrop == null) return child;
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<TaskItem>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDrop!(details.data),
      builder: (context, candidates, rejected) => Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? scheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  final TaskItem task;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: task.completed ? '标记为未完成' : '标记为完成',
                button: true,
                child: InkResponse(
                  onTap: onToggle,
                  radius: 16,
                  child: Icon(
                    task.completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 17,
                    color: task.completed ? scheme.primary : scheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (task.dueAt != null && !task.allDay) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatDue(task.dueAt, allDay: false),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isOverdue(task)
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
