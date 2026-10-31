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
      builder: (context) => const _HabitEditorSheet(),
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
      builder: (context) => _HabitEditorSheet(initial: habit),
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'habits-compose-fab',
        onPressed: _create,
        child: const Icon(Icons.add_rounded),
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

class _HabitEditorSheet extends StatefulWidget {
  const _HabitEditorSheet({this.initial});

  final HabitItem? initial;

  @override
  State<_HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<_HabitEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _goal;
  late final TextEditingController _step;
  late final TextEditingController _unit;
  late String _color;
  late String _frequency;
  late int _targetDays;

  static const _colors = [
    '#97E38B',
    '#4772FA',
    '#F59E0B',
    '#EF4444',
    '#8B5CF6',
    '#14B8A6',
  ];

  @override
  void initState() {
    super.initState();
    final habit = widget.initial;
    _name = TextEditingController(text: habit?.name ?? '');
    _goal = TextEditingController(text: _number(habit?.goal ?? 1));
    _step = TextEditingController(text: _number(habit?.step ?? 1));
    _unit = TextEditingController(text: habit?.unit ?? 'Count');
    _color = habit?.color.isNotEmpty == true ? habit!.color : _colors.first;
    _frequency = habit?.frequency ?? '';
    _targetDays = habit?.targetDays ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    _step.dispose();
    _unit.dispose();
    super.dispose();
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  String get _frequencyType {
    try {
      final decoded = jsonDecode(_frequency);
      if (decoded is Map<String, dynamic>) {
        final type = (decoded['type'] ?? '').toString();
        if (type == 'weekly' && decoded['weekdays'] is List) return 'weekdays';
        if (type == 'weekly') return 'weekly';
      }
    } on FormatException {
      // Fall back to daily.
    }
    return 'daily';
  }

  void _setFrequency(String type) {
    setState(() {
      _frequency = switch (type) {
        'weekdays' => '{"type":"weekly","weekdays":[1,2,3,4,5]}',
        'weekly' => '{"type":"weekly","daysPerWeek":1}',
        _ => '{"type":"daily","weekdays":[0,1,2,3,4,5,6]}',
      };
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写习惯名称')));
      return;
    }
    final goal = double.tryParse(_goal.text.trim()) ?? 1;
    final step = double.tryParse(_step.text.trim()) ?? 1;
    Navigator.pop(
      context,
      HabitDraft(
        name: name,
        color: _color,
        sectionId: widget.initial?.sectionId ?? 0,
        goal: goal <= 0 ? 1 : goal,
        step: step <= 0 ? 1 : step,
        unit: _unit.text.trim().isEmpty ? 'Count' : _unit.text.trim(),
        frequency: _frequency,
        targetDays: _targetDays,
        status: widget.initial?.status ?? 0,
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
              widget.initial == null ? '新建习惯' : '编辑习惯',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            Text('颜色', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: [
                for (final color in _colors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorFromHex(color),
                        shape: BoxShape.circle,
                        border: _color == color
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 2,
                              )
                            : null,
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _goal,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '目标'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _step,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '每次'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: '单位'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _frequencyType,
              decoration: const InputDecoration(labelText: '频率'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('每天')),
                DropdownMenuItem(value: 'weekdays', child: Text('工作日')),
                DropdownMenuItem(value: 'weekly', child: Text('每周')),
              ],
              onChanged: (value) {
                if (value != null) _setFrequency(value);
              },
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
