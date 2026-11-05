import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// Abstraction over local notifications so the planner/scheduler can be tested
/// without a platform channel.
abstract class NotificationGateway {
  Future<void> initialize({required void Function(String? payload) onTap});

  /// Requests the Android 13+ notification permission. Older Android returns
  /// true without prompting.
  Future<bool> requestPermissions();

  /// Reads the current authorization without prompting. Returns null when the
  /// platform cannot report it. Used on resume so a permission granted in the
  /// system settings takes effect without restarting the app.
  Future<bool?> permissionStatus();

  /// Whether exact alarms are allowed (Android 12+). Older versions return
  /// true.
  Future<bool> exactAlarmsAllowed();

  /// Opens the system "Alarms & reminders" screen on Android 12+. Returns true
  /// on older Android or when already allowed.
  Future<bool> requestExactAlarmsPermission();

  Future<void> schedule(ReminderPlanItem item, {required bool exact});

  /// Fires a notification immediately, bypassing the OS scheduler. Used for the
  /// settings-page test and for the "missed reminders" digest.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// The payload of the notification that cold-started the app, if any.
  ///
  /// Tapping a notification while the app is terminated does not fire
  /// [initialize]'s callback on iOS/Android — the tap is only visible here.
  Future<String?> launchPayload();

  /// Opens the OS notification settings for this app. Returns false when the
  /// platform has no such entry point.
  Future<bool> openSystemSettings();

  /// Cancels pending (not yet delivered) notifications only.
  Future<void> cancelPending();

  /// Cancels pending and displayed notifications.
  Future<void> cancelAll();
}

class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _channelId = 'task_reminders';
  static const _channelName = '任务提醒';
  static const _channelDescription = '任务到期和自定义提醒';

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('ic_notification');
    // iOS 和 macOS 共用 Darwin 配置，但 macOS 必须显式传给 macOS 字段：
    // 只传 iOS 字段时 macOS 侧拿不到初始化参数，插件不会注册通知。
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  MacOSFlutterLocalNotificationsPlugin? get _macos => _plugin
      .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermissions() async {
    if (Platform.isMacOS) {
      final granted = await _macos?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? true;
    }
    if (Platform.isIOS) {
      final granted = await _ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? true;
    }
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true;
  }

  @override
  Future<bool?> permissionStatus() async {
    try {
      if (Platform.isMacOS) {
        final options = await _macos?.checkPermissions();
        return options?.isEnabled;
      }
      if (Platform.isIOS) {
        final options = await _ios?.checkPermissions();
        return options?.isEnabled;
      }
      return await _android?.areNotificationsEnabled();
    } catch (error) {
      debugPrint('read notification permission failed: $error');
      return null;
    }
  }

  @override
  Future<bool> exactAlarmsAllowed() async {
    final allowed = await _android?.canScheduleExactNotifications();
    return allowed ?? true;
  }

  @override
  Future<bool> requestExactAlarmsPermission() async {
    final granted = await _android?.requestExactAlarmsPermission();
    return granted ?? true;
  }

  @override
  Future<void> schedule(ReminderPlanItem item, {required bool exact}) async {
    final details = _details();
    final scheduled = tz.TZDateTime.from(item.at.toUtc(), tz.UTC);
    // 习惯是每天同一时间重复，其余提醒都是一次性。
    final repeat = item.repeat == ReminderRepeat.daily
        ? DateTimeComponents.time
        : null;
    try {
      await _plugin.zonedSchedule(
        id: item.id,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: item.title,
        body: item.body,
        payload: item.payload,
        matchDateTimeComponents: repeat,
      );
    } on PlatformException catch (error) {
      if (!exact ||
          !(error.code.contains('exact') ||
              error.message?.toLowerCase().contains('exact') == true)) {
        rethrow;
      }
      await _plugin.zonedSchedule(
        id: item.id,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: item.title,
        body: item.body,
        payload: item.payload,
        matchDateTimeComponents: repeat,
      );
    }
  }

  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      icon: 'ic_notification',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
  );

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: _details(),
    );
  }

  @override
  Future<String?> launchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || details.didNotificationLaunchApp != true) {
        return null;
      }
      return details.notificationResponse?.payload;
    } catch (error) {
      debugPrint('read notification launch details failed: $error');
      return null;
    }
  }

  @override
  Future<bool> openSystemSettings() async {
    try {
      final opened = await _plugin.openAppNotificationSettings();
      return opened ?? false;
    } catch (error) {
      debugPrint('open notification settings failed: $error');
      return false;
    }
  }

  @override
  Future<void> cancelPending() => _plugin.cancelAllPendingNotifications();

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

class NoOpNotificationGateway implements NotificationGateway {
  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool?> permissionStatus() async => null;

  @override
  Future<bool> exactAlarmsAllowed() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;

  @override
  Future<void> schedule(ReminderPlanItem item, {required bool exact}) async {}

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<bool> openSystemSettings() async => false;

  @override
  Future<void> cancelPending() async {}

  @override
  Future<void> cancelAll() async {}
}

NotificationGateway createDefaultGateway() {
  // macOS 同样支持本地通知：漏掉这里会让调度器走 NoOp 网关，
  // 排程数量照常增加但系统里一条都没注册（表现为「设置页显示已排程，
  // 到点却没有任何提醒」）。
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    return LocalNotificationGateway();
  }
  return NoOpNotificationGateway();
}
