import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/calendar/calendar_api.dart';
import '../../design/format.dart';

enum CalendarView { month, week, day, agenda }

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
      final snapshot = await _api.fetch(from: from, to: to);
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
      case CalendarView.day:
        return (anchor, anchor.add(const Duration(days: 1)));
      case CalendarView.agenda:
        return (anchor, anchor.add(const Duration(days: 30)));
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
        CalendarView.day => _anchor.add(Duration(days: delta)),
        CalendarView.agenda => _anchor.add(Duration(days: 30 * delta)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
        actions: [
          IconButton(
            tooltip: '刷新日历',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<CalendarView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: CalendarView.month, label: Text('月')),
                  ButtonSegment(value: CalendarView.week, label: Text('周')),
                  ButtonSegment(value: CalendarView.day, label: Text('日')),
                  ButtonSegment(value: CalendarView.agenda, label: Text('议程')),
                ],
                selected: {_view},
                onSelectionChanged: (values) => _setView(values.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 12, 6),
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
      case CalendarView.day:
        return '${anchor.month}月${anchor.day}日 ${_weekday(anchor)}';
      case CalendarView.agenda:
        return '${anchor.month}月${anchor.day}日起 30 天';
    }
  }

  Future<void> _openEvent(CalendarEvent event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EventSheet(event: event),
    );
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
              return Padding(
                padding: const EdgeInsets.all(1),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelectDay(day),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
                    decoration: BoxDecoration(
                      color: isToday
                          ? scheme.primary.withValues(alpha: 0.08)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday
                            ? scheme.primary.withValues(alpha: 0.4)
                            : scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: inMonth
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                        ),
                        const SizedBox(height: 1),
                        for (final entry in entries.take(2))
                          GestureDetector(
                            onTap: () => entry.isTask
                                ? onOpenTask(entry.task!)
                                : onOpenEvent(entry.event!),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 1),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: entry.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      entry.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontSize: 8,
                                            height: 1.15,
                                            decoration: entry.completed
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color: inMonth
                                                ? scheme.onSurface
                                                : scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (entries.length > 2)
                          Text(
                            '+${entries.length - 2}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 8,
                                  color: scheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(
          '${anchor.month}月${anchor.day}日 ${_weekday(anchor)}',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 40,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '今天没有安排',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          for (final entry in entries) ...[
            _EntryTile(
              entry: entry,
              onOpenEvent: onOpenEvent,
              onOpenTask: onOpenTask,
              onToggleTask: onToggleTask,
            ),
            const SizedBox(height: 8),
          ],
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => task != null ? onOpenTask(task) : onOpenEvent(event!),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            10,
            compact ? 8 : 10,
            10,
            compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: compact ? 30 : 38,
                decoration: BoxDecoration(
                  color: entry.color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
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
