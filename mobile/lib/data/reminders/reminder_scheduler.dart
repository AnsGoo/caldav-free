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

  static const _heartbeatKey = 'reminder.heartbeat';
  static const _scheduledSlotsKey = 'reminder.scheduled_slots';
  static const _missedNotificationId = 990002;

  /// 上次进程还活着的时间点。启动时读出来，用来界定「应用不在运行时」到点
  /// 的那些提醒。
  DateTime? _resumeSince;

  /// 上次进程退出前已经排进系统队列的通知槽位（`id@触发时刻`）。
  ///
  /// 这些提醒到点后系统会正常投递，补发时必须排除，否则用户会同时收到系统
  /// 通知和「错过的提醒」汇总。只在 start 时读一次并留在内存里，后续
  /// [_refresh] 覆盖的是数据库里的值，不影响本次启动的判定。
  Set<String> _scheduledBeforeExit = <String>{};

  DateTime? _heartbeatAt;
  bool _missedChecked = false;
  final Set<int> _notifiedMissed = <int>{};
  Timer? _heartbeatTimer;

  /// 用户点“稍后10分钟”后排期的一次性提醒。它们不在任务的提醒偏移里，
  /// 但每次重建计划都必须带上，否则下一轮 cancelPending 会把它清掉。
  final Map<int, ReminderPlanItem> _snoozes = <int, ReminderPlanItem>{};

  Future<void> start({
    void Function(String? taskId)? onTap,
    void Function(String? actionId, String? payload)? onAction,
  }) async {
    if (_started) return;
    _started = true;
    final tap = onTap ?? (_) {};
    try {
      await _gateway.initialize(onTap: tap, onAction: onAction);
      permissionGranted = await _gateway.requestPermissions();
      // 冷启动（应用是被点击通知拉起的）时，点击事件不会走 initialize 的
      // 回调，只在 launch details 里。
      final launch = await _gateway.launchPayload();
      if (launch != null && launch.trim().isNotEmpty) tap(launch);
    } catch (error) {
      lastError = error.toString();
      debugPrint('reminder init failed: $error');
    }
    if (!_started) return;
    _resumeSince = await _readHeartbeat();
    _scheduledBeforeExit = await _readScheduledSlots();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _writeHeartbeat(DateTime.now());
    });
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
      // 只在本次启动的头一次刷新里补发，之后应用一直活着，到点的提醒由系统
      // 正常投递，不再算「错过」。
      if (!_missedChecked) {
        _missedChecked = true;
        await _notifyMissed(tasks, now);
      }
      await _writeHeartbeat(now);
      final signature = _reminderSignature(tasks);
      if (!_forceNext && signature == _lastSignature) {
        return;
      }
      _forceNext = false;
      // iOS 只保留最早的 64 条待处理通知，留一点余量。
      final cap = Platform.isIOS ? 60 : 120;
      _snoozes.removeWhere((_, item) => !item.at.isAfter(now));
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
        ..._snoozes.values,
      ]..sort((a, b) => a.at.compareTo(b.at));
      final plan = merged.length > cap ? merged.sublist(0, cap) : merged;
      // 角标跟着待办数走，和通知一起更新。
      await _gateway.setBadge(badgeCount(tasks, now: now));
      await _gateway.cancelPending();
      final exact = await _gateway.exactAlarmsAllowed();
      var scheduled = 0;
      final slots = <String>[];
      for (final item in plan) {
        try {
          await _gateway.schedule(item, exact: exact);
          scheduled++;
          // 习惯是每天重复的，补发逻辑本来就排除它们，不必进快照。
          if (item.repeat == ReminderRepeat.none) {
            slots.add(reminderSlotKey(item));
          }
        } catch (error) {
          lastError = error.toString();
          debugPrint('schedule reminder failed: $error');
        }
      }
      _lastSignature = scheduled == plan.length ? signature : null;
      scheduledCount = scheduled;
      if (scheduled == plan.length) lastError = null;
      // 记下这一轮实际排进系统队列的通知，供下次启动判断哪些已经送达。
      await _writeScheduledSlots(slots);
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
  ///
  /// 拒绝过之后系统不会再弹授权框，这里也只返回当前状态，由设置页引导用户
  /// 去系统设置重新开启，避免每次启动都去骚扰一遍。
  Future<bool> requestPermissions() async {
    if (permissionGranted == false) {
      final current = await permissionStatus();
      if (current == false) return false;
    }
    final granted = await _gateway.requestPermissions();
    permissionGranted = granted;
    return granted;
  }

  /// Reads the OS authorization without prompting and refreshes the cached
  /// state. Returns null when the platform cannot report it.
  Future<bool?> permissionStatus() async {
    final status = await _gateway.permissionStatus();
    if (status != null) permissionGranted = status;
    return status;
  }

  /// Called when the app returns to the foreground. Picks up a permission the
  /// user may have granted in the system settings while we were away and
  /// rebuilds the plan so pending reminders start firing again.
  /// Returns true when notifications became available just now.
  Future<bool> refreshPermissionAfterResume() async {
    final previous = permissionGranted;
    final status = await permissionStatus();
    if (status == null) return false;
    if (status && previous != true) {
      // 权限刚打开：之前因为没权限而没送达的提醒，这时候可以补一次汇总。
      // 权限关闭期间系统不可能投递，所以「已排期」在这里不代表「已送达」，
      // 清掉快照才能把这段时间的提醒补回来。
      _missedChecked = false;
      _scheduledBeforeExit = <String>{};
      await reschedule();
      return true;
    }
    return false;
  }

  /// Sends an immediate notification. Useful for verifying that the OS really
  /// delivers notifications instead of trusting the scheduled count.
  Future<bool> sendTestNotification() async {
    try {
      await _gateway.showNow(
        id: _missedNotificationId + 1,
        title: '通知测试',
        body: '看到这条说明系统通知已正常工作。',
      );
      lastError = null;
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }

  Future<bool> openSystemNotificationSettings() => _gateway.openSystemSettings();

  /// 「稍后10分钟」：按 payload 找回提醒内容，重新排一条一次性通知。
  ///
  /// 排好的通知会记在 [_snoozes] 里，后续重建计划时一并带上，否则下一轮
  /// cancelPending 会把它取消掉。
  Future<bool> snooze(String? payload, {int minutes = 10}) async {
    final value = payload?.trim() ?? '';
    if (value.isEmpty || minutes <= 0) return false;
    final content = _snoozeContent(value);
    if (content == null) return false;
    final at = DateTime.now().add(Duration(minutes: minutes));
    final id = reminderNotificationId(
      'snooze:$value:${at.millisecondsSinceEpoch}',
    );
    final item = ReminderPlanItem(
      id: id,
      payload: value,
      title: content.$1,
      body: content.$2,
      at: at,
    );
    _snoozes[id] = item;
    try {
      final exact = await _gateway.exactAlarmsAllowed();
      await _gateway.schedule(item, exact: exact);
      lastError = null;
      return true;
    } catch (error) {
      _snoozes.remove(id);
      lastError = error.toString();
      debugPrint('snooze reminder failed: $error');
      return false;
    }
  }

  (String, String)? _snoozeContent(String payload) {
    if (payload.startsWith('task:')) {
      final id = payload.substring('task:'.length).trim();
      for (final task in store.allTasks()) {
        if (task.id == id) return ('任务提醒', task.title);
      }
      return null;
    }
    if (payload.startsWith('habit:')) {
      final id = int.tryParse(payload.substring('habit:'.length).trim());
      if (id == null) return null;
      for (final habit in habits?.snapshot.habits ?? const <HabitItem>[]) {
        if (habit.id == id) return ('习惯提醒', '${habit.name} 今天还没有打卡');
      }
      return null;
    }
    if (payload.startsWith('countdown:')) {
      final id = int.tryParse(payload.substring('countdown:'.length).trim());
      if (id == null) return null;
      for (final item in countdowns?.items ?? const <CountdownItem>[]) {
        if (item.id == id) return ('倒数日提醒', '「${item.name}」');
      }
      return null;
    }
    return null;
  }

  /// 重新按当前待办数刷新图标角标，不重建排期。
  Future<void> refreshBadge() async {
    try {
      await _gateway.setBadge(badgeCount(store.allTasks(), now: DateTime.now()));
    } catch (error) {
      debugPrint('refresh badge failed: $error');
    }
  }

  Future<bool> exactAlarmsAllowed() => _gateway.exactAlarmsAllowed();

  /// 把上次应用不在运行期间到点、没能送达的提醒合成一条即时通知。
  ///
  /// 只补最近一个心跳窗口，且每个提醒在一个进程生命周期内只补一次，避免
  /// 数据反复变更时重复弹。
  Future<void> _notifyMissed(Iterable<TaskItem> tasks, DateTime now) async {
    final since = _resumeSince;
    if (since == null || permissionGranted == false) return;
    final missed = buildMissedPlan(
      tasks,
      countdowns?.items ?? const <CountdownItem>[],
      now: now,
      since: since,
      alreadyScheduled: _scheduledBeforeExit,
    ).where((item) => !_notifiedMissed.contains(item.id)).toList();
    if (missed.isEmpty) return;
    for (final item in missed) {
      _notifiedMissed.add(item.id);
    }
    missed.sort((a, b) => a.at.compareTo(b.at));
    final first = missed.first;
    final at = first.at.toLocal();
    final clock =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final body = missed.length == 1
        ? '${first.body}（$clock）'
        : '${missed.length} 条提醒未送达，最早：${first.body}（$clock）';
    try {
      await _gateway.showNow(
        id: _missedNotificationId,
        title: '错过的提醒',
        body: body,
        payload: 'missed',
      );
    } catch (error) {
      lastError = error.toString();
      debugPrint('missed reminder digest failed: $error');
    }
  }

  Future<DateTime?> _readHeartbeat() async {
    try {
      final raw = await store.metaValue(_heartbeatKey);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    } catch (error) {
      debugPrint('read reminder heartbeat failed: $error');
      return null;
    }
  }

  Future<void> _writeHeartbeat(DateTime now) async {
    final last = _heartbeatAt;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _heartbeatAt = now;
    try {
      await store.putMeta(_heartbeatKey, now.toUtc().toIso8601String());
    } catch (error) {
      debugPrint('write reminder heartbeat failed: $error');
    }
  }

  Future<Set<String>> _readScheduledSlots() async {
    try {
      final raw = await store.metaValue(_scheduledSlotsKey);
      if (raw == null || raw.isEmpty) return <String>{};
      return raw
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('read scheduled reminder slots failed: $error');
      return <String>{};
    }
  }

  Future<void> _writeScheduledSlots(Iterable<String> slots) async {
    try {
      await store.putMeta(_scheduledSlotsKey, slots.join('\n'));
    } catch (error) {
      debugPrint('write scheduled reminder slots failed: $error');
    }
  }

  /// Stops listening. Set [cancelAll] on logout so the previous account's
  /// reminders do not fire.
  Future<void> stop({bool cancelAll = false}) async {
    _started = false;
    _debounce?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
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
    _resumeSince = null;
    _scheduledBeforeExit = <String>{};
    _heartbeatAt = null;
    _missedChecked = false;
    _notifiedMissed.clear();
    _snoozes.clear();
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
