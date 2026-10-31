import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../design/format.dart';

/// Eisenhower matrix matching the web default rule ("按优先级"):
/// priority 3 → Q1, 2 → Q2, 1 → Q3, 0 (or none) → Q4.
class MatrixView extends StatelessWidget {
  const MatrixView({
    super.key,
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    this.lists = const [],
    this.groupByList = false,
  });

  final List<TaskItem> tasks;
  final void Function(TaskItem task) onOpenTask;
  final void Function(TaskItem task) onToggleTask;
  final List<TaskListItem> lists;
  final bool groupByList;

  @override
  Widget build(BuildContext context) {
    final quadrants = List.generate(4, (_) => <TaskItem>[]);
    for (final task in tasks) {
      final priority = task.priority > 3 || task.priority < 0
          ? 0
          : task.priority;
      final index = priority >= 3
          ? 0
          : priority == 2
          ? 1
          : priority == 1
          ? 2
          : 3;
      quadrants[index].add(task);
    }
    Widget quadrant({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required int index,
    }) => _Quadrant(
      key: ValueKey('matrix-q$index'),
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      tasks: quadrants[index],
      lists: lists,
      groupByList: groupByList,
      onOpenTask: onOpenTask,
      onToggleTask: onToggleTask,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: quadrant(
                    title: '重要且紧急',
                    subtitle: '优先处理',
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFEF4444),
                      index: 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: quadrant(
                    title: '重要不紧急',
                    subtitle: '计划推进',
                    icon: Icons.flag_rounded,
                    color: const Color(0xFF3B82F6),
                      index: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: quadrant(
                    title: '紧急不重要',
                    subtitle: '尽快处理',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFF59E0B),
                      index: 2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: quadrant(
                    title: '不重要不紧急',
                    subtitle: '有空再做',
                    icon: Icons.spa_rounded,
                    color: const Color(0xFF22C55E),
                      index: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Quadrant extends StatelessWidget {
  const _Quadrant({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    this.lists = const [],
    this.groupByList = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<TaskItem> tasks;
  final void Function(TaskItem task) onOpenTask;
  final void Function(TaskItem task) onToggleTask;
  final List<TaskListItem> lists;
  final bool groupByList;

  Widget _card(TaskItem task) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: _MatrixTask(
      task: task,
      onTap: () => onOpenTask(task),
      onToggle: () => onToggleTask(task),
    ),
  );

  List<Widget> _rows(BuildContext context) {
    if (!groupByList || lists.length < 2) {
      return [for (final task in tasks) _card(task)];
    }
    final scheme = Theme.of(context).colorScheme;
    final order = {for (var i = 0; i < lists.length; i++) lists[i].id: i};
    final byList = <String, List<TaskItem>>{};
    for (final task in tasks) {
      (byList[task.listId] ??= <TaskItem>[]).add(task);
    }
    final ids =
        byList.keys.toList()
          ..sort(
            (a, b) => (order[a] ?? lists.length).compareTo(
              order[b] ?? lists.length,
            ),
          );
    final rows = <Widget>[];
    for (final id in ids) {
      TaskListItem? list;
      for (final candidate in lists) {
        if (candidate.id == id) {
          list = candidate;
          break;
        }
      }
      if (list != null) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 3),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorFromHex(list.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  list.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      for (final task in byList[id]!) {
        rows.add(_card(task));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      '暂无任务',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    children: _rows(context),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MatrixTask extends StatelessWidget {
  const _MatrixTask({
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final due = task.dueAt;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (due != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatDue(due, allDay: task.allDay),
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
