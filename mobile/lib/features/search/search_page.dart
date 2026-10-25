import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/models.dart';
import '../../data/calendar/calendar_api.dart';
import '../../data/countdowns/countdown_api.dart';
import '../../data/habits/habit_api.dart';
import '../../design/components.dart';
import '../../design/format.dart';

enum SearchScope { all, tasks, events, habits, countdowns }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.loadRemote = true});

  /// Remote modules are disabled in widget tests and can be disabled when the
  /// caller only wants local task search.
  final bool loadRemote;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  final _queryFocus = FocusNode();
  StreamSubscription<List<TaskItem>>? _openSub;
  StreamSubscription<List<TaskItem>>? _doneSub;
  CalendarApi? _calendarApi;
  HabitApi? _habitApi;
  CountdownApi? _countdownApi;

  List<TaskItem> _tasks = const [];
  List<CalendarEvent> _events = const [];
  List<HabitItem> _habits = const [];
  List<CountdownItem> _countdowns = const [];
  bool _remoteLoading = false;
  String? _remoteError;
  SearchScope _scope = SearchScope.all;
  _SearchFilters _filters = const _SearchFilters();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final session = app.session;
    _openSub = app.store.watchTasks(completed: false, view: 'all').listen((
      tasks,
    ) {
      if (!mounted) return;
      setState(() {
        _tasks = [...tasks, ..._tasks.where((task) => task.completed)];
      });
    });
    _doneSub = app.store.watchTasks(completed: true, view: 'all').listen((
      tasks,
    ) {
      if (!mounted) return;
      setState(() {
        _tasks = [..._tasks.where((task) => !task.completed), ...tasks];
      });
    });
    if (session != null) {
      _calendarApi = CalendarApi(
        baseUrl: session.baseUrl,
        username: session.username,
        password: session.password,
      );
      _habitApi = HabitApi(
        baseUrl: session.baseUrl,
        username: session.username,
        password: session.password,
      );
      _countdownApi = CountdownApi(
        baseUrl: session.baseUrl,
        username: session.username,
        password: session.password,
      );
      if (widget.loadRemote) unawaited(_loadRemote());
    }
  }

  @override
  void dispose() {
    _openSub?.cancel();
    _doneSub?.cancel();
    _calendarApi?.close();
    _habitApi?.close();
    _countdownApi?.close();
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRemote() async {
    final calendar = _calendarApi;
    final habits = _habitApi;
    final countdowns = _countdownApi;
    if (calendar == null || habits == null || countdowns == null) return;
    setState(() {
      _remoteLoading = true;
      _remoteError = null;
    });
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 1, 1);
    final to = DateTime(now.year, now.month + 2, 1);
    List<CalendarEvent> events = const [];
    List<HabitItem> habitItems = const [];
    List<CountdownItem> countdownItems = const [];
    String? error;
    Future<void> loadEvents() async {
      try {
        final snapshot = await calendar
            .fetch(from: from, to: to)
            .timeout(const Duration(seconds: 8));
        events = snapshot.events;
      } catch (value) {
        error ??= value.toString();
      }
    }

    Future<void> loadHabits() async {
      try {
        final snapshot = await habits.fetch().timeout(
          const Duration(seconds: 8),
        );
        habitItems = snapshot.habits;
      } catch (value) {
        error ??= value.toString();
      }
    }

    Future<void> loadCountdowns() async {
      try {
        countdownItems = await countdowns.fetch().timeout(
          const Duration(seconds: 8),
        );
      } catch (value) {
        error ??= value.toString();
      }
    }

    await Future.wait([loadEvents(), loadHabits(), loadCountdowns()]);
    if (!mounted) return;
    setState(() {
      _events = events;
      _habits = habitItems;
      _countdowns = countdownItems;
      _remoteLoading = false;
      _remoteError = error;
    });
  }

  String get _needle => _query.text.trim().toLowerCase();

  bool get _hasQuery => _needle.isNotEmpty;

  List<TaskListItem> get _lists =>
      context.read<AppState>().store.listsSnapshot();

  List<TaskItem> get _taskResults {
    if (!_hasQuery) return const [];
    final items = _tasks
        .where((task) {
          if (!_matchesTask(task)) return false;
          if (_filters.status == 'open' && task.completed) return false;
          if (_filters.status == 'completed' && !task.completed) return false;
          if (_filters.priority >= 0 && task.priority != _filters.priority) {
            return false;
          }
          if (_filters.listId != null && task.listId != _filters.listId) {
            return false;
          }
          if (_filters.tags.isNotEmpty &&
              !_filters.tags.every(task.tags.contains)) {
            return false;
          }
          return _matchesDue(task);
        })
        .toList(growable: false);
    return items..sort((a, b) => (b.updatedAt).compareTo(a.updatedAt));
  }

  bool _matchesTask(TaskItem task) {
    if (task.title.toLowerCase().contains(_needle)) return true;
    if (task.notes.toLowerCase().contains(_needle)) return true;
    if (task.tags.any((tag) => tag.toLowerCase().contains(_needle))) {
      return true;
    }
    if (task.checklist.any(
      (item) => item.title.toLowerCase().contains(_needle),
    )) {
      return true;
    }
    final list = context.read<AppState>().store.list(task.listId);
    return list != null && list.name.toLowerCase().contains(_needle);
  }

  bool _matchesDue(TaskItem task) {
    final due = task.dueAt?.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_filters.due) {
      case 'today':
        return due != null &&
            due.year == today.year &&
            due.month == today.month &&
            due.day == today.day;
      case 'next7':
        final end = today.add(const Duration(days: 7));
        return due != null && !due.isBefore(today) && due.isBefore(end);
      case 'overdue':
        return !task.completed && due != null && due.isBefore(now);
      case 'none':
        return due == null;
      default:
        return true;
    }
  }

  List<CalendarEvent> get _eventResults {
    if (!_hasQuery) return const [];
    final items = _events
        .where((event) {
          return event.summary.toLowerCase().contains(_needle) ||
              event.location.toLowerCase().contains(_needle) ||
              event.description.toLowerCase().contains(_needle) ||
              event.calendarName.toLowerCase().contains(_needle);
        })
        .toList(growable: false);
    items.sort((a, b) => a.start.compareTo(b.start));
    return items;
  }

  List<HabitItem> get _habitResults {
    if (!_hasQuery) return const [];
    return _habits
        .where(
          (habit) =>
              habit.name.toLowerCase().contains(_needle) ||
              habit.unit.toLowerCase().contains(_needle),
        )
        .toList(growable: false);
  }

  List<CountdownItem> get _countdownResults {
    if (!_hasQuery) return const [];
    return _countdowns
        .where(
          (item) =>
              item.name.toLowerCase().contains(_needle) ||
              item.remark.toLowerCase().contains(_needle),
        )
        .toList(growable: false);
  }

  bool get _showTasks =>
      _scope == SearchScope.all || _scope == SearchScope.tasks;
  bool get _showEvents =>
      _scope == SearchScope.all || _scope == SearchScope.events;
  bool get _showHabits =>
      _scope == SearchScope.all || _scope == SearchScope.habits;
  bool get _showCountdowns =>
      _scope == SearchScope.all || _scope == SearchScope.countdowns;

  List<String> get _allTags {
    final tags = <String>{};
    for (final task in _tasks) {
      tags.addAll(task.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  Future<void> _openFilters() async {
    final selected = await showModalBottomSheet<_SearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _FilterSheet(initial: _filters, lists: _lists, tags: _allTags),
    );
    if (selected != null && mounted) {
      setState(() => _filters = selected);
    }
  }

  void _showEvent(CalendarEvent event) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(event.summary, style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              _SearchDetailRow(
                icon: Icons.schedule_rounded,
                text: _eventTime(event),
              ),
              _SearchDetailRow(
                icon: Icons.calendar_today_outlined,
                text: event.calendarName,
              ),
              if (event.location.isNotEmpty)
                _SearchDetailRow(
                  icon: Icons.place_outlined,
                  text: event.location,
                ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showHabit(HabitItem habit) {
    final theme = Theme.of(context);
    final color = colorFromHex(habit.color);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(habit.name, style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SearchDetailRow(
                icon: Icons.bolt_rounded,
                text: '连续 ${habit.currentStreak} 天',
              ),
              _SearchDetailRow(
                icon: Icons.history_rounded,
                text: '累计 ${habit.totalCheckIns} 次',
              ),
              if (habit.targetDays > 0)
                _SearchDetailRow(
                  icon: Icons.flag_outlined,
                  text: '目标 ${habit.targetDays} 天',
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountdown(CountdownItem item) {
    final theme = Theme.of(context);
    final color = colorFromHex(item.color);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      item.type == 'birthday'
                          ? Icons.cake_rounded
                          : Icons.hourglass_bottom_rounded,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.name, style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SearchDetailRow(
                icon: Icons.event_outlined,
                text: _stampLabel(item.occurrenceDate),
              ),
              _SearchDetailRow(
                icon: Icons.timelapse_rounded,
                text: item.isToday
                    ? '就是今天'
                    : '${item.days} 天${item.isPast ? '前' : '后'}',
              ),
              if (item.remark.isNotEmpty)
                _SearchDetailRow(icon: Icons.notes_rounded, text: item.remark),
            ],
          ),
        ),
      ),
    );
  }

  String _stampLabel(int stamp) {
    if (stamp <= 0) return '';
    final text = stamp.toString().padLeft(8, '0');
    return '${text.substring(0, 4)}.${text.substring(4, 6)}.${text.substring(6, 8)}';
  }

  String _eventTime(CalendarEvent event) {
    final start = event.start.toLocal();
    final end = event.end.toLocal();
    if (event.allDay) {
      return '${start.month}月${start.day}日 · 全天';
    }
    final date = '${start.month}月${start.day}日';
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endTime =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$date $time - $endTime';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final taskResults = _showTasks ? _taskResults : const <TaskItem>[];
    final eventResults = _showEvents ? _eventResults : const <CalendarEvent>[];
    final habitResults = _showHabits ? _habitResults : const <HabitItem>[];
    final countdownResults = _showCountdowns
        ? _countdownResults
        : const <CountdownItem>[];
    final resultCount =
        taskResults.length +
        eventResults.length +
        habitResults.length +
        countdownResults.length;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 2),
          child: TextField(
            controller: _query,
            focusNode: _queryFocus,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              color: scheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: '搜索任务、日程、习惯、倒数',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: scheme.onSurfaceVariant,
              ),
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 42,
                minHeight: 42,
              ),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      onPressed: () {
                        _query.clear();
                        setState(() {});
                        _queryFocus.requestFocus();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.45),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
        actions: [
          if (_showTasks)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: '筛选任务',
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune_rounded),
                ),
                if (_filters.activeCount > 0)
                  Positioned(
                    right: 8,
                    top: 7,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_filters.activeCount}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 16, 2),
            child: AppUnderlineTabs<SearchScope>(
              values: SearchScope.values,
              labels: const ['全部', '任务', '日程', '习惯', '倒数'],
              selected: _scope,
              onChanged: (value) => setState(() => _scope = value),
            ),
          ),
          if (_remoteLoading) const LinearProgressIndicator(minHeight: 2),
          if (_remoteError != null && _scope != SearchScope.tasks)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '部分远程内容加载失败，任务搜索仍可用',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _loadRemote, child: const Text('重试')),
                ],
              ),
            ),
          if (_filters.activeCount > 0 && _showTasks)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _filters.summary(_lists),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _filters = const _SearchFilters()),
                    child: const Text('清除筛选'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: !_hasQuery
                ? const Center(
                    child: AppEmptyState(
                      icon: Icons.search_rounded,
                      title: '搜索所有内容',
                      message: '输入关键词，查找任务、日程、习惯和倒数日。',
                    ),
                  )
                : resultCount == 0
                ? const Center(
                    child: AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: '没有匹配结果',
                      message: '换个关键词，或放宽任务筛选条件。',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (taskResults.isNotEmpty)
                        _SearchSection(
                          title: '任务',
                          count: taskResults.length,
                          children: [
                            for (var i = 0; i < taskResults.length; i++) ...[
                              _SearchTaskRow(
                                task: taskResults[i],
                                list: context.read<AppState>().store.list(
                                  taskResults[i].listId,
                                ),
                                onToggle: () => context
                                    .read<AppState>()
                                    .repository
                                    .toggleCompleted(taskResults[i].id),
                                onTap: () =>
                                    Navigator.pop(context, taskResults[i]),
                              ),
                              if (i != taskResults.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 58,
                                  endIndent: 14,
                                  color: scheme.outlineVariant,
                                ),
                            ],
                          ],
                        ),
                      if (eventResults.isNotEmpty)
                        _SearchSection(
                          title: '日程',
                          count: eventResults.length,
                          children: [
                            for (var i = 0; i < eventResults.length; i++) ...[
                              _SearchEventRow(
                                event: eventResults[i],
                                onTap: () => _showEvent(eventResults[i]),
                              ),
                              if (i != eventResults.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 58,
                                  endIndent: 14,
                                  color: scheme.outlineVariant,
                                ),
                            ],
                          ],
                        ),
                      if (habitResults.isNotEmpty)
                        _SearchSection(
                          title: '习惯',
                          count: habitResults.length,
                          children: [
                            for (var i = 0; i < habitResults.length; i++) ...[
                              _SearchHabitRow(
                                habit: habitResults[i],
                                onTap: () => _showHabit(habitResults[i]),
                              ),
                              if (i != habitResults.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 58,
                                  endIndent: 14,
                                  color: scheme.outlineVariant,
                                ),
                            ],
                          ],
                        ),
                      if (countdownResults.isNotEmpty)
                        _SearchSection(
                          title: '倒数日',
                          count: countdownResults.length,
                          children: [
                            for (
                              var i = 0;
                              i < countdownResults.length;
                              i++
                            ) ...[
                              _SearchCountdownRow(
                                item: countdownResults[i],
                                onTap: () =>
                                    _showCountdown(countdownResults[i]),
                              ),
                              if (i != countdownResults.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 58,
                                  endIndent: 14,
                                  color: scheme.outlineVariant,
                                ),
                            ],
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchFilters {
  const _SearchFilters({
    this.status = 'all',
    this.priority = -1,
    this.listId,
    this.due = 'all',
    this.tags = const {},
  });

  final String status;
  final int priority;
  final String? listId;
  final String due;
  final Set<String> tags;

  int get activeCount =>
      (status == 'all' ? 0 : 1) +
      (priority >= 0 ? 1 : 0) +
      (listId == null ? 0 : 1) +
      (due == 'all' ? 0 : 1) +
      (tags.isEmpty ? 0 : 1);

  String summary(List<TaskListItem> lists) {
    final parts = <String>[];
    if (status == 'open') parts.add('未完成');
    if (status == 'completed') parts.add('已完成');
    if (priority >= 0) {
      parts.add('优先级 ${const ['无', '低', '中', '高'][priority]}');
    }
    if (listId != null) {
      parts.add(
        lists.where((list) => list.id == listId).firstOrNull?.name ?? '清单',
      );
    }
    if (due == 'today') parts.add('今天');
    if (due == 'next7') parts.add('最近 7 天');
    if (due == 'overdue') parts.add('已逾期');
    if (due == 'none') parts.add('无日期');
    if (tags.isNotEmpty) parts.add('标签 ${tags.join('、')}');
    return parts.join(' · ');
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.lists,
    required this.tags,
  });

  final _SearchFilters initial;
  final List<TaskListItem> lists;
  final List<String> tags;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _status;
  late int _priority;
  late String? _listId;
  late String _due;
  late Set<String> _tags;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _priority = widget.initial.priority;
    _listId = widget.initial.listId;
    _due = widget.initial.due;
    _tags = {...widget.initial.tags};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('筛选任务', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              _filterLabel('状态'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choice('全部', _status == 'all', () => _status = 'all'),
                  _choice('未完成', _status == 'open', () => _status = 'open'),
                  _choice(
                    '已完成',
                    _status == 'completed',
                    () => _status = 'completed',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _filterLabel('优先级'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choice('全部', _priority < 0, () => _priority = -1),
                  _choice('高', _priority == 3, () => _priority = 3),
                  _choice('中', _priority == 2, () => _priority = 2),
                  _choice('低', _priority == 1, () => _priority = 1),
                  _choice('无', _priority == 0, () => _priority = 0),
                ],
              ),
              const SizedBox(height: 16),
              _filterLabel('清单'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choice('全部', _listId == null, () => _listId = null),
                  for (final list in widget.lists)
                    _choice(
                      list.name,
                      _listId == list.id,
                      () => _listId = list.id,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _filterLabel('日期'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choice('全部', _due == 'all', () => _due = 'all'),
                  _choice('今天', _due == 'today', () => _due = 'today'),
                  _choice('最近 7 天', _due == 'next7', () => _due = 'next7'),
                  _choice('已逾期', _due == 'overdue', () => _due = 'overdue'),
                  _choice('无日期', _due == 'none', () => _due = 'none'),
                ],
              ),
              if (widget.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                _filterLabel('标签'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in widget.tags)
                      FilterChip(
                        label: Text(tag),
                        selected: _tags.contains(tag),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _tags.add(tag);
                          } else {
                            _tags.remove(tag);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _status = 'all';
                      _priority = -1;
                      _listId = null;
                      _due = 'all';
                      _tags.clear();
                    }),
                    child: const Text('重置'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _SearchFilters(
                        status: _status,
                        priority: _priority,
                        listId: _listId,
                        due: _due,
                        tags: _tags,
                      ),
                    ),
                    child: const Text('应用筛选'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(onTap),
    );
  }

  Widget _filterLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionLabel(
            title: '$title $count',
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SearchTaskRow extends StatelessWidget {
  const _SearchTaskRow({
    required this.task,
    required this.list,
    required this.onToggle,
    required this.onTap,
  });

  final TaskItem task;
  final TaskListItem? list;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final due = task.dueAt;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: task.completed ? '标记为未完成' : '标记为完成',
              child: InkResponse(
                onTap: onToggle,
                radius: 18,
                child: Icon(
                  task.completed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: task.completed ? scheme.primary : scheme.outline,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (task.completed) '已完成',
                      if (due != null) formatDue(due, allDay: task.allDay),
                      if (list != null) list!.name,
                      if (task.tags.isNotEmpty) '#${task.tags.first}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isOverdue(task)
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEventRow extends StatelessWidget {
  const _SearchEventRow({required this.event, required this.onTap});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: colorFromHex(event.color).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.event_rounded,
                size: 17,
                color: colorFromHex(event.color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _eventTime(event),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHabitRow extends StatelessWidget {
  const _SearchHabitRow({required this.habit, required this.onTap});

  final HabitItem habit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = colorFromHex(habit.color);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 17,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '连续 ${habit.currentStreak} 天 · 累计 ${habit.totalCheckIns} 次',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCountdownRow extends StatelessWidget {
  const _SearchCountdownRow({required this.item, required this.onTap});

  final CountdownItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = colorFromHex(item.color);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.type == 'birthday'
                    ? Icons.cake_rounded
                    : Icons.hourglass_bottom_rounded,
                size: 17,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.isToday
                        ? '就是今天'
                        : '${item.days} 天${item.isPast ? '前' : '后'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchDetailRow extends StatelessWidget {
  const _SearchDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

String _eventTime(CalendarEvent event) {
  final start = event.start.toLocal();
  final end = event.end.toLocal();
  if (event.allDay) return '${start.month}月${start.day}日 · 全天';
  final date = '${start.month}月${start.day}日';
  final from =
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  final to =
      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  return '$date $from - $to';
}
