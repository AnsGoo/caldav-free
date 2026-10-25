import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/models.dart';
import '../../design/format.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppState>().store;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: StreamBuilder<List<TaskItem>>(
        stream: store.watchTrash(),
        builder: (context, snapshot) {
          final tasks = snapshot.data ?? const <TaskItem>[];
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '回收站是空的',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '删除的任务会先放在这里，可随时恢复。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '删除于 ${relativeTime(task.deletedAt ?? task.updatedAt)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _restore(context, task),
                        child: const Text('恢复'),
                      ),
                      IconButton(
                        tooltip: '永久删除',
                        onPressed: () => _purge(context, task),
                        icon: Icon(
                          Icons.delete_forever_rounded,
                          color: scheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _restore(BuildContext context, TaskItem task) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().repository.restoreTask(task.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已恢复到原清单')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$error')));
    }
  }

  Future<void> _purge(BuildContext context, TaskItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除？'),
        content: Text('“${task.title}”将无法恢复。'),
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
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().repository.purgeTask(task.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已永久删除')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }
}
