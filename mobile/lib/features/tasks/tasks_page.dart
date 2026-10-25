import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/models.dart';
import '../../data/engine/sync_controller.dart';
import '../../design/format.dart';
import '../settings/sync_diagnostics_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String? _selectedListId;
  bool _completed = false;
  List<TaskListItem> _lists = const [];
  List<TaskItem> _tasks = const [];
  StreamSubscription<List<TaskListItem>>? _listsSub;
  StreamSubscription<List<TaskItem>>? _tasksSub;
  final _quickAdd = TextEditingController();
  final _quickAddFocus = FocusNode();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _subscribeLists();
    _subscribeTasks();
  }

  @override
  void dispose() {
    _listsSub?.cancel();
    _tasksSub?.cancel();
    _quickAdd.dispose();
    _quickAddFocus.dispose();
    super.dispose();
  }

  void _subscribeLists() {
    _listsSub?.cancel();
    final store = context.read<AppState>().store;
    _listsSub = store.watchLists().listen((allLists) {
      if (!mounted) return;
      // P0 renders tasks only; note lists are synced but not editable here.
      final lists =
          allLists.where((list) => list.kind == TaskKind.task).toList();
      var reset = false;
      if (_selectedListId != null &&
          !lists.any((list) => list.id == _selectedListId)) {
        _selectedListId = null;
        reset = true;
      }
      setState(() => _lists = lists);
      if (reset) _subscribeTasks();
    });
  }

  void _subscribeTasks() {
    _tasksSub?.cancel();
    final store = context.read<AppState>().store;
    _tasksSub = store
        .watchTasks(listId: _selectedListId, completed: _completed)
        .listen((tasks) {
      if (mounted) setState(() => _tasks = tasks);
    });
  }

  TaskListItem? get _inbox {
    for (final list in _lists) {
      if (list.isInbox) return list;
    }
    return null;
  }

  String? get _targetListId => _selectedListId ?? _inbox?.id;

  TaskListItem? get _selectedList {
    final id = _selectedListId;
    if (id == null) return null;
    for (final list in _lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sync = app.syncController;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _selectedList;
    final title = _completed ? '已完成' : (selected?.name ?? '任务');
    final listsById = {for (final list in _lists) list.id: list};

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _statusColor(sync, scheme),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _statusText(sync),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (sync?.phase == SyncPhase.syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: '立即同步',
              onPressed: () => app.syncNow(),
              icon: const Icon(Icons.sync_rounded),
            ),
          IconButton(
            tooltip: _completed ? '查看未完成' : '查看已完成',
            onPressed: () {
              setState(() => _completed = !_completed);
              _subscribeTasks();
            },
            icon: Icon(
              _completed
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              color: _completed ? scheme.primary : null,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              switch (value) {
                case 'diagnostics':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SyncDiagnosticsPage(),
                    ),
                  );
                  break;
                case 'full':
                  app.syncNow(full: true);
                  break;
                case 'logout':
                  _confirmLogout();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'diagnostics',
                child: Text('同步诊断'),
              ),
              PopupMenuItem(
                value: 'full',
                child: Text('全量同步'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Text('退出登录'),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (sync?.error != null)
            _SyncBanner(
              message: sync!.error!,
              onRetry: () => app.syncNow(),
            ),
          _ListSelector(
            lists: _lists,
            selectedId: _selectedListId,
            onSelected: (id) {
              setState(() => _selectedListId = id);
              _subscribeTasks();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => app.syncNow(),
              child: _tasks.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.35,
                        ),
                        _EmptyState(
                          completed: _completed,
                          hasLists: _lists.isNotEmpty,
                          onSync: () => app.syncNow(),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        final list = listsById[task.listId];
                        return _TaskTile(
                          key: ValueKey(task.id),
                          task: task,
                          list: list,
                          showListName: _selectedListId == null,
                          onToggle: () => _toggle(task),
                          onDelete: () => _delete(task),
                          onTap: () => _openEditor(task, list),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _completed
          ? null
          : _QuickAddBar(
              controller: _quickAdd,
              focusNode: _quickAddFocus,
              enabled: _targetListId != null && !_adding,
              listName: _selectedList?.name ?? _inbox?.name ?? '收集箱',
              onAdd: _addTask,
            ),
    );
  }

  String _statusText(SyncController? sync) {
    if (sync == null) return '未连接';
    if (sync.phase == SyncPhase.syncing) return '正在同步…';
    if (sync.error != null) return '同步失败';
    final base = sync.lastSyncedAt == null
        ? '等待首次同步'
        : '已同步 · ${relativeTime(sync.lastSyncedAt)}';
    final extras = <String>[];
    if (sync.pending > 0) extras.add('待推送 ${sync.pending}');
    if (sync.failed > 0) extras.add('失败 ${sync.failed}');
    return extras.isEmpty ? base : '$base · ${extras.join(' · ')}';
  }

  Color _statusColor(SyncController? sync, ColorScheme scheme) {
    if (sync == null) return scheme.outline;
    if (sync.error != null) return scheme.error;
    if (sync.phase == SyncPhase.syncing) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  Future<void> _addTask() async {
    if (_adding) return;
    final title = _quickAdd.text.trim();
    final listId = _targetListId;
    if (title.isEmpty || listId == null) return;
    setState(() => _adding = true);
    try {
      await context.read<AppState>().repository.createTask(
            title: title,
            listId: listId,
          );
      _quickAdd.clear();
      _quickAddFocus.requestFocus();
    } catch (error) {
      _snack('添加失败：$error');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggle(TaskItem task) async {
    try {
      await context.read<AppState>().repository.toggleCompleted(task.id);
    } catch (error) {
      _snack('更新失败：$error');
    }
  }

  Future<void> _delete(TaskItem task) async {
    try {
      await context.read<AppState>().repository.deleteTask(task.id);
      _snack('已移到回收站');
    } catch (error) {
      _snack('删除失败：$error');
    }
  }

  void _openEditor(TaskItem task, TaskListItem? list) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TaskEditorSheet(task: task, list: list),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('本地任务、待推送操作和凭据都会被清空。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppState>().logout();
    }
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _ListSelector extends StatelessWidget {
  const _ListSelector({
    required this.lists,
    required this.selectedId,
    required this.onSelected,
  });

  final List<TaskListItem> lists;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) return const SizedBox(height: 12);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lists.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SelectorChip(
              label: '全部',
              selected: selectedId == null,
              color: scheme.primary,
              onTap: () => onSelected(null),
            );
          }
          final list = lists[index - 1];
          final color = colorFromHex(list.color);
          return _SelectorChip(
            label: list.name,
            selected: selectedId == list.id,
            color: color,
            onTap: () => onSelected(list.id),
          );
        },
      ),
    );
  }
}

class _SelectorChip extends StatelessWidget {
  const _SelectorChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? color : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    super.key,
    required this.task,
    required this.list,
    required this.showListName,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  final TaskItem task;
  final TaskListItem? list;
  final bool showListName;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final due = task.dueAt;
    final overdue = isOverdue(task);
    final priorityColor = switch (task.priority) {
      3 => const Color(0xFFEF4444),
      2 => const Color(0xFFF59E0B),
      1 => const Color(0xFF3B82F6),
      _ => null,
    };
    final dueColor = overdue ? scheme.error : scheme.onSurfaceVariant;
    final listColor = colorFromHex(list?.color ?? '');

    return Dismissible(
      key: ValueKey('dismiss-${task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('删除任务？'),
                content: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
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
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
      ),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CheckCircle(
                  completed: task.completed,
                  onTap: onToggle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          decoration: task.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.completed
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                      if (task.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.notes.replaceAll(RegExp(r'\s+'), ' ').trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (due != null || (showListName && list != null)) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            if (due != null) ...[
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: dueColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatDue(due, allDay: task.allDay),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: dueColor,
                                  fontWeight: overdue
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                            if (due != null && showListName && list != null)
                              const SizedBox(width: 10),
                            if (showListName && list != null) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: listColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  list!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (priorityColor != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 4,
                    height: 18,
                    margin: const EdgeInsets.only(top: 3),
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
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.completed, required this.onTap});

  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 1, right: 2, bottom: 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? scheme.primary : Colors.transparent,
            border: Border.all(
              color: completed
                  ? scheme.primary
                  : scheme.outline.withValues(alpha: 0.65),
              width: 1.6,
            ),
          ),
          child: completed
              ? Icon(Icons.check_rounded, size: 15, color: scheme.onPrimary)
              : null,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.completed,
    required this.hasLists,
    required this.onSync,
  });

  final bool completed;
  final bool hasLists;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            completed ? Icons.task_alt_rounded : Icons.playlist_add_rounded,
            color: scheme.primary,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          completed
              ? '还没有已完成任务'
              : (hasLists ? '这里还没有任务' : '正在获取清单…'),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          completed ? '完成的任务会出现在这里' : '在下方输入框添加第一条任务，离线也能记录',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (!hasLists) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onSync,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('立即同步'),
          ),
        ],
      ],
    );
  }
}

