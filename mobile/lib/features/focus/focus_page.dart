import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/focus/focus_api.dart';
import '../../data/focus/focus_store.dart';
import '../../design/components.dart';
import '../../design/format.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  FocusStore? _store;
  List<FocusSession> _sessions = const [];
  FocusStats _stats = const FocusStats();

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
    _attach(context.read<AppState>().focus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach(context.read<AppState>().focus);
  }

  /// The store is app-scoped and pushes mirror updates on its own; the page
  /// only repaints when it says the data changed.
  void _attach(FocusStore store) {
    if (identical(_store, store)) return;
    _store?.removeListener(_onStoreChanged);
    _store = store..addListener(_onStoreChanged);
    _sessions = store.sessions;
    _stats = store.stats;
  }

  void _onStoreChanged() {
    final store = _store;
    if (store == null || !mounted) return;
    setState(() {
      _sessions = store.sessions;
      _stats = store.stats;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _store?.removeListener(_onStoreChanged);
    super.dispose();
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
    final store = _store;
    if (store == null) return;
    try {
      await store.saveSession(
        startedAt: started,
        endedAt: ended,
        durationSeconds: seconds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('专注完成，已记录 $_minutes 分钟')));
    } catch (error, stack) {
      debugPrint('专注记录本地保存失败: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('专注记录保存失败，请稍后重试')));
    }
  }

  Future<void> _deleteSession(FocusSession session) async {
    try {
      await _store?.deleteSession(session.id);
    } catch (error, stack) {
      debugPrint('专注记录本地删除失败: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = _minutes * 60;
    final progress = total == 0
        ? 0.0
        : (1 - _remaining / total).clamp(0.0, 1.0);
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    final stats = _stats;
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
              '今日 ${stats.todayFocusMinutes} 分钟 · '
              '${stats.todayPomodoroCount}/${stats.goal} 番茄',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
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
            trailing: Text(
              '累计 ${stats.totalFocusMinutes} 分钟',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_sessions.isEmpty)
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
                  for (var i = 0; i < _sessions.length && i < 8; i++) ...[
                    _SessionRow(
                      session: _sessions[i],
                      onDelete: () => _deleteSession(_sessions[i]),
                    ),
                    if (i != _sessions.length - 1 && i != 7)
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
