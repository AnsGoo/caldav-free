import 'dart:math';

import 'package:drift/drift.dart' show DoUpdate, OrderingTerm;
import 'package:flutter/foundation.dart';

import '../../core/ids.dart';
import '../db/local_database.dart';
import 'focus_api.dart';
import 'focus_write_queue.dart';

/// Focus data as the app sees it: a SQLite mirror of the server's recent
/// sessions plus the cached preferences/stats and the queue of local records
/// not pushed yet.
///
/// Reads are synchronous and network-free, so the focus page renders its first
/// frame offline; the background sync pass calls [replaceMirror].
class FocusStore extends ChangeNotifier {
  FocusStore._(this._db, this._queue);

  static Future<FocusStore> open({
    AppDatabase? database,
    FocusWriteQueue? queue,
  }) async {
    final store = FocusStore._(
      database,
      queue ?? await FocusWriteQueue.shared(),
    );
    await store._ensureLoaded();
    return store;
  }

  /// Synchronous memory-only store for widget tests and offline boot.
  factory FocusStore.inMemory({FocusWriteQueue? queue}) {
    final store = FocusStore._(null, queue ?? FocusWriteQueue.inMemory());
    store._loaded = true;
    return store;
  }

  final AppDatabase? _db;
  final FocusWriteQueue _queue;

  /// Asked to schedule the background sync pass after a local write. Set by
  /// the app wiring; the store itself never touches the network.
  void Function()? onLocalWrite;

  List<FocusSession> _sessions = const [];
  FocusPreferences _preferences = const FocusPreferences();
  FocusStats _cached = const FocusStats();
  List<FocusPendingOp> _ops = const [];
  bool _loaded = false;
  Future<void>? _loading;

  /// Newest first, queued records included.
  List<FocusSession> get sessions => _overlay(_sessions);

  FocusPreferences get preferences => _preferences;

  /// Today's numbers come from the session rows (the mirror always holds the
  /// most recent hundred); totals are the last server aggregate, shifted by
  /// whatever is still queued.
  FocusStats get stats {
    final today = _startOfToday();
    var todaySeconds = 0;
    var todayPomodoros = 0;
    for (final session in sessions) {
      final started = session.startedAt;
      if (started == null || started.isBefore(today)) continue;
      todaySeconds += session.durationSeconds;
      todayPomodoros += session.pomodoroCount;
    }
    return FocusStats(
      todayPomodoroCount: todayPomodoros,
      todayFocusMinutes: (todaySeconds / 60).round(),
      todayFocusSeconds: todaySeconds,
      totalPomodoroCount: _cached.totalPomodoroCount,
      totalFocusMinutes: _cached.totalFocusMinutes,
      goal: _preferences.dailyGoal,
    );
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final running = _loading;
    if (running != null) return running;
    final task = _load();
    _loading = task;
    try {
      await task;
    } finally {
      _loading = null;
      _loaded = true;
    }
  }

  Future<void> _load() async {
    _ops = await _queue.items();
    final db = _db;
    if (db == null) return;
    final rows = await (db.select(
      db.focusSessions,
    )..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).get();
    _sessions = rows.map((row) => row.toModel()).toList(growable: false);
    final preferences = decodeJsonObject(
      await db.metaValue(focusPreferencesKey),
    );
    _preferences = preferences == null
        ? const FocusPreferences()
        : FocusPreferences.fromJson(preferences);
    final cached = decodeJsonObject(await db.metaValue(focusStatsKey));
    _cached = cached == null ? const FocusStats() : FocusStats.fromJson(cached);
  }

  // ------------------------------------------------------------- local writes

