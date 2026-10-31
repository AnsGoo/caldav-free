import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/ids.dart';
import '../../core/models.dart';
import '../../design/components.dart';
import '../../design/format.dart';

/// Summary editor mirroring the web panel: the generated Markdown is editable,
/// regenerated from the chosen filters, and templates stay on this device.
class SummaryPanel extends StatefulWidget {
  const SummaryPanel({super.key, required this.tasks, required this.lists});

  final List<TaskItem> tasks;
  final List<TaskListItem> lists;

  @override
  State<SummaryPanel> createState() => _SummaryPanelState();
}

enum _SummaryRange {
  today('今天'),
  tomorrow('明天'),
  yesterday('昨天'),
  week('本周'),
  nextWeek('下周'),
  lastWeek('上周'),
  month('本月'),
  lastMonth('上月'),
  custom('自定义');

  const _SummaryRange(this.label);
  final String label;
}

enum _SummaryGroup {
  status('按完成状态'),
  list('按清单'),
  priority('按优先级'),
  due('按任务时间');

  const _SummaryGroup(this.label);
  final String label;
}

class _SummaryFilter {
  const _SummaryFilter({
    this.range = _SummaryRange.week,
    this.customFrom,
    this.customTo,
    this.listId = '',
    this.status = 'all',
    this.priority = 0,
    this.tag = '',
    this.includeNext = false,
    this.group = _SummaryGroup.status,
    this.fields = const ['completedAt'],
  });

  final _SummaryRange range;
  final DateTime? customFrom;
  final DateTime? customTo;
  final String listId;
  final String status;
  final int priority;
  final String tag;
  final bool includeNext;
  final _SummaryGroup group;

  /// Which per-task fields the generated Markdown includes.
  final List<String> fields;

  _SummaryFilter copyWith({
    _SummaryRange? range,
    DateTime? customFrom,
    DateTime? customTo,
    String? listId,
    String? status,
    int? priority,
    String? tag,
    bool? includeNext,
    _SummaryGroup? group,
    List<String>? fields,
  }) => _SummaryFilter(
    range: range ?? this.range,
    customFrom: customFrom ?? this.customFrom,
    customTo: customTo ?? this.customTo,
    listId: listId ?? this.listId,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    tag: tag ?? this.tag,
    includeNext: includeNext ?? this.includeNext,
    group: group ?? this.group,
    fields: fields ?? this.fields,
  );
}

class _SummaryPanelState extends State<SummaryPanel> {
  _SummaryFilter _filter = const _SummaryFilter();
  String _markdown = '';

  @override
  void initState() {
    super.initState();
    _markdown = _buildMarkdown();
  }

  ({DateTime from, DateTime to}) _bounds(_SummaryFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const day = Duration(days: 1);
    DateTime weekStart(DateTime date) =>
        date.subtract(Duration(days: date.weekday - 1));
    switch (filter.range) {
      case _SummaryRange.today:
        return (from: today, to: today.add(day));
      case _SummaryRange.tomorrow:
        final start = today.add(day);
        return (from: start, to: start.add(day));
      case _SummaryRange.yesterday:
        return (from: today.subtract(day), to: today);
      case _SummaryRange.week:
        final start = weekStart(today);
        return (from: start, to: start.add(const Duration(days: 7)));
      case _SummaryRange.nextWeek:
        final start = weekStart(today).add(const Duration(days: 7));
        return (from: start, to: start.add(const Duration(days: 7)));
      case _SummaryRange.lastWeek:
        final start = weekStart(today).subtract(const Duration(days: 7));
        return (from: start, to: start.add(const Duration(days: 7)));
      case _SummaryRange.month:
        return (
          from: DateTime(today.year, today.month, 1),
          to: DateTime(today.year, today.month + 1, 1),
        );
      case _SummaryRange.lastMonth:
        return (
          from: DateTime(today.year, today.month - 1, 1),
          to: DateTime(today.year, today.month, 1),
        );
      case _SummaryRange.custom:
        final from = filter.customFrom ?? today;
        final to = filter.customTo ?? today;
        return (
          from: DateTime(from.year, from.month, from.day),
          to: DateTime(to.year, to.month, to.day).add(day),
        );
    }
  }

