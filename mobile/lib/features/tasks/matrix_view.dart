import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../design/format.dart';

/// Eisenhower matrix: important = priority 2/3, urgent = due within 2 days.
class MatrixView extends StatelessWidget {
  const MatrixView({
    super.key,
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final List<TaskItem> tasks;
  final void Function(TaskItem task) onOpenTask;
  final void Function(TaskItem task) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final urgentBefore = now.add(const Duration(days: 2));
    final quadrants = List.generate(4, (_) => <TaskItem>[]);
    for (final task in tasks) {
      final important = task.priority >= 2;
      final urgent =
          task.dueAt != null && task.dueAt!.toUtc().isBefore(urgentBefore);
      final index = important ? (urgent ? 0 : 1) : (urgent ? 2 : 3);
      quadrants[index].add(task);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Quadrant(
                    title: '重要且紧急',
                    subtitle: '优先处理',
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFEF4444),
                    tasks: quadrants[0],
                    onOpenTask: onOpenTask,
                    onToggleTask: onToggleTask,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Quadrant(
                    title: '重要不紧急',
                    subtitle: '计划推进',
                    icon: Icons.flag_rounded,
                    color: const Color(0xFF3B82F6),
                    tasks: quadrants[1],
                    onOpenTask: onOpenTask,
                    onToggleTask: onToggleTask,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Quadrant(
                    title: '紧急不重要',
                    subtitle: '尽快处理',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFF59E0B),
                    tasks: quadrants[2],
                    onOpenTask: onOpenTask,
                    onToggleTask: onToggleTask,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Quadrant(
                    title: '不重要不紧急',
                    subtitle: '有空再做',
                    icon: Icons.spa_rounded,
                    color: const Color(0xFF22C55E),
                    tasks: quadrants[3],
                    onOpenTask: onOpenTask,
                    onToggleTask: onToggleTask,
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
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<TaskItem> tasks;
  final void Function(TaskItem task) onOpenTask;
  final void Function(TaskItem task) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      '暂无任务',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _MatrixTask(
                        task: task,
                        onTap: () => onOpenTask(task),
                        onToggle: () => onToggleTask(task),
                      );
                    },
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
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
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
