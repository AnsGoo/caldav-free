import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ui_utils.dart';
import '../../data/calendar/calendar_api.dart';
import '../../design/format.dart';

/// Opens the iCal subscription manager used by the settings page.
Future<void> showCalendarSubscriptionSheet(
  BuildContext context,
  CalendarApi api,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.72,
      child: CalendarSubscriptionSheet(api: api),
    ),
  );
}

class CalendarSubscriptionSheet extends StatefulWidget {
  const CalendarSubscriptionSheet({super.key, required this.api});

  final CalendarApi api;

  @override
  State<CalendarSubscriptionSheet> createState() =>
      CalendarSubscriptionSheetState();
}

class CalendarSubscriptionSheetState extends State<CalendarSubscriptionSheet> {
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