  Future<void> saveSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    String mode = 'pomodoro',
    String title = '专注',
    int pomodoroCount = 1,
  }) => _enqueue(
    FocusPendingOp(
      opId: newSyncId(),
      action: 'create',
      sessionId: _newTempId(),
      payload: {
        'mode': mode,
        'title': title,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'durationSeconds': durationSeconds,
        'pomodoroCount': pomodoroCount,
        'note': '',
      },
      createdAt: DateTime.now().toUtc(),
    ),
  );

  Future<void> deleteSession(int id) async {
    if (id < 0) {
      await _queue.cancelTemp(id);
      await _reloadOps();
      notifyListeners();
      return;
    }
    await _enqueue(
      FocusPendingOp(
        opId: newSyncId(),
        action: 'delete',
        sessionId: id,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _enqueue(FocusPendingOp op) async {
    await _queue.add(op);
    await _reloadOps();
    notifyListeners();
    onLocalWrite?.call();
  }

  Future<void> _reloadOps() async {
    _ops = await _queue.items();
  }

  // -------------------------------------------------------------- background

  /// Replaces the mirror with the server's snapshot. Called by the sync thread
  /// only; records still queued stay in the overlay.
  Future<void> replaceMirror(FocusDash server) async {
    _sessions = _sorted(server.sessions);
    _preferences = server.preferences;
    _cached = server.stats;
    await _reloadOps();
    final db = _db;
    if (db != null) {
      await db.transaction(() async {
        await db.delete(db.focusSessions).go();
        for (final session in _sessions) {
          final row = FocusSessionRow(
            id: session.id,
            title: session.title,
            mode: session.mode,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            durationSeconds: session.durationSeconds,
            pomodoroCount: session.pomodoroCount,
          );
          await db
              .into(db.focusSessions)
              .insert(row, onConflict: DoUpdate((_) => row));
        }
        await db.putMeta(
          focusPreferencesKey,
          encodeJsonObject(_preferences.toJson()),
        );
        await db.putMeta(focusStatsKey, encodeJsonObject(_cached.toJson()));
      });
    }
    notifyListeners();
  }

  /// Drops the cached server rows (connecting to a different account).
  Future<void> clearMirror() async {
    _sessions = const [];
    _preferences = const FocusPreferences();
    _cached = const FocusStats();
    final db = _db;
    if (db != null) {
      await db.transaction(() async {
        await db.delete(db.focusSessions).go();
        await db.deleteMeta(focusPreferencesKey);
        await db.deleteMeta(focusStatsKey);
      });
    }
    notifyListeners();
  }

  List<FocusSession> _overlay(List<FocusSession> base) {
    if (_ops.isEmpty) return base;
    final byId = <int, FocusSession>{
      for (final session in base)
        if (!session.id.isNegative) session.id: session,
    };
    for (final op in _ops) {
      switch (op.action) {
        case 'delete':
          byId.remove(op.sessionId);
        case 'create':
          final payload = op.payload;
          if (payload == null) continue;
          byId[op.sessionId] = optimisticSession(op.sessionId, payload);
        default:
          continue;
      }
    }
    return _sorted(byId.values);
  }

  static List<FocusSession> _sorted(Iterable<FocusSession> sessions) {
    final merged = sessions.toList(growable: false)
      ..sort((a, b) {
        final left = a.startedAt;
        final right = b.startedAt;
        if (left == null || right == null) return 0;
        return right.compareTo(left);
      });
    return merged;
  }

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static int _newTempId() =>
      -(DateTime.now().microsecondsSinceEpoch * 10 + _random.nextInt(10));

  static final _random = Random.secure();
}

extension FocusMirrorRow on FocusSession {
  FocusSessionRow toRow() => FocusSessionRow(
    id: id,
    title: title,
    mode: mode,
    startedAt: startedAt,
    endedAt: endedAt,
    durationSeconds: durationSeconds,
    pomodoroCount: pomodoroCount,
  );
}

extension FocusMirrorModel on FocusSessionRow {
  FocusSession toModel() => FocusSession(
    id: id,
    title: title,
    mode: mode,
    startedAt: startedAt,
    endedAt: endedAt,
    durationSeconds: durationSeconds,
    pomodoroCount: pomodoroCount,
  );
}

/// A session built from a queued payload, shown until the server row arrives.
FocusSession optimisticSession(int id, Map<String, dynamic> payload) =>
    FocusSession(
      id: id,
      title: (payload['title'] ?? '专注').toString(),
      mode: (payload['mode'] ?? 'pomodoro').toString(),
      startedAt: DateTime.tryParse(payload['startedAt']?.toString() ?? '')
          ?.toUtc(),
      endedAt: DateTime.tryParse(payload['endedAt']?.toString() ?? '')?.toUtc(),
      durationSeconds: payload['durationSeconds'] is num
          ? (payload['durationSeconds'] as num).toInt()
          : 0,
      pomodoroCount: payload['pomodoroCount'] is num
          ? (payload['pomodoroCount'] as num).toInt()
          : 0,
    );
