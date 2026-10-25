import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/ids.dart';
import '../../core/models.dart';
import '../../data/engine/sync_controller.dart';
import '../../design/format.dart';
import '../lists/lists_page.dart';
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
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _adding = false;
  bool _searching = false;
  String _query = '';
  String _view = 'all';

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
    _search.dispose();
    _searchFocus.dispose();
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
        .watchTasks(
          listId: _selectedListId,
          completed: _completed,
          view: _view,
        )
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
    final title = _completed
        ? '已完成'
        : (selected?.name ??
            (_view == 'today'
                ? '今天'
                : _view == 'next7'
                    ? '最近 7 天'
                    : '任务'));
    final listsById = {for (final list in _lists) list.id: list};
    final visible = _filteredTasks;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 72,
        titleSpacing: 20,
        title: _searching
            ? TextField(
                controller: _search,
                focusNode: _searchFocus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: '搜索标题、备注、标签、子任务',
                  border: InputBorder.none,
                  isDense: true,
                ),
              )
            : Column(
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
        actions: _searching
            ? [
                IconButton(
                  tooltip: '关闭搜索',
                  onPressed: _closeSearch,
                  icon: const Icon(Icons.close_rounded),
                ),
                const SizedBox(width: 4),
              ]
            : [
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
          IconButton(
            tooltip: '搜索',
            onPressed: () {
              setState(() => _searching = true);
              _searchFocus.requestFocus();
            },
            icon: const Icon(Icons.search_rounded),
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
                case 'lists':
                  _openLists();
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
              PopupMenuItem(
                value: 'lists',
                child: Text('清单管理'),
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
            selectedView: _view,
            onSelected: (id) {
              setState(() {
                _view = 'all';
                _selectedListId = id;
              });
              _subscribeTasks();
            },
            onViewSelected: (view) {
              setState(() {
                _selectedListId = null;
                _view = view;
              });
              _subscribeTasks();
            },
            onManage: _openLists,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => app.syncNow(),
              child: visible.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.35,
                        ),
                        _EmptyState(
                          completed: _completed,
                          hasLists: _lists.isNotEmpty,
                          searching: _searching && _query.isNotEmpty,
                          onSync: () => app.syncNow(),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final task = visible[index];
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

  List<TaskItem> get _filteredTasks {
    final query = _query;
    if (query.isEmpty) return _tasks;
    return _tasks.where((task) {
      if (task.title.toLowerCase().contains(query)) return true;
      if (task.notes.toLowerCase().contains(query)) return true;
      if (task.tags.any((tag) => tag.toLowerCase().contains(query))) {
        return true;
      }
      return task.checklist
          .any((item) => item.title.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  void _closeSearch() {
    _search.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
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

  void _openLists() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ListsPage()),
    );
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
    required this.selectedView,
    required this.onSelected,
    required this.onViewSelected,
    required this.onManage,
  });

  final List<TaskListItem> lists;
  final String? selectedId;
  final String selectedView;
  final ValueChanged<String?> onSelected;
  final ValueChanged<String> onViewSelected;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lists.length + 4,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SelectorChip(
              label: '全部',
              selected: selectedId == null && selectedView == 'all',
              color: scheme.primary,
              onTap: () => onViewSelected('all'),
            );
          }
          if (index == 1) {
            return _SelectorChip(
              label: '今天',
              selected: selectedId == null && selectedView == 'today',
              color: const Color(0xFFF59E0B),
              onTap: () => onViewSelected('today'),
            );
          }
          if (index == 2) {
            return _SelectorChip(
              label: '最近 7 天',
              selected: selectedId == null && selectedView == 'next7',
              color: const Color(0xFF3B82F6),
              onTap: () => onViewSelected('next7'),
            );
          }
          if (index == lists.length + 3) {
            return _SelectorChip(
              label: '管理',
              selected: false,
              color: scheme.onSurfaceVariant,
              icon: Icons.tune_rounded,
              onTap: onManage,
            );
          }
          final list = lists[index - 3];
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
    this.icon,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

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
              if (icon != null)
                Icon(icon, size: 14, color: color)
              else
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
    final checklistDone = task.checklist.where((item) => item.done).length;

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
                      if (due != null ||
                          (showListName && list != null) ||
                          task.checklist.isNotEmpty ||
                          task.tags.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (due != null)
                              _MetaBadge(
                                icon: Icons.schedule_rounded,
                                text: formatDue(due, allDay: task.allDay),
                                color: dueColor,
                                bold: overdue,
                              ),
                            if (showListName && list != null)
                              _MetaBadge(
                                dotColor: listColor,
                                text: list!.name,
                                color: scheme.onSurfaceVariant,
                              ),
                            if (task.checklist.isNotEmpty)
                              _MetaBadge(
                                icon: Icons.checklist_rounded,
                                text: '$checklistDone/${task.checklist.length}',
                                color: checklistDone == task.checklist.length
                                    ? const Color(0xFF22C55E)
                                    : scheme.onSurfaceVariant,
                              ),
                            for (final tag in task.tags.take(3))
                              _TagBadge(label: tag),
                            if (task.tags.length > 3)
                              _TagBadge(label: '+${task.tags.length - 3}'),
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

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.text,
    required this.color,
    this.icon,
    this.dotColor,
    this.bold = false,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final Color? dotColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 13, color: color)
        else if (dotColor != null)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w500,
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
    return Semantics(
      button: true,
      label: completed ? '标记为未完成' : '标记为完成',
      child: GestureDetector(
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
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.completed,
    required this.hasLists,
    required this.searching,
    required this.onSync,
  });

  final bool completed;
  final bool hasLists;
  final bool searching;
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
          searching
              ? '没有匹配的任务'
              : (completed
                  ? '还没有已完成任务'
                  : (hasLists ? '这里还没有任务' : '正在获取清单…')),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          searching
              ? '试试标题、备注、标签或子任务里的关键词'
              : (completed ? '完成的任务会出现在这里' : '在下方输入框添加第一条任务，离线也能记录'),
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
  late final TaskItem _baseline;
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _tagInput;
  late final TextEditingController _subtaskInput;
  late String _listId;
  DateTime? _dueAt;
  bool _allDay = false;
  int _priority = 0;
  List<String> _tags = const [];
  List<ChecklistItem> _checklist = const [];
  bool _saving = false;

  static const _priorityLabels = ['无', '低', '中', '高'];

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _baseline = task;
    _title = TextEditingController(text: task.title);
    _notes = TextEditingController(text: task.notes);
    _tagInput = TextEditingController();
    _subtaskInput = TextEditingController();
    _listId = task.listId;
    _dueAt = task.dueAt;
    _allDay = task.allDay;
    _priority = task.priority;
    _tags = List<String>.of(task.tags);
    _checklist = List<ChecklistItem>.of(task.checklist);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _tagInput.dispose();
    _subtaskInput.dispose();
    super.dispose();
  }

  Future<void> _pickList() async {
    final store = context.read<AppState>().store;
    final lists = store
        .listsSnapshot()
        .where((list) => list.kind == TaskKind.task)
        .toList();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final list in lists)
              ListTile(
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colorFromHex(list.color),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(list.name),
                trailing: list.id == _listId
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(context, list.id),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _listId = selected);
    }
  }

  Future<void> _pickDue() async {
    final initial = (_dueAt ?? DateTime.now()).toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    if (_allDay) {
      setState(() {
        _dueAt = DateTime(date.year, date.month, date.day).toUtc();
      });
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toUtc();
    });
  }

  void _toggleAllDay(bool value) {
    setState(() {
      _allDay = value;
      final due = _dueAt;
      if (due == null) return;
      final local = due.toLocal();
      _dueAt = value
          ? DateTime(local.year, local.month, local.day).toUtc()
          : DateTime(local.year, local.month, local.day, 9).toUtc();
    });
  }

  void _addTag() {
    final value = _tagInput.text.replaceAll(',', '').trim();
    if (value.isEmpty) return;
    if (!_tags.contains(value) && _tags.length < 20) {
      setState(() => _tags = [..._tags, value]);
    }
    _tagInput.clear();
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((item) => item != tag).toList());
  }

  void _addSubtask() {
    final value = _subtaskInput.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _checklist = [
        ..._checklist,
        ChecklistItem(id: newSyncId(), title: value),
      ];
    });
    _subtaskInput.clear();
  }

  void _toggleSubtask(String id) {
    setState(() {
      _checklist = _checklist
          .map((item) =>
              item.id == id ? item.copyWith(done: !item.done) : item)
          .toList();
    });
  }

  void _removeSubtask(String id) {
    setState(() {
      _checklist = _checklist.where((item) => item.id != id).toList();
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().repository.saveEdits(
            widget.task.id,
            baseline: _baseline,
            title: title,
            notes: _notes.text,
            dueAt: _dueAt,
            allDay: _allDay,
            priority: _priority,
            tags: _tags,
            checklist: _checklist,
            listId: _listId,
          );
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
    final due = _dueAt;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            20,
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
                if (task.completed)
                  Text(
                    '已完成',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF22C55E),
                      fontWeight: FontWeight.w600,
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
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sheetLabel(context, '清单'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickList,
              icon: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorFromHex(
                    context
                            .read<AppState>()
                            .store
                            .list(_listId)
                            ?.color ??
                        '',
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              label: Text(
                context.read<AppState>().store.list(_listId)?.name ?? '选择清单',
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            _sheetLabel(context, '截止日期'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDue,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(
                      due == null
                          ? '设置日期'
                          : formatDue(due, allDay: _allDay),
                    ),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                if (due != null)
                  IconButton(
                    tooltip: '清除日期',
                    onPressed: _saving
                        ? null
                        : () => setState(() => _dueAt = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
              ],
            ),
            Row(
              children: [
                Text('全天', style: theme.textTheme.bodySmall),
                const SizedBox(width: 6),
                Switch(
                  value: _allDay,
                  onChanged: _saving ? null : _toggleAllDay,
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            _sheetLabel(context, '优先级'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var value = 0; value <= 3; value++)
                  ChoiceChip(
                    label: Text(_priorityLabels[value]),
                    selected: _priority == value,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _priority = value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _sheetLabel(context, '标签'),
            const SizedBox(height: 8),
            if (_tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final tag in _tags)
                    InputChip(
                      label: Text(tag),
                      onDeleted: _saving ? null : () => _removeTag(tag),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _tagInput,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addTag(),
              decoration: InputDecoration(
                isDense: true,
                hintText: '添加标签，回车确认',
                prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                suffixIcon: IconButton(
                  tooltip: '添加标签',
                  onPressed: _saving ? null : _addTag,
                  icon: const Icon(Icons.add_rounded, size: 18),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sheetLabel(context, '子任务'),
            const SizedBox(height: 4),
            for (final item in _checklist)
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Checkbox(
                      value: item.done,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged:
                          _saving ? null : (_) => _toggleSubtask(item.id),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        decoration: item.done
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.done
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '删除子任务',
                    onPressed: _saving ? null : () => _removeSubtask(item.id),
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
            TextField(
              controller: _subtaskInput,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addSubtask(),
              decoration: InputDecoration(
                isDense: true,
                hintText: '添加子任务，回车确认',
                prefixIcon: const Icon(Icons.add_task_rounded, size: 18),
                suffixIcon: IconButton(
                  tooltip: '添加子任务',
                  onPressed: _saving ? null : _addSubtask,
                  icon: const Icon(Icons.add_rounded, size: 18),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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

  Widget _sheetLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
