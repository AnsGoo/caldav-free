import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/local_store.dart';
import 'sync_engine.dart';

enum SyncPhase { idle, syncing, error }

/// Owns the periodic refresh, debounce for local writes, and the UI snapshot.
class SyncController extends ChangeNotifier {
  SyncController({required this.engine, required this.store});

  final SyncEngine engine;
  final LocalStore store;

  SyncPhase phase = SyncPhase.idle;
  String? error;
  DateTime? lastRunAt;
  int pending = 0;
  int failed = 0;
  int conflicts = 0;
  String cursor = '0';
  DateTime? lastSyncedAt;

  Timer? _periodic;
  Timer? _debounce;
  bool _started = false;
  bool _disposed = false;
  bool _rerun = false;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    refreshStats();
    await sync();
    if (_disposed) return;
    _periodic = Timer.periodic(
      const Duration(seconds: 15),
      (_) => sync(),
    );
  }

  void requestSync() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), sync);
  }

  Future<void> sync({bool full = false}) async {
    if (_disposed) return;
    if (phase == SyncPhase.syncing) {
      // A local write arrived while a request was in flight. Run once more
      // after the current pass instead of dropping the change until the next
      // periodic tick.
      _rerun = true;
      return;
    }
    phase = SyncPhase.syncing;
    error = null;
    _notify();
    try {
      final result = await engine.sync(full: full);
      lastRunAt = DateTime.now().toUtc();
      if (result.errors.isNotEmpty) {
        error = result.errors.first;
      }
    } catch (failure) {
      error = _friendlyError(failure);
    } finally {
      refreshStats();
      phase = error == null ? SyncPhase.idle : SyncPhase.error;
      _notify();
      if (_rerun && !_disposed) {
        _rerun = false;
        unawaited(sync());
      }
    }
  }

  void refreshStats() {
    pending = store.pendingCount;
    failed = store.failedCount;
    conflicts = store.conflictCount;
    cursor = store.cursor;
    lastSyncedAt = store.syncedAt;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _periodic?.cancel();
    _debounce?.cancel();
    engine.close();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _friendlyError(Object failure) {
    final text = failure.toString();
    if (text.contains('SocketException') ||
        text.contains('Connection') ||
        text.contains('timed out') ||
        text.contains('TimeoutException')) {
      return '网络不可用，修改已保存在本地';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
