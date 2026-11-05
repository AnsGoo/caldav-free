import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// 鸿蒙（HarmonyOS / OpenHarmony）上 `Platform.operatingSystem` 的取值。
///
/// `dart:io` 的 `Platform.isAndroid` 等便捷 getter 里没有 ohos，
/// 只能用字符串比较，所以集中在这里判断一次。
bool get isOhosPlatform => Platform.operatingSystem == 'ohos';

/// Resolves the app-private directory used by the JSON store and credentials.
///
/// P0 deliberately avoids `path_provider`: its transitive iOS/macOS plugin
/// pulls in a native-assets build hook that requires Xcode, which blocks
/// `flutter test` on this machine. Android gets the real `filesDir` over a
/// tiny platform channel; desktop/test runs use `$HOME/.caldav_free`.
///
/// 鸿蒙复用同一套通道：`ohos/entry/src/main/ets/entryability/EntryAbility.ets`
/// 用 UIAbilityContext.filesDir 应答。通道没注册上时退到临时目录，
/// 保证应用能起来（代价是数据不持久）。
Future<Directory> appStorageDirectory() async {
  if (Platform.isAndroid || Platform.isIOS || isOhosPlatform) {
    try {
      const channel = MethodChannel('caldav_free/paths');
      final path = await channel.invokeMethod<String>('supportDirectory');
      if (path != null && path.isNotEmpty) {
        final directory = Directory(path);
        await directory.create(recursive: true);
        return directory;
      }
    } on MissingPluginException {
      // Fall through to a best-effort host directory.
    } on PlatformException {
      // Fall through to a best-effort host directory.
    }
  }
  if (isOhosPlatform) {
    // 鸿蒙沙箱里 HOME 不可靠，直接落在应用临时目录下。
    final directory = Directory(p.join(Directory.systemTemp.path, 'caldav_free'));
    await directory.create(recursive: true);
    return directory;
  }
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  final directory = home != null && home.isNotEmpty
      ? Directory(p.join(home, '.caldav_free'))
      : Directory(p.join(Directory.systemTemp.path, 'caldav_free'));
  await directory.create(recursive: true);
  return directory;
}
