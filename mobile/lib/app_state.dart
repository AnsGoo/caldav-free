import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/db/local_store.dart';
import 'data/engine/sync_controller.dart';
import 'data/engine/sync_engine.dart';
import 'data/remote/sync_api.dart';
import 'data/session/credentials.dart';
import 'data/tasks_repository.dart';

/// Application-scoped session + sync wiring. Kept as a ChangeNotifier so the
/// widget tree can rebuild on login/logout without a router dependency.
class AppState extends ChangeNotifier {
  AppState({
    required this.store,
    required this.credentials,
    required this.repository,
  });

  final LocalStore store;
  final CredentialsStore credentials;
  final TaskRepository repository;

  Session? session;
  SyncController? syncController;
  bool busy = false;
  String? error;

  VoidCallback? _syncListener;

  bool get signedIn => session != null;

  Future<void> restore() async {
    session = await credentials.load();
    if (session != null) {
      _wireSync();
    }
    notifyListeners();
  }

  Future<void> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final normalized = HttpSyncApi.normalizeBaseUrl(baseUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('服务器地址需要以 http:// 或 https:// 开头');
    }
    final user = username.trim();
    if (user.isEmpty || password.isEmpty) {
      throw const FormatException('请输入用户名和密码');
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      final probe = HttpSyncApi(
        baseUrl: normalized,
        username: user,
        password: password,
      );
      try {
        await probe.pull(since: '0', limit: 1);
      } finally {
        probe.close();
      }

      final deviceId = await credentials.deviceId();
      final previous = await credentials.load();
      if (previous == null ||
          previous.baseUrl != normalized ||
          previous.username != user) {
        await store.clearAll();
      }

      final next = Session(
        baseUrl: normalized,
        username: user,
        password: password,
        deviceId: deviceId,
      );
      await credentials.save(next);
      session = next;
      _wireSync();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _detachSync();
    syncController?.dispose();
    syncController = null;
    repository.onLocalChange = null;
    await store.clearAll();
    await credentials.clear();
    session = null;
    error = null;
    notifyListeners();
  }

  Future<void> syncNow({bool full = false}) async {
    await syncController?.sync(full: full);
  }

  void _wireSync() {
    _detachSync();
    syncController?.dispose();
    final current = session!;
    final engine = SyncEngine(
      store: store,
      api: HttpSyncApi(
        baseUrl: current.baseUrl,
        username: current.username,
        password: current.password,
      ),
      deviceId: current.deviceId,
    );
    final controller = SyncController(engine: engine, store: store);
    repository.onLocalChange = controller.requestSync;
    syncController = controller;
    _syncListener = notifyListeners;
    controller.addListener(_syncListener!);
    unawaited(controller.start());
  }

  void _detachSync() {
    final listener = _syncListener;
    if (listener != null) {
      syncController?.removeListener(listener);
      _syncListener = null;
    }
  }

  @override
  void dispose() {
    _detachSync();
    syncController?.dispose();
    super.dispose();
  }
}
