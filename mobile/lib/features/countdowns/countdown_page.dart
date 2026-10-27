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
      floatingActionButton: FloatingActionButton(
        heroTag: 'countdown-compose-fab',
        onPressed: _create,
        child: const Icon(Icons.add_rounded),
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

class _CountdownEditorSheet extends StatefulWidget {
  const _CountdownEditorSheet({this.initial});

  final CountdownItem? initial;

  @override
  State<_CountdownEditorSheet> createState() => _CountdownEditorSheetState();
}

class _CountdownEditorSheetState extends State<_CountdownEditorSheet> {
  static const _types = {
    'countdown': '倒数日',
    'anniversary': '纪念日',
    'birthday': '生日',
    'festival': '节日',
  };
  static const _colors = [
    '#92D0FF',
    '#FF8A65',
    '#66BB6A',
    '#BA68C8',
    '#FFB74D',
    '#4DB6AC',
  ];

  late final TextEditingController _name;
  late final TextEditingController _remark;
  late DateTime _date;
  late String _type;
  late String _repeat;
  late bool _pinned;
  late String _color;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    _name = TextEditingController(text: item?.name ?? '');
    _remark = TextEditingController(text: item?.remark ?? '');
    _date =
        _dateFromStamp(item?.date) ??
        DateTime.now().add(const Duration(days: 30));
    _type = item?.type ?? 'countdown';
    _repeat = item?.repeat ?? 'none';
    _pinned = item?.pinned ?? false;
    _color = item?.color ?? _colors.first;
  }

  @override
  void dispose() {
    disposeControllerSoon(_name);
    disposeControllerSoon(_remark);
    super.dispose();
  }

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

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入名称')));
      return;
    }
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initial == null ? '新建倒数日' : '编辑倒数日',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: widget.initial == null,
                textInputAction: TextInputAction.next,
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例如：旅行出发、生日',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('日期'),
                subtitle: Text(_dateLabel(_date)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickDate,
              ),
              const SizedBox(height: 4),
              Text('类型', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _types.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _type == entry.key,
                      onSelected: (_) => setState(() => _type = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('每年重复'),
                subtitle: const Text('生日、纪念日会显示下一次日期'),
                value: _repeat == 'yearly',
                onChanged: (value) =>
                    setState(() => _repeat = value ? 'yearly' : 'none'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('置顶'),
                value: _pinned,
                onChanged: (value) => setState(() => _pinned = value),
              ),
              const SizedBox(height: 4),
              Text('颜色', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (final value in _colors)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _color = value),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _hexColor(value, scheme.primary),
                          shape: BoxShape.circle,
                          border: _color == value
                              ? Border.all(color: scheme.onSurface, width: 2)
                              : null,
                        ),
                        child: _color == value
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remark,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.initial == null ? '创建' : '保存'),
              ),
            ],
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
