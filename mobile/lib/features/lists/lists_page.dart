import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/models.dart';
import '../../design/format.dart';

const _listColors = [
  '#4772fa',
  '#22c55e',
  '#f59e0b',
  '#ef4444',
  '#8b5cf6',
  '#06b6d4',
  '#ec4899',
  '#64748b',
];

class ListsPage extends StatelessWidget {
  const ListsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final store = app.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('清单管理'),
        actions: [
          IconButton(
            tooltip: '新建清单',
            onPressed: () => _createList(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createList(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建清单'),
      ),
      body: StreamBuilder<List<TaskListItem>>(
        stream: store.watchLists(),
        builder: (context, snapshot) {
          final lists = (snapshot.data ?? const <TaskListItem>[])
              .where((list) => list.kind == TaskKind.task)
              .toList();
          if (lists.isEmpty) {
            return Center(
              child: Text(
                '还没有清单',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: lists.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final list = lists[index];
              return Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorFromHex(list.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    list.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: list.isInbox ? const Text('默认清单') : null,
                  trailing: list.isInbox
                      ? null
                      : PopupMenuButton<String>(
                          tooltip: '清单操作',
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editList(context, list);
                            } else if (value == 'delete') {
                              _deleteList(context, list);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('编辑'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('删除'),
                            ),
                          ],
                        ),
                  onTap: list.isInbox
                      ? null
                      : () => _editList(context, list),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createList(BuildContext context) async {
    final value = await showDialog<_ListDraft>(
      context: context,
      builder: (_) => const _ListEditorDialog(),
    );
    if (value == null || !context.mounted) return;
    try {
      await context.read<AppState>().repository.createList(
            name: value.name,
            color: value.color,
          );
    } catch (error) {
      if (context.mounted) _snack(context, '新建失败：$error');
    }
  }

  Future<void> _editList(BuildContext context, TaskListItem list) async {
    final value = await showDialog<_ListDraft>(
      context: context,
      builder: (_) => _ListEditorDialog(list: list),
    );
    if (value == null || !context.mounted) return;
    try {
      await context.read<AppState>().repository.updateList(
            list.id,
            name: value.name,
            color: value.color,
          );
    } catch (error) {
      if (context.mounted) _snack(context, '保存失败：$error');
    }
  }

  Future<void> _deleteList(BuildContext context, TaskListItem list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${list.name}」？'),
        content: const Text('清单里的任务会移动到收集箱。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<AppState>().repository.deleteList(list.id);
    } catch (error) {
      if (context.mounted) _snack(context, '删除失败：$error');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ListDraft {
  const _ListDraft({required this.name, required this.color});

  final String name;
  final String color;
}

class _ListEditorDialog extends StatefulWidget {
  const _ListEditorDialog({this.list});

  final TaskListItem? list;

  @override
  State<_ListEditorDialog> createState() => _ListEditorDialogState();
}

class _ListEditorDialogState extends State<_ListEditorDialog> {
  late final TextEditingController _name;
  late String _color;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.list?.name ?? '');
    _color = widget.list?.color ?? _listColors.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.list != null;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(editing ? '编辑清单' : '新建清单'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '例如：工作、家庭',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Text('颜色', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in _listColors)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => _color = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorFromHex(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == color
                            ? scheme.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _color == color
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, _ListDraft(name: name, color: _color));
  }
}
