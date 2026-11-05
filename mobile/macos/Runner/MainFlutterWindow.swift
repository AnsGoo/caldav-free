import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// 必须持有引用，否则 channel 释放后 Dart 侧调用会一直无响应。
  private var badgeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 应用角标：Dart 侧只有通知体里的 badgeNumber，清不掉旧角标，
    // 所以直接改 Dock 图标上的标签。
    let channel = FlutterMethodChannel(
      name: "caldav_free/badge",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setBadge" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let count = arguments?["count"] as? Int ?? 0
      NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
      result(nil)
    }
    badgeChannel = channel

    super.awakeFromNib()
  }
}
