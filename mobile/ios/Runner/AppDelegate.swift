import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pathsChannel: FlutterMethodChannel?
  private var badgeChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Local reminders must be visible while the app is in the foreground.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Mirrors the Android `caldav_free/paths` channel: resolve the sandbox
    // Application Support directory (Application Support does not exist by
    // default on iOS, so create it here).
    let channel = FlutterMethodChannel(
      name: "caldav_free/paths",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "supportDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let url = try FileManager.default.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        try FileManager.default.createDirectory(
          at: url,
          withIntermediateDirectories: true
        )
        result(url.path)
      } catch {
        result(
          FlutterError(
            code: "supportDirectory",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
    pathsChannel = channel

    // 应用角标：通知体里的 badge 只在投递时生效，用户读完要清零必须
    // 直接调系统接口，所以补一个 channel。
    let badge = FlutterMethodChannel(
      name: "caldav_free/badge",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    badge.setMethodCallHandler { call, result in
      guard call.method == "setBadge" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let count = arguments?["count"] as? Int ?? 0
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
      } else {
        DispatchQueue.main.async {
          UIApplication.shared.applicationIconBadgeNumber = count
        }
      }
      result(nil)
    }
    badgeChannel = badge
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
