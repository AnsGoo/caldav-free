import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/habits/habit_api.dart';
import '../../data/habits/habit_store.dart';
import '../../design/components.dart';
import '../../design/format.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  HabitStore? _store;
  HabitSnapshot _snapshot = const HabitSnapshot(
    habits: [],
    checkins: [],
    sections: [],
    preferences: {},
  );
  int _selectedStamp = _stampFor(DateTime.now());

  @override
  void initState() {
    super.initState();
    _attach(context.read<AppState>().habits);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach(context.read<AppState>().habits);
  }

  /// The page renders the local mirror only. The sync thread pushes queued
  /// edits and refreshes the mirror in the background; this listener is how
  /// those silent updates reach the screen.
  void _attach(HabitStore store) {
    if (identical(_store, store)) return;
    _store?.removeListener(_onStoreChanged);
    _store = store..addListener(_onStoreChanged);
    _snapshot = store.snapshot;
  }

  void _onStoreChanged() {
    final store = _store;
    if (store == null || !mounted) return;
    setState(() => _snapshot = store.snapshot);
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    _store = null;
    super.dispose();
  }

  int get _todayStamp => _stampFor(DateTime.now());

  DateTime get _selectedDate => _dateForStamp(_selectedStamp);

  bool get _selectedIsToday => _selectedStamp == _todayStamp;

  HabitCheckinItem? _checkinFor(HabitItem habit, int stamp) {
    for (final checkin in _snapshot.checkins) {
      if (checkin.habitId == habit.id && checkin.stamp == stamp) {
        return checkin;
      }
    }
    return null;
  }

  Future<void> _checkin(HabitItem habit) async {
    if (_selectedIsFuture || _selectedIsPast) return;
    try {
      await _store?.checkin(habit.id, _selectedStamp);
    } catch (error, stack) {
      debugPrint('习惯打卡本地处理失败: $error\n$stack');
    }
  }

  bool get _selectedIsFuture =>
      _selectedDate.isAfter(DateTime.now().subtract(const Duration(days: 0))) &&
      _selectedStamp != _todayStamp;

  /// 过去的日期只用于查看历史，不允许补卡。
  bool get _selectedIsPast => _selectedStamp < _todayStamp;

  Future<void> _create() async {
    final draft = await showModalBottomSheet<HabitDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => _HabitEditorSheet(sections: _snapshot.sections),
    );
    if (draft == null || !mounted) return;
    try {
      await _store?.create(draft);
    } catch (error, stack) {
      debugPrint('习惯创建本地处理失败: $error\n$stack');
    }
  }

  Future<void> _edit(HabitItem habit) async {
    final draft = await showModalBottomSheet<HabitDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) =>
          _HabitEditorSheet(sections: _snapshot.sections, initial: habit),
    );
    if (draft == null || !mounted) return;
    try {
      await _store?.update(habit.id, draft);
    } catch (error, stack) {
      debugPrint('习惯保存本地处理失败: $error\n$stack');
    }
  }

  Future<void> _delete(HabitItem habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除习惯？'),
        content: Text('“${habit.name}”及其打卡记录将被删除。'),
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
      await _store?.delete(habit.id);
    } catch (error, stack) {
      debugPrint('习惯删除本地处理失败: $error\n$stack');
    }
  }

  void _openDetail(HabitItem habit) {
    final snapshot = _snapshot;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _HabitDetailSheet(
        habit: habit,
        checkins: snapshot.checkins
            .where((checkin) => checkin.habitId == habit.id)
            .toList(growable: false),
        stamp: _selectedStamp,
        onCheckin: (_selectedIsFuture || _selectedIsPast)
            ? null
            : () {
                Navigator.pop(context);
                _checkin(habit);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = _snapshot;
    final active = snapshot.habits
        .where((habit) => !habit.archived)
        .toList(growable: false);
    final due = active.where((habit) => habit.dueToday).toList();
    final done = due.where((habit) => habit.doneToday).length;
    final selectedDone = active
        .where((habit) => _checkinFor(habit, _selectedStamp)?.done == true)
        .length;
    final subtitle = active.isEmpty
        ? '用微小的重复，换取长期的变化'
        : _selectedIsToday
        ? (due.isEmpty ? '今天没有安排' : '今天完成 $done / ${due.length}')
        : '${_selectedDate.month}月${_selectedDate.day}日 · '
              '完成 $selectedDone / ${active.length}';
    final sections = <int, String>{};
    for (final section in snapshot.sections) {
      final id = section['id'];
      final name = (section['name'] ?? '').toString().trim();
      if (id is num && name.isNotEmpty) sections[id.toInt()] = name;
    }
    final groups = <_HabitGroup>[];
    for (final entry in sections.entries) {
      final items = active
          .where((habit) => habit.sectionId == entry.key)
          .toList(growable: false);
      if (items.isNotEmpty) {
        groups.add(_HabitGroup(entry.value, items));
      }
    }
    final known = sections.keys.toSet();
    final other = active
        .where((habit) => !known.contains(habit.sectionId))
        .toList(growable: false);
    if (other.isNotEmpty) {
      groups.add(_HabitGroup(sections.isEmpty ? '我的习惯' : '其他', other));
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('习惯'),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (!_selectedIsToday)
            IconButton(
              tooltip: '回到今天',
              onPressed: () => setState(() => _selectedStamp = _todayStamp),
              icon: const Icon(Icons.today_rounded),
            ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'habits-compose-fab',
        onPressed: _create,
        child: const Icon(Icons.add_rounded, size: 18),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HabitWeekStrip(
            today: DateTime.now(),
            selectedStamp: _selectedStamp,
            onSelected: (stamp) => setState(() => _selectedStamp = stamp),
          ),
          Expanded(
            child: active.isEmpty
                ? Center(
                    child: AppEmptyState(
                      icon: Icons.local_fire_department_outlined,
                      title: '还没有习惯',
                      message: '从一个小目标开始，今天就能完成第一次打卡。',
                      action: FilledButton(
                        onPressed: _create,
                        child: const Text('创建习惯'),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 108),
                    children: [
                      for (var g = 0; g < groups.length; g++) ...[
                        AppSectionLabel(
                          title: groups[g].name,
                          trailing: Text(
                            '${groups[g].habits.where((habit) => _checkinFor(habit, _selectedStamp)?.done == true).length}'
                            ' / ${groups[g].habits.length}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (
                                var i = 0;
                                i < groups[g].habits.length;
                                i++
                              ) ...[
                                _HabitRow(
                                  habit: groups[g].habits[i],
                                  checkin: _checkinFor(
                                    groups[g].habits[i],
                                    _selectedStamp,
                                  ),
                                  onCheckin:
                                      (_selectedIsFuture || _selectedIsPast)
                                      ? null
                                      : () => _checkin(groups[g].habits[i]),
                                  onOpen: () =>
                                      _openDetail(groups[g].habits[i]),
                                  onEdit: () => _edit(groups[g].habits[i]),
                                  onDelete: () => _delete(groups[g].habits[i]),
                                ),
                                if (i != groups[g].habits.length - 1)
                                  Divider(
                                    height: 1,
                                    indent: 78,
                                    endIndent: 16,
                                    color: scheme.outlineVariant,
                                  ),
                              ],
                            ],
                          ),
                        ),
                        if (g != groups.length - 1) const SizedBox(height: 18),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HabitGroup {
  const _HabitGroup(this.name, this.habits);

  final String name;
  final List<HabitItem> habits;
}

class _HabitWeekStrip extends StatelessWidget {
  const _HabitWeekStrip({
    required this.today,
    required this.selectedStamp,
    required this.onSelected,
  });

  final DateTime today;
  final int selectedStamp;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final todayDate = DateTime(today.year, today.month, today.day);
    final monday = todayDate.subtract(Duration(days: todayDate.weekday - 1));
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 2, 13, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _HabitDayCell(
                  day: monday.add(Duration(days: i)),
                  today: todayDate,
                  selectedStamp: selectedStamp,
                  onSelected: onSelected,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitDayCell extends StatelessWidget {
  const _HabitDayCell({
    required this.day,
    required this.today,
    required this.selectedStamp,
    required this.onSelected,
  });

  final DateTime day;
  final DateTime today;
  final int selectedStamp;
  final ValueChanged<int> onSelected;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stamp = _stampFor(day);
    final selected = stamp == selectedStamp;
    final isToday = stamp == _stampFor(today);
    final future = day.isAfter(today);
    final foreground = selected
        ? scheme.onPrimary
        : future
        ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
        : isToday
        ? scheme.primary
        : scheme.onSurface;
    final fill = selected
        ? scheme.primary.withValues(alpha: 0.12)
        : isToday
        ? scheme.primary.withValues(alpha: 0.07)
        : scheme.surfaceContainerLow;
    final outline = selected
        ? scheme.primary
        : isToday
        ? scheme.primary.withValues(alpha: 0.45)
        : scheme.outlineVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: '${day.month}月${day.day}日',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: outline, width: selected ? 1.2 : 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: future ? null : () => onSelected(stamp),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weekdays[day.weekday - 1],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? scheme.primary
                          : future
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                          : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? scheme.primary : Colors.transparent,
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        color: foreground,
                        fontWeight: selected || isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habit,
    required this.checkin,
    required this.onCheckin,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final HabitItem habit;
  final HabitCheckinItem? checkin;
  final VoidCallback? onCheckin;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = colorFromHex(habit.color);
    final value = checkin?.value ?? 0;
    final done = checkin?.done == true;
    final progress = habit.goal <= 1 ? (done ? 1.0 : 0.0) : value / habit.goal;
    final ringColor = onCheckin == null
        ? scheme.onSurfaceVariant.withValues(alpha: 0.3)
        : color;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0, 1),
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                      color: ringColor,
                      backgroundColor: ringColor.withValues(alpha: 0.16),
                    ),
                  ),
                  InkResponse(
                    onTap: onCheckin,
                    radius: 22,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: progress >= 1
                            ? color
                            : color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        progress >= 1 ? Icons.check_rounded : Icons.add_rounded,
                        size: 18,
                        color: progress >= 1 ? Colors.white : color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      '连续 ${habit.currentStreak} 天',
                      '累计 ${habit.totalCheckIns} 次',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (habit.goal > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_number(value)} / ${_number(habit.goal)} ${habit.unit}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '习惯操作',
              iconSize: 18,
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _HabitOption<T> {
  const _HabitOption(this.value, this.label);

  final T value;
  final String label;
}

/// Compact select used by the habit editor. A anchored popup menu keeps the
/// option rows tight and rounded; the field highlight follows its own radius
/// so focusing/switching never flashes square corners.
class _HabitSelect<T> extends StatelessWidget {
  const _HabitSelect({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<_HabitOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = options
        .firstWhere(
          (option) => option.value == value,
          orElse: () => options.first,
        )
        .label;
    return Builder(
      builder: (fieldContext) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context, fieldContext),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color:
                  theme.inputDecorationTheme.fillColor ??
                  scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 38),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, BuildContext fieldContext) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = fieldContext.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(origin.dx, origin.dy + box.size.height, box.size.width, 0),
      Offset.zero & overlay.size,
    );
    final scheme = Theme.of(context).colorScheme;
    final selected = await showMenu<T>(
      context: context,
      position: position,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 320),
      items: [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            height: 42,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (option.value == value)
                  Icon(Icons.check_rounded, size: 18, color: scheme.primary),
              ],
            ),
          ),
      ],
    );
    if (selected != null) onChanged(selected);
  }
}

class _HabitEditorSheet extends StatefulWidget {
  const _HabitEditorSheet({required this.sections, this.initial});

  final List<Map<String, dynamic>> sections;
  final HabitItem? initial;

  @override
  State<_HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<_HabitEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _goal;
  late final TextEditingController _daysPerWeek;
  late final TextEditingController _interval;
  late final TextEditingController _targetDays;
  late String _icon;
  late String _color;
  late String _frequencyMode;
  late Set<int> _weekdays;
  late String _goalMode;
  late DateTime _startDate;
  late String _durationMode;
  late int _sectionId;
  late String _style;
  late bool _recordEnable;
  late List<String> _reminders;
  late List<int> _exDates;

  static const _emojis = [
    '😊',
    '📚',
    '🏃',
    '💧',
    '🧘',
    '🌱',
    '🎯',
    '✍️',
    '🌙',
    '🍎',
    '💪',
    '🎨',
  ];
  static const _colors = [
    '#97E38B',
    '#FFB84D',
    '#FF7B7B',
    '#7B9CFF',
    '#B58BFF',
    '#5ED4C5',
    '#F28BC5',
    '#A2A8B8',
  ];
  static const _weekdayLabels = ['日', '一', '二', '三', '四', '五', '六'];

  @override
  void initState() {
    super.initState();
    final habit = widget.initial;
    _name = TextEditingController(text: habit?.name ?? '');
    _icon = habit?.icon.isNotEmpty == true ? habit!.icon : _emojis.first;
    _color = habit?.color.isNotEmpty == true ? habit!.color : _colors.first;
    _sectionId = habit?.sectionId ?? 0;
    _style = habit?.style == 'icon' ? 'icon' : 'check';
    _recordEnable = habit?.recordEnable ?? false;
    _reminders = [...?habit?.reminders];
    _exDates = [...?habit?.exDates]..sort();
    _goalMode = (habit?.goal ?? 1) > 1 ? 'quantity' : 'completion';
    _goal = TextEditingController(
      text: _number((habit?.goal ?? 1) <= 1 ? 1 : habit!.goal),
    );
    _durationMode = (habit?.targetDays ?? 0) > 0 ? 'days' : 'forever';
    _targetDays = TextEditingController(
      text: _number((habit?.targetDays ?? 0) > 0 ? habit!.targetDays : 30),
    );
    _startDate = _dateFromStamp(habit?.startDate ?? 0) ?? DateTime.now();
    _daysPerWeek = TextEditingController(text: '2');
    _interval = TextEditingController(text: '2');
    _frequencyMode = 'daily';
    _weekdays = {0, 1, 2, 3, 4, 5, 6};
    _loadFrequency(habit?.frequency ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    _daysPerWeek.dispose();
    _interval.dispose();
    _targetDays.dispose();
    super.dispose();
  }

  static String _number(num value) {
    final doubleValue = value.toDouble();
    if (doubleValue == doubleValue.roundToDouble()) {
      return doubleValue.toInt().toString();
    }
    return doubleValue.toStringAsFixed(1);
  }

  static num _asNum(Object? value, num fallback) {
    if (value is num) return value;
    return num.tryParse('${value ?? ''}') ?? fallback;
  }

  static DateTime? _dateFromStamp(int stamp) {
    if (stamp <= 0) return null;
    final year = stamp ~/ 10000;
    final month = (stamp ~/ 100) % 100;
    final day = stamp % 100;
    if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    return DateTime(year, month, day);
  }

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void _loadFrequency(String raw) {
    if (raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final type = decoded['type']?.toString();
      final weekdays = decoded['weekdays'];
      if (type == 'weekly' && weekdays is List) {
        _frequencyMode = 'daily';
        final values = _parseWeekdays(weekdays);
        if (values.isNotEmpty) _weekdays = values;
        return;
      }
      if (type == 'weekly') {
        _frequencyMode = 'weekly';
        _daysPerWeek.text = _number(
          _asNum(decoded['daysPerWeek'], 2).clamp(1, 7),
        );
        return;
      }
      if (type == 'interval') {
        _frequencyMode = 'interval';
        _interval.text = _number(_asNum(decoded['interval'], 2).clamp(1, 365));
        return;
      }
      if (weekdays is List) {
        final values = _parseWeekdays(weekdays);
        if (values.isNotEmpty) _weekdays = values;
      }
    } on FormatException {
      // Keep the defaults when the stored rule is malformed.
    }
  }

  Set<int> _parseWeekdays(List<dynamic> raw) => raw
      .map((value) => value is int ? value : int.tryParse('$value') ?? -1)
      .where((value) => value >= 0 && value <= 6)
      .toSet();

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写习惯名称')));
      return;
    }
    final weekdays = _weekdays.isEmpty
        ? <int>[0, 1, 2, 3, 4, 5, 6]
        : (_weekdays.toList()..sort());
    final frequency = switch (_frequencyMode) {
      'weekly' => jsonEncode({
        'type': 'weekly',
        'daysPerWeek': _asNum(_daysPerWeek.text, 2).toInt().clamp(1, 7),
      }),
      'interval' => jsonEncode({
        'type': 'interval',
        'interval': _asNum(_interval.text, 2).toInt().clamp(1, 365),
      }),
      _ => jsonEncode({'type': 'daily', 'weekdays': weekdays}),
    };
    final goal = _goalMode == 'quantity'
        ? _asNum(_goal.text, 1).clamp(1, 9999).toDouble()
        : 1.0;
    final targetDays = _durationMode == 'days'
        ? _asNum(_targetDays.text, 30).toInt().clamp(1, 9999)
        : 0;
    final exDates = _exDates.toSet().toList()..sort();
    Navigator.pop(
      context,
      HabitDraft(
        name: name,
        color: _color,
        icon: _icon,
        sectionId: _sectionId,
        goal: goal,
        step: widget.initial?.step ?? 1,
        unit: widget.initial?.unit ?? 'Count',
        frequency: frequency,
        targetDays: targetDays,
        style: _style,
        status: widget.initial?.status ?? 0,
        reminders: _reminders.where((value) => value.isNotEmpty).toList(),
        recordEnable: _recordEnable,
        startDate: _stampFor(_startDate),
        exDates: exDates,
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _addExDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final stamp = _stampFor(picked);
    setState(() {
      if (!_exDates.contains(stamp)) {
        _exDates = [..._exDates, stamp]..sort();
      }
    });
  }

  Future<void> _addReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      _reminders = [
        ..._reminders,
        '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}',
      ];
    });
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _inlineNumberField(TextEditingController controller) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: 76,
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              theme.inputDecorationTheme.fillColor ??
              scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
          decoration: const InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = theme.copyWith(
      visualDensity: VisualDensity.compact,
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    return Theme(
      data: compact,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom:
              MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom +
              12,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.initial == null ? '新建习惯' : '编辑习惯',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorFromHex(_color),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _icon,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _name,
                          autofocus: true,
                          decoration: const InputDecoration(labelText: '名称'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final emoji in _emojis)
                        InkWell(
                          onTap: () => setState(() => _icon = emoji),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _icon == emoji
                                    ? scheme.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 19),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final color in _colors)
                        InkWell(
                          onTap: () => setState(() => _color = color),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: colorFromHex(color),
                              shape: BoxShape.circle,
                              border: _color == color
                                  ? Border.all(
                                      color: scheme.onSurface,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: _color == color
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  _sectionTitle('频率'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _HabitSelect<String>(
                            value: _frequencyMode,
                            options: const [
                              _HabitOption('daily', '按天'),
                              _HabitOption('weekly', '按周'),
                              _HabitOption('interval', '按时间间隔'),
                            ],
                            onChanged: (value) =>
                                setState(() => _frequencyMode = value),
                          ),
                        ),
                        if (_frequencyMode == 'weekly') ...[
                          const SizedBox(width: 8),
                          _inlineNumberField(_daysPerWeek),
                          const SizedBox(width: 6),
                          const Center(child: Text('天')),
                        ] else if (_frequencyMode == 'interval') ...[
                          const SizedBox(width: 8),
                          _inlineNumberField(_interval),
                          const SizedBox(width: 6),
                          const Center(child: Text('天')),
                        ],
                      ],
                    ),
                  ),
                  if (_frequencyMode == 'daily') ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var index = 0; index < 7; index++)
                          FilterChip(
                            label: Text(_weekdayLabels[index]),
                            selected: _weekdays.contains(index),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _weekdays.add(index);
                                } else {
                                  _weekdays.remove(index);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                  _sectionTitle('目标'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _HabitSelect<String>(
                            value: _goalMode,
                            options: const [
                              _HabitOption('completion', '当天完成打卡'),
                              _HabitOption('quantity', '当天完成一定量'),
                            ],
                            onChanged: (value) =>
                                setState(() => _goalMode = value),
                          ),
                        ),
                        if (_goalMode == 'quantity') ...[
                          const SizedBox(width: 8),
                          _inlineNumberField(_goal),
                          const SizedBox(width: 6),
                          const Center(child: Text('次/天')),
                        ],
                      ],
                    ),
                  ),
                  _sectionTitle('开始日期'),
                  OutlinedButton.icon(
                    onPressed: _pickStartDate,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(_dateLabel(_startDate)),
                  ),
                  _sectionTitle('例外日期'),
                  OutlinedButton.icon(
                    onPressed: _addExDate,
                    icon: const Icon(Icons.event_busy_rounded, size: 18),
                    label: const Text('添加例外日期'),
                  ),
                  if (_exDates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final stamp in _exDates)
                          if (_dateFromStamp(stamp) != null)
                            InputChip(
                              label: Text(_dateLabel(_dateFromStamp(stamp)!)),
                              onDeleted: () => setState(() {
                                _exDates = _exDates
                                    .where((e) => e != stamp)
                                    .toList();
                              }),
                            ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '例外日期不会进入打卡和连续统计，也不能补卡。',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  _sectionTitle('坚持天数'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _HabitSelect<String>(
                            value: _durationMode,
                            options: const [
                              _HabitOption('forever', '永远'),
                              _HabitOption('days', '指定天数'),
                            ],
                            onChanged: (value) =>
                                setState(() => _durationMode = value),
                          ),
                        ),
                        if (_durationMode == 'days') ...[
                          const SizedBox(width: 8),
                          _inlineNumberField(_targetDays),
                          const SizedBox(width: 6),
                          const Center(child: Text('天')),
                        ],
                      ],
                    ),
                  ),
                  _sectionTitle('所属分组'),
                  _HabitSelect<int>(
                    value: _sectionId,
                    options: [
                      const _HabitOption(0, '其他'),
                      for (final section in widget.sections)
                        _HabitOption(
                          _asNum(section['id'], 0).toInt(),
                          '${section['name'] ?? ''}',
                        ),
                    ],
                    onChanged: (value) => setState(() => _sectionId = value),
                  ),
                  _sectionTitle('打卡样式'),
                  _HabitSelect<String>(
                    value: _style,
                    options: const [
                      _HabitOption('check', '对勾'),
                      _HabitOption('icon', '习惯图标'),
                    ],
                    onChanged: (value) => setState(() => _style = value),
                  ),
                  _sectionTitle('提醒'),
                  for (var index = 0; index < _reminders.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final initial = _parseTime(_reminders[index]);
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: initial,
                                );
                                if (picked == null) return;
                                setState(() {
                                  _reminders[index] =
                                      '${picked.hour.toString().padLeft(2, '0')}:'
                                      '${picked.minute.toString().padLeft(2, '0')}';
                                });
                              },
                              icon: const Icon(
                                Icons.access_time_rounded,
                                size: 18,
                              ),
                              label: Text(_reminders[index]),
                            ),
                          ),
                          IconButton(
                            tooltip: '删除提醒',
                            onPressed: () => setState(() {
                              _reminders = [..._reminders]..removeAt(index);
                            }),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _addReminder,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('添加提醒'),
                  ),
                  CheckboxListTile(
                    value: _recordEnable,
                    onChanged: (value) =>
                        setState(() => _recordEnable = value ?? false),
                    title: const Text('自动弹出打卡日志'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),
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
          ),
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 10;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }
}

