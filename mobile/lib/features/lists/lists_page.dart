import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/models.dart';
import '../../design/components.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('清单管理'),
        actions: [
          IconButton(
            tooltip: '新建文件夹',
            onPressed: () => _createFolder(context),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            tooltip: '新建清单',
            onPressed: () => _createList(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'lists-compose-fab',
        onPressed: () => _createList(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<List<FolderItem>>(
        stream: store.watchFolders(),
        builder: (context, folderSnapshot) {
          final folders = folderSnapshot.data ?? const <FolderItem>[];
          return StreamBuilder<List<TaskListItem>>(
            stream: store.watchLists(),
            builder: (context, listSnapshot) {
              final lists = (listSnapshot.data ?? const <TaskListItem>[])
                  .where((list) => list.kind == TaskKind.task)
                  .toList();
              if (lists.isEmpty && folders.isEmpty) {
                return const Center(
                  child: AppEmptyState(
                    icon: Icons.folder_open_rounded,
                    title: '还没有清单',
                    message: '创建一个清单，开始整理你的任务。',
                  ),
                );
              }
              final folderIds = folders.map((folder) => folder.id).toSet();
              final ungrouped = lists
                  .where(
                    (list) =>
                        list.folderId == null ||
                        !folderIds.contains(list.folderId),
                  )
                  .toList(growable: false);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  if (ungrouped.isNotEmpty) ...[
                    _sectionLabel(context, '未分组'),
                    for (final list in ungrouped)
                      _listTile(context, list, folders),
                    const SizedBox(height: 18),
                  ],
                  for (final folder in folders) ...[
                    _folderHeader(
                      context,
                      folder,
                      lists.where((list) => list.folderId == folder.id).length,
                    ),
                    for (final list in lists.where(
                      (list) => list.folderId == folder.id,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _listTile(context, list, folders),
                      ),
                    const SizedBox(height: 18),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _folderHeader(BuildContext context, FolderItem folder, int count) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
      child: Row(
        children: [
          Icon(Icons.folder_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            folder.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: '文件夹操作',
            onSelected: (value) {
              if (value == 'edit') {
                _editFolder(context, folder);
              } else if (value == 'delete') {
                _deleteFolder(context, folder);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('重命名')),
              PopupMenuItem(value: 'delete', child: Text('删除文件夹')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listTile(
    BuildContext context,
    TaskListItem list,
    List<FolderItem> folders,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canMove = folders.isNotEmpty || list.folderId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
                    switch (value) {
                      case 'edit':
                        _editList(context, list);
                        break;
                      case 'move':
                        _moveList(context, list, folders);
                        break;
                      case 'delete':
                        _deleteList(context, list);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    if (canMove)
                      const PopupMenuItem(value: 'move', child: Text('移动到文件夹')),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
          onTap: list.isInbox ? null : () => _editList(context, list),
        ),
      ),
    );
  }

  Future<void> _createFolder(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(title: '新建文件夹', hint: '例如：工作、生活'),
    );
    if (name == null || !context.mounted) return;
    try {
      await context.read<AppState>().repository.createFolder(name);
    } catch (error) {
      if (context.mounted) _snack(context, '新建失败：$error');
    }
  }

  Future<void> _editFolder(BuildContext context, FolderItem folder) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _NameDialog(title: '重命名文件夹', hint: '文件夹名称', initial: folder.name),
    );
    if (name == null || !context.mounted) return;
    try {
      await context.read<AppState>().repository.updateFolder(folder.id, name);
    } catch (error) {
      if (context.mounted) _snack(context, '保存失败：$error');
    }
  }

  Future<void> _deleteFolder(BuildContext context, FolderItem folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${folder.name}」？'),
        content: const Text('文件夹里的清单会移动到「未分组」，清单和任务不会被删除。'),
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
      await context.read<AppState>().repository.deleteFolder(folder.id);
    } catch (error) {
      if (context.mounted) _snack(context, '删除失败：$error');
    }
  }

  Future<void> _moveList(
    BuildContext context,
    TaskListItem list,
    List<FolderItem> folders,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('移动到文件夹'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('未分组'),
              trailing: list.folderId == null
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final folder in folders)
              ListTile(
                leading: const Icon(Icons.folder_rounded),
                title: Text(folder.name),
                trailing: list.folderId == folder.id
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(context, folder.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    try {
      await context.read<AppState>().repository.moveListToFolder(
        list.id,
        selected.isEmpty ? null : selected,
      );
    } catch (error) {
      if (context.mounted) _snack(context, '移动失败：$error');
    }
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

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.hint, this.initial});

  final String title;
  final String hint;
  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }
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
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, _ListDraft(name: name, color: _color));
  }
}
