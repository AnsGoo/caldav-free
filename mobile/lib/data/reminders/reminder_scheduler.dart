import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dart:io';

import '../../core/models.dart';
import '../countdowns/countdown_api.dart';
import '../countdowns/countdown_store.dart';
import '../db/local_store.dart';
import '../habits/habit_api.dart';
import '../habits/habit_store.dart';
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
    this.habits,
    this.countdowns,
    NotificationGateway? gateway,
  }) : _gateway = gateway ?? createDefaultGateway();

  final LocalStore store;
  final HabitStore? habits;
  final CountdownStore? countdowns;
  final NotificationGateway _gateway;

  StreamSubscription<List<TaskItem>>? _subscription;
  bool _listeningExtra = false;
  Timer? _debounce;
  bool _started = false;
  bool _refreshing = false;
  bool _again = false;
  bool _forceNext = false;
  String? _lastSignature;

  int scheduledCount = 0;
  String? lastError;

  /// null = 还没问过系统。
  bool? permissionGranted;

  Future<void> start({void Function(String? taskId)? onTap}) async {
    if (_started) return;
    _started = true;
    try {
      await _gateway.initialize(onTap: onTap ?? (_) {});
      permissionGranted = await _gateway.requestPermissions();
    } catch (error) {
      lastError = error.toString();
      debugPrint('reminder init failed: $error');
    }
    if (!_started) return;
    _subscription = store.watchAllTasks().listen((_) => _scheduleSoon());
    habits?.addListener(_onExtraChanged);
    countdowns?.addListener(_onExtraChanged);
    _listeningExtra = true;
    await _refresh();
  }

  void _onExtraChanged() => _scheduleSoon();

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
      final now = DateTime.now();
      final signature = _reminderSignature(tasks);
      if (!_forceNext && signature == _lastSignature) {
        return;
      }
      _forceNext = false;
      // iOS 只保留最早的 64 条待处理通知，留一点余量。
      final cap = Platform.isIOS ? 60 : 120;
      final merged = <ReminderPlanItem>[
        ...buildReminderPlan(tasks, now: now.toUtc(), max: cap),
        ...buildCountdownPlan(
          countdowns?.items ?? const <CountdownItem>[],
          now: now,
          max: cap,
        ),
        ...buildHabitPlan(
          habits?.snapshot.habits ?? const <HabitItem>[],
          now: now,
          max: cap,
        ),
      ]..sort((a, b) => a.at.compareTo(b.at));
      final plan = merged.length > cap ? merged.sublist(0, cap) : merged;
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
      rows.add(
        [
          task.id,
          task.title,
          task.dueAt!.toUtc().toIso8601String(),
          task.reminderOffsets.join(','),
          task.completed ? 'completed' : 'open',
          task.deleted ? 'deleted' : 'live',
        ].join('|'),
      );
    }
    for (final habit in habits?.snapshot.habits ?? const <HabitItem>[]) {
      if (habit.archived) continue;
      rows.add('habit:${habit.id}:${habit.reminders.join(",")}');
    }
    for (final item in countdowns?.items ?? const <CountdownItem>[]) {
      rows.add(
        'countdown:${item.id}:${item.occurrenceDate}:'
        '${item.reminders.join(",")}:${item.reminderTime}',
      );
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
  Future<bool> requestPermissions() async {
    final granted = await _gateway.requestPermissions();
    permissionGranted = granted;
    return granted;
  }

  Future<bool> exactAlarmsAllowed() => _gateway.exactAlarmsAllowed();

  /// Stops listening. Set [cancelAll] on logout so the previous account's
  /// reminders do not fire.
  Future<void> stop({bool cancelAll = false}) async {
    _started = false;
    _debounce?.cancel();
    // Do not await the cancellation: the subscription wraps an async*
    // generator over a broadcast stream, and awaiting it can block forever.
    // `_started` already gates any late event, so fire and forget is safe and
    // keeps logout responsive.
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel().catchError((Object _) {}));
    }
    if (_listeningExtra) {
      habits?.removeListener(_onExtraChanged);
      countdowns?.removeListener(_onExtraChanged);
      _listeningExtra = false;
    }
    _lastSignature = null;
    _forceNext = false;
    if (cancelAll) {
      try {
        await _gateway.cancelAll().timeout(const Duration(seconds: 2));
      } catch (error) {
        debugPrint('cancel reminders failed: $error');
      }
    }
    scheduledCount = 0;
  }
}
