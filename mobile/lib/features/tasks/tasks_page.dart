import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/ids.dart';
import '../../core/models.dart';
import '../../data/engine/sync_controller.dart';
import '../../data/reminders/reminder_plan.dart';
import '../../design/format.dart';
import '../lists/lists_page.dart';
import '../settings/sync_diagnostics_page.dart';
import 'board_view.dart';
import 'matrix_view.dart';
import 'timeline_view.dart';
import 'trash_page.dart';

enum _TaskLayout { list, board, matrix, timeline }

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
  _TaskLayout _layout = _TaskLayout.list;
  TimelineScale _timelineScale = TimelineScale.day;
  DateTime? _timelineAnchor;
  bool _manualSort = false;
  bool _selecting = false;
  final Set<String> _selectedIds = {};

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
      final lists = allLists
          .where((list) => list.kind == TaskKind.task)
          .toList();
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
          manualSort: _manualSort,
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

  TaskListItem? get _boardList =>
      _selectedList ?? _inbox ?? (_lists.isNotEmpty ? _lists.first : null);

  void _setLayout(_TaskLayout layout) {
    setState(() {
      _layout = layout;
      _completed = false;
      _manualSort = false;
      _selecting = false;
      _selectedIds.clear();
      if (layout != _TaskLayout.list) {
        _view = 'all';
        if (layout == _TaskLayout.board && _selectedListId == null) {
          _selectedListId = _boardList?.id;
        }
      }
    });
    _subscribeTasks();
  }

  void _setScope(String? listId) {
    setState(() => _selectedListId = listId);
    _subscribeTasks();
  }

  void _toggleManualSort() {
    if (_manualSort) {
      setState(() => _manualSort = false);
      _subscribeTasks();
      return;
    }
    final listId = _selectedListId ?? _boardList?.id;
    if (listId == null) {
      _snack('请先选择一个清单');
      return;
    }
    final store = context.read<AppState>().store;
    final ids = store
        .tasksSnapshot(listId: listId, completed: false, view: 'all')
        .map((task) => task.id)
        .toList();
    setState(() {
      _manualSort = true;
      _selectedListId = listId;
      _view = 'all';
      _completed = false;
      _selecting = false;
      _selectedIds.clear();
    });
    _subscribeTasks();
    if (ids.isNotEmpty) {
      unawaited(context.read<AppState>().repository.reorderTasks(ids));
    }
  }

  Future<void> _reorderTasks(int oldIndex, int newIndex) async {
    final tasks = _filteredTasks;
    if (oldIndex < 0 || oldIndex >= tasks.length) return;
    if (newIndex < 0 || newIndex >= tasks.length) return;
    final ids = tasks.map((task) => task.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    try {
      await context.read<AppState>().repository.reorderTasks(ids);
    } catch (error) {
      _snack('排序失败：$error');
    }
  }

  Future<void> _reschedule(TaskItem task, DateTime? due) async {
    try {
      await context.read<AppState>().repository.rescheduleTask(task.id, due);
    } catch (error) {
      _snack('改期失败：$error');
    }
  }

  void _toggleSelection(TaskItem task) {
    setState(() {
      _selecting = true;
      if (!_selectedIds.add(task.id)) {
        _selectedIds.remove(task.id);
      }
      if (_selectedIds.isEmpty) _selecting = false;
    });
  }

  void _clearSelection() {
    if (!_selecting && _selectedIds.isEmpty) return;
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  Future<void> _batchComplete() async {
    if (_selectedIds.isEmpty) return;
    final app = context.read<AppState>();
    final repository = app.repository;
    final store = app.store;
    setState(() => _selecting = false);
    try {
      for (final id in _selectedIds.toList()) {
        final task = store.task(id);
        if (task != null && !task.completed) {
          await repository.toggleCompleted(id);
        }
      }
    } catch (error) {
      _snack('批量完成失败：$error');
    }
    if (mounted) setState(() => _selectedIds.clear());
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${_selectedIds.length} 个任务？'),
        content: const Text('任务会移到回收站，可随时恢复。'),
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
    if (confirmed != true || !mounted) return;
    final repository = context.read<AppState>().repository;
    final ids = _selectedIds.toList();
    setState(() => _selecting = false);
    try {
      for (final id in ids) {
        await repository.deleteTask(id);
      }
    } catch (error) {
      _snack('批量删除失败：$error');
    }
    if (mounted) setState(() => _selectedIds.clear());
  }

  Future<void> _batchMove() async {
    if (_selectedIds.isEmpty) return;
    final targetId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('移动到清单'),
            ),
            for (final list in _lists)
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
                onTap: () => Navigator.pop(context, list.id),
              ),
          ],
        ),
      ),
    );
    if (targetId == null || !mounted) return;
    final repository = context.read<AppState>().repository;
    final ids = _selectedIds.toList();
    setState(() => _selecting = false);
    try {
      for (final id in ids) {
        await repository.moveTaskToList(id, targetId);
      }
    } catch (error) {
      _snack('批量移动失败：$error');
    }
    if (mounted) setState(() => _selectedIds.clear());
  }

  Future<void> _runBatch(
    String label,
    Future<void> Function(String id) action,
  ) async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    setState(() => _selecting = false);
    try {
      for (final id in ids) {
        await action(id);
      }
    } catch (error) {
      _snack('$label失败：$error');
    }
    if (mounted) setState(() => _selectedIds.clear());
  }

  Future<void> _batchPriority() async {
    const labels = ['无', '低', '中', '高'];
    final priority = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('设置优先级'),
            ),
            for (var value = 0; value <= 3; value++)
              ListTile(
                leading: Icon(
                  Icons.flag_rounded,
                  color: switch (value) {
                    3 => const Color(0xFFEF4444),
                    2 => const Color(0xFFF59E0B),
                    1 => const Color(0xFF3B82F6),
                    _ => null,
                  },
                ),
                title: Text(labels[value]),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (priority == null || !mounted) return;
    final repository = context.read<AppState>().repository;
    await _runBatch('批量设置优先级', (id) => repository.updatePriority(id, priority));
  }

  Future<void> _batchDue() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('设置截止日期'),
            ),
            ListTile(
              leading: const Icon(Icons.today_rounded),
              title: const Text('今天'),
              onTap: () => Navigator.pop(context, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.event_rounded),
              title: const Text('明天'),
              onTap: () => Navigator.pop(context, 'tomorrow'),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_rounded),
              title: const Text('选择日期…'),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_rounded),
              title: const Text('清除截止日期'),
              onTap: () => Navigator.pop(context, 'clear'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    DateTime? due;
    if (choice == 'today') {
      due = DateTime(today.year, today.month, today.day, 9);
    } else if (choice == 'tomorrow') {
      final date = today.add(const Duration(days: 1));
      due = DateTime(date.year, date.month, date.day, 9);
    } else if (choice == 'custom') {
      final picked = await showDatePicker(
        context: context,
        initialDate: today,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked == null || !mounted) return;
      due = DateTime(picked.year, picked.month, picked.day, 9);
    }
    final repository = context.read<AppState>().repository;
    await _runBatch('批量改期', (id) => repository.setDue(id, due));
  }

  Future<void> _batchTags() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '标签',
            helperText: '多个标签用逗号分隔',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    final tags = value
        .split(RegExp(r'[,，]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    if (tags.isEmpty) return;
    final repository = context.read<AppState>().repository;
    await _runBatch('批量添加标签', (id) => repository.addTags(id, tags));
  }

  Future<void> _batchTitle({required bool prefix}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prefix ? '标题加前缀' : '标题加后缀'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: prefix ? '前缀' : '后缀',
            hintText: prefix ? '例如：[工作] ' : '例如： - 本周',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('应用'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    final app = context.read<AppState>();
    await _runBatch(prefix ? '批量加前缀' : '批量加后缀', (id) async {
      final task = app.store.task(id);
      if (task == null) return;
      final title = prefix ? '$value${task.title}' : '${task.title}$value';
      await app.repository.updateTitle(id, title);
    });
  }

  Future<void> _batchNotes() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('追加备注'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '备注内容',
            hintText: '会追加到现有备注末尾',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty || !mounted) return;
    final app = context.read<AppState>();
    await _runBatch('批量追加备注', (id) async {
      final task = app.store.task(id);
      if (task == null) return;
      final notes = task.notes.isEmpty
          ? value.trim()
          : '${task.notes}\n${value.trim()}';
      await app.repository.updateNotes(id, notes);
    });
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
        title: _selecting
            ? Text(
                '已选 ${_selectedIds.length} 项',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
            : _searching
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
        actions: _selecting
            ? [
                IconButton(
                  tooltip: '取消选择',
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.close_rounded),
                ),
                const SizedBox(width: 4),
              ]
            : _searching
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
                if (_layout == _TaskLayout.list) ...[
                  IconButton(
                    tooltip: _completed ? '查看未完成' : '查看已完成',
                    onPressed: () {
                      setState(() {
                        _completed = !_completed;
                        _manualSort = false;
                      });
                      _subscribeTasks();
                    },
                    icon: Icon(
                      _completed
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      color: _completed ? scheme.primary : null,
                    ),
                  ),
                ],
                if ((_layout == _TaskLayout.list ||
                        _layout == _TaskLayout.board) &&
                    !_completed)
                  IconButton(
                    tooltip: _manualSort ? '按截止时间排序' : '手动排序',
                    onPressed: _toggleManualSort,
                    icon: Icon(
                      _manualSort
                          ? Icons.swap_vert_circle_rounded
                          : Icons.swap_vert_rounded,
                      color: _manualSort ? scheme.primary : null,
                    ),
                  ),
                IconButton(
                  tooltip: '搜索',
                  onPressed: () {
                    setState(() {
                      _layout = _TaskLayout.list;
                      _searching = true;
                      _selectedListId = null;
                      _view = 'all';
                      _completed = false;
                      _manualSort = false;
                    });
                    _subscribeTasks();
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
                      case 'trash':
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TrashPage()),
                        );
                        break;
                      case 'logout':
                        _confirmLogout();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'diagnostics', child: Text('同步诊断')),
                    PopupMenuItem(value: 'full', child: Text('全量同步')),
                    PopupMenuItem(value: 'lists', child: Text('清单管理')),
                    PopupMenuItem(value: 'trash', child: Text('回收站')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'logout', child: Text('退出登录')),
                  ],
                ),
                const SizedBox(width: 4),
              ],
      ),
      body: Column(
        children: [
          if (sync?.error != null)
            _SyncBanner(message: sync!.error!, onRetry: () => app.syncNow()),
          if (!_searching && !_selecting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _LayoutSwitcher(layout: _layout, onChanged: _setLayout),
            ),
          if (_selecting && _layout == _TaskLayout.list)
            _BatchBar(
              count: _selectedIds.length,
              onComplete: _batchComplete,
              onMove: _batchMove,
              onDelete: _batchDelete,
              onPriority: _batchPriority,
              onDue: _batchDue,
              onTags: _batchTags,
              onTitlePrefix: () => _batchTitle(prefix: true),
              onTitleSuffix: () => _batchTitle(prefix: false),
              onNotes: _batchNotes,
            ),
          if (_layout == _TaskLayout.list) ...[
            _ListSelector(
              lists: _lists,
              selectedId: _selectedListId,
              selectedView: _view,
              onSelected: (id) {
                setState(() {
                  _view = 'all';
                  _selectedListId = id;
                  _manualSort = false;
                });
                _subscribeTasks();
              },
              onViewSelected: (view) {
                setState(() {
                  _selectedListId = null;
                  _view = view;
                  _manualSort = false;
                });
                _subscribeTasks();
              },
              onManage: _openLists,
            ),
            Expanded(
              child: visible.isEmpty
                  ? RefreshIndicator(
                      onRefresh: () => app.syncNow(),
                      child: ListView(
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
                      ),
                    )
                  : _manualSort
                  ? ReorderableListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: visible.length,
                      buildDefaultDragHandles: false,
                      onReorderItem: _reorderTasks,
                      itemBuilder: (context, index) {
                        final task = visible[index];
                        final list = listsById[task.listId];
                        return Padding(
                          key: ValueKey('reorder-${task.id}'),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TaskTile(
                            task: task,
                            list: list,
                            showListName: _selectedListId == null,
                            selected: _selectedIds.contains(task.id),
                            dragHandle: ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  size: 20,
                                ),
                              ),
                            ),
                            onToggle: () => _toggle(task),
                            onDelete: () => _delete(task),
                            onLongPress: () => _toggleSelection(task),
                            onTap: _selecting
                                ? () => _toggleSelection(task)
                                : () => _openEditor(task, list),
                          ),
                        );
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: () => app.syncNow(),
                      child: ListView.separated(
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
                            selected: _selectedIds.contains(task.id),
                            onToggle: () => _toggle(task),
                            onDelete: () => _delete(task),
                            onLongPress: () => _toggleSelection(task),
                            onTap: _selecting
                                ? () => _toggleSelection(task)
                                : () => _openEditor(task, list),
                          );
                        },
                      ),
                    ),
            ),
          ] else if (_layout == _TaskLayout.board) ...[
            _ViewScopeBar(
              lists: _lists,
              selectedId: _boardList?.id,
              includeAll: false,
              onChanged: _setScope,
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: _boardList == null
                    ? Center(
                        child: Text(
                          _lists.isEmpty ? '先创建一个清单' : '暂无可展示的清单',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : BoardView(
                        list: _boardList!,
                        tasks: _tasks,
                        manualSort: _manualSort,
                        onOpenTask: (task) =>
                            _openEditor(task, listsById[task.listId]),
                        onToggleTask: _toggle,
                      ),
              ),
            ),
          ] else if (_layout == _TaskLayout.matrix) ...[
            _ViewScopeBar(
              lists: _lists,
              selectedId: _selectedListId,
              includeAll: true,
              onChanged: _setScope,
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: MatrixView(
                  tasks: _tasks,
                  onOpenTask: (task) =>
                      _openEditor(task, listsById[task.listId]),
                  onToggleTask: _toggle,
                ),
              ),
            ),
          ] else ...[
            _ViewScopeBar(
              lists: _lists,
              selectedId: _selectedListId,
              includeAll: true,
              onChanged: _setScope,
            ),
            _TimelineScaleBar(
              scale: _timelineScale,
              anchor: _timelineAnchor,
              onChanged: (value) => setState(() => _timelineScale = value),
              onAnchorChanged: (value) =>
                  setState(() => _timelineAnchor = value),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: TimelineView(
                  tasks: _tasks,
                  scale: _timelineScale,
                  anchor: _timelineAnchor,
                  onOpenTask: (task) =>
                      _openEditor(task, listsById[task.listId]),
                  onToggleTask: _toggle,
                  onReschedule: _reschedule,
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar:
          _layout == _TaskLayout.list && !_completed && !_selecting
          ? _QuickAddBar(
              controller: _quickAdd,
              focusNode: _quickAddFocus,
              enabled: _targetListId != null && !_adding,
              listName: _selectedList?.name ?? _inbox?.name ?? '收集箱',
              onAdd: _addTask,
            )
          : null,
    );
  }

  List<TaskItem> get _filteredTasks {
    final query = _query;
    if (query.isEmpty) return _tasks;
    return _tasks
        .where((task) {
          if (task.title.toLowerCase().contains(query)) return true;
          if (task.notes.toLowerCase().contains(query)) return true;
          if (task.tags.any((tag) => tag.toLowerCase().contains(query))) {
            return true;
          }
          return task.checklist.any(
            (item) => item.title.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);
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
      var order = 0;
      if (_manualSort) {
        for (final task in _tasks) {
          if (task.listId == listId && task.sortOrder >= order) {
            order = task.sortOrder + 1;
          }
        }
      }
      await context.read<AppState>().repository.createTask(
        title: title,
        listId: listId,
        sortOrder: order,
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
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ListsPage()));
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
          Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _LayoutSwitcher extends StatelessWidget {
  const _LayoutSwitcher({required this.layout, required this.onChanged});

  final _TaskLayout layout;
  final ValueChanged<_TaskLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_TaskLayout>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: _TaskLayout.list,
            icon: Icon(Icons.view_list_rounded, size: 17),
            label: Text('列表'),
          ),
          ButtonSegment(
            value: _TaskLayout.board,
            icon: Icon(Icons.view_kanban_outlined, size: 17),
            label: Text('看板'),
          ),
          ButtonSegment(
            value: _TaskLayout.matrix,
            icon: Icon(Icons.grid_view_rounded, size: 17),
            label: Text('矩阵'),
          ),
          ButtonSegment(
            value: _TaskLayout.timeline,
            icon: Icon(Icons.view_timeline_outlined, size: 17),
            label: Text('时间线'),
          ),
        ],
        selected: {layout},
        onSelectionChanged: (values) => onChanged(values.first),
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

class _BatchBar extends StatelessWidget {
  const _BatchBar({
    required this.count,
    required this.onComplete,
    required this.onMove,
    required this.onDelete,
    required this.onPriority,
    required this.onDue,
    required this.onTags,
    required this.onTitlePrefix,
    required this.onTitleSuffix,
    required this.onNotes,
  });

  final int count;
  final VoidCallback onComplete;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback onPriority;
  final VoidCallback onDue;
  final VoidCallback onTags;
  final VoidCallback onTitlePrefix;
  final VoidCallback onTitleSuffix;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            '$count 项',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('完成'),
          ),
          TextButton.icon(
            onPressed: onMove,
            icon: const Icon(Icons.drive_file_move_outline, size: 18),
            label: const Text('移动'),
          ),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('删除'),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
          ),
          PopupMenuButton<String>(
            tooltip: '更多批量操作',
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (value) {
              switch (value) {
                case 'priority':
                  onPriority();
                  break;
                case 'due':
                  onDue();
                  break;
                case 'tags':
                  onTags();
                  break;
                case 'title_prefix':
                  onTitlePrefix();
                  break;
                case 'title_suffix':
                  onTitleSuffix();
                  break;
                case 'notes':
                  onNotes();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'priority', child: Text('设置优先级')),
              PopupMenuItem(value: 'due', child: Text('设置截止日期')),
              PopupMenuItem(value: 'tags', child: Text('添加标签')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'title_prefix', child: Text('标题加前缀')),
              PopupMenuItem(value: 'title_suffix', child: Text('标题加后缀')),
              PopupMenuItem(value: 'notes', child: Text('追加备注')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineScaleBar extends StatelessWidget {
  const _TimelineScaleBar({
    required this.scale,
    required this.anchor,
    required this.onChanged,
    required this.onAnchorChanged,
  });

  final TimelineScale scale;
  final DateTime? anchor;
  final ValueChanged<TimelineScale> onChanged;
  final ValueChanged<DateTime?> onAnchorChanged;

  Future<void> _pickAnchor(BuildContext context) async {
    final now = DateTime.now();
    final initial = anchor ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onAnchorChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = anchor == null ? '今天' : '${anchor!.month}/${anchor!.day}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: Row(
        children: [
          Text(
            '缩放',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          ChoiceChip(
            label: const Text('日'),
            selected: scale == TimelineScale.day,
            onSelected: (_) => onChanged(TimelineScale.day),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('周'),
            selected: scale == TimelineScale.week,
            onSelected: (_) => onChanged(TimelineScale.week),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('月'),
            selected: scale == TimelineScale.month,
            onSelected: (_) => onChanged(TimelineScale.month),
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _pickAnchor(context),
            icon: const Icon(Icons.calendar_month_rounded, size: 16),
            label: Text(label),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          if (anchor != null)
            IconButton(
              tooltip: '回到今天',
              onPressed: () => onAnchorChanged(null),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _ViewScopeBar extends StatelessWidget {
  const _ViewScopeBar({
    required this.lists,
    required this.selectedId,
    required this.includeAll,
    required this.onChanged,
  });

  final List<TaskListItem> lists;
  final String? selectedId;
  final bool includeAll;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final valid = lists.any((list) => list.id == selectedId);
    final value = valid ? selectedId : (includeAll ? null : lists.first.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_outlined,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '范围',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: value,
                isDense: true,
                items: [
                  if (includeAll)
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部清单'),
                    ),
                  for (final list in lists)
                    DropdownMenuItem<String?>(
                      value: list.id,
                      child: Text(list.name),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
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
    required this.onLongPress,
    this.selected = false,
    this.dragHandle,
  });

  final TaskItem task;
  final TaskListItem? list;
  final bool showListName;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;
  final Widget? dragHandle;

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
                content: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
        ),
      ),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(alpha: 0.5),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CheckCircle(completed: task.completed, onTap: onToggle),
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
                          task.tags.isNotEmpty ||
                          task.pinned ||
                          task.reminderOffsets.isNotEmpty ||
                          task.recurrence.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (task.pinned)
                              _MetaBadge(
                                icon: Icons.push_pin_rounded,
                                text: '',
                                color: scheme.primary,
                              ),
                            if (due != null)
                              _MetaBadge(
                                icon: Icons.schedule_rounded,
                                text: formatDue(due, allDay: task.allDay),
                                color: dueColor,
                                bold: overdue,
                              ),
                            if (task.reminderOffsets.isNotEmpty)
                              _MetaBadge(
                                icon: Icons.notifications_active_outlined,
                                text: '',
                                color: scheme.onSurfaceVariant,
                              ),
                            if (task.recurrence.isNotEmpty)
                              _MetaBadge(
                                icon: Icons.repeat_rounded,
                                text: '',
                                color: scheme.onSurfaceVariant,
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
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ],
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
                if (dragHandle != null) ...[
                  const SizedBox(width: 4),
                  dragHandle!,
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
        if (text.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
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
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w500),
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
              : (completed ? '还没有已完成任务' : (hasLists ? '这里还没有任务' : '正在获取清单…')),
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          searching
              ? '试试标题、备注、标签或子任务里的关键词'
              : (completed ? '完成的任务会出现在这里' : '在下方输入框添加第一条任务，离线也能记录'),
          style: Theme.of(context).textTheme.bodySmall
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
                  fillColor: scheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
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
  DateTime? _startAt;
  DateTime? _dueAt;
  bool _allDay = false;
  int _priority = 0;
  List<int> _reminders = const [];
  bool _pinned = false;
  String _recurrence = '';
  List<String> _tags = const [];
  List<ChecklistItem> _checklist = const [];
  bool _saving = false;

  static const _priorityLabels = ['无', '低', '中', '高'];
  static const _recurrencePresets = <(String, String)>[
    ('不重复', ''),
    ('每天', 'FREQ=DAILY'),
    ('工作日', 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'),
    ('每周', 'FREQ=WEEKLY'),
    ('每月', 'FREQ=MONTHLY'),
    ('每年', 'FREQ=YEARLY'),
  ];

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
    _startAt = task.startAt;
    _dueAt = task.dueAt;
    _allDay = task.allDay;
    _priority = task.priority;
    _reminders = List<int>.of(task.reminderOffsets);
    _pinned = task.pinned;
    _recurrence = task.recurrence;
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

  Future<void> _pickStart() async {
    final initial = (_startAt ?? DateTime.now()).toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    if (_allDay) {
      setState(() {
        _startAt = DateTime(date.year, date.month, date.day).toUtc();
      });
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toUtc();
    });
  }

  Future<void> _addReminder() async {
    const presets = [0, 5, 15, 60, 1440, 10080];
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '添加提醒',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final minutes in presets)
              ListTile(
                leading: const Icon(Icons.notifications_none_rounded),
                title: Text(reminderLabel(minutes)),
                trailing: _reminders.contains(minutes)
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, minutes),
              ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_rounded),
              title: const Text('自定义…'),
              onTap: () => Navigator.pop(context, -1),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    var minutes = picked;
    if (picked < 0) {
      final custom = await _customReminderMinutes();
      if (custom == null || !mounted) return;
      minutes = custom;
    }
    if (_reminders.contains(minutes)) {
      _editorSnack('该提醒已存在');
      return;
    }
    if (_reminders.length >= 10) {
      _editorSnack('最多设置 10 个提醒');
      return;
    }
    setState(() {
      _reminders = [..._reminders, minutes]..sort();
    });
    final scheduler = context.read<AppState>().reminders;
    if (scheduler != null) {
      final exact = await scheduler.exactAlarmsAllowed();
      if (!exact) {
        final granted = await scheduler.ensureExactAlarms();
        if (!granted && mounted) {
          _editorSnack('未开启精确提醒，系统可能延迟通知');
        }
      }
    }
  }

  Future<int?> _customReminderMinutes() async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('自定义提醒'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '提前分钟数',
              helperText: '0 = 准时，最大 10080（7 天）',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value < 0 || value > 10080) {
                  setDialogState(() => error = '请输入 0–10080 的整数');
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  void _editorSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editRecurrence() async {
    final controller = TextEditingController(text: _recurrence);
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('自定义重复规则'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'RRULE',
              hintText: 'FREQ=WEEKLY;BYDAY=MO,WE',
              helperText: '留空表示不重复',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty &&
                    !value
                        .toUpperCase()
                        .replaceFirst(RegExp(r'^RRULE:'), '')
                        .startsWith('FREQ=')) {
                  setDialogState(() => error = '规则需要以 FREQ= 开头');
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result != null && mounted) {
      setState(() => _recurrence = result);
    }
  }

  Future<void> _skipOccurrence() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳过本次？'),
        content: const Text('截止日期会推进到下一次，未保存的编辑不会提交。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('跳过'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AppState>().repository.skipOccurrence(widget.task.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _editorSnack('跳过失败：$error');
    }
  }

  void _toggleAllDay(bool value) {
    setState(() {
      _allDay = value;
      final due = _dueAt;
      if (due != null) {
        final local = due.toLocal();
        _dueAt = value
            ? DateTime(local.year, local.month, local.day).toUtc()
            : DateTime(local.year, local.month, local.day, 9).toUtc();
      }
      final start = _startAt;
      if (start != null) {
        final local = start.toLocal();
        _startAt = value
            ? DateTime(local.year, local.month, local.day).toUtc()
            : DateTime(local.year, local.month, local.day, 9).toUtc();
      }
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
          .map((item) => item.id == id ? item.copyWith(done: !item.done) : item)
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
        startAt: _startAt,
        dueAt: _dueAt,
        allDay: _allDay,
        priority: _priority,
        reminderOffsets: _reminders,
        pinned: _pinned,
        recurrence: _recurrence,
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
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
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
                IconButton(
                  tooltip: _pinned ? '取消置顶' : '置顶',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _pinned = !_pinned),
                  icon: Icon(
                    _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 20,
                    color: _pinned ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
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
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
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
                    context.read<AppState>().store.list(_listId)?.color ?? '',
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              label: Text(
                context.read<AppState>().store.list(_listId)?.name ?? '选择清单',
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sheetLabel(context, '开始时间'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickStart,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(
                      _startAt == null
                          ? '设置开始时间'
                          : formatDue(_startAt!, allDay: _allDay),
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
                if (_startAt != null)
                  IconButton(
                    tooltip: '清除开始时间',
                    onPressed: _saving
                        ? null
                        : () => setState(() => _startAt = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
              ],
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
                      due == null ? '设置日期' : formatDue(due, allDay: _allDay),
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
            _sheetLabel(context, '提醒'),
            const SizedBox(height: 8),
            if (_reminders.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final minutes in _reminders)
                    InputChip(
                      avatar: const Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                      ),
                      label: Text(reminderLabel(minutes)),
                      onDeleted: _saving
                          ? null
                          : () => setState(
                              () => _reminders = _reminders
                                  .where((item) => item != minutes)
                                  .toList(),
                            ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            ActionChip(
              avatar: const Icon(Icons.add_alarm_rounded, size: 18),
              label: const Text('添加提醒'),
              onPressed: _saving ? null : _addReminder,
            ),
            if (_dueAt == null && _reminders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '设置截止日期后提醒才会生效',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _sheetLabel(context, '重复'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final preset in _recurrencePresets)
                  ChoiceChip(
                    label: Text(preset.$1),
                    selected: _recurrence == preset.$2,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _recurrence = preset.$2),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.edit_calendar_rounded, size: 18),
                  label: Text(
                    _recurrence.isEmpty ||
                            _recurrencePresets.any(
                              (preset) => preset.$2 == _recurrence,
                            )
                        ? '自定义…'
                        : '自定义规则',
                  ),
                  onPressed: _saving ? null : _editRecurrence,
                ),
              ],
            ),
            if (_dueAt == null && _recurrence.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '设置截止日期后重复任务才会推进',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
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
                      onChanged: _saving
                          ? null
                          : (_) => _toggleSubtask(item.id),
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
            if (widget.task.recurrence.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _skipOccurrence,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text('跳过本次'),
                ),
              ),
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
