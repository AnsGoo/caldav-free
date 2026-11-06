import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'notification_gateway.dart';
import 'reminder_plan.dart';

/// 鸿蒙原生通知实现，对端是
/// `ohos/entry/src/main/ets/notify/NotifyBridge.ets`。
///
/// 分工：
///   - [showNow] 走 `notificationManager.publish`，立即弹一条
///   - [schedule] 走 `reminderAgentManager`，由系统代理守着，应用退到后台
///     甚至被杀也能准点响
///
/// 暂时不支持的项：
///   - 通知上的「完成 / 稍后10分钟」按钮：鸿蒙的通知按钮要配
///     `actionButtons` + `WantAgent` 回调，还没接
///   - 冷启动点击回传（[launchResponse]）：需要 EntryAbility.onNewWant 把
///     want 参数转进通道，还没接
/// 这两项缺失时的表现是「点通知只会把应用拉到前台」，不影响提醒本身。
class OhosNotificationGateway implements NotificationGateway {
  OhosNotificationGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_kChannelName);

  static const String _kChannelName = 'caldav_free/notify';
  final MethodChannel _channel;

  /// 系统提醒（`reminderAgentManager`）不可用时的兜底定时器。
  ///
  /// 未签名 / 没有 provisioning profile 的包在系统里 `reminder_capability`
  /// 为空，`ReminderControl` 给它的提醒配额是 0，`publishReminder` 必抛
  /// 1700002。真机签名包不受影响，所以这里只在命中 1700002 时降级，
  /// 其它错误照旧上抛。
  final Map<int, Timer> _fallbackTimers = <int, Timer>{};

  /// 系统提醒是否已被判定为不可用。设置页据此提示"仅应用内有效"。
  bool nativeRemindersUnavailable = false;

  static bool _isQuotaError(PlatformException error) {
    final message = error.message ?? '';
    // 鸿蒙侧的 errText 会把 BusinessError 拼成 "code=1700002 message=..."
    return message.contains('1700002');
  }

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
    void Function(String? actionId, String? payload)? onAction,
  }) async {
    // 鸿蒙的通知点击由 want 参数带入应用，不走插件回调，这里没有要注册的东西。
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } on PlatformException catch (error) {
      // 用户在系统弹窗里点「不允许」时，鸿蒙侧可能直接抛错
      if (error.code != 'notify_publish') rethrow;
      return false;
    }
  }

  @override
  Future<bool?> permissionStatus() async {
    try {
      return await _channel.invokeMethod<bool>('permissionStatus');
    } catch (error) {
      return null;
    }
  }

  @override
  Future<bool> exactAlarmsAllowed() async {
    // 鸿蒙的 reminderAgentManager 本身就是精确提醒，没有 Android 那种
    // "精确闹钟" 单独授权，固定返回 true。
    return true;
  }

  @override
  Future<bool> requestExactAlarmsPermission() async => true;

  @override
  Future<void> schedule(ReminderPlanItem item, {required bool exact}) async {
    if (nativeRemindersUnavailable) {
      _armFallback(item);
      return;
    }
    try {
      await _channel.invokeMethod<void>('schedule', <String, Object?>{
        'id': item.id,
        'at': item.at.millisecondsSinceEpoch,
        'title': item.title,
        'body': item.body,
        'payload': item.payload,
        'repeatDaily': item.repeat == ReminderRepeat.daily,
      });
    } on PlatformException catch (error) {
      if (!_isQuotaError(error)) rethrow;
      // 配额为 0：以后不再白试系统提醒，直接走应用内定时。
      nativeRemindersUnavailable = true;
      debugPrint(
        'ohos reminder quota is 0, falling back to in-app timers: '
        '${error.message}',
      );
      _armFallback(item);
    }
  }

  /// 用 Dart 定时器在目标时刻弹一条即时通知。
  ///
  /// 局限：进程被系统回收后不会触发。它的价值是在未签名包上把"到点完全
  /// 不响"变成"应用活着就响"，签名包里永远不会走到这条路径。
  void _armFallback(ReminderPlanItem item) {
    _fallbackTimers.remove(item.id)?.cancel();
    final delay = item.at.difference(DateTime.now());
    if (delay.isNegative) return;
    _fallbackTimers[item.id] = Timer(delay, () {
      _fallbackTimers.remove(item.id);
      // 失败不抛：这里已经是兜底路径，再抛只会污染调度器的 lastError
      showNow(
        id: item.id,
        title: item.title,
        body: item.body,
        payload: item.payload,
      ).catchError((Object error) {
        debugPrint('ohos fallback notification failed: $error');
      });
    });
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _channel.invokeMethod<void>('showNow', <String, Object?>{
      'id': id,
      'title': title,
      'body': body,
      'payload': payload ?? '',
    });
  }

  @override
  Future<NotificationLaunch?> launchResponse() async => null;

  @override
  Future<bool> openSystemSettings() async {
    // 鸿蒙要跳到本应用的系统通知页需要 startAbility 一个设置 want，
    // 暂时不做，调用方会退回「请手动打开系统设置」。
    return false;
  }

  @override
  Future<void> setBadge(int count) async {
    // 鸿蒙没有桌面角标 API，通知栏数字由系统自己维护。
  }

  @override
  Future<void> cancelPending() async {
    // 兜底定时器必须一起撤，否则 cancelPending 之后还会弹旧提醒。
    for (final timer in _fallbackTimers.values) {
      timer.cancel();
    }
    _fallbackTimers.clear();
    try {
      await _channel.invokeMethod<void>('cancelPending');
    } on PlatformException {
      // 取消失败不该阻塞退出/重排流程
    }
  }

  @override
  Future<void> cancelAll() async {
    for (final timer in _fallbackTimers.values) {
      timer.cancel();
    }
    _fallbackTimers.clear();
    try {
      await _channel.invokeMethod<void>('cancelAll');
    } on PlatformException {
      // 同上
    }
  }
}
