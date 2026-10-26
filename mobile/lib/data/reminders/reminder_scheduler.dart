import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models.dart';
import '../db/local_store.dart';
import 'notification_gateway.dart';
import 'reminder_plan.dart';

/// Keeps Android's pending notification set in sync with local tasks.
///
/// The store is the source of truth: every sync page or local edit triggers a
/// debounced rebuild. Pending notifications are replaced atomically enough for
/// P1: cancel all pending (not displayed) notifications, then schedule the new
/// plan.
class ReminderScheduler {
  ReminderScheduler({
    required this.store,
    NotificationGateway? gateway,
  }) : _gateway = gateway ?? createDefaultGateway();

  final LocalStore store;
  final NotificationGateway _gateway;

  StreamSubscription<List<TaskItem>>? _subscription;
  Timer? _debounce;
  bool _started = false;
  bool _refreshing = false;
  bool _again = false;
  bool _forceNext = false;
  String? _lastSignature;

  int scheduledCount = 0;
  String? lastError;

  Future<void> start({void Function(String? taskId)? onTap}) async {
    if (_started) return;
    _started = true;
    try {
      await _gateway.initialize(onTap: onTap ?? (_) {});
      unawaited(_gateway.requestPermissions());
    } catch (error) {
      lastError = error.toString();
      debugPrint('reminder init failed: $error');
    }
    if (!_started) return;
    _subscription = store.watchAllTasks().listen((_) => _scheduleSoon());
    await _refresh();
  }

  void _scheduleSoon() {
    if (!_started) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _refresh);
  }

  Future<void> _refresh({bool force = false}) async {
    if (!_started) return;
    if (_refreshing) {
      _again = true;
      _forceNext = _forceNext || force;
      return;
    }
    if (force) _forceNext = true;
    _refreshing = true;
    try {
      final tasks = store.allTasks();
      final signature = _reminderSignature(tasks);
      if (!_forceNext && signature == _lastSignature) {
        return;
      }
      _forceNext = false;
      final plan = buildReminderPlan(
        tasks,
        now: DateTime.now().toUtc(),
      );
      await _gateway.cancelPending();
      final exact = await _gateway.exactAlarmsAllowed();
      var scheduled = 0;
      for (final item in plan) {
        try {
          await _gateway.schedule(item, exact: exact);
          scheduled++;
        } catch (error) {
          lastError = error.toString();
          debugPrint('schedule reminder failed: $error');
        }
      }
      _lastSignature = scheduled == plan.length ? signature : null;
      scheduledCount = scheduled;
      if (scheduled == plan.length) lastError = null;
    } catch (error) {
      lastError = error.toString();
      debugPrint('reminder refresh failed: $error');
    } finally {
      _refreshing = false;
      if (_again && _started) {
        _again = false;
        _scheduleSoon();
      }
    }
  }

  String _reminderSignature(List<TaskItem> tasks) {
    final rows = <String>[];
    for (final task in tasks) {
      if (task.kind != TaskKind.task ||
          task.reminderOffsets.isEmpty ||
          task.dueAt == null) {
        continue;
      }
      rows.add([
        task.id,
        task.title,
        task.dueAt!.toUtc().toIso8601String(),
        task.reminderOffsets.join(','),
        task.completed ? 'completed' : 'open',
        task.deleted ? 'deleted' : 'live',
      ].join('|'));
    }
    rows.sort();
    return rows.join('\n');
  }

  /// Forces a rebuild after the exact-alarm permission changed.
  Future<void> reschedule() => _refresh(force: true);

  /// Asks Android 12+ for exact-alarm permission and rebuilds the schedule if
  /// it was granted.
  Future<bool> ensureExactAlarms() async {
    if (await _gateway.exactAlarmsAllowed()) return true;
    final granted = await _gateway.requestExactAlarmsPermission();
    if (granted) await reschedule();
    return granted;
  }

  /// Requests the runtime notification permission (Android 13+).
  Future<bool> requestPermissions() => _gateway.requestPermissions();

  Future<bool> exactAlarmsAllowed() => _gateway.exactAlarmsAllowed();

  /// Stops listening. Set [cancelAll] on logout so the previous account's
  /// reminders do not fire.
  Future<void> stop({bool cancelAll = false}) async {
    _started = false;
    _debounce?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    _lastSignature = null;
    _forceNext = false;
    if (cancelAll) {
      try {
        await _gateway.cancelAll();
      } catch (error) {
        debugPrint('cancel reminders failed: $error');
      }
    }
    scheduledCount = 0;
  }
}
