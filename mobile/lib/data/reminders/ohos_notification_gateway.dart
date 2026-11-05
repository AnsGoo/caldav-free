import 'dart:async';

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
    await _channel.invokeMethod<void>('schedule', <String, Object?>{
      'id': item.id,
      'at': item.at.millisecondsSinceEpoch,
      'title': item.title,
      'body': item.body,
      'payload': item.payload,
      'repeatDaily': item.repeat == ReminderRepeat.daily,
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
    try {
      await _channel.invokeMethod<void>('cancelPending');
    } on PlatformException {
      // 取消失败不该阻塞退出/重排流程
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod<void>('cancelAll');
    } on PlatformException {
      // 同上
    }
  }
}
