import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/models.dart';
import '../../design/format.dart';

/// Kanban board: one column per synced section, plus an "unassigned" column.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.list,
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final TaskListItem list;
  final List<TaskItem> tasks;
  final void Function(TaskItem task) onOpenTask;
  final void Function(TaskItem task) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppState>().store;
    return StreamBuilder<List<TaskSection>>(
      stream: store.watchSections(listId: list.id),
      builder: (context, snapshot) {
        final sections = snapshot.data ?? const <TaskSection>[];
        final known = {for (final section in sections) section.id};
        final bySection = <String?, List<TaskItem>>{null: <TaskItem>[]};
        for (final section in sections) {
          bySection[section.id] = <TaskItem>[];
        }
        for (final task in tasks) {
          final id = known.contains(task.sectionId) ? task.sectionId : null;
          (bySection[id] ??= <TaskItem>[]).add(task);
        }
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (var index = 0; index < sections.length; index++)
              _BoardColumn(
                key: ValueKey(sections[index].id),
                list: list,
                section: sections[index],
                tasks: bySection[sections[index].id] ?? const [],
                onOpenTask: onOpenTask,
                onToggleTask: onToggleTask,
                onMoveLeft: index > 0
                    ? () => _reorderSections(
                        context,
                        list.id,
                        sections,
                        index,
                        index - 1,
                      )
                    : null,
                onMoveRight: index < sections.length - 1
                    ? () => _reorderSections(
                        context,
                        list.id,
                        sections,
                        index,
                        index + 1,
                      )
                    : null,
              ),
            _BoardColumn(
              key: const ValueKey('unassigned'),
              list: list,
              section: null,
              tasks: bySection[null] ?? const [],
              onOpenTask: onOpenTask,
              onToggleTask: onToggleTask,
            ),
            _AddColumnButton(listId: list.id),
          ],
        );
      },
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    super.key,
    required this.list,
    required this.section,
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    this.onMoveLeft,
    this.onMoveRight,
  });

  final TaskListItem list;
  final TaskSection? section;
  final List<TaskItem> tasks;
  final void Function(TaskItem task) onOpenTask;
  final void Function(TaskItem task) onToggleTask;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = section?.name ?? '未分列';
    return Container(
      width: 278,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${tasks.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (section != null)
                  PopupMenuButton<String>(
                    tooltip: '列操作',
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onSelected: (value) {
                      if (value == 'rename') {
                        _renameSection(context, section!);
                      } else if (value == 'delete') {
                        _deleteSection(context, section!);
                      } else if (value == 'left') {
                        onMoveLeft?.call();
                      } else if (value == 'right') {
                        onMoveRight?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'rename', child: Text('重命名')),
                      if (onMoveLeft != null)
                        const PopupMenuItem(value: 'left', child: Text('左移')),
                      if (onMoveRight != null)
                        const PopupMenuItem(value: 'right', child: Text('右移')),
                      const PopupMenuItem(value: 'delete', child: Text('删除列')),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<String>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) {
                _moveTask(context, details.data, section?.id);
              },
              builder: (context, candidates, rejected) {
                final active = candidates.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: tasks.isEmpty
                      ? Center(
                          child: Text(
                            active ? '放到这里' : '暂无任务',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                          itemCount: tasks.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return LongPressDraggable<String>(
                              data: task.id,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: 240,
                                  child: _BoardCard(
                                    task: task,
                                    onTap: null,
                                    onToggle: null,
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.35,
                                child: _BoardCard(
                                  task: task,
                                  onTap: null,
                                  onToggle: null,
                                ),
                              ),
                              child: _BoardCard(
                                task: task,
                                onTap: () => onOpenTask(task),
                                onToggle: () => onToggleTask(task),
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
          TextButton.icon(
            onPressed: () => _addTask(context, list, section),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('添加任务'),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
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
    final due = task.dueAt;
    final overdue = isOverdue(task);
    final priorityColor = switch (task.priority) {
      3 => const Color(0xFFEF4444),
      2 => const Color(0xFFF59E0B),
      1 => const Color(0xFF3B82F6),
      _ => null,
    };
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniCheck(task: task, onTap: onToggle),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (due != null || task.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (due != null)
                            Text(
                              formatDue(due, allDay: task.allDay),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: overdue
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                                fontWeight: overdue
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          for (final tag in task.tags.take(2))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tag,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (priorityColor != null) ...[
                const SizedBox(width: 6),
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCheck extends StatelessWidget {
  const _MiniCheck({required this.task, required this.onTap});

  final TaskItem task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: task.completed ? '标记为未完成' : '标记为完成',
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Icon(
          task.completed
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 20,
          color: task.completed ? scheme.primary : scheme.outline,
        ),
      ),
    );
  }
}

class _AddColumnButton extends StatelessWidget {
  const _AddColumnButton({required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: Align(
        alignment: Alignment.topCenter,
        child: OutlinedButton.icon(
          onPressed: () => _createSection(context, listId),
          icon: const Icon(Icons.view_column_outlined, size: 18),
          label: const Text('添加列'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}

Future<void> _reorderSections(
  BuildContext context,
  String listId,
  List<TaskSection> sections,
  int from,
  int to,
) async {
  final ids = sections.map((section) => section.id).toList();
  if (from < 0 || from >= ids.length || to < 0 || to >= ids.length) return;
  final moved = ids.removeAt(from);
  ids.insert(to, moved);
  try {
    await context.read<AppState>().repository.reorderSections(listId, ids);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('排序失败：$error')));
  }
}

Future<void> _moveTask(
  BuildContext context,
  String taskId,
  String? sectionId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<AppState>().repository.moveTaskToSection(
      taskId,
      sectionId,
    );
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('移动失败：$error')));
  }
}

Future<void> _createSection(BuildContext context, String listId) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('新建列'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '列名称'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('创建'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<AppState>().repository.createSection(
      listId: listId,
      name: name,
    );
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('创建失败：$error')));
  }
}

Future<void> _renameSection(BuildContext context, TaskSection section) async {
  final controller = TextEditingController(text: section.name);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('重命名列'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '列名称'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty || !context.mounted) return;
  try {
    await context.read<AppState>().repository.renameSection(section.id, name);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('重命名失败：$error')));
  }
}

Future<void> _deleteSection(BuildContext context, TaskSection section) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除列？'),
      content: Text('“${section.name}”中的任务会移到「未分列」，任务本身不会删除。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await context.read<AppState>().repository.deleteSection(section.id);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('删除失败：$error')));
  }
}

Future<void> _addTask(
  BuildContext context,
  TaskListItem list,
  TaskSection? section,
) async {
  final controller = TextEditingController();
  final title = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(section?.name ?? '添加任务'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '任务标题'),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('添加'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (title == null || title.isEmpty || !context.mounted) return;
  final repository = context.read<AppState>().repository;
  try {
    final task = await repository.createTask(title: title, listId: list.id);
    if (section != null) {
      await repository.moveTaskToSection(task.id, section.id);
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('添加失败：$error')));
  }
}