  bool _matchesFilter(TaskItem task, _SummaryFilter filter) {
    if (task.deleted || task.kind != TaskKind.task) return false;
    if (filter.listId.isNotEmpty && task.listId != filter.listId) return false;
    if (filter.priority > 0 && task.priority != filter.priority) return false;
    if (filter.tag.isNotEmpty && !task.tags.contains(filter.tag)) return false;
    return true;
  }

  ({List<TaskItem> done, List<TaskItem> open}) _collect(
    _SummaryFilter filter,
  ) {
    final bounds = _bounds(filter);
    final done = <TaskItem>[];
    final open = <TaskItem>[];
    for (final task in widget.tasks) {
      if (!_matchesFilter(task, filter)) continue;
      if (task.completed) {
        final at = task.completedAt?.toLocal();
        if (at != null && !at.isBefore(bounds.from) && at.isBefore(bounds.to)) {
          done.add(task);
        }
      } else {
        final due = task.dueAt?.toLocal() ?? task.createdAt?.toLocal();
        if (due != null &&
            !due.isBefore(bounds.from) &&
            due.isBefore(bounds.to)) {
          open.add(task);
        }
      }
    }
    done.sort(
      (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
        a.completedAt ?? a.updatedAt,
      ),
    );
    open.sort(
      (a, b) => (a.dueAt ?? a.updatedAt).compareTo(b.dueAt ?? b.updatedAt),
    );
    return (done: done, open: open);
  }

  List<TaskItem> _nextCycle(_SummaryFilter filter) {
    if (!filter.includeNext) return const [];
    final bounds = _bounds(filter);
    final span = bounds.to.difference(bounds.from);
    final out = <TaskItem>[];
    for (final task in widget.tasks) {
      if (!_matchesFilter(task, filter) || task.completed) continue;
      final due = task.dueAt?.toLocal();
      if (due == null) continue;
      if (!due.isBefore(bounds.to) && due.isBefore(bounds.to.add(span))) {
        out.add(task);
      }
    }
    out.sort((a, b) => (a.dueAt ?? a.updatedAt).compareTo(b.dueAt ?? b.updatedAt));
    return out;
  }

  Map<String, TaskListItem> get _listsById => {
    for (final list in widget.lists) list.id: list,
  };

  String _groupLabel(TaskItem task, _SummaryFilter filter) {
    switch (filter.group) {
      case _SummaryGroup.list:
        return _listsById[task.listId]?.name ?? '未分组';
      case _SummaryGroup.priority:
        return switch (task.priority) {
          3 => '高优先级',
          2 => '中优先级',
          1 => '低优先级',
          _ => '无优先级',
        };
      case _SummaryGroup.due:
        final due = task.dueAt?.toLocal();
        return due == null ? '无日期' : '${due.month} 月 ${due.day} 日';
      case _SummaryGroup.status:
        return task.completed ? '已完成' : '未完成';
    }
  }

  String _taskLine(TaskItem task) {
    final fields = _filter.fields;
    final parts = <String>[];
    final DateTime? when;
    if (task.completed) {
      when = fields.contains('completedAt') ? task.completedAt : null;
    } else {
      when = fields.contains('due') ? (task.dueAt ?? task.createdAt) : null;
    }
    if (when != null) {
      final local = when.toLocal();
      parts.add(
        '[${local.month}/${local.day}'
        '${task.allDay ? '' : ' ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}'}]',
      );
    }
    parts.add(task.title);
    if (fields.contains('tags') && task.tags.isNotEmpty) {
      parts.add('· ${task.tags.take(3).map((tag) => '#$tag').join(' ')}');
    }
    final list = _listsById[task.listId];
    if (fields.contains('list') && list != null) parts.add('· ${list.name}');
    if (fields.contains('priority') && task.priority > 0) {
      parts.add(
        '· ${switch (task.priority) { 3 => '高优先级', 2 => '中优先级', _ => '低优先级' }}',
      );
    }
    if (fields.contains('status')) {
      parts.add('· ${task.completed ? '已完成' : '未完成'}');
    }
    if (fields.contains('progress') && task.checklist.isNotEmpty) {
      final done = task.checklist.where((item) => item.done).length;
      parts.add('· 进度 $done/${task.checklist.length}');
    }
    if (fields.contains('details') && task.notes.trim().isNotEmpty) {
      parts.add('· ${task.notes.trim().replaceAll(RegExp(r'\s+'), ' ')}');
    }
    return '- [${task.completed ? 'x' : ' '}] ${parts.join(' ')}';
  }

