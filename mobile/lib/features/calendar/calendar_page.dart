import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/ui_utils.dart';
import '../../data/calendar/calendar_api.dart';
import '../../design/components.dart';
import '../../design/format.dart';

enum CalendarView { month, week, threeDay, day, agenda, year }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final CalendarApi _api;
  CalendarView _view = CalendarView.month;
  DateTime _anchor = _dateOnly(DateTime.now());
  CalendarSnapshot? _snapshot;
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    final session = context.read<AppState>().session!;
    _api = CalendarApi(
      baseUrl: session.baseUrl,
      username: session.username,
      password: session.password,
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    final request = ++_request;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final (from, to) = _rangeFor(_view, _anchor);
    try {
      final snapshot = await _fetchSnapshot(from, to);
      if (!mounted || request != _request) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<CalendarSnapshot> _fetchSnapshot(DateTime from, DateTime to) async {
    if (_view != CalendarView.year) {
      return _api.fetch(from: from, to: to);
    }
    final year = from.year;
    final ranges = [
      (DateTime(year, 1, 1), DateTime(year, 4, 1)),
      (DateTime(year, 4, 1), DateTime(year, 7, 1)),
      (DateTime(year, 7, 1), DateTime(year, 10, 1)),
      (DateTime(year, 10, 1), DateTime(year + 1, 1, 1)),
    ];
    final snapshots = await Future.wait(
      ranges.map((range) => _api.fetch(from: range.$1, to: range.$2)),
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
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        return (monday, monday.add(const Duration(days: 7)));
      case CalendarView.threeDay:
        return (anchor, anchor.add(const Duration(days: 3)));
      case CalendarView.day:
        return (anchor, anchor.add(const Duration(days: 1)));
      case CalendarView.agenda:
        return (anchor, anchor.add(const Duration(days: 30)));
      case CalendarView.year:
        return (DateTime(anchor.year, 1, 1), DateTime(anchor.year + 1, 1, 1));
    }
  }

  void _setView(CalendarView view) {
    setState(() => _view = view);
    unawaited(_load());
  }

  void _move(int delta) {
    setState(() {
      _anchor = switch (_view) {
        CalendarView.month => DateTime(_anchor.year, _anchor.month + delta, 1),
        CalendarView.week => _anchor.add(Duration(days: 7 * delta)),
        CalendarView.threeDay => _anchor.add(Duration(days: 3 * delta)),
        CalendarView.day => _anchor.add(Duration(days: delta)),
        CalendarView.agenda => _anchor.add(Duration(days: 30 * delta)),
        CalendarView.year => DateTime(_anchor.year + delta, 1, 1),
      };
    });
    unawaited(_load());
  }

  void _today() {
    setState(() => _anchor = _dateOnly(DateTime.now()));
    unawaited(_load());
  }

  void _selectDay(DateTime day) {
    setState(() {
      _anchor = day;
      _view = CalendarView.day;
    });
    unawaited(_load());
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
                CalendarView.agenda,
                CalendarView.year,
                CalendarView.month,
                CalendarView.week,
                CalendarView.threeDay,
                CalendarView.day,
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
      floatingActionButton: _writableSources.isEmpty
          ? null
          : Tooltip(
              message: '新建日程',
              child: FloatingActionButton(
                onPressed: _createEvent,
                child: const Icon(Icons.add_rounded),
              ),
            ),
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
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else if (_error != null)
            Material(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _load(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          if (snapshot != null && snapshot.sources.isNotEmpty)
            _SourceLegend(sources: snapshot.sources),
          Expanded(
            child: snapshot == null
                ? const Center(child: CircularProgressIndicator())
                : switch (_view) {
                    CalendarView.month => _MonthView(
                      anchor: _anchor,
                      snapshot: snapshot,
                      onSelectDay: _selectDay,
                      onOpenEvent: _openEvent,
                      onOpenTask: _openTask,
                      onToggleTask: _toggleTask,
                    ),
                    CalendarView.week => _WeekView(
                      anchor: _anchor,
                      snapshot: snapshot,
                      onSelectDay: _selectDay,
                      onOpenEvent: _openEvent,
                      onOpenTask: _openTask,
                      onToggleTask: _toggleTask,
                    ),
                    CalendarView.threeDay => _ThreeDayView(
                      anchor: _anchor,
                      snapshot: snapshot,
                      onSelectDay: _selectDay,
                      onOpenEvent: _openEvent,
                      onOpenTask: _openTask,
                      onToggleTask: _toggleTask,
                    ),
                    CalendarView.day => _DayView(
                      anchor: _anchor,
                      snapshot: snapshot,
                      onOpenEvent: _openEvent,
                      onOpenTask: _openTask,
                      onToggleTask: _toggleTask,
                    ),
                    CalendarView.agenda => _AgendaView(
                      anchor: _anchor,
                      snapshot: snapshot,
                      onSelectDay: _selectDay,
                      onOpenEvent: _openEvent,
                      onOpenTask: _openTask,
                      onToggleTask: _toggleTask,
                    ),
                    CalendarView.year => _YearView(
                      anchor: _anchor,
                      snapshot: snapshot,
                      onSelectDay: _selectDay,
                    ),
                  },
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
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return '${monday.month}月${monday.day}日 - ${sunday.month}月${sunday.day}日';
      case CalendarView.threeDay:
        final end = anchor.add(const Duration(days: 2));
        return '${anchor.month}月${anchor.day}日 - ${end.month}月${end.day}日';
      case CalendarView.day:
        return '${anchor.month}月${anchor.day}日 ${_weekday(anchor)}';
      case CalendarView.agenda:
        return '${anchor.month}月${anchor.day}日起 30 天';
      case CalendarView.year:
        return '${anchor.year}年';
    }
  }

  String _viewLabel(CalendarView view) => switch (view) {
    CalendarView.month => '月视图',
    CalendarView.week => '周视图',
    CalendarView.threeDay => '3 日视图',
    CalendarView.day => '日视图',
    CalendarView.agenda => '议程',
    CalendarView.year => '年视图',
  };

  IconData _viewIcon(CalendarView view) => switch (view) {
    CalendarView.month => Icons.calendar_view_month_rounded,
    CalendarView.week => Icons.view_week_outlined,
    CalendarView.threeDay => Icons.view_column_outlined,
    CalendarView.day => Icons.calendar_view_day_rounded,
    CalendarView.agenda => Icons.view_agenda_outlined,
    CalendarView.year => Icons.grid_view_rounded,
  };

  Future<void> _openEvent(CalendarEvent event) async {
    final canEdit =
        event.calendarId > 0 &&
        !event.readOnly &&
        _writableSources.any((source) => source.id == event.calendarId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EventSheet(
        event: event,
        onEdit: canEdit ? () => _editEvent(event) : null,
        onDelete: canEdit ? () => _deleteEvent(event) : null,
      ),
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
      await _api.createEvent(
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
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await _api.updateEvent(
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
      await _api.deleteEvent(
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: _SubscriptionSheet(api: _api),
      ),
    );
    if (mounted) await _load(showLoading: false);
  }

  Future<void> _openTask(CalendarTask task) async {
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

class _MonthView extends StatelessWidget {
  const _MonthView({
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
    final first = DateTime(anchor.year, anchor.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
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
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.72,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final day = gridStart.add(Duration(days: index));
              final entries = _entriesForDay(snapshot, day);
              final inMonth = day.month == anchor.month;
              final isToday = day == today;
              final holiday = _holidayLabel(snapshot, day);
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelectDay(day),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? scheme.primary : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isToday
                              ? scheme.onPrimary
                              : inMonth
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 10,
                      child: Center(
                        child: Text(
                          holiday ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 7.5,
                                height: 1,
                                color: const Color(0xFFE08A2E),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final entry in entries.take(3))
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: entry.completed
                                    ? scheme.onSurfaceVariant.withValues(
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
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
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final day = monday.add(Duration(days: index));
        final entries = _entriesForDay(snapshot, day);
        return _WeekDayColumn(
          day: day,
          entries: entries,
          onSelectDay: onSelectDay,
          onOpenEvent: onOpenEvent,
          onOpenTask: onOpenTask,
          onToggleTask: onToggleTask,
        );
      },
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({
    required this.day,
    required this.entries,
    required this.onSelectDay,
    required this.onOpenEvent,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final DateTime day;
  final List<_Entry> entries;
  final void Function(DateTime day) onSelectDay;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = _dateOnly(DateTime.now()) == day;
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelectDay(day),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Text(
                    '${day.month}/${day.day}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: today ? scheme.primary : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _weekday(day),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    '${entries.length}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        '暂无安排',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) => _EntryTile(
                        entry: entries[index],
                        compact: true,
                        onOpenEvent: onOpenEvent,
                        onOpenTask: onOpenTask,
                        onToggleTask: onToggleTask,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.anchor,
    required this.snapshot,
    required this.onOpenEvent,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final DateTime anchor;
  final CalendarSnapshot snapshot;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final entries = _entriesForDay(snapshot, anchor);
    if (entries.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.event_available_rounded,
          title: '今天没有安排',
          message: '留一点空白，也是一种安排。',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _EntryTile(
        entry: entries[index],
        onOpenEvent: onOpenEvent,
        onOpenTask: onOpenTask,
        onToggleTask: onToggleTask,
      ),
    );
  }
}

class _ThreeDayView extends StatelessWidget {
  const _ThreeDayView({
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
          _ThreeDayHeader(
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

class _ThreeDayHeader extends StatelessWidget {
  const _ThreeDayHeader({
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
  });

  final DateTime anchor;
  final CalendarSnapshot snapshot;
  final void Function(DateTime day) onSelectDay;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.82,
        mainAxisSpacing: 18,
        crossAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        return _MiniMonth(
          year: anchor.year,
          month: month,
          snapshot: snapshot,
          today: today,
          onSelectDay: onSelectDay,
        );
      },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$month月',
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 8.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final day = start.add(Duration(days: index));
            final inMonth = day.month == month;
            final isToday = day == today;
            final hasEntries = _entriesForDay(snapshot, day).isNotEmpty;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelectDay(day),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? scheme.primary : null,
                    shape: BoxShape.circle,
                  ),
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
            );
          },
        ),
      ],
    );
  }
}

class _AgendaView extends StatelessWidget {
  const _AgendaView({
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
    final groups = <DateTime, List<_Entry>>{};
    for (var offset = 0; offset < 30; offset++) {
      final day = anchor.add(Duration(days: offset));
      final entries = _entriesForDay(snapshot, day);
      if (entries.isNotEmpty) groups[day] = entries;
    }
    if (groups.isEmpty) {
      return Center(
        child: Text(
          '未来 30 天没有安排',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        for (final group in groups.entries) ...[
          InkWell(
            onTap: () => onSelectDay(group.key),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
              child: Row(
                children: [
                  Text(
                    '${group.key.month}月${group.key.day}日',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _weekday(group.key),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${group.value.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final entry in group.value) ...[
            _EntryTile(
              entry: entry,
              onOpenEvent: onOpenEvent,
              onOpenTask: onOpenTask,
              onToggleTask: onToggleTask,
            ),
            const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onOpenEvent,
    required this.onOpenTask,
    required this.onToggleTask,
    this.compact = false,
  });

  final _Entry entry;
  final Future<void> Function(CalendarEvent event) onOpenEvent;
  final Future<void> Function(CalendarTask task) onOpenTask;
  final Future<void> Function(CalendarTask task) onToggleTask;
  final bool compact;

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
          padding: EdgeInsets.fromLTRB(
            14,
            compact ? 10 : 13,
            14,
            compact ? 10 : 13,
          ),
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
                            maxLines: compact ? 2 : 3,
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
  const _EventSheet({required this.event, this.onEdit, this.onDelete});

  final CalendarEvent event;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onDelete;

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
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onEdit!();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('编辑'),
                    ),
                  if (onDelete != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete!();
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('删除'),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                    ),
                ],
              ),
            ],
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
