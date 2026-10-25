import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../design/format.dart';

/// A simple 14-day timeline. Tasks can be dragged between days to reschedule.
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onReschedule,
  }) : days = 14;

  final List<TaskItem> tasks;
  final void Function(TaskItem task) onOpenTask;
  final void Function(TaskItem task) onToggleTask;
  final void Function(TaskItem task, DateTime? due) onReschedule;
  final int days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(Duration(days: days));
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
      if (day.isBefore(today)) {
        buckets.putIfAbsent('overdue', () => <TaskItem>[]).add(task);
      } else if (day.isBefore(end)) {
        buckets.putIfAbsent(_dayKey(day), () => <TaskItem>[]).add(task);
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
        if (buckets['overdue']?.isNotEmpty == true)
          _TimelineColumn(
            title: '已逾期',
            subtitle: '${buckets['overdue']!.length} 项',
            tasks: buckets['overdue']!,
            acceptsDrop: false,
            onDrop: null,
            onOpenTask: onOpenTask,
            onToggleTask: onToggleTask,
            accent: const Color(0xFFEF4444),
          ),
        for (var i = 0; i < days; i++)
          _TimelineColumn(
            title: _dayTitle(today.add(Duration(days: i)), i),
            subtitle: _weekday(today.add(Duration(days: i))),
            tasks: buckets[_dayKey(today.add(Duration(days: i)))] ?? const [],
            acceptsDrop: true,
            onDrop: (task) {
              final existing = task.dueAt?.toLocal();
              final date = today.add(Duration(days: i));
              final due = task.allDay || existing == null
                  ? DateTime(date.year, date.month, date.day)
                  : DateTime(
                      date.year,
                      date.month,
                      date.day,
                      existing.hour,
                      existing.minute,
                    );
              onReschedule(task, due.toUtc());
            },
            onOpenTask: onOpenTask,
            onToggleTask: onToggleTask,
            today: i == 0,
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

  static String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  static String _dayTitle(DateTime day, int index) {
    if (index == 0) return '今天';
    if (index == 1) return '明天';
    return '${day.month}月${day.day}日';
  }

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
  final Color? accent;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = accent ?? scheme.primary;
    return Container(
      width: 196,
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