class _HabitDetailSheet extends StatelessWidget {
  const _HabitDetailSheet({
    required this.habit,
    required this.checkins,
    required this.stamp,
    required this.onCheckin,
  });

  final HabitItem habit;
  final List<HabitCheckinItem> checkins;
  final int stamp;
  final VoidCallback? onCheckin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = colorFromHex(habit.color);
    final selected = checkins
        .where((checkin) => checkin.stamp == stamp)
        .toList(growable: false);
    final done = selected.isNotEmpty && selected.first.done;
    final byStamp = {for (final checkin in checkins) checkin.stamp: checkin};
    final now = DateTime.now();
    final days = List.generate(30, (index) {
      final day = now.subtract(Duration(days: 29 - index));
      final stamp = day.year * 10000 + day.month * 100 + day.day;
      return (day: day, stamp: stamp, checkin: byStamp[stamp]);
    });
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
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    habit.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCheckin,
                  icon: Icon(
                    done ? Icons.check_rounded : Icons.add_rounded,
                    size: 18,
                  ),
                  label: Text(done ? '已完成' : '打卡'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: '连续', value: '${habit.currentStreak} 天'),
                _Stat(label: '最长', value: '${habit.maxStreak} 天'),
                _Stat(label: '累计', value: '${habit.totalCheckIns} 次'),
                if (habit.goal > 1)
                  _Stat(
                    label: '当日',
                    value:
                        '${selected.isEmpty ? 0 : selected.first.value}/${habit.goal}',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('最近 30 天', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final day in days)
                  Tooltip(
                    message:
                        '${day.day.month}/${day.day.day} ${day.checkin?.done == true ? '已完成' : '未完成'}',
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: day.checkin?.done == true
                            ? color
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

int _stampFor(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

DateTime _dateForStamp(int stamp) {
  final text = stamp.toString().padLeft(8, '0');
  return DateTime(
    int.parse(text.substring(0, 4)),
    int.parse(text.substring(4, 6)),
    int.parse(text.substring(6, 8)),
  );
}
