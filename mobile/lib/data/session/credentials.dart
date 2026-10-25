import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/ids.dart';
import '../storage_paths.dart';

class Session {
  const Session({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.deviceId,
  });

  final String baseUrl;
  final String username;
  final String password;
  final String deviceId;

  String get accountKey => '$baseUrl|$username';
}

/// P0 credential storage.
///
/// `flutter_secure_storage` could not be fetched in the current environment.
/// The file lives in the app's private support directory and is not readable
/// by other apps on Android, but it is still plaintext. Migrating to
/// Keystore/Keychain is part of the P1 security pass.
abstract class CredentialsStore {
  Future<Session?> load();
  Future<void> save(Session session);
  Future<void> clear();
  Future<String> deviceId();
}

class FileCredentialsStore implements CredentialsStore {
  FileCredentialsStore({String? path}) : _explicitPath = path;

  final String? _explicitPath;
  File? _file;
  Map<String, dynamic> _data = {};
  Future<void>? _loadFuture;

  Future<File> _resolveFile() async {
    final existing = _file;
    if (existing != null) return existing;
    final path = _explicitPath ??
        p.join((await appStorageDirectory()).path, 'credentials.json');
    return _file = File(path);
  }

  Future<void> _ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    final file = await _resolveFile();
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        _data = decoded;
      }
    } on FormatException {
      _data = {};
    }
  }

  @override
  Future<Session?> load() async {
    await _ensureLoaded();
    final baseUrl = _data['baseUrl']?.toString() ?? '';
    final username = _data['username']?.toString() ?? '';
    final password = _data['password']?.toString() ?? '';
    final deviceId = _data['deviceId']?.toString() ?? '';
    if (baseUrl.isEmpty || username.isEmpty || password.isEmpty) return null;
    if (deviceId.isEmpty) return null;
    return Session(
      baseUrl: baseUrl,
      username: username,
      password: password,
      deviceId: deviceId,
    );
  }

  @override
  Future<void> save(Session session) async {
    await _ensureLoaded();
    _data = {
      'baseUrl': session.baseUrl,
      'username': session.username,
      'password': session.password,
      'deviceId': session.deviceId,
    };
    await _write();
  }

  @override
  Future<void> clear() async {
    await _ensureLoaded();
    _data = {'deviceId': _data['deviceId'] ?? newSyncId()};
    await _write();
  }

  @override
  Future<String> deviceId() async {
    await _ensureLoaded();
    final existing = _data['deviceId']?.toString() ?? '';
    if (existing.isNotEmpty) return existing;
    final created = newSyncId();
    _data['deviceId'] = created;
    await _write();
    return created;
  }

  Future<void> _write() async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(_data), flush: true);
    await temp.rename(file.path);
  }
}

class MemoryCredentialsStore implements CredentialsStore {
  MemoryCredentialsStore({Session? storedSession, String? deviceId})
      : _session = storedSession,
        _deviceId = deviceId ?? newSyncId();

  Session? _session;
  String _deviceId;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<String> deviceId() async => _deviceId;

  @override
  Future<Session?> load() async => _session;

  @override
  Future<void> save(Session session) async {
    _session = session;
    _deviceId = session.deviceId;
  }
}
