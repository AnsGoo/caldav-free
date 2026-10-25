import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/habits/habit_api.dart';
import '../../design/components.dart';
import '../../design/format.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  late final HabitApi _api;
  HabitSnapshot? _snapshot;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = context.read<AppState>().session!;
    _api = HabitApi(
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
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await _api.fetch();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  int get _todayStamp {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  HabitCheckinItem? _todayCheckin(HabitItem habit) {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    for (final checkin in snapshot.checkins) {
      if (checkin.habitId == habit.id && checkin.stamp == _todayStamp) {
        return checkin;
      }
    }
    return null;
  }

  Future<void> _checkin(HabitItem habit) async {
    try {
      await _api.checkin(habit.id, _todayStamp);
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('打卡失败：$error')));
    }
  }

  Future<void> _create() async {
    final draft = await showModalBottomSheet<HabitDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _HabitEditorSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      await _api.create(draft);
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建习惯失败：$error')));
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
      await _api.update(habit.id, draft);
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存习惯失败：$error')));
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
      await _api.delete(habit.id);
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }

  void _openDetail(HabitItem habit) {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _HabitDetailSheet(
        habit: habit,
        checkins: snapshot.checkins
            .where((checkin) => checkin.habitId == habit.id)
            .toList(growable: false),
        todayStamp: _todayStamp,
        onCheckin: () {
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
    final active = (snapshot?.habits ?? const <HabitItem>[])
        .where((habit) => !habit.archived)
        .toList(growable: false);
    final due = active.where((habit) => habit.dueToday).toList();
    final done = due.where((habit) => habit.doneToday).length;
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
              due.isEmpty ? '用微小的重复，换取长期的变化' : '今天完成 $done / ${due.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '刷新习惯',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Material(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
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
            ),
          Expanded(
            child: snapshot == null
                ? const Center(child: CircularProgressIndicator())
                : active.isEmpty
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
                : RefreshIndicator(
                    onRefresh: () => _load(showLoading: false),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 108),
                      children: [
                        AppSectionLabel(
                          title: '我的习惯',
                          trailing: due.isEmpty
                              ? null
                              : Text(
                                  '$done / ${due.length}',
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
                              for (var i = 0; i < active.length; i++) ...[
                                _HabitRow(
                                  habit: active[i],
                                  checkin: _todayCheckin(active[i]),
                                  onCheckin: () => _checkin(active[i]),
                                  onOpen: () => _openDetail(active[i]),
                                  onEdit: () => _edit(active[i]),
                                  onDelete: () => _delete(active[i]),
                                ),
                                if (i != active.length - 1)
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
                      ],
                    ),
                  ),
          ),
        ],
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
  final VoidCallback onCheckin;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = colorFromHex(habit.color);
    final value = checkin?.value ?? 0;
    final progress = habit.goal <= 1
        ? (habit.doneToday ? 1.0 : 0.0)
        : value / habit.goal;
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
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.16),
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
    required this.todayStamp,
    required this.onCheckin,
  });

  final HabitItem habit;
  final List<HabitCheckinItem> checkins;
  final int todayStamp;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = colorFromHex(habit.color);
    final today = checkins
        .where((checkin) => checkin.stamp == todayStamp)
        .toList(growable: false);
    final done = today.isNotEmpty && today.first.done;
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
                    label: '今日',
                    value:
                        '${today.isEmpty ? 0 : today.first.value}/${habit.goal}',
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