  String _buildMarkdown() {
    final bounds = _bounds(_filter);
    final rows = _collect(_filter);
    final end = bounds.to.subtract(const Duration(days: 1));
    final lines = <String>[
      '## ${_filter.range.label}摘要',
      '',
      '${bounds.from.month} 月 ${bounds.from.day} 日 - ${end.month} 月 ${end.day} 日',
      '',
      '已完成 ${rows.done.length} 项 · 未完成 ${rows.open.length} 项',
      '',
    ];

    final tasks = <TaskItem>[...rows.done, ...rows.open];
    if (_filter.group == _SummaryGroup.status) {
      void addGroup(String label, List<TaskItem> items) {
        if (items.isEmpty) return;
        lines.addAll(['### $label', '']);
        for (final task in items) {
          lines.add(_taskLine(task));
        }
        lines.add('');
      }

      addGroup('已完成', rows.done);
      addGroup('未完成', rows.open);
    } else {
      final groups = <String, List<TaskItem>>{};
      for (final task in tasks) {
        (groups[_groupLabel(task, _filter)] ??= <TaskItem>[]).add(task);
      }
      for (final entry in groups.entries) {
        lines.addAll(['### ${entry.key}', '']);
        for (final task in entry.value) {
          lines.add(_taskLine(task));
        }
        lines.add('');
      }
    }

    final next = _nextCycle(_filter);
    if (next.isNotEmpty) {
      lines.addAll(['### 下一周期', '']);
      for (final task in next) {
        lines.add(_taskLine(task));
      }
      lines.add('');
    }
    if (rows.done.isEmpty && rows.open.isEmpty && next.isEmpty) {
      lines.add('当前范围内没有符合条件的任务');
    }
    return '${lines.join('\n').trim()}\n';
  }

  void _regenerate() {
    setState(() {
      _markdown = _buildMarkdown();
    });
    _showMessage('已按当前条件重新生成');
  }

  void _applyFilter(_SummaryFilter next) {
    setState(() {
      _filter = next;
      _markdown = _buildMarkdown();
    });
  }

