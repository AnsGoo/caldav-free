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
/// 通知上的快捷操作标识，点击后由 [NotificationGateway] 回传给上层。
abstract final class NotificationActionId {
  static const complete = 'complete';
  static const snooze = 'snooze';
}

/// 冷启动时被点击的那条通知。Android/iOS 在应用被系统杀掉后点通知（或通知
/// 上的按钮）拉起应用时，事件只会出现在 launch details 里，[actionId] 为空
/// 表示点的是通知本体，非空表示点的是某个按钮。
class NotificationLaunch {
  const NotificationLaunch({this.actionId, this.payload});

  final String? actionId;
  final String? payload;
}

abstract class NotificationGateway {
  /// [onTap] 处理点击通知本身；[onAction] 处理通知按钮（完成 / 稍后提醒），
  /// 参数依次是按钮标识和通知携带的 payload。
  Future<void> initialize({
    required void Function(String? payload) onTap,
    void Function(String? actionId, String? payload)? onAction,
  });

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

  /// 冷启动时被点击的通知（含按钮点击的 actionId）。
  ///
  /// Tapping a notification while the app is terminated does not fire
  /// [initialize]'s callback on iOS/Android — the tap is only visible here.
  Future<NotificationLaunch?> launchResponse();

  /// Opens the OS notification settings for this app. Returns false when the
  /// platform has no such entry point.
  Future<bool> openSystemSettings();

  /// Sets the app icon badge. 0 clears it. Platforms without a badge API
  /// (Android 8+) simply ignore the call — launchers derive the dot from
  /// notifications themselves.
  Future<void> setBadge(int count);

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

  /// 通知分类标识。Darwin 侧必须先注册分类，通知上才会出现按钮。
  static const _categoryId = 'caldav_reminder';

  /// iOS/macOS 的角标要写进应用本身（通知体里的 badge 只是“顺带设值”，
  /// 清不掉旧角标），所以走一个小 channel 直接改系统图标。
  static const _badgeChannel = MethodChannel('caldav_free/badge');

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
    void Function(String? actionId, String? payload)? onAction,
  }) async {
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('ic_notification');
    // iOS 和 macOS 共用 Darwin 配置，但 macOS 必须显式传给 macOS 字段：
    // 只传 iOS 字段时 macOS 侧拿不到初始化参数，插件不会注册通知。
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          _categoryId,
          actions: <DarwinNotificationAction>[
            // foreground：按钮点击时把应用带到前台，回调一定送达（否则应用被
            // 杀进程时按钮事件只会进后台 isolate，拿不到本地数据库）。
            DarwinNotificationAction.plain(
              NotificationActionId.complete,
              '完成',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              NotificationActionId.snooze,
              '稍后10分钟',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );
    final settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final actionId = response.actionId?.trim() ?? '';
        if (actionId.isEmpty) {
          // 点通知本体（而不是某个按钮）时才做跳转。
          onTap(response.payload);
          return;
        }
        if (onAction != null) {
          onAction(actionId, response.payload);
          return;
        }
        onTap(response.payload);
      },
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

  /// 当前角标数。排期和即时通知都会带上它，这样系统在投递时顺手把图标
  /// 角标设成最新值（iOS/macOS 的 badgeNumber、Android 的 number）。
  int _badge = 0;

  NotificationDetails _details() => NotificationDetails(
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
      number: _badge > 0 ? _badge : null,
      actions: <AndroidNotificationAction>[
        // showsUserInterface: false 会让按钮在后台 isolate 里执行，那里拿不到
        // 本地数据库，完不成任务；所以让它把应用带到前台再处理。
        const AndroidNotificationAction(
          NotificationActionId.complete,
          '完成',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          NotificationActionId.snooze,
          '稍后10分钟',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      categoryIdentifier: _categoryId,
      badgeNumber: _badge > 0 ? _badge : null,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      categoryIdentifier: _categoryId,
      badgeNumber: _badge > 0 ? _badge : null,
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
  Future<NotificationLaunch?> launchResponse() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || details.didNotificationLaunchApp != true) {
        return null;
      }
      final response = details.notificationResponse;
      if (response == null) return null;
      // 冷启动点按钮（例如「完成」）时 actionId 才有值；只取 payload 会让按钮
      // 退化成普通点击，任务不会被勾掉（Android 进程被回收后很常见）。
      final actionId = response.actionId?.trim() ?? '';
      return NotificationLaunch(
        actionId: actionId.isEmpty ? null : actionId,
        payload: response.payload,
      );
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
  Future<void> setBadge(int count) async {
    final value = count < 0 ? 0 : count;
    _badge = value;
    // Android 的角标由通知自带的 number 决定，没有可直接调用的系统接口。
    if (!Platform.isIOS && !Platform.isMacOS) return;
    try {
      await _badgeChannel.invokeMethod<void>('setBadge', <String, int>{
        'count': value,
      });
    } catch (error) {
      debugPrint('set app badge failed: $error');
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
    void Function(String? actionId, String? payload)? onAction,
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
  Future<NotificationLaunch?> launchResponse() async => null;

  @override
  Future<bool> openSystemSettings() async => false;

  @override
  Future<void> setBadge(int count) async {}

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
  // 鸿蒙暂时走 NoOp：flutter_local_notifications 没有 ohos 实现，
  // 直接调用会抛 MissingPluginException。P1 用 ArkTS 的
  // reminderAgentManager 写一个 NotificationGateway 实现接上即可
  // （接口已经隔离好，不需要改调度器）。
  return NoOpNotificationGateway();
}
