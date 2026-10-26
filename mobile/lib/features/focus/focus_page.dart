import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/focus/focus_api.dart';
import '../../design/components.dart';
import '../../design/format.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  FocusApi? _api;
  FocusDash? _dash;
  bool _loading = false;
  String? _error;
  bool _connected = false;

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
    final session = context.read<AppState>().session;
    _connected = session != null;
    if (session != null) {
      _api = FocusApi(
        baseUrl: session.baseUrl,
        username: session.username,
        password: session.password,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final connected = context.watch<AppState>().connected;
    if (connected == _connected && _api != null) return;
    _connected = connected;
    _api?.close();
    final session = context.read<AppState>().session;
    _api = connected && session != null
        ? FocusApi(
            baseUrl: session.baseUrl,
            username: session.username,
            password: session.password,
          )
        : null;
    if (_api != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    } else if (mounted) {
      setState(() {
        _dash = null;
        _loading = false;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _api?.close();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (_api == null) return;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final dash = await _api!.fetch();
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
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    _startedAt ??= now;
    _deadline = now.add(Duration(seconds: _remaining));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() => _running = true);
  }

  void _pause() {
    if (!_running) return;
    HapticFeedback.selectionClick();
    _ticker?.cancel();
    final deadline = _deadline;
    if (deadline != null) {
      final left = deadline.difference(DateTime.now()).inSeconds;
      _remaining = left < 0 ? 0 : left;
    }
    setState(() => _running = false);
  }

  void _reset() {
    HapticFeedback.selectionClick();
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
    HapticFeedback.mediumImpact();
    final started = _startedAt ?? DateTime.now();
    final ended = DateTime.now();
    final seconds = _minutes * 60;
    setState(() {
      _running = false;
      _remaining = _minutes * 60;
      _startedAt = null;
      _deadline = null;
    });
    final api = _api;
    if (api == null) return;
    try {
      await api.saveSession(
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
      await _api!.deleteSession(session.id);
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除记录失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_api == null) {
      return const Scaffold(
        body: Center(
          child: AppEmptyState(
            icon: Icons.wifi_off_rounded,
            title: '服务未连接',
            message: '请先连接服务器后再使用专注功能',
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dash = _dash;
    final total = _minutes * 60;
    final progress = total == 0
        ? 0.0
        : (1 - _remaining / total).clamp(0.0, 1.0);
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    final stats = dash?.stats;
    final ringSize = (MediaQuery.sizeOf(context).width - 56).clamp(
      228.0,
      286.0,
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '专注',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 5),
            Text(
              stats == null
                  ? '把注意力留给当下'
                  : '今日 ${stats.todayFocusMinutes} 分钟 · '
                        '${stats.todayPomodoroCount}/${stats.goal} 番茄',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '刷新专注',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
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
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: ringSize,
              height: ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: progress,
                        track: scheme.surfaceContainerHighest,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$minutes:${seconds.toString().padLeft(2, '0')}',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: 58,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -2.4,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _running ? '专注中' : '准备开始',
                          key: ValueKey(_running),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final value in _durations) ...[
                _DurationPill(
                  minutes: value,
                  selected: _minutes == value,
                  enabled: !_running,
                  onTap: () => _setMinutes(value),
                ),
                if (value != _durations.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 148,
                child: FilledButton(
                  onPressed: _running ? _pause : _start,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                  child: Text(_running ? '暂停' : '开始'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: '重置计时',
                onPressed: _reset,
                style: IconButton.styleFrom(
                  minimumSize: const Size(42, 42),
                  maximumSize: const Size(42, 42),
                  backgroundColor: scheme.surface,
                  foregroundColor: scheme.onSurfaceVariant,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 36),
          AppSectionLabel(
            title: '最近专注',
            trailing: dash == null
                ? null
                : Text(
                    '累计 ${dash.stats.totalFocusMinutes} 分钟',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
          ),
          if (dash == null || dash.sessions.isEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 22),
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
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < dash.sessions.length && i < 8; i++) ...[
                    _SessionRow(
                      session: dash.sessions[i],
                      onDelete: () => _deleteSession(dash.sessions[i]),
                    ),
                    if (i != dash.sessions.length - 1 && i != 7)
                      Divider(
                        height: 1,
                        indent: 64,
                        endIndent: 16,
                        color: scheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 14) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, trackPaint);
    if (progress <= 0) return;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -1.5707963267948966,
      6.283185307179586 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.color != color;
}

class _DurationPill extends StatelessWidget {
  const _DurationPill({
    required this.minutes,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            '$minutes 分钟',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(
                      alpha: enabled ? 1 : 0.5,
                    ),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onDelete});

  final FocusSession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final minutes = (session.durationSeconds / 60).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.timer_rounded, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title.isEmpty ? '专注' : session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  session.startedAt == null
                      ? '$minutes 分钟'
                      : '${relativeTime(session.startedAt)} · $minutes 分钟',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '删除记录',
            onPressed: onDelete,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
