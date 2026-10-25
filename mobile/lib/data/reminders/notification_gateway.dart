import 'dart:async';

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

  /// Whether exact alarms are allowed (Android 12+). Older versions return
  /// true.
  Future<bool> exactAlarmsAllowed();

  /// Opens the system "Alarms & reminders" screen on Android 12+. Returns true
  /// on older Android or when already allowed.
  Future<bool> requestExactAlarmsPermission();

  Future<void> schedule(ReminderPlanItem item, {required bool exact});

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
    const settings = InitializationSettings(android: android);
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

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermissions() async {
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true;
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
    final details = NotificationDetails(
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
    );
    final scheduled = tz.TZDateTime.from(item.at.toUtc(), tz.UTC);
    try {
      await _plugin.zonedSchedule(
        id: item.id,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: '任务提醒',
        body: item.body,
        payload: item.taskId,
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
        title: '任务提醒',
        body: item.body,
        payload: item.taskId,
      );
    }
  }

  @override
  Future<void> cancelPending() => _plugin.cancelAllPendingNotifications();

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
