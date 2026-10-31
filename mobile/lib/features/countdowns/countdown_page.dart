import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/ui_utils.dart';
import '../../data/countdowns/countdown_api.dart';
import '../../data/countdowns/countdown_store.dart';
import '../../design/components.dart';

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  CountdownStore? _store;
  List<CountdownItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _attach(context.read<AppState>().countdowns);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach(context.read<AppState>().countdowns);
  }

  /// Renders the local mirror only; the sync thread refreshes it in the
  /// background and this listener repaints the page.
  void _attach(CountdownStore store) {
    if (identical(_store, store)) return;
    _store?.removeListener(_onStoreChanged);
    _store = store..addListener(_onStoreChanged);
    _items = store.items;
  }

  void _onStoreChanged() {
    final store = _store;
    if (store == null || !mounted) return;
    setState(() => _items = store.items);
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    _store = null;
    super.dispose();
  }

  Future<void> _create() async {
    final draft = await showModalBottomSheet<CountdownDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => const _CountdownEditorSheet(),
    );
    if (draft == null || !mounted) return;
    await _store?.create(draft);
  }

  Future<void> _edit(CountdownItem item) async {
    final draft = await showModalBottomSheet<CountdownDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => _CountdownEditorSheet(initial: item),
    );
    if (draft == null || !mounted) return;
    await _store?.update(item.id, draft);
  }

  Future<void> _delete(CountdownItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除倒数记录'),
        content: Text('确定删除「${item.name}」吗？'),
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
    await _store?.delete(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('倒数日'),
            const SizedBox(height: 5),
            Text(
              _items.isEmpty ? '记住值得期待的日子' : '${_items.length} 个日子',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [const SizedBox(width: 6)],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'countdown-compose-fab',
        onPressed: _create,
        child: const Icon(Icons.add_rounded, size: 18),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
          children: [
            if (_items.isEmpty)
              SizedBox(
                height: constraints.maxHeight - 40,
                child: const Center(
                  child: AppEmptyState(
                    icon: Icons.hourglass_empty_rounded,
                    title: '还没有倒数记录',
                    message: '记录重要日子，看看还有多少天',
                  ),
                ),
              )
            else
              for (final item in _items) ...[
                _CountdownCard(
                  item: item,
                  onEdit: () => _edit(item),
                  onDelete: () => _delete(item),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final CountdownItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = _hexColor(item.color, scheme.primary);
    final accent = _strongColor(base, theme.brightness);
    return AppCard(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: base.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_countdownIcon(item.type), color: accent, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.pinned) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.push_pin_rounded, size: 14, color: accent),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _countdownDateLabel(item),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (item.remark.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.remark,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.isToday)
                Text(
                  '今天',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: -0.5,
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${item.days}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: item.isPast ? scheme.onSurfaceVariant : accent,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '天',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              if (item.isPast)
                Text(
                  '前',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              SizedBox(
                height: 26,
                child: PopupMenuButton<String>(
                  tooltip: '更多操作',
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountdownOption<T> {
  const _CountdownOption(this.value, this.label);

  final T value;
  final String label;
}

class _CountdownSelect<T> extends StatelessWidget {
  const _CountdownSelect({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<_CountdownOption<T>> options;
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

class _CountdownEditorSheet extends StatefulWidget {
  const _CountdownEditorSheet({this.initial});

  final CountdownItem? initial;

  @override
  State<_CountdownEditorSheet> createState() => _CountdownEditorSheetState();
}

class _CountdownEditorSheetState extends State<_CountdownEditorSheet> {
  static const _types = [
    _CountdownOption('countdown', '倒数日'),
    _CountdownOption('anniversary', '纪念日'),
    _CountdownOption('birthday', '生日'),
    _CountdownOption('festival', '节日'),
  ];
  static const _emojis = [
    '⏳',
    '🎂',
    '🎉',
    '💍',
    '🏖️',
    '🎓',
    '🏆',
    '❤️',
    '🌸',
    '📅',
  ];
  static const _colors = [
    '#92D0FF',
    '#FDB368',
    '#FF8F9C',
    '#B58BFF',
    '#97E38B',
    '#5ED4C5',
    '#F4C95D',
    '#A2A8B8',
  ];
  static const _styles = [
    _CountdownOption('normal', '简约'),
    _CountdownOption('soft', '柔和'),
    _CountdownOption('color', '彩色'),
    _CountdownOption('outline', '描边'),
  ];
  static const _backgrounds = [
    _CountdownOption('', '无'),
    _CountdownOption('aurora', '极光'),
    _CountdownOption('sunset', '晚霞'),
    _CountdownOption('mint', '薄荷'),
    _CountdownOption('rose', '玫瑰'),
  ];
  static const _repeats = [
    _CountdownOption('none', '不重复'),
    _CountdownOption('yearly', '每年'),
    _CountdownOption('monthly', '每月'),
    _CountdownOption('weekly', '每周'),
    _CountdownOption('weekend', '每个周末'),
  ];
  static const _reminderOptions = {
    0: '当天',
    1: '提前 1 天',
    3: '提前 3 天',
    7: '提前 7 天',
  };
  static const _lunarMonths = [
    '正月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '冬月',
    '腊月',
  ];
  static const _lunarDays = [
    '初一',
    '初二',
    '初三',
    '初四',
    '初五',
    '初六',
    '初七',
    '初八',
    '初九',
    '初十',
    '十一',
    '十二',
    '十三',
    '十四',
    '十五',
    '十六',
    '十七',
    '十八',
    '十九',
    '二十',
    '廿一',
    '廿二',
    '廿三',
    '廿四',
    '廿五',
    '廿六',
    '廿七',
    '廿八',
    '廿九',
    '三十',
  ];

  late final TextEditingController _name;
  late final TextEditingController _remark;
  late final TextEditingController _lunarYear;
  late DateTime _date;
  late String _type;
  late String _repeat;
  late bool _pinned;
  late String _color;
  late String _icon;
  late String _calendar;
  late int _lunarMonth;
  late int _lunarDay;
  late bool _lunarLeap;
  late String _style;
  late String _background;
  late String _dateDisplayFormat;
  late String _daysOption;
  late bool _ignoreYear;
  late bool _showAge;
  late Set<int> _reminderOffsets;
  late TimeOfDay _reminderTime;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    _name = TextEditingController(text: item?.name ?? '');
    _remark = TextEditingController(text: item?.remark ?? '');
    _lunarYear = TextEditingController(
      text: (item?.lunarYear ?? 0) > 0 ? '${item!.lunarYear}' : '',
    );
    _date =
        _dateFromStamp(item?.date) ??
        DateTime.now().add(const Duration(days: 30));
    _type = item?.type ?? 'countdown';
    _repeat = item?.repeat ?? 'none';
    _pinned = item?.pinned ?? false;
    _color = item?.color ?? _colors.first;
    _icon = item?.icon.isNotEmpty == true ? item!.icon : _emojis.first;
    _calendar = item?.calendar ?? 'solar';
    _lunarMonth = (item?.lunarMonth ?? 0) > 0 ? item!.lunarMonth : 1;
    _lunarDay = (item?.lunarDay ?? 0) > 0 ? item!.lunarDay : 1;
    _lunarLeap = item?.lunarLeap ?? false;
    _style = item?.style ?? 'normal';
    _background = item?.background ?? '';
    _dateDisplayFormat = item?.dateDisplayFormat ?? 'day';
    _daysOption = item?.daysOption ?? 'day';
    _ignoreYear = item?.ignoreYear ?? false;
    _showAge = item?.showAge ?? false;
    _reminderOffsets = {...?item?.reminders};
    _reminderTime = _parseTime(item?.reminderTime ?? '09:00');
  }

  @override
  void dispose() {
    disposeControllerSoon(_name);
    disposeControllerSoon(_remark);
    disposeControllerSoon(_lunarYear);
    super.dispose();
  }

  TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _timeLabel(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null) return;
    setState(() => _reminderTime = picked);
  }

  void _setCalendar(String value) {
    setState(() {
      _calendar = value;
      if (value == 'lunar' &&
          (_repeat == 'monthly' ||
              _repeat == 'weekly' ||
              _repeat == 'weekend')) {
        _repeat = 'yearly';
      }
    });
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入名称')));
      return;
    }
    final lunarYear = int.tryParse(_lunarYear.text.trim()) ?? 0;
    Navigator.pop(
      context,
      CountdownDraft(
        name: name,
        date: _date,
        type: _type,
        repeat: _repeat,
        pinned: _pinned,
        color: _color,
        remark: _remark.text.trim(),
        icon: _icon,
        calendar: _calendar,
        lunarMonth: _calendar == 'lunar' ? _lunarMonth : 0,
        lunarDay: _calendar == 'lunar' ? _lunarDay : 0,
        lunarLeap: _calendar == 'lunar' && _lunarLeap,
        lunarYear: _calendar == 'lunar' && _type == 'birthday' && lunarYear > 0
            ? lunarYear.clamp(1900, 2100)
            : 0,
        style: _style,
        background: _background,
        reminders: _reminderOffsets.toList()..sort(),
        reminderTime: _timeLabel(_reminderTime),
        ignoreYear: _type != 'birthday' && _ignoreYear,
        showAge: _type == 'birthday' && _showAge,
        dateDisplayFormat: _dateDisplayFormat,
        daysOption: _daysOption,
      ),
    );
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

  Widget _dateButton() => OutlinedButton.icon(
    onPressed: _pickDate,
    icon: const Icon(Icons.event_rounded, size: 18),
    label: Text(_dateLabel(_date)),
  );

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
    final isLunar = _calendar == 'lunar';
    final isBirthday = _type == 'birthday';
    return Theme(
      data: compact,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.initial == null ? '新建倒数日' : '编辑倒数日',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _hexColor(_color, scheme.primary),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _name,
                            autofocus: widget.initial == null,
                            maxLength: 64,
                            decoration: const InputDecoration(
                              labelText: '名称',
                              hintText: '例如：旅行出发、生日',
                              counterText: '',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final emoji in _emojis)
                          InkWell(
                            onTap: () => setState(() => _icon = emoji),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 30,
                              height: 30,
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
                                style: const TextStyle(fontSize: 17),
                              ),
                            ),
                          ),
                      ],
                    ),
                    _sectionTitle('类型'),
                    _CountdownSelect<String>(
                      value: _type,
                      options: _types,
                      onChanged: (value) => setState(() => _type = value),
                    ),
                    _sectionTitle('历法'),
                    _CountdownSelect<String>(
                      value: _calendar,
                      options: const [
                        _CountdownOption('solar', '公历'),
                        _CountdownOption('lunar', '农历'),
                      ],
                      onChanged: _setCalendar,
                    ),
                    if (!isLunar) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _dateButton()),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CountdownSelect<String>(
                              value: _repeat,
                              options: _repeats,
                              onChanged: (value) =>
                                  setState(() => _repeat = value),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _CountdownSelect<int>(
                              value: _lunarMonth,
                              options: [
                                for (var month = 1; month <= 12; month++)
                                  _CountdownOption(
                                    month,
                                    _lunarMonths[month - 1],
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _lunarMonth = value),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CountdownSelect<int>(
                              value: _lunarDay,
                              options: [
                                for (var day = 1; day <= 30; day++)
                                  _CountdownOption(day, _lunarDays[day - 1]),
                              ],
                              onChanged: (value) =>
                                  setState(() => _lunarDay = value),
                            ),
                          ),
                        ],
                      ),
                      CheckboxListTile(
                        value: _lunarLeap,
                        onChanged: (value) =>
                            setState(() => _lunarLeap = value ?? false),
                        title: const Text('闰月'),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (isBirthday)
                        TextField(
                          controller: _lunarYear,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '出生年份'),
                        ),
                      const SizedBox(height: 8),
                      _CountdownSelect<String>(
                        value: _repeat == 'yearly' || _repeat == 'none'
                            ? _repeat
                            : 'yearly',
                        options: const [
                          _CountdownOption('yearly', '每年'),
                          _CountdownOption('none', '不重复'),
                        ],
                        onChanged: (value) => setState(() => _repeat = value),
                      ),
                    ],
                    _sectionTitle('显示'),
                    Row(
                      children: [
                        Expanded(
                          child: _CountdownSelect<String>(
                            value: _dateDisplayFormat,
                            options: const [
                              _CountdownOption('day', '标准'),
                              _CountdownOption('full', '完整日期'),
                            ],
                            onChanged: (value) =>
                                setState(() => _dateDisplayFormat = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CountdownSelect<String>(
                            value: _daysOption,
                            options: const [
                              _CountdownOption('day', '按天'),
                              _CountdownOption('hour', '按小时'),
                              _CountdownOption('minute', '按分钟'),
                              _CountdownOption('second', '按秒'),
                            ],
                            onChanged: (value) =>
                                setState(() => _daysOption = value),
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      value: isBirthday ? _showAge : _ignoreYear,
                      onChanged: (value) => setState(() {
                        if (isBirthday) {
                          _showAge = value ?? false;
                        } else {
                          _ignoreYear = value ?? false;
                        }
                      }),
                      title: Text(isBirthday ? '显示年龄' : '忽略年份'),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    _sectionTitle('提醒'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in _reminderOptions.entries)
                          FilterChip(
                            label: Text(entry.value),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            selected: _reminderOffsets.contains(entry.key),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _reminderOffsets.add(entry.key);
                              } else {
                                _reminderOffsets.remove(entry.key);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('提醒时间'),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _pickReminderTime,
                          icon: const Icon(Icons.access_time_rounded, size: 18),
                          label: Text(_timeLabel(_reminderTime)),
                        ),
                      ],
                    ),
                    _sectionTitle('背景'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final background in _backgrounds)
                          ChoiceChip(
                            label: Text(background.label),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            selected: _background == background.value,
                            onSelected: (_) =>
                                setState(() => _background = background.value),
                          ),
                      ],
                    ),
                    _sectionTitle('样式'),
                    _CountdownSelect<String>(
                      value: _style,
                      options: _styles,
                      onChanged: (value) => setState(() => _style = value),
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
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: _hexColor(color, scheme.primary),
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
                                      Icons.check,
                                      size: 15,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    _sectionTitle('备注'),
                    TextField(
                      controller: _remark,
                      maxLines: 2,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: '记下这个日子的意义…',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _submit,
                          child: Text(widget.initial == null ? '创建' : '保存'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _countdownIcon(String type) => switch (type) {
  'birthday' => Icons.cake_rounded,
  'anniversary' => Icons.favorite_rounded,
  'festival' => Icons.celebration_rounded,
  _ => Icons.hourglass_bottom_rounded,
};

Color _strongColor(Color color, Brightness brightness) {
  if (brightness == Brightness.dark) return color;
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness * 0.72).clamp(0.32, 0.55))
      .withSaturation((hsl.saturation * 0.95).clamp(0.0, 1.0))
      .toColor();
}

String _countdownDateLabel(CountdownItem item) {
  final occurrence = _dateFromStamp(item.occurrenceDate);
  final base = occurrence == null ? '' : _dateLabel(occurrence);
  if (item.repeat == 'yearly') return '$base · 每年';
  return base;
}

DateTime? _dateFromStamp(int? stamp) {
  if (stamp == null || stamp <= 0) return null;
  final text = stamp.toString().padLeft(8, '0');
  final year = int.tryParse(text.substring(0, 4));
  final month = int.tryParse(text.substring(4, 6));
  final day = int.tryParse(text.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String _dateLabel(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.'
    '${date.day.toString().padLeft(2, '0')}';

Color _hexColor(String value, Color fallback) {
  final cleaned = value.replaceAll('#', '').trim();
  if (cleaned.length != 6) return fallback;
  final parsed = int.tryParse(cleaned, radix: 16);
  if (parsed == null) return fallback;
  return Color(0xFF000000 | parsed);
}