class _QuickAddBar extends StatelessWidget {
  const _QuickAddBar({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.listName,
    required this.onAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String listName;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: enabled ? '添加到「$listName」' : '等待清单同步…',
                  prefixIcon: const Icon(Icons.add_rounded, size: 20),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest
                      .withValues(alpha: 0.55),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '添加任务',
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({required this.task, required this.list});

  final TaskItem task;
  final TaskListItem? list;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _notes = TextEditingController(text: widget.task.notes);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final repository = context.read<AppState>().repository;
    try {
      await repository.updateTitle(widget.task.id, title);
      await repository.updateNotes(widget.task.id, _notes.text);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final repository = context.read<AppState>().repository;
    try {
      await repository.deleteTask(widget.task.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = widget.task;
    final list = widget.list;
    final due = task.dueAt;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (list != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorFromHex(list.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    list.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                if (due != null)
                  Text(
                    formatDue(due, allDay: task.allDay),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isOverdue(task)
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: true,
              maxLines: null,
              textInputAction: TextInputAction.next,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: '任务标题',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const Divider(height: 24),
            TextField(
              controller: _notes,
              maxLines: 6,
              minLines: 3,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              decoration: InputDecoration(
                hintText: '备注',
                filled: true,
                fillColor: scheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('删除'),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
