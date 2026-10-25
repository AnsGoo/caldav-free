import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/focus/focus_api.dart';
import '../../design/format.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  late final FocusApi _api;
  FocusDash? _dash;
  bool _loading = false;
  String? _error;

  int _minutes = 25;
  int _remaining = 25 * 60;
  bool _running = false;
  DateTime? _startedAt;
  DateTime? _deadline;
  Timer? _ticker;

  static const _durations = [25, 45, 60];

  @override
  void initState() {
    super.initState();
    final session = context.read<AppState>().session!;
    _api = FocusApi(
      baseUrl: session.baseUrl,
      username: session.username,
      password: session.password,
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
      final dash = await _api.fetch();
      if (!mounted) return;
      setState(() {
        _dash = dash;
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

  void _setMinutes(int minutes) {
    if (_running) return;
    setState(() {
      _minutes = minutes;
      _remaining = minutes * 60;
    });
  }

  void _start() {
    if (_running) return;
    final now = DateTime.now();
    _startedAt ??= now;
    _deadline = now.add(Duration(seconds: _remaining));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() => _running = true);
  }

  void _pause() {
    if (!_running) return;
    _ticker?.cancel();
    final deadline = _deadline;
    if (deadline != null) {
      final left = deadline.difference(DateTime.now()).inSeconds;
      _remaining = left < 0 ? 0 : left;
    }
    setState(() => _running = false);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _startedAt = null;
      _deadline = null;
      _remaining = _minutes * 60;
    });
  }

  void _tick() {
    final deadline = _deadline;
    if (deadline == null) return;
    final left = deadline.difference(DateTime.now()).inSeconds;
    if (left <= 0) {
      _complete();
      return;
    }
    setState(() => _remaining = left);
  }

  Future<void> _complete() async {
    _ticker?.cancel();
    final started = _startedAt ?? DateTime.now();
    final ended = DateTime.now();
    final seconds = _minutes * 60;
    setState(() {
      _running = false;
      _remaining = _minutes * 60;
      _startedAt = null;
      _deadline = null;
    });
    try {
      await _api.saveSession(
        startedAt: started,
        endedAt: ended,
        durationSeconds: seconds,
      );
      await _load(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('专注完成，已记录 $_minutes 分钟')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存专注记录失败：$error')));
    }
  }

  Future<void> _deleteSession(FocusSession session) async {
    try {
      await _api.deleteSession(session.id);
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除记录失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dash = _dash;
    final total = _minutes * 60;
    final progress = total == 0
        ? 0.0
        : (1 - _remaining / total).clamp(0.0, 1.0);
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    return Scaffold(
      appBar: AppBar(
        title: const Text('专注'),
        actions: [
          IconButton(
            tooltip: '刷新专注',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Material(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                    TextButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          if (dash != null) _StatsRow(stats: dash.stats),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: scheme.primary,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$minutes:${seconds.toString().padLeft(2, '0')}',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _running ? '专注中' : '准备开始',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final value in _durations) ...[
                ChoiceChip(
                  label: Text('$value 分钟'),
                  selected: _minutes == value,
                  onSelected: _running ? null : (_) => _setMinutes(value),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _running ? _pause : _start,
                icon: Icon(
                  _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(_running ? '暂停' : '开始'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重置'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                '最近专注',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (dash != null)
                Text(
                  '累计 ${dash.stats.totalFocusMinutes} 分钟',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (dash == null || dash.sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '还没有专注记录',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final session in dash.sessions.take(8))
              _SessionTile(
                session: session,
                onDelete: () => _deleteSession(session),
              ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final FocusStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: '今日专注',
          value: '${stats.todayFocusMinutes} 分钟',
          icon: Icons.timer_outlined,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: '今日番茄',
          value: '${stats.todayPomodoroCount} / ${stats.goal}',
          icon: Icons.local_fire_department_outlined,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: '累计次数',
          value: '${stats.totalPomodoroCount}',
          icon: Icons.auto_awesome_outlined,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onDelete});

  final FocusSession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final started = session.startedAt?.toLocal();
    final minutes = (session.durationSeconds / 60).round();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.timer_rounded, size: 18, color: scheme.primary),
      ),
      title: Text(
        session.title.isEmpty ? '专注' : session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        started == null
            ? '$minutes 分钟'
            : '${relativeTime(session.startedAt)} · $minutes 分钟',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        tooltip: '删除记录',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
      ),
    );
  }
}
