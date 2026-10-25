import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Resolves the app-private directory used by the JSON store and credentials.
///
/// P0 deliberately avoids `path_provider`: its transitive iOS/macOS plugin
/// pulls in a native-assets build hook that requires Xcode, which blocks
/// `flutter test` on this machine. Android gets the real `filesDir` over a
/// tiny platform channel; desktop/test runs use `$HOME/.caldav_free`.
Future<Directory> appStorageDirectory() async {
  if (Platform.isAndroid || Platform.isIOS) {
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
  final home = Platform.environment['HOME'];
  final directory = home != null && home.isNotEmpty
      ? Directory(p.join(home, '.caldav_free'))
      : Directory(p.join(Directory.systemTemp.path, 'caldav_free'));
  await directory.create(recursive: true);
  return directory;
}