  Future<void> _openSettings() async {
    final next = await showModalBottomSheet<_SummaryFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SummarySettingsSheet(
        filter: _filter,
        lists: widget.lists,
        tags: _tagOptions(),
      ),
    );
    if (next != null && mounted) _applyFilter(next);
  }

  List<String> _tagOptions() {
    final tags = <String>{};
    for (final task in widget.tasks) {
      if (task.deleted) continue;
      for (final tag in task.tags) {
        if (tag.trim().isNotEmpty) tags.add(tag.trim());
      }
    }
    return tags.toList()..sort();
  }

  Future<void> _saveTemplate() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SaveTemplateDialog(
        initial: '${_filter.range.label}摘要',
      ),
    );
    final value = (name ?? '').trim();
    if (value.isEmpty || !mounted) return;
    await context.read<AppState>().store.saveSummaryTemplate(
      SummaryTemplate(
        id: newSyncId(),
        name: value,
        range: _filter.range.name,
        content: _markdown,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    if (mounted) setState(() {});
    _showMessage('模板已保存到本机');
  }

  Future<void> _deleteTemplate(SummaryTemplate template) async {
    await context.read<AppState>().store.deleteSummaryTemplate(template.id);
    if (mounted) setState(() {});
  }

  Future<void> _loadTemplate(SummaryTemplate template) async {
    final name = template.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('套用模板「$name」？'),
        content: const Text('会用模板中的摘要内容覆盖当前编辑器。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('套用'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      final range = _SummaryRange.values.where(
        (item) => item.name == template.range,
      );
      if (range.isNotEmpty) _filter = _filter.copyWith(range: range.first);
      _markdown = template.content.trim().isNotEmpty
          ? template.content
          : _buildMarkdown();
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _markdown));
    _showMessage('摘要已复制');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Tablets/desktop keep the aside; phones (even landscape) always use the
    // bottom sheet and keep the filter panel hidden by default.
    final wide = MediaQuery.sizeOf(context).shortestSide >= 600;
    final editor = _buildEditor(context, wide);
    if (!wide) return editor;
    // The right filter panel is permanent on PC, like the web summary aside.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: editor),
        SizedBox(width: 286, child: _buildAside(context)),
      ],
    );
  }

  Widget _buildEditor(BuildContext context, bool wide) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final templates = context
        .read<AppState>()
        .store
        .summaryTemplatesSnapshot();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '摘要编辑器',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '重新生成',
                onPressed: _regenerate,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
              if (!wide)
                IconButton(
                  tooltip: '筛选与分组',
                  onPressed: _openSettings,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                ),
              IconButton(
                tooltip: '复制摘要',
                onPressed: _copy,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
              IconButton(
                tooltip: '保存为模板',
                onPressed: _saveTemplate,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              ),
            ],
          ),
        ),
        if (templates.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: templates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final template = templates[index];
                return InputChip(
                  label: Text(template.name),
                  onPressed: () => _loadTemplate(template),
                  onDeleted: () => _deleteTemplate(template),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelStyle: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: _MarkdownPreview(
                  markdown: _markdown,
                  listColors: {
                    for (final list in widget.lists)
                      list.name: colorFromHex(list.color),
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Wide layout keeps the filters in a right-hand aside, like the web panel.
  Widget _buildAside(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '摘要筛选',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: _SummarySettingsForm(
                filter: _filter,
                lists: widget.lists,
                tags: _tagOptions(),
                onChanged: _applyFilter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact list picker for the summary filters: a small bordered field that
/// opens a dropdown with each list's colour dot.
class _ListFilterDropdown extends StatelessWidget {
  const _ListFilterDropdown({
    required this.lists,
    required this.value,
    required this.onChanged,
  });

  final List<TaskListItem> lists;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    TaskListItem? current;
    for (final list in lists) {
      if (list.id == value) {
        current = list;
        break;
      }
    }
    return PopupMenuButton<String>(
      tooltip: '清单',
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: '',
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Expanded(child: Text('所有清单')),
              if (value.isEmpty)
                Icon(Icons.check_rounded, size: 16, color: scheme.primary),
            ],
          ),
        ),
        for (final list in lists)
          PopupMenuItem(
            value: list.id,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorFromHex(list.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (list.id == value)
                  Icon(Icons.check_rounded, size: 16, color: scheme.primary),
              ],
            ),
          ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            if (current != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorFromHex(current.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                current?.name ?? '所有清单',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact tag picker matching the list dropdown, with tag colours.
class _TagFilterDropdown extends StatelessWidget {
  const _TagFilterDropdown({
    required this.tags,
    required this.value,
    required this.onChanged,
  });

  final List<String> tags;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: '标签',
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: '',
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Expanded(child: Text('所有标签')),
              if (value.isEmpty)
                Icon(Icons.check_rounded, size: 16, color: scheme.primary),
            ],
          ),
        ),
        for (final tag in tags)
          PopupMenuItem(
            value: tag,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tagColorForName(tag),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '# $tag',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tag == value)
                  Icon(Icons.check_rounded, size: 16, color: scheme.primary),
              ],
            ),
          ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            if (value.isNotEmpty) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tagColorForName(value),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                value.isEmpty ? '所有标签' : '# $value',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only Markdown preview for the generated summary.
///
/// The generated subset is headings, checkbox bullets and `·` metadata, so a
/// focused renderer produces a cleaner result than dumping raw Markdown and
/// avoids pulling in a full parser dependency.
class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.markdown, required this.listColors});

  final String markdown;
  final Map<String, Color> listColors;

  static final _checkbox = RegExp(r'^- \[([ xX])\]\s?(.*)$');
  static final _datePrefix = RegExp(r'^\[([^\]]+)\]\s*(.*)$');
  static final _stats = RegExp(r'^已完成\s*(\d+)\s*项\s*·\s*未完成\s*(\d+)\s*项$');
  static final _dayRange = RegExp(r'^\d+\s*月\s*\d+\s*日\s*-\s*\d+\s*月\s*\d+\s*日$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <Widget>[];
    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 4));
        continue;
      }
      if (line.startsWith('## ')) {
        rows.add(
          Text(
            line.substring(3),
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('### ')) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  line.substring(4),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      final stats = _stats.firstMatch(line.trim());
      if (stats != null) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _PreviewPill(
                  label: '已完成 ${stats.group(1)}',
                  color: const Color(0xFF10B981),
                ),
                _PreviewPill(
                  label: '未完成 ${stats.group(2)}',
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        );
        continue;
      }
      if (_dayRange.hasMatch(line.trim())) {
        rows.add(
          Text(
            line.trim(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
        continue;
      }
      final checkbox = _checkbox.firstMatch(line);
      if (checkbox != null) {
        rows.add(
          _PreviewTaskRow(
            done: checkbox.group(1)!.toLowerCase() == 'x',
            body: checkbox.group(2) ?? '',
            listColors: listColors,
          ),
        );
        continue;
      }
      if (line.startsWith('- ')) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.substring(2),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      rows.add(
        Text(
          line,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12.5,
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PreviewTaskRow extends StatelessWidget {
  const _PreviewTaskRow({
    required this.done,
    required this.body,
    required this.listColors,
  });

  final bool done;
  final String body;
  final Map<String, Color> listColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final match = _MarkdownPreview._datePrefix.firstMatch(body);
    final date = match?.group(1);
    final rest = (match?.group(2) ?? body).trim();
    final parts = rest
        .split(' · ')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final title = parts.isEmpty ? rest : parts.first;
    final meta = parts.length > 1 ? parts.skip(1).toList(growable: false) : const <String>[];

    Color metaColor(String value) {
      final listColor = listColors[value];
      if (listColor != null) return listColor;
      if (value.startsWith('#')) return tagColorForName(value.substring(1).trim());
      if (value.contains('高优先级')) return const Color(0xFFE5484D);
      if (value.contains('中优先级')) return const Color(0xFFF76B15);
      if (value.contains('低优先级')) return const Color(0xFF3B82F6);
      return scheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 15,
              color: done ? scheme.primary : scheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (date != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: done ? scheme.onSurfaceVariant : null,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: scheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final item in meta)
                          if (listColors.containsKey(item))
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: listColors[item],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: listColors[item],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              item,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: metaColor(item),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySettingsSheet extends StatefulWidget {
  const _SummarySettingsSheet({
    required this.filter,
    required this.lists,
    required this.tags,
  });

  final _SummaryFilter filter;
  final List<TaskListItem> lists;
  final List<String> tags;

  @override
  State<_SummarySettingsSheet> createState() => _SummarySettingsSheetState();
}

class _SummarySettingsSheetState extends State<_SummarySettingsSheet> {
  late _SummaryFilter _draft = widget.filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '摘要筛选',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: const Text('应用'),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: _SummarySettingsForm(
                    filter: _draft,
                    lists: widget.lists,
                    tags: widget.tags,
                    onChanged: (next) => setState(() => _draft = next),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter controls shared by the narrow bottom sheet and the wide right aside.
class _SummarySettingsForm extends StatelessWidget {
  const _SummarySettingsForm({
    required this.filter,
    required this.lists,
    required this.tags,
    required this.onChanged,
  });

  final _SummaryFilter filter;
  final List<TaskListItem> lists;
  final List<String> tags;
  final ValueChanged<_SummaryFilter> onChanged;

  Future<void> _pickCustom(BuildContext context, {required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? filter.customFrom : filter.customTo) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    onChanged(
      from
          ? filter.copyWith(customFrom: picked)
          : filter.copyWith(customTo: picked),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4, top: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    labelStyle: const TextStyle(fontSize: 12),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(context, '日期'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final range in _SummaryRange.values)
              _chip(
                label: range.label,
                selected: filter.range == range,
                onTap: () => onChanged(filter.copyWith(range: range)),
              ),
          ],
        ),
        if (filter.range == _SummaryRange.custom) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: _dateButtonStyle,
                  onPressed: () => _pickCustom(context, from: true),
                  child: Text(
                    filter.customFrom == null
                        ? '开始日期'
                        : '${filter.customFrom!.month}/${filter.customFrom!.day}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: _dateButtonStyle,
                  onPressed: () => _pickCustom(context, from: false),
                  child: Text(
                    filter.customTo == null
                        ? '结束日期'
                        : '${filter.customTo!.month}/${filter.customTo!.day}',
                  ),
                ),
              ),
            ],
          ),
        ],
        if (lists.isNotEmpty) ...[
          _label(context, '清单'),
          _ListFilterDropdown(
            lists: lists,
            value: filter.listId,
            onChanged: (value) => onChanged(filter.copyWith(listId: value)),
          ),
        ],
        _label(context, '状态'),
        Wrap(
          spacing: 6,
          children: [
            for (final entry in const {
              'all': '所有状态',
              'open': '未完成',
              'completed': '已完成',
            }.entries)
              _chip(
                label: entry.value,
                selected: filter.status == entry.key,
                onTap: () => onChanged(filter.copyWith(status: entry.key)),
              ),
          ],
        ),
        _label(context, '优先级'),
        Wrap(
          spacing: 6,
          children: [
            for (final entry in const {
              0: '所有优先级',
              3: '高',
              2: '中',
              1: '低',
            }.entries)
              _chip(
                label: entry.value,
                selected: filter.priority == entry.key,
                onTap: () => onChanged(filter.copyWith(priority: entry.key)),
              ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          _label(context, '标签'),
          _TagFilterDropdown(
            tags: tags,
            value: filter.tag,
            onChanged: (value) => onChanged(filter.copyWith(tag: value)),
          ),
        ],
        _label(context, '分组'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final group in _SummaryGroup.values)
              _chip(
                label: group.label,
                selected: filter.group == group,
                onTap: () => onChanged(filter.copyWith(group: group)),
              ),
          ],
        ),
        _label(context, '显示内容'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in const {
              'completedAt': '完成时间',
              'due': '任务时间',
              'tags': '标签',
              'list': '所属清单',
              'priority': '优先级',
              'status': '状态',
              'progress': '进度',
              'details': '详细内容',
            }.entries)
              _chip(
                label: entry.value,
                selected: filter.fields.contains(entry.key),
                onTap: () {
                  final next = [...filter.fields];
                  if (!next.remove(entry.key)) next.add(entry.key);
                  onChanged(filter.copyWith(fields: next));
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '下一周期任务',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            AppSwitch(
              value: filter.includeNext,
              onChanged: (value) =>
                  onChanged(filter.copyWith(includeNext: value)),
            ),
          ],
        ),
      ],
    );
  }
}

ButtonStyle get _dateButtonStyle => OutlinedButton.styleFrom(
  minimumSize: const Size(0, 32),
  padding: const EdgeInsets.symmetric(horizontal: 8),
  visualDensity: VisualDensity.compact,
  textStyle: const TextStyle(fontSize: 12),
);

/// Owns its controller so disposal happens with the dialog route.
class _SaveTemplateDialog extends StatefulWidget {
  const _SaveTemplateDialog({required this.initial});

  final String initial;

  @override
  State<_SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<_SaveTemplateDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('保存为模板'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        decoration: const InputDecoration(
          isDense: true,
          labelText: '模板名称',
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}
