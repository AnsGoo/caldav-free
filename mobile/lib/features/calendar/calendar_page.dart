import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/models.dart';
import '../../core/recurrence.dart';
import '../../core/ui_utils.dart';
import '../../data/calendar/calendar_api.dart';
import '../../design/app_theme.dart';
import '../../design/components.dart';
import '../../design/format.dart';
import '../tasks/tasks_page.dart';

enum CalendarView { month, week, schedule, day, year }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarApi? _api;
  CalendarView _view = CalendarView.schedule;
  DateTime _anchor = _dateOnly(DateTime.now());
  CalendarSnapshot? _snapshot;
  Map<String, CalendarAlmanacDay> _almanac = const {};
  bool _loading = false;
  int _request = 0;
  bool _connected = false;
  DateTime? _composingDay;

  @override
  void initState() {
    super.initState();
    final session = context.read<AppState>().session;
    if (session != null) {
      _api = CalendarApi(
        baseUrl: session.baseUrl,
        username: session.username,
        password: session.password,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final connected = context.watch<AppState>().connected;
    if (connected == _connected && _api != null) return;
    _connected = connected;
    _api?.close();
    final session = context.read<AppState>().session;
    _api = connected && session != null
        ? CalendarApi(
            baseUrl: session.baseUrl,
            username: session.username,
            password: session.password,
          )
        : null;
    if (_api != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    } else if (mounted) {
      setState(() {
        _snapshot = null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (_api == null) return;
    final request = ++_request;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }
    final (from, to) = _rangeFor(_view, _anchor);
    try {
      final snapshot = await _fetchSnapshot(from, to);
      var almanac = const <String, CalendarAlmanacDay>{};
      if (_view == CalendarView.month ||
          _view == CalendarView.week ||
          _view == CalendarView.day) {
        try {
          almanac = await _api!.fetchAlmanac(from: from, to: to);
        } catch (_) {
          // The grid still works without the cultural labels.
        }
      }
      if (!mounted || request != _request) return;
      setState(() {
        _snapshot = snapshot;
        _almanac = almanac;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<CalendarSnapshot> _fetchSnapshot(DateTime from, DateTime to) async {
    if (_view != CalendarView.year) {
      return _api!.fetch(from: from, to: to);
    }
    final year = from.year;
    final ranges = [
      (DateTime(year, 1, 1), DateTime(year, 4, 1)),
      (DateTime(year, 4, 1), DateTime(year, 7, 1)),
      (DateTime(year, 7, 1), DateTime(year, 10, 1)),
      (DateTime(year, 10, 1), DateTime(year + 1, 1, 1)),
    ];
    final snapshots = await Future.wait(
      ranges.map((range) => _api!.fetch(from: range.$1, to: range.$2)),
    );
    final sources = <int, CalendarSource>{};
    final events = <String, CalendarEvent>{};
    final tasks = <String, CalendarTask>{};
    for (final snapshot in snapshots) {
      for (final source in snapshot.sources) {
        sources[source.id] = source;
      }
      for (final event in snapshot.events) {
        events['${event.id}:${event.start.toUtc().toIso8601String()}'] = event;
      }
      for (final task in snapshot.tasks) {
        tasks['${task.syncId}:${task.occurrence}:${task.id}'] = task;
      }
    }
    final mergedEvents = events.values.toList(growable: false)
      ..sort((a, b) => a.start.compareTo(b.start));
    final mergedTasks = tasks.values.toList(growable: false);
    return CalendarSnapshot(
      sources: sources.values.toList(growable: false),
      events: mergedEvents,
      tasks: mergedTasks,
      from: from,
      to: to,
    );
  }

  (DateTime, DateTime) _rangeFor(CalendarView view, DateTime anchor) {
    switch (view) {
      case CalendarView.month:
        final first = DateTime(anchor.year, anchor.month, 1);
        return (
          first.subtract(const Duration(days: 7)),
          DateTime(
            anchor.year,
            anchor.month + 1,
            1,
          ).add(const Duration(days: 7)),
        );
      case CalendarView.week:
        // The pager renders the neighbouring weeks too, so fetch one week of
        // padding on both sides of the visible week.
        final sunday = _sundayOf(anchor);
        return (
          sunday.subtract(const Duration(days: 7)),
          sunday.add(const Duration(days: 21)),
        );
      case CalendarView.schedule:
        return (anchor, anchor.add(const Duration(days: 3)));
      case CalendarView.day:
        return (
          anchor.subtract(const Duration(days: 8)),
          anchor.add(const Duration(days: 8)),
        );
      case CalendarView.year:
        return (DateTime(anchor.year, 1, 1), DateTime(anchor.year + 1, 1, 1));
    }
  }

  void _setView(CalendarView view) {
    setState(() {
      _view = view;
      _anchor = _dateOnly(DateTime.now());
      _composingDay = null;
    });
    unawaited(_load());
  }

  void _move(int delta) {
    setState(() {
      _composingDay = null;
      _anchor = switch (_view) {
        CalendarView.month => DateTime(_anchor.year, _anchor.month + delta, 1),
        CalendarView.week => _anchor.add(Duration(days: 7 * delta)),
        CalendarView.schedule => _anchor.add(Duration(days: 3 * delta)),
        CalendarView.day => _anchor.add(Duration(days: delta)),
        CalendarView.year => DateTime(_anchor.year + delta, 1, 1),
      };
    });
    unawaited(_load());
  }

  void _today() {
    setState(() {
      _anchor = _dateOnly(DateTime.now());
      _composingDay = null;
    });
    unawaited(_load());
  }

  void _selectDay(DateTime day) {
    setState(() {
      _anchor = day;
      _view = CalendarView.day;
      _composingDay = null;
    });
    unawaited(_load());
  }

  void _selectDate(DateTime day) {
    setState(() {
      _anchor = _dateOnly(day);
      _composingDay = null;
    });
    unawaited(_load());
  }

  void _startCompose(DateTime day) {
    if (_composingDay == day) return;
    setState(() => _composingDay = day);
  }

  void _cancelCompose() {
    if (_composingDay == null) return;
    setState(() => _composingDay = null);
  }

  /// Inline month-cell quick add: the task is written locally with an all-day
  /// due date and the silent sync thread pushes it; the dot shows up from the
  /// local merge without any request here.
  Future<void> _commitCompose(String title) async {
    final day = _composingDay;
    if (day == null) return;
    final app = context.read<AppState>();
    final lists = app.store.listsSnapshot();
    final list = app.store.inbox() ?? (lists.isEmpty ? null : lists.first);
    if (list == null) {
      _cancelCompose();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('还没有清单，请先在任务页新建清单')));
      return;
    }
    try {
      await app.repository.createTask(
        title: title,
        listId: list.id,
        dueAt: DateTime(day.year, day.month, day.day),
        allDay: true,
      );
    } catch (error) {
      _cancelCompose();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('新建任务失败：$error')));
      return;
    }
    // Rebuild so the merged local task shows on the cell immediately.
    if (!mounted) return;
    setState(() => _composingDay = null);
  }

  /// Offline fallback: the calendar is rendered from the local task store so
  /// scheduled tasks stay visible while the server is unreachable.
  ///
  /// Recurring tasks follow internal/web/calendar.go: the due date is the first
  /// occurrence and every later one is a virtual entry, so a finished or
  /// undated repeat does not reach the calendar at all.
  CalendarSnapshot _localSnapshot() {
    final store = context.read<AppState>().store;
    final lists = {for (final l in store.listsSnapshot()) l.id: l};
    final (from, to) = _rangeFor(_view, _anchor);
    final tasks = <CalendarTask>[];
    for (final t in store.allTasks()) {
      if (t.deleted || t.kind != TaskKind.task) continue;
      final due = t.dueAt?.toLocal();
      final start = t.startAt?.toLocal();
      if (due == null && start == null) continue;
      final list = lists[t.listId];
      CalendarTask entry(DateTime when, {bool virtual = false}) => CalendarTask(
        id: 0,
        syncId: t.id,
        title: t.title,
        listName: list?.name ?? '',
        listColor: list?.color ?? '',
        start: start,
        due: when,
        allDay: t.allDay,
        completed: t.completed,
        priority: t.priority,
        occurrence: virtual ? when.toIso8601String() : '',
        virtual: virtual,
        recurring: t.recurrence.isNotEmpty,
      );
      if (t.recurrence.isNotEmpty) {
        if (due == null || t.completed) continue;
        for (final when in occurrencesBetween(t.recurrence, due, from, to)) {
          tasks.add(entry(when, virtual: true));
        }
        continue;
      }
      final when = due ?? start!;
      if (!when.isBefore(from) && when.isBefore(to)) tasks.add(entry(when));
    }
    return CalendarSnapshot(
      sources: const [],
      events: const [],
      tasks: tasks,
      from: from,
      to: to,
    );
  }

  /// Local tasks that the server snapshot does not carry yet (created while
  /// offline, or not synced for the window) are merged in by syncId.
  CalendarSnapshot _mergeLocalTasks(CalendarSnapshot? snapshot) {
    if (snapshot == null) return _localSnapshot();
    final known = {for (final t in snapshot.tasks) t.syncId};
    final extra = _localSnapshot().tasks
        .where((t) => t.syncId.isNotEmpty && !known.contains(t.syncId))
        .toList();
    if (extra.isEmpty) return snapshot;
    return CalendarSnapshot(
      sources: snapshot.sources,
      events: snapshot.events,
      tasks: [...snapshot.tasks, ...extra],
      from: snapshot.from,
      to: snapshot.to,
    );
  }

  Future<void> _toggleTask(CalendarTask task) async {
    if (task.syncId.isEmpty || task.virtual) return;
    final app = context.read<AppState>();
    if (app.store.task(task.syncId) == null) return;
    try {
      await app.repository.toggleCompleted(task.syncId);
      final snapshot = _snapshot;
      if (mounted && snapshot != null) {
        final completed = !task.completed;
        setState(() {
          _snapshot = CalendarSnapshot(
            sources: snapshot.sources,
            events: snapshot.events,
            tasks: snapshot.tasks
                .map(
                  (item) =>
                      item.syncId == task.syncId &&
                          (task.occurrence.isEmpty ||
                              item.occurrence == task.occurrence)
                      ? item.copyWith(completed: completed)
                      : item,
                )
                .toList(growable: false),
            from: snapshot.from,
            to: snapshot.to,
          );
        });
      }
      unawaited(app.syncNow());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新任务失败：$error')));
    }
  }

  List<CalendarSource> get _writableSources =>
      (_snapshot?.sources ?? const <CalendarSource>[])
          .where((source) => source.id > 0)
          .toList(growable: false);

  /// 日视图只保留新建日程入口；任务统一在任务页创建。
  Widget? _fab() {
    if (_writableSources.isEmpty) return null;
    return Tooltip(
      message: '新建日程',
      child: FloatingActionButton.small(
        heroTag: 'calendar-compose-fab',
        onPressed: _createEvent,
        child: const Icon(Icons.add_rounded, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('日历'),
            const SizedBox(height: 5),
            Text(
              _viewLabel(_view),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<CalendarView>(
            tooltip: '切换日历视图',
            icon: const Icon(Icons.calendar_view_month_rounded),
            onSelected: _setView,
            itemBuilder: (context) => [
              for (final view in const [
                CalendarView.year,
                CalendarView.month,
                CalendarView.week,
                CalendarView.day,
                CalendarView.schedule,
              ])
                PopupMenuItem(
                  value: view,
                  child: Row(
                    children: [
                      Icon(
                        _viewIcon(view),
                        size: 19,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(_viewLabel(view)),
                      const SizedBox(width: 20),
                      if (_view == view)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'iCal 订阅',
            onPressed: _manageSubscriptions,
            icon: const Icon(Icons.rss_feed_rounded),
          ),
          IconButton(
            tooltip: '刷新日历',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: _fab(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
            child: Row(
              children: [
                IconButton(
                  tooltip: '上一段',
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    _title(_view, _anchor),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '下一段',
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                TextButton(onPressed: _today, child: const Text('今天')),
              ],
            ),
          ),
          if (snapshot != null && snapshot.sources.isNotEmpty)
            _SourceLegend(sources: snapshot.sources),
          Expanded(
            child: Builder(
              builder: (context) {
                final effective = _mergeLocalTasks(snapshot);
                return switch (_view) {
                  CalendarView.month => LayoutBuilder(
                    builder: (context, constraints) {
                      // 只保留本月实际需要的周数，月历随行数自然变矮，
                      // 把更多空间留给下方的当月任务列表。
                      final firstOfMonth = DateTime(
                        _anchor.year,
                        _anchor.month,
                        1,
                      );
                      final daysInMonth = DateTime(
                        _anchor.year,
                        _anchor.month + 1,
                        0,
                      ).day;
                      final weeks =
                          ((firstOfMonth.weekday - 1 + daysInMonth) / 7).ceil();
                      final preferred = constraints.maxHeight * 0.46;
                      final compact = 36.0 + weeks * 78.0;
                      final gridHeight = math
                          .min(preferred, compact)
                          .clamp(260.0, 500.0)
                          .clamp(
                            0.0,
                            math.max(0.0, constraints.maxHeight - 120),
                          )
                          .toDouble();
                      return Column(
                        children: [
                          SizedBox(
                            height: gridHeight,
                            child: _MonthView(
                              anchor: _anchor,
                              snapshot: effective,
                              almanac: _almanac,
                              composingDay: _composingDay,
                              onSelectDay: _selectDay,
                              onOpenEvent: _openEvent,
                              onOpenTask: _openTask,
                              onToggleTask: _toggleTask,
                              onStartCompose: _startCompose,
                              onCommitCompose: _commitCompose,
                              onCancelCompose: _cancelCompose,
                            ),
                          ),
                          Expanded(
                            child: _MonthTaskList(
                              anchor: _anchor,
                              snapshot: effective,
                              onOpenTask: _openTask,
                              onToggleTask: _toggleTask,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  CalendarView.week => _WeekView(
                    anchor: _anchor,
                    snapshot: effective,
                    almanac: _almanac,
                    onSelectDay: _selectDay,
                    onSelectedDate: _selectDate,
                    onOpenEvent: _openEvent,
                    onOpenTask: _openTask,
                    onToggleTask: _toggleTask,
                  ),
                  CalendarView.schedule => _ScheduleView(
                    anchor: _anchor,
                    snapshot: effective,
                    onSelectDay: _selectDay,
                    onOpenEvent: _openEvent,
                    onOpenTask: _openTask,
                    onToggleTask: _toggleTask,
                  ),
                  CalendarView.day => _DayView(
                    anchor: _anchor,
                    snapshot: effective,
                    almanac: _almanac,
                    composingDay: _composingDay,
                    onSelectedDate: _selectDate,
                    onOpenEvent: _openEvent,
                    onOpenTask: _openTask,
                    onToggleTask: _toggleTask,
                    onCommitCompose: _commitCompose,
                    onCancelCompose: _cancelCompose,
                  ),
                  CalendarView.year => _YearView(
                    anchor: _anchor,
                    snapshot: effective,
                    onSelectDay: _selectDay,
                    bottomInset: _writableSources.isEmpty ? 12 : 78,
                  ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  String _title(CalendarView view, DateTime anchor) {
    switch (view) {
      case CalendarView.month:
        return '${anchor.year}年${anchor.month}月';
      case CalendarView.week:
        return '${anchor.year}年${anchor.month}月';
      case CalendarView.schedule:
        final end = anchor.add(const Duration(days: 2));
        return '${anchor.month}月${anchor.day}日 - ${end.month}月${end.day}日';
      case CalendarView.day:
        return '${anchor.year}年${anchor.month}月';
      case CalendarView.year:
        return '${anchor.year}年';
    }
  }

  String _viewLabel(CalendarView view) => switch (view) {
    CalendarView.month => '月视图',
    CalendarView.week => '周视图',
    CalendarView.schedule => '日程',
    CalendarView.day => '日视图',
    CalendarView.year => '年视图',
  };

  IconData _viewIcon(CalendarView view) => switch (view) {
    CalendarView.month => Icons.calendar_view_month_rounded,
    CalendarView.week => Icons.view_week_outlined,
    CalendarView.schedule => Icons.view_column_outlined,
    CalendarView.day => Icons.calendar_view_day_rounded,
    CalendarView.year => Icons.grid_view_rounded,
  };

  Future<void> _openEvent(CalendarEvent event) async {
    final canEdit =
        event.calendarId > 0 &&
        !event.readOnly &&
        _writableSources.any((source) => source.id == event.calendarId);
    if (canEdit) {
      await _editEvent(event);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EventSheet(event: event),
    );
  }

  Future<void> _createEvent() async {
    final sources = _writableSources;
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有可写入的 VEVENT 日历')));
      return;
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour + 1);
    final draft = await showModalBottomSheet<_EventDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EventEditorSheet(
        calendars: sources,
        initialCalendarId: sources.first.id,
        initialStart: start,
        initialEnd: start.add(const Duration(hours: 1)),
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await _api!.createEvent(
        calendarId: draft.calendarId,
        summary: draft.summary,
        start: draft.start,
        end: draft.end,
        allDay: draft.allDay,
        location: draft.location,
        description: draft.description,
        reminders: draft.reminders,
      );
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建日程失败：$error')));
    }
  }

  Future<_EventScope?> _chooseScope(CalendarEvent event, String action) async {
    if (!event.recurring || event.recurrenceId.isEmpty) {
      return _EventScope.all;
    }
    return showModalBottomSheet<_EventScope>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('$action重复日程'), subtitle: Text(event.summary)),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.looks_one_outlined),
              title: const Text('仅此次'),
              subtitle: const Text('只修改/删除当前实例'),
              onTap: () => Navigator.pop(context, _EventScope.single),
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('整个系列'),
              subtitle: const Text('修改/删除所有重复实例'),
              onTap: () => Navigator.pop(context, _EventScope.all),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editEvent(CalendarEvent event) async {
    final sources = _writableSources;
    if (sources.isEmpty || event.href.isEmpty) return;
    final scope = await _chooseScope(event, '编辑');
    if (scope == null || !mounted) return;
    final draft = await showModalBottomSheet<_EventDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EventEditorSheet(
        calendars: sources,
        initialCalendarId: event.calendarId,
        initialSummary: event.summary,
        initialLocation: event.location,
        initialDescription: event.description,
        initialStart: event.start.toLocal(),
        initialEnd: event.end.toLocal(),
        initialAllDay: event.allDay,
        initialReminders: event.reminders,
        lockCalendar: true,
        onDelete: () {
          Navigator.pop(context);
          unawaited(_deleteEvent(event));
        },
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await _api!.updateEvent(
        calendarId: event.calendarId,
        href: event.href,
        summary: draft.summary,
        start: draft.start,
        end: draft.end,
        allDay: draft.allDay,
        location: draft.location,
        description: draft.description,
        reminders: draft.reminders,
        rrule: event.rrule,
        attendees: event.attendees,
        scope: scope == _EventScope.single ? 'single' : 'all',
        recurrenceId: scope == _EventScope.single ? event.recurrenceId : '',
      );
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存日程失败：$error')));
    }
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final scope = await _chooseScope(event, '删除');
    if (scope == null || !mounted) return;
    final single = scope == _EventScope.single;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日程？'),
        content: Text(
          single
              ? '仅删除“${event.summary}”的此次实例，其他重复实例保留。'
              : '“${event.summary}”的整个系列将从日历中删除。',
        ),
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
    if (confirmed != true || !mounted) return;
    try {
      await _api!.deleteEvent(
        calendarId: event.calendarId,
        href: event.href,
        recurrenceId: single ? event.recurrenceId : '',
      );
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除日程失败：$error')));
    }
  }

  Future<void> _manageSubscriptions() async {
    if (_api == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: _SubscriptionSheet(api: _api!),
      ),
    );
    if (mounted) await _load(showLoading: false);
  }

  Future<void> _openTask(CalendarTask task) async {
    final app = context.read<AppState>();
    final stored = task.virtual || task.syncId.isEmpty
        ? null
        : app.store.task(task.syncId);
    if (stored != null) {
      final list = app.store
          .listsSnapshot()
          .where((l) => l.id == stored.listId)
          .firstOrNull;
      await showTaskEditor(context, task: stored, list: list);
      if (mounted) await _load(showLoading: false);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CalendarTaskSheet(task: task),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _weekday(DateTime day) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return names[day.weekday - 1];
}

DateTime _sundayOf(DateTime day) =>
    _dateOnly(day).subtract(Duration(days: day.weekday % 7));

class _SourceLegend extends StatelessWidget {
  const _SourceLegend({required this.sources});

  final List<CalendarSource> sources;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sources.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final source = sources[index];
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorFromHex(source.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                source.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Entry {
  const _Entry.event(this.event) : task = null;
  const _Entry.task(this.task) : event = null;

  final CalendarEvent? event;
  final CalendarTask? task;

  DateTime get start =>
      event?.start.toLocal() ?? task?.when?.toLocal() ?? DateTime.now();
  bool get allDay => event?.allDay ?? task?.allDay ?? false;
  String get title => event?.summary ?? task?.title ?? '';
  Color get color => colorFromHex(event?.color ?? task?.listColor ?? '');
  bool get isTask => task != null;
  bool get completed => task?.completed ?? false;
  String get key =>
      event?.id ?? 'task:${task!.syncId}:${task!.occurrence}:${task!.id}';
}

String _dateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

String? _holidayLabel(CalendarSnapshot snapshot, DateTime day) {
  final target = _dateOnly(day);
  for (final event in snapshot.events) {
    if (event.calendarName != '节假日' || event.summary.isEmpty) continue;
    if (_dateOnly(event.start.toLocal()) == target) {
      return event.summary;
    }
  }
  return null;
}

List<_Entry> _entriesForDay(CalendarSnapshot snapshot, DateTime day) {
  final start = _dateOnly(day);
  final end = start.add(const Duration(days: 1));
  final entries = <_Entry>[];
  for (final event in snapshot.events) {
    final eventStart = _dateOnly(event.start.toLocal());
    final eventEnd = event.end.toLocal();
    final last = eventEnd.isAfter(event.start.toLocal())
        ? _dateOnly(eventEnd.subtract(const Duration(seconds: 1)))
        : eventStart;
    if (!start.isBefore(eventStart) &&
        start.isBefore(last.add(const Duration(days: 1)))) {
      entries.add(_Entry.event(event));
    }
  }
  for (final task in snapshot.tasks) {
    final when = task.when;
    if (when == null) continue;
    final local = when.toLocal();
    if (!local.isBefore(start) && local.isBefore(end)) {
      entries.add(_Entry.task(task));
    }
  }
  entries.sort((a, b) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    final time = a.start.compareTo(b.start);
    if (time != 0) return time;
    return a.title.compareTo(b.title);
  });
  return entries;
}

class _MonthView extends StatefulWidget {
  const _MonthView({
    required this.anchor,
    required this.snapshot,
    required this.almanac,
    required this.composingDay,
    required this.onSelectDay,
    required this.onOpenEvent,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onStartCompose,
    required this.onCommitCompose,
    required this.onCancelCompose,
  });

  final DateTime anchor;
  final CalendarSnapshot snapshot;
  final Map<String, CalendarAlmanacDay> almanac;
  final DateTime? composingDay;
  final void Function(DateTime day) onSelectDay;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;
  final void Function(DateTime day) onStartCompose;
  final Future<void> Function(String title) onCommitCompose;
  final VoidCallback onCancelCompose;

  @override
  State<_MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<_MonthView> {
  int? _hoveredCell;

  @override
  void didUpdateWidget(covariant _MonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchor != widget.anchor) _hoveredCell = null;
  }

  @override
  Widget build(BuildContext context) {
    final anchor = widget.anchor;
    final snapshot = widget.snapshot;
    final almanac = widget.almanac;
    final first = DateTime(anchor.year, anchor.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final firstIndex = first.weekday - 1;
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final weeks = ((firstIndex + daysInMonth) / 7).ceil();
    final lastIndex = firstIndex + daysInMonth - 1;
    final today = _dateOnly(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            for (final day in const ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
            child: LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  // 只渲染本月实际占用的周数，不再补足 6 行。
                  mainAxisExtent: constraints.maxHeight / weeks,
                ),
                itemCount: weeks * 7,
                itemBuilder: (context, index) {
                  final day = gridStart.add(Duration(days: index));
                  final inMonth = day.month == anchor.month;
                  // 前后补位的日期不展示，也不画边框。
                  if (!inMonth) return const SizedBox.shrink();
                  final entries = _entriesForDay(snapshot, day);
                  final isToday = day == today;
                  final hovered = _hoveredCell == index;
                  final dayAlmanac = almanac[_dateKey(day)];
                  final holiday = _holidayLabel(snapshot, day);
                  final label = dayAlmanac?.label ?? holiday ?? '';
                  final special =
                      dayAlmanac?.special == true || holiday != null;
                  final composing = day == widget.composingDay;
                  final corner = Radius.circular(12);
                  final isTopLeft = index == firstIndex;
                  final isTopRight = index == 6;
                  final isBottomLeft = index == lastIndex - (lastIndex % 7);
                  final isBottomRight = index == lastIndex;
                  return Container(
                    decoration: BoxDecoration(
                      // 与年视图一致：画布透出，仅用细线勾勒，而不是填充卡片。
                      color: isToday
                          ? scheme.primary.withValues(alpha: 0.07)
                          : hovered
                          ? scheme.primary.withValues(alpha: 0.035)
                          : null,
                      borderRadius: BorderRadius.only(
                        topLeft: isTopLeft ? corner : Radius.zero,
                        topRight: isTopRight ? corner : Radius.zero,
                        bottomLeft: isBottomLeft ? corner : Radius.zero,
                        bottomRight: isBottomRight ? corner : Radius.zero,
                      ),
                      // 只给本月日期绘制边框，四个最外角做圆润处理。
                      border: Border(
                        top: index - 7 < firstIndex
                            ? BorderSide(color: scheme.outline)
                            : BorderSide.none,
                        left: index == firstIndex || index % 7 == 0
                            ? BorderSide(color: scheme.outline)
                            : BorderSide.none,
                        right: BorderSide(color: scheme.outline),
                        bottom: BorderSide(color: scheme.outline),
                      ),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: MouseRegion(
                        onEnter: (_) {
                          if (_hoveredCell != index) {
                            setState(() => _hoveredCell = index);
                          }
                        },
                        onExit: (_) {
                          if (_hoveredCell == index) {
                            setState(() => _hoveredCell = null);
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => widget.onSelectDay(day),
                              onLongPress: () => widget.onStartCompose(day),
                              child: LayoutBuilder(
                                builder: (context, cell) => Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: cell.maxWidth,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            width: 32,
                                            height: 32,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: isToday
                                                  ? scheme.primary
                                                  : Colors.transparent,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${day.day}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    fontSize: 14,
                                                    fontWeight: isToday
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: isToday
                                                        ? scheme.onPrimary
                                                        : inMonth
                                                        ? scheme.onSurface
                                                        : scheme
                                                              .onSurfaceVariant
                                                              .withValues(
                                                                alpha: 0.45,
                                                              ),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (composing)
                                            _DayComposer(
                                              key: ValueKey(day),
                                              onCommit: widget.onCommitCompose,
                                              onCancel: widget.onCancelCompose,
                                            )
                                          else ...[
                                            SizedBox(
                                              height: 10,
                                              child: Center(
                                                child: Text(
                                                  label,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        fontSize: 7.5,
                                                        height: 1,
                                                        color: special
                                                            ? AppColors.festivalFor(
                                                                Theme.of(
                                                                  context,
                                                                ).brightness,
                                                              )
                                                            : scheme
                                                                  .onSurfaceVariant
                                                                  .withValues(
                                                                    alpha: 0.8,
                                                                  ),
                                                        fontWeight: special
                                                            ? FontWeight.w600
                                                            : FontWeight.w500,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              height: 6,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  for (final entry
                                                      in entries.take(3))
                                                    Container(
                                                      width: 5,
                                                      height: 5,
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 1,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: entry.completed
                                                            ? scheme
                                                                  .onSurfaceVariant
                                                                  .withValues(
                                                                    alpha: 0.35,
                                                                  )
                                                            : entry.color,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!composing && _hoveredCell == index)
                              Positioned(
                                top: 1,
                                right: 2,
                                child: Tooltip(
                                  message: '在 ${day.month}月${day.day}日新建任务',
                                  waitDuration: const Duration(
                                    milliseconds: 400,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(7),
                                    onTap: () => widget.onStartCompose(day),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 15,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 月视图下方的当月任务列表：按日期分组，可直接勾选完成或打开详情。
class _MonthTaskList extends StatelessWidget {
  const _MonthTaskList({
    required this.anchor,
    required this.snapshot,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final DateTime anchor;
  final CalendarSnapshot snapshot;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = _dateOnly(DateTime.now());
    final byDay = <DateTime, List<_Entry>>{};
    for (final task in snapshot.tasks) {
      final when = task.when?.toLocal();
      if (when == null ||
          when.year != anchor.year ||
          when.month != anchor.month) {
        continue;
      }
      byDay
          .putIfAbsent(_dateOnly(when), () => <_Entry>[])
          .add(_Entry.task(task));
    }
    final days = byDay.keys.toList()..sort();
    for (final day in days) {
      byDay[day]!.sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        final time = a.start.compareTo(b.start);
        if (time != 0) return time;
        return a.title.compareTo(b.title);
      });
    }
    final total = days.fold<int>(0, (sum, day) => sum + byDay[day]!.length);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Text(
                  '${anchor.month}月任务',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '$total 项',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outline),
          Expanded(
            child: total == 0
                ? Center(
                    child: Text(
                      '${anchor.month}月还没有任务',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                    children: [
                      for (final day in days) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                          child: Row(
                            children: [
                              Text(
                                '${day.month}月${day.day}日 ${_weekday(day)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: day == today
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              if (day == today) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '今天',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 9,
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                '${byDay[day]!.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final entry in byDay[day]!) ...[
                          _EntryTile(
                            entry: entry,
                            onOpenEvent: (_) async {},
                            onOpenTask: onOpenTask,
                            onToggleTask: onToggleTask,
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Inline quick-add input replacing a month cell's content: Enter or leaving
/// the field commits, Escape cancels, an empty title cancels silently.
class _DayComposer extends StatefulWidget {
  const _DayComposer({
    super.key,
    required this.onCommit,
    required this.onCancel,
  });

  final Future<void> Function(String title) onCommit;
  final VoidCallback onCancel;

  @override
  State<_DayComposer> createState() => _DayComposerState();
}

class _DayComposerState extends State<_DayComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _node = FocusNode();
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_node.hasFocus) _submit(_controller.text);
  }

  void _submit(String value) {
    if (_settled) return;
    _settled = true;
    final title = value.trim();
    if (title.isEmpty) {
      widget.onCancel();
      return;
    }
    unawaited(widget.onCommit(title));
  }

  @override
  void dispose() {
    _node
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _settled = true;
          widget.onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: _controller,
        focusNode: _node,
        autofocus: true,
        maxLength: 200,
        textInputAction: TextInputAction.done,
        onSubmitted: _submit,
        style: theme.textTheme.labelMedium?.copyWith(fontSize: 11),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          filled: false,
          hintText: '新建任务',
          hintStyle: theme.textTheme.labelMedium?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 2,
          ),
        ),
      ),
    );
  }
}

class _WeekView extends StatefulWidget {
  const _WeekView({
    required this.anchor,
    required this.snapshot,
    required this.almanac,
    required this.onSelectDay,
    required this.onSelectedDate,
    required this.onOpenEvent,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final DateTime anchor;
  final CalendarSnapshot snapshot;
  final Map<String, CalendarAlmanacDay> almanac;
  final void Function(DateTime day) onSelectDay;
  final void Function(DateTime day) onSelectedDate;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;

  @override
  State<_WeekView> createState() => _WeekViewState();
}

/// Middle index of the infinite week/day pagers: page 0 of the pager is the
/// base week/day kept in the view's own state, so swiping never feeds back
/// into the geometry the parent anchor is derived from.
const int _kPagerOrigin = 100000;

class _WeekViewState extends State<_WeekView> {
  late DateTime _baseWeekStart = _sundayOf(widget.anchor);
  late final PageController _controller = PageController(
    initialPage: _kPagerOrigin,
  );
  int _page = _kPagerOrigin;

  @override
  void didUpdateWidget(_WeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Swiping reports its own week back as the anchor, so only an outside
    // change (today, month drill-in, view switch) recentres the pager.
    if (_sundayOf(widget.anchor) != _visibleWeekStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _baseWeekStart = _sundayOf(widget.anchor);
          _page = _kPagerOrigin;
        });
        _controller.jumpToPage(_kPagerOrigin);
      });
    }
  }

  DateTime get _visibleWeekStart =>
      _baseWeekStart.add(Duration(days: (_page - _kPagerOrigin) * 7));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    return PageView.builder(
      controller: _controller,
      onPageChanged: (page) {
        if (page == _page) return;
        setState(() => _page = page);
        widget.onSelectedDate(
          _baseWeekStart.add(Duration(days: (page - _kPagerOrigin) * 7)),
        );
      },
      itemBuilder: (context, page) {
        final weekStart = _baseWeekStart.add(
          Duration(days: (page - _kPagerOrigin) * 7),
        );
        final days = [
          for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i)),
        ];
        return _TimeGrid(
          days: days,
          header: _WeekHeaderRow(
            days: days,
            today: today,
            almanac: widget.almanac,
            onSelectDay: widget.onSelectDay,
          ),
          snapshot: widget.snapshot,
          selectedDay: null,
          onOpenEvent: widget.onOpenEvent,
          onOpenTask: widget.onOpenTask,
          onToggleTask: widget.onToggleTask,
        );
      },
    );
  }
}

/// Day titles drawn inside the grid sheet and inset by the time gutter, so
/// every header sits exactly above its column.
class _WeekHeaderRow extends StatelessWidget {
  const _WeekHeaderRow({
    required this.days,
    required this.today,
    required this.almanac,
    required this.onSelectDay,
    this.selectedDay,
  });

  final List<DateTime> days;
  final DateTime today;
  final Map<String, CalendarAlmanacDay> almanac;
  final void Function(DateTime day) onSelectDay;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kTimeGutterWidth, 6, 0, 0),
      child: Row(
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Container(
                decoration: i == days.length - 1
                    ? null
                    : BoxDecoration(
                        border: Border(
                          right: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                child: _DayHeaderCell(
                  day: days[i],
                  today: today,
                  selected: days[i] == selectedDay,
                  label: almanac[_dateKey(days[i])]?.label ?? '',
                  special: almanac[_dateKey(days[i])]?.special ?? false,
                  onTap: () => onSelectDay(days[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeaderCell extends StatelessWidget {
  const _DayHeaderCell({
    required this.day,
    required this.today,
    required this.selected,
    required this.label,
    required this.special,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final bool selected;
  final String label;
  final bool special;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = day == today;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(
              const ['日', '一', '二', '三', '四', '五', '六'][day.weekday % 7],
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? scheme.primary : null,
                shape: BoxShape.circle,
                border: !selected && isToday
                    ? Border.all(
                        color: scheme.primary.withValues(alpha: 0.5),
                        width: 1.2,
                      )
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: selected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: selected
                      ? scheme.onPrimary
                      : isToday
                      ? scheme.primary
                      : scheme.onSurface,
                ),
              ),
            ),
            SizedBox(
              height: 12,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 8.5,
                    height: 1,
                    fontWeight: special ? FontWeight.w600 : FontWeight.w500,
                    color: label.isEmpty
                        ? Colors.transparent
                        : special
                        ? AppColors.festivalFor(theme.brightness)
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayView extends StatefulWidget {
  const _DayView({
    required this.anchor,
    required this.snapshot,
    required this.almanac,
    required this.composingDay,
    required this.onSelectedDate,
    required this.onOpenEvent,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onCommitCompose,
    required this.onCancelCompose,
  });

  final DateTime anchor;
  final CalendarSnapshot snapshot;
  final Map<String, CalendarAlmanacDay> almanac;
  final DateTime? composingDay;
  final void Function(DateTime day) onSelectedDate;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;
  final Future<void> Function(String title) onCommitCompose;
  final VoidCallback onCancelCompose;

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  late DateTime _baseDay = _dateOnly(widget.anchor);
  late final PageController _controller = PageController(
    initialPage: _kPagerOrigin,
  );
  int _page = _kPagerOrigin;

  DateTime get _visibleDay =>
      _baseDay.add(Duration(days: _page - _kPagerOrigin));

  @override
  void didUpdateWidget(_DayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dateOnly(widget.anchor) != _visibleDay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _baseDay = _dateOnly(widget.anchor);
          _page = _kPagerOrigin;
        });
        _controller.jumpToPage(_kPagerOrigin);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = _dateOnly(DateTime.now());
    final visibleDay = _visibleDay;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (page) {
              if (page == _page) return;
              setState(() => _page = page);
              widget.onSelectedDate(
                _baseDay.add(Duration(days: page - _kPagerOrigin)),
              );
            },
            itemBuilder: (context, page) {
              final day = _baseDay.add(Duration(days: page - _kPagerOrigin));
              final weekStart = _sundayOf(day);
              final weekDays = List.generate(
                7,
                (index) => weekStart.add(Duration(days: index)),
              );
              final empty = _entriesForDay(widget.snapshot, day).isEmpty;
              return Stack(
                children: [
                  _TimeGrid(
                    days: [day],
                    header: _WeekHeaderRow(
                      days: weekDays,
                      today: today,
                      almanac: widget.almanac,
                      selectedDay: day,
                      onSelectDay: widget.onSelectedDate,
                    ),
                    snapshot: widget.snapshot,
                    selectedDay: null,
                    onOpenEvent: widget.onOpenEvent,
                    onOpenTask: widget.onOpenTask,
                    onToggleTask: widget.onToggleTask,
                  ),
                  if (empty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Text(
                              '暂无安排',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (widget.composingDay == visibleDay)
          _DayTaskComposer(
            day: visibleDay,
            onCommit: widget.onCommitCompose,
            onCancel: widget.onCancelCompose,
          ),
      ],
    );
  }
}

/// Inline quick-add for the day view; the task is written locally with an
/// all-day due date, exactly like the month view's cell composer.
class _DayTaskComposer extends StatefulWidget {
  const _DayTaskComposer({
    required this.day,
    required this.onCommit,
    required this.onCancel,
  });

  final DateTime day;
  final Future<void> Function(String title) onCommit;
  final VoidCallback onCancel;

  @override
  State<_DayTaskComposer> createState() => _DayTaskComposerState();
}

class _DayTaskComposerState extends State<_DayTaskComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _settled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    if (_settled) return;
    _settled = true;
    final title = value.trim();
    if (title.isEmpty) {
      widget.onCancel();
      return;
    }
    unawaited(widget.onCommit(title));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
        color: scheme.surfaceContainerLow,
        child: Row(
          children: [
            Icon(Icons.playlist_add_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 200,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  filled: false,
                  hintText: '在 ${widget.day.month}月${widget.day.day}日新建任务',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            IconButton(
              tooltip: '取消',
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
            IconButton.filled(
              tooltip: '添加任务',
              onPressed: () => _submit(_controller.text),
              style: IconButton.styleFrom(
                minimumSize: const Size(36, 36),
                maximumSize: const Size(36, 36),
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

/// Day view keeps the spec's empty state instead of an all-day empty grid.
const double _kHourSlotHeight = 52;
const double _kTimeGutterWidth = 44;

class _DayTimed {
  const _DayTimed(this.entry, this.startMinutes, this.endMinutes);

  final _Entry entry;
  final double startMinutes;
  final double endMinutes;
}

class _PlacedTimed {
  const _PlacedTimed(this.item, this.column, this.columns);

  final _DayTimed item;
  final int column;
  final int columns;
}

List<_PlacedTimed> _packDayTimed(List<_DayTimed> items) {
  final sorted = [...items]
    ..sort((a, b) {
      final start = a.startMinutes.compareTo(b.startMinutes);
      if (start != 0) return start;
      return b.endMinutes.compareTo(a.endMinutes);
    });
  final placed = <_PlacedTimed>[];
  var group = <_DayTimed>[];
  var groupEnd = 0.0;

  void flush() {
    if (group.isEmpty) return;
    final groupColumns = <List<_DayTimed>>[];
    final assignment = <_DayTimed, int>{};
    for (final item in group) {
      var assigned = false;
      for (var c = 0; c < groupColumns.length; c++) {
        if (item.startMinutes >= groupColumns[c].last.endMinutes) {
          groupColumns[c].add(item);
          assignment[item] = c;
          assigned = true;
          break;
        }
      }
      if (!assigned) {
        groupColumns.add([item]);
        assignment[item] = groupColumns.length - 1;
      }
    }
    for (final item in group) {
      placed.add(_PlacedTimed(item, assignment[item]!, groupColumns.length));
    }
    group = [];
    groupEnd = 0;
  }

  for (final item in sorted) {
    if (group.isNotEmpty && item.startMinutes >= groupEnd) flush();
    group.add(item);
    groupEnd = math.max(groupEnd, item.endMinutes);
  }
  flush();
  return placed;
}

({double top, double height}) _timedBlockRect(_DayTimed item) {
  final top = item.startMinutes / 60 * _kHourSlotHeight;
  final bottom = item.endMinutes / 60 * _kHourSlotHeight;
  return (top: top, height: math.max(bottom - top, _kMinTimedBlockHeight));
}

/// Shortest block the grid draws: keeps a 30-minute event readable and
/// close enough to the 48dp touch target rule for a scrollable grid.
const double _kMinTimedBlockHeight = 26;

class _TimeGrid extends StatefulWidget {
  const _TimeGrid({
    required this.days,
    required this.snapshot,
    required this.selectedDay,
    required this.onOpenEvent,
    required this.onOpenTask,
    required this.onToggleTask,
    this.header,
  });

  final List<DateTime> days;
  final CalendarSnapshot snapshot;
  final DateTime? selectedDay;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;

  /// Optional day titles drawn inside the same sheet as the grid, so the
  /// columns and their headers share one paper surface.
  final Widget? header;

  @override
  State<_TimeGrid> createState() => _TimeGridState();
}

class _TimeGridState extends State<_TimeGrid> {
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _initialScroll,
  );
  Timer? _ticker;

  /// Open on the working part of the day, or on the current time when the
  /// window contains today, the way TickTick's grid does.
  double get _initialScroll {
    final now = DateTime.now();
    final showsToday = widget.days.any(
      (day) => _dateOnly(day) == _dateOnly(now),
    );
    if (!showsToday) return 7.5 * _kHourSlotHeight;
    final minutes = now.hour * 60 + now.minute;
    return math.max(0, minutes / 60 * _kHourSlotHeight - 2 * _kHourSlotHeight);
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final today = _dateOnly(now);
    final days = widget.days;
    final allDay = [
      for (final day in days)
        _entriesForDay(
          widget.snapshot,
          day,
        ).where((entry) => entry.allDay).toList(growable: false),
    ];
    final timed = [
      for (final day in days)
        _packDayTimed(_timedEntriesForDay(widget.snapshot, day)),
    ];
    final hasToday = days.any((day) => _dateOnly(day) == today);
    final nowOffset = hasToday
        ? (now.hour * 60 + now.minute) / 60 * _kHourSlotHeight
        : -1.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          if (widget.header != null) widget.header!,
          SizedBox(
            height: 30,
            child: Row(
              children: [
                SizedBox(
                  width: _kTimeGutterWidth,
                  child: Center(
                    child: Text(
                      '全天',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < allDay.length; i++)
                  Expanded(
                    child: Container(
                      decoration: i == allDay.length - 1
                          ? null
                          : BoxDecoration(
                              border: Border(
                                right: BorderSide(color: scheme.outlineVariant),
                              ),
                            ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Row(
                          children: [
                            for (final entry in allDay[i])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: _AllDayChip(
                                  entry: entry,
                                  onOpenEvent: widget.onOpenEvent,
                                  onOpenTask: widget.onOpenTask,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: _kTimeGutterWidth),
            color: scheme.outlineVariant,
          ),
          Expanded(
            child: ListView(
              controller: _controller,
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: _kHourSlotHeight * 24,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columnWidth =
                          (constraints.maxWidth - _kTimeGutterWidth) /
                          days.length;
                      return Stack(
                        children: [
                          for (var hour = 0; hour <= 24; hour++)
                            Positioned(
                              left: _kTimeGutterWidth,
                              right: 0,
                              top: hour * _kHourSlotHeight,
                              child: Container(
                                height: 1,
                                color: scheme.outlineVariant,
                              ),
                            ),
                          // 时间刻度与日程列之间的竖线，单日视图也能看出网格边界。
                          Positioned(
                            left: _kTimeGutterWidth,
                            top: 0,
                            bottom: 0,
                            width: 1,
                            child: ColoredBox(color: scheme.outlineVariant),
                          ),
                          for (var d = 1; d < days.length; d++)
                            Positioned(
                              left: _kTimeGutterWidth + d * columnWidth,
                              top: 0,
                              bottom: 0,
                              width: 1,
                              child: ColoredBox(color: scheme.outlineVariant),
                            ),
                          for (var hour = 0; hour < 24; hour++)
                            Positioned(
                              left: 0,
                              width: _kTimeGutterWidth - 8,
                              top: hour * _kHourSlotHeight - 6,
                              child: Text(
                                hour == 0
                                    ? ''
                                    : hour.toString().padLeft(2, '0'),
                                textAlign: TextAlign.right,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10.5,
                                  height: 1,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          for (var d = 0; d < days.length; d++)
                            Positioned(
                              left: _kTimeGutterWidth + d * columnWidth,
                              width: columnWidth,
                              top: 0,
                              bottom: 0,
                              child: Stack(
                                children: [
                                  if (widget.selectedDay != null &&
                                      days[d] == widget.selectedDay)
                                    Positioned.fill(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.primary.withValues(
                                            alpha: 0.13,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  for (final placed in timed[d])
                                    () {
                                      final rect = _timedBlockRect(placed.item);
                                      final split =
                                          columnWidth / placed.columns;
                                      // A real split leaves ~17dp in a seven-day
                                      // column, so cascade instead and keep the
                                      // blocks wide enough to read.
                                      final cascade = split - 4 < 40;
                                      final step = placed.columns > 1
                                          ? math.min(
                                              0.18,
                                              0.5 / (placed.columns - 1),
                                            )
                                          : 0.0;
                                      final left = cascade
                                          ? columnWidth * step * placed.column
                                          : split * placed.column;
                                      final width = cascade
                                          ? math.max(
                                              12.0,
                                              columnWidth - left - 4,
                                            )
                                          : math.max(12.0, split - 4);
                                      return Positioned(
                                        left: left,
                                        width: width,
                                        top: rect.top,
                                        height: rect.height,
                                        child: _TimedBlock(
                                          entry: placed.item.entry,
                                          startMinutes:
                                              placed.item.startMinutes,
                                          endMinutes: placed.item.endMinutes,
                                          width: width,
                                          onOpenEvent: widget.onOpenEvent,
                                          onOpenTask: widget.onOpenTask,
                                          onToggleTask: widget.onToggleTask,
                                        ),
                                      );
                                    }(),
                                ],
                              ),
                            ),
                          if (nowOffset >= 0)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: nowOffset,
                              child: const _NowIndicator(),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<_DayTimed> _timedEntriesForDay(CalendarSnapshot snapshot, DateTime day) {
  final dayStart = _dateOnly(day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final items = <_DayTimed>[];
  for (final entry in _entriesForDay(snapshot, dayStart)) {
    if (entry.allDay) continue;
    final event = entry.event;
    final task = entry.task;
    final rawStart = event?.start.toLocal() ?? task!.when!.toLocal();
    final rawEnd = event != null
        ? event.end.toLocal()
        : (task!.due != null && task.due!.toLocal().isAfter(rawStart)
              ? task.due!.toLocal()
              : rawStart.add(const Duration(hours: 1)));
    final start = rawStart.isBefore(dayStart) ? dayStart : rawStart;
    final end = rawEnd.isAfter(dayEnd) ? dayEnd : rawEnd;
    double offset(DateTime moment) => math.min(
      1440.0,
      math.max(0.0, moment.difference(dayStart).inMinutes.toDouble()),
    );
    var startMinutes = offset(start);
    var endMinutes = offset(end);
    if (endMinutes <= startMinutes) {
      endMinutes = math.min(1440.0, startMinutes + 30);
    }
    items.add(_DayTimed(entry, startMinutes, endMinutes));
  }
  return items;
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({
    required this.entry,
    required this.onOpenEvent,
    required this.onOpenTask,
  });

  final _Entry entry;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = entry.task;
    final event = entry.event;
    final tint = Color.alphaBlend(
      entry.color.withValues(alpha: 0.28),
      scheme.surface,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: tint,
        borderRadius: BorderRadius.circular(7),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => task != null ? onOpenTask(task) : onOpenEvent(event!),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.completed)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  )
                else
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: entry.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10.5,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimedBlock extends StatelessWidget {
  const _TimedBlock({
    required this.entry,
    required this.startMinutes,
    required this.endMinutes,
    required this.width,
    required this.onOpenEvent,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final _Entry entry;
  final double startMinutes;
  final double endMinutes;
  final double width;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = entry.task;
    final event = entry.event;
    final blockHeight = math.max(
      (endMinutes - startMinutes) / 60 * _kHourSlotHeight,
      _kMinTimedBlockHeight,
    );
    final compact = blockHeight < 46;
    // Week columns are ~48dp wide: drop the colour dot there and let the tint
    // alone carry the calendar.
    final slim = width < 62;
    final tint = Color.alphaBlend(
      entry.color.withValues(alpha: 0.22),
      scheme.surface,
    );
    if (width < 30) {
      // Too narrow for any glyph: a deeper bar still reads as "this slot is
      // taken" and stays tappable.
      return Material(
        color: Color.alphaBlend(
          (entry.completed ? scheme.onSurfaceVariant : entry.color).withValues(
            alpha: 0.55,
          ),
          scheme.surface,
        ),
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => task != null ? onOpenTask(task) : onOpenEvent(event!),
        ),
      );
    }
    final verticalPad = compact ? math.max(1.0, (blockHeight - 13) / 2) : 6.0;
    final timeText =
        '${(startMinutes ~/ 60).toString().padLeft(2, '0')}:${(startMinutes % 60).round().toString().padLeft(2, '0')}'
        ' - '
        '${(endMinutes ~/ 60).toString().padLeft(2, '0')}:${(endMinutes % 60).round().toString().padLeft(2, '0')}';
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => task != null ? onOpenTask(task) : onOpenEvent(event!),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            slim ? 4 : (compact ? 5 : 8),
            verticalPad,
            slim ? 4 : (compact ? 5 : 8),
            verticalPad,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!slim) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: entry.completed
                            ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                            : entry.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: compact ? 11 : 12,
                        height: 1.2,
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        decoration: entry.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: EdgeInsets.only(left: slim ? 0 : 13),
                  child: Text(
                    timeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10.5,
                      height: 1.2,
                      color: scheme.onSurfaceVariant,
                    ),
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

class _NowIndicator extends StatelessWidget {
  const _NowIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: _kTimeGutterWidth - 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.circle, size: 7, color: AppColors.red),
        ),
        Expanded(
          child: SizedBox(height: 1.4, child: ColoredBox(color: AppColors.red)),
        ),
      ],
    );
  }
}

class _ScheduleView extends StatelessWidget {
  const _ScheduleView({
    required this.anchor,
    required this.snapshot,
    required this.onSelectDay,
    required this.onOpenEvent,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final DateTime anchor;
  final CalendarSnapshot snapshot;
  final void Function(DateTime day) onSelectDay;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = _dateOnly(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 100),
      children: [
        for (var offset = 0; offset < 3; offset++) ...[
          _ScheduleHeader(
            day: anchor.add(Duration(days: offset)),
            count: _entriesForDay(
              snapshot,
              anchor.add(Duration(days: offset)),
            ).length,
            today: today,
            onTap: () => onSelectDay(anchor.add(Duration(days: offset))),
          ),
          const SizedBox(height: 10),
          if (_entriesForDay(
            snapshot,
            anchor.add(Duration(days: offset)),
          ).isEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '暂无安排',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final entry in _entriesForDay(
              snapshot,
              anchor.add(Duration(days: offset)),
            )) ...[
              _EntryTile(
                entry: entry,
                onOpenEvent: onOpenEvent,
                onOpenTask: onOpenTask,
                onToggleTask: onToggleTask,
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({
    required this.day,
    required this.count,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final int count;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = day == today;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              '${day.month}月${day.day}日',
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              _weekday(day),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '今天',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              '$count 项',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearView extends StatelessWidget {
  const _YearView({
    required this.anchor,
    required this.snapshot,
    required this.onSelectDay,
    required this.bottomInset,
  });

  final DateTime anchor;
  final CalendarSnapshot snapshot;
  final void Function(DateTime day) onSelectDay;

  /// Height the floating action button claims in the bottom-right corner.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    // One screen, no scrolling: the four rows split the available height and
    // each mini month squeezes its week rows into whatever is left.
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 2, 12, bottomInset),
      child: Column(
        children: [
          for (var row = 0; row < 4; row++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: row == 3 ? 0 : 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < 3; column++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: column == 0 ? 0 : 8),
                          // PC frames each month with the canvas showing
                          // through and a hairline border, not a filled card.
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: scheme.outline),
                            ),
                            child: _MiniMonth(
                              year: anchor.year,
                              month: row * 3 + column + 1,
                              snapshot: snapshot,
                              today: today,
                              onSelectDay: onSelectDay,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.year,
    required this.month,
    required this.snapshot,
    required this.today,
    required this.onSelectDay,
  });

  final int year;
  final int month;
  final CalendarSnapshot snapshot;
  final DateTime today;
  final void Function(DateTime day) onSelectDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = DateTime(year, month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final cells = <({DateTime day, List<_Entry> entries})>[];
    for (var index = 0; index < 42; index++) {
      final day = start.add(Duration(days: index));
      cells.add((day: day, entries: _entriesForDay(snapshot, day)));
    }
    final total = cells
        .where((cell) => cell.day.month == month)
        .fold<int>(0, (sum, cell) => sum + cell.entries.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$month月',
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            // Three narrow cards per row plus accessibility text scaling can
            // outgrow the header; the count gives way, never the month name.
            Flexible(
              child: Text(
                '$total 项',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 7.5,
                      height: 1,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Six week rows share whatever height the card has left; the
              // day marker follows the row so nothing ever gets clipped.
              final rowExtent = constraints.maxHeight / 6;
              final marker = (rowExtent * 0.94).clamp(0.0, 18.0);
              return Column(
                children: [
                  for (var week = 0; week < 6; week++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var weekday = 0; weekday < 7; weekday++)
                            Expanded(
                              child: _dayCell(
                                context: context,
                                cell: cells[week * 7 + weekday],
                                marker: marker,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _dayCell({
    required BuildContext context,
    required ({DateTime day, List<_Entry> entries}) cell,
    required double marker,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = cell.day;
    final inMonth = day.month == month;
    final isToday = day == today;
    final hasEntries = cell.entries.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onSelectDay(day),
      child: Center(
        child: Container(
          width: marker,
          height: marker,
          alignment: Alignment.center,
          decoration: isToday
              ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle)
              : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${day.day}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                height: 1,
                fontWeight: hasEntries || isToday
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isToday
                    ? scheme.onPrimary
                    : inMonth
                    ? (hasEntries ? scheme.primary : scheme.onSurface)
                    : scheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onOpenEvent,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final _Entry entry;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = entry.task;
    final event = entry.event;
    final time = entry.allDay
        ? '全天'
        : '${entry.start.hour.toString().padLeft(2, '0')}:${entry.start.minute.toString().padLeft(2, '0')}';
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => task != null ? onOpenTask(task) : onOpenEvent(event!),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: entry.completed
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                      : entry.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (task != null)
                          GestureDetector(
                            onTap: task.virtual
                                ? null
                                : () => onToggleTask(task),
                            child: Icon(
                              task.completed
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: task.completed
                                  ? scheme.primary
                                  : scheme.outline,
                            ),
                          ),
                        if (task != null) const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: task?.completed == true
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (task?.recurring == true)
                          Icon(
                            Icons.repeat_rounded,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        time,
                        if (task != null && task.listName.isNotEmpty)
                          task.listName,
                        if (event != null && event.calendarName.isNotEmpty)
                          event.calendarName,
                        if (event != null && event.location.isNotEmpty)
                          event.location,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
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

class _SubscriptionSheet extends StatefulWidget {
  const _SubscriptionSheet({required this.api});

  final CalendarApi api;

  @override
  State<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<_SubscriptionSheet> {
  List<CalendarSubscription> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.subscriptions();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final url = TextEditingController();
    final value = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加 iCal 订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '订阅地址',
                hintText: 'https://example.com/calendar.ics',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, (name.text.trim(), url.text.trim())),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    disposeControllerSoon(name);
    disposeControllerSoon(url);
    if (value == null || !mounted) return;
    if (value.$1.isEmpty || value.$2.isEmpty) return;
    try {
      await widget.api.createSubscription(name: value.$1, url: value.$2);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('添加失败：$error')));
    }
  }

  Future<void> _delete(CalendarSubscription subscription) async {
    try {
      await widget.api.deleteSubscription(subscription.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'iCal 订阅',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                  TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      '还没有订阅。添加 http/https ICS 地址后，事件会出现在日历中。',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final subscription = _items[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: scheme.surfaceContainerLow,
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colorFromHex(subscription.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(subscription.name),
                        subtitle: Text(
                          subscription.lastError.isEmpty
                              ? subscription.url
                              : '同步失败：${subscription.lastError}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: '删除订阅',
                          onPressed: () => _delete(subscription),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: scheme.error,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventDraft {
  const _EventDraft({
    required this.calendarId,
    required this.summary,
    required this.start,
    required this.end,
    required this.allDay,
    required this.location,
    required this.description,
    required this.reminders,
  });

  final int calendarId;
  final String summary;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String location;
  final String description;
  final List<int> reminders;
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({
    required this.calendars,
    required this.initialCalendarId,
    required this.initialStart,
    required this.initialEnd,
    this.initialSummary = '',
    this.initialLocation = '',
    this.initialDescription = '',
    this.initialAllDay = false,
    this.initialReminders = const [],
    this.lockCalendar = false,
    this.onDelete,
  });

  final List<CalendarSource> calendars;
  final int initialCalendarId;
  final DateTime initialStart;
  final DateTime initialEnd;
  final String initialSummary;
  final String initialLocation;
  final String initialDescription;
  final bool initialAllDay;
  final List<int> initialReminders;
  final bool lockCalendar;
  final VoidCallback? onDelete;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  late final TextEditingController _summary;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late int _calendarId;
  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  late List<int> _reminders;

  @override
  void initState() {
    super.initState();
    _summary = TextEditingController(text: widget.initialSummary);
    _location = TextEditingController(text: widget.initialLocation);
    _description = TextEditingController(text: widget.initialDescription);
    _calendarId = widget.initialCalendarId;
    _allDay = widget.initialAllDay;
    _start = _allDay
        ? _dateOnly(widget.initialStart.toLocal())
        : widget.initialStart.toLocal();
    final rawEnd = widget.initialEnd.toLocal();
    _end = _allDay
        ? _dateOnly(rawEnd.subtract(const Duration(days: 1)))
        : rawEnd;
    if (_end.isBefore(_start)) _end = _start;
    _reminders = List<int>.of(widget.initialReminders);
  }

  @override
  void dispose() {
    _summary.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    if (_allDay) {
      setState(() {
        final value = _dateOnly(date);
        if (start) {
          _start = value;
          if (_end.isBefore(_start)) _end = _start;
        } else {
          _end = value.isBefore(_start) ? _start : value;
        }
      });
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _start = value;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = value.isAfter(_start)
            ? value
            : _start.add(const Duration(hours: 1));
      }
    });
  }

  void _toggleAllDay(bool value) {
    setState(() {
      _allDay = value;
      final startLocal = _start.toLocal();
      final endLocal = _end.toLocal();
      if (value) {
        _start = _dateOnly(startLocal);
        _end = _dateOnly(endLocal);
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _start = DateTime(startLocal.year, startLocal.month, startLocal.day, 9);
        _end = DateTime(endLocal.year, endLocal.month, endLocal.day, 10);
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      }
    });
  }

  void _save() {
    final summary = _summary.text.trim();
    if (summary.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写事件标题')));
      return;
    }
    final end = _allDay ? _end.add(const Duration(days: 1)) : _end;
    if (!end.isAfter(_start)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('结束时间需要晚于开始时间')));
      return;
    }
    Navigator.pop(
      context,
      _EventDraft(
        calendarId: _calendarId,
        summary: summary,
        start: _start,
        end: end,
        allDay: _allDay,
        location: _location.text.trim(),
        description: _description.text.trim(),
        reminders: _reminders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initialSummary.isEmpty ? '新建日程' : '编辑日程',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _summary,
              autofocus: widget.initialSummary.isEmpty,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            const SizedBox(height: 10),
            if (!widget.lockCalendar)
              DropdownButtonFormField<int>(
                initialValue: _calendarId,
                decoration: const InputDecoration(labelText: '日历'),
                items: [
                  for (final calendar in widget.calendars)
                    DropdownMenuItem(
                      value: calendar.id,
                      child: Text(calendar.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _calendarId = value);
                },
              )
            else
              _DetailRow(
                icon: Icons.calendar_month_outlined,
                text: widget.calendars
                    .firstWhere(
                      (calendar) => calendar.id == _calendarId,
                      orElse: () => widget.calendars.first,
                    )
                    .name,
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('全天', style: theme.textTheme.bodyMedium),
                const SizedBox(width: 8),
                Switch(value: _allDay, onChanged: _toggleAllDay),
              ],
            ),
            _DateRow(
              label: '开始',
              value: formatDue(_start, allDay: _allDay),
              onTap: () => _pickDate(start: true),
            ),
            _DateRow(
              label: _allDay ? '结束（含）' : '结束',
              value: formatDue(_end, allDay: _allDay),
              onTap: () => _pickDate(start: false),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int?>(
              initialValue: _reminders.isEmpty ? null : _reminders.first,
              decoration: const InputDecoration(labelText: '提醒'),
              items: const [
                DropdownMenuItem<int?>(value: null, child: Text('不提醒')),
                DropdownMenuItem<int?>(value: 0, child: Text('准时')),
                DropdownMenuItem<int?>(value: 10, child: Text('提前 10 分钟')),
                DropdownMenuItem<int?>(value: 30, child: Text('提前 30 分钟')),
                DropdownMenuItem<int?>(value: 60, child: Text('提前 1 小时')),
                DropdownMenuItem<int?>(value: 1440, child: Text('提前 1 天')),
              ],
              onChanged: (value) => setState(
                () => _reminders = value == null ? const [] : [value],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: '地点'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '描述'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                if (widget.onDelete != null)
                  TextButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('删除'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Spacer(),
                FilledButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
              child: Text(value),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSheet extends StatelessWidget {
  const _EventSheet({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colorFromHex(event.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.calendarName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (event.recurring)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: const Text('重复'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.summary,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _DetailRow(icon: Icons.schedule_rounded, text: _eventTime(event)),
            if (event.location.isNotEmpty)
              _DetailRow(icon: Icons.place_outlined, text: event.location),
            if (event.reminders.isNotEmpty)
              _DetailRow(
                icon: Icons.notifications_active_outlined,
                text: event.reminders
                    .map((minutes) => minutes == 0 ? '准时' : '提前 $minutes 分钟')
                    .join('、'),
              ),
            if (event.description.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                event.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              event.readOnly ? '只读日历' : '来自 CalDAV 日历',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _eventTime(CalendarEvent event) {
    final start = event.start.toLocal();
    final end = event.end.toLocal();
    if (event.allDay) {
      final last = end.subtract(const Duration(days: 1));
      if (_dateOnly(start) == _dateOnly(last)) {
        return '${start.year}年${start.month}月${start.day}日 · 全天';
      }
      return '${start.month}月${start.day}日 - ${last.month}月${last.day}日 · 全天';
    }
    final date = '${start.year}年${start.month}月${start.day}日';
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
        ' - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _CalendarTaskSheet extends StatelessWidget {
  const _CalendarTaskSheet({required this.task});

  final CalendarTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            task.listName,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            task.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              decoration: task.completed ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 10),
          if (task.when != null)
            _DetailRow(
              icon: Icons.schedule_rounded,
              text: formatDue(task.when, allDay: task.allDay),
            ),
          if (task.virtual)
            const _DetailRow(icon: Icons.repeat_rounded, text: '重复任务实例'),
          if (task.postponed)
            const _DetailRow(icon: Icons.update_rounded, text: '已顺延'),
          const SizedBox(height: 8),
          Text(
            '在任务列表中编辑此任务',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

enum _EventScope { single, all }
