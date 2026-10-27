import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/countdowns/countdown_api.dart';
import 'data/countdowns/countdown_store.dart';
import 'data/db/local_store.dart';
import 'data/engine/sync_controller.dart';
import 'data/engine/sync_engine.dart';
import 'data/focus/focus_api.dart';
import 'data/focus/focus_store.dart';
import 'data/habits/habit_api.dart';
import 'data/habits/habit_store.dart';
import 'data/reminders/reminder_scheduler.dart';
import 'data/remote/sync_api.dart';
import 'data/session/credentials.dart';
import 'data/tasks_repository.dart';

/// Application-scoped session + sync wiring. Kept as a ChangeNotifier so the
/// widget tree can rebuild on connect/disconnect without a router dependency.
class AppState extends ChangeNotifier {
  AppState({
    required this.store,
    required this.credentials,
    required this.repository,
    HabitStore? habits,
    CountdownStore? countdowns,
    FocusStore? focus,
  }) : habits = habits ?? HabitStore.inMemory(),
       countdowns = countdowns ?? CountdownStore.inMemory(),
       focus = focus ?? FocusStore.inMemory();

  final LocalStore store;
  final CredentialsStore credentials;
  final TaskRepository repository;

  /// Habit, countdown and focus read mirrors. Pages render from these, never
  /// from the network; the sync thread fills them in the background.
  final HabitStore habits;
  final CountdownStore countdowns;
  final FocusStore focus;

  Session? session;
  SyncController? syncController;
  ReminderScheduler? reminders;
  bool busy = false;
  String? error;

  HabitApi? _habitApi;
  CountdownApi? _countdownApi;
  FocusApi? _focusApi;

  VoidCallback? _syncListener;

  bool get connected => session != null;

  String get accent => store.accent;

  Future<void> setAccent(String value) async {
    await store.setAccent(value);
    notifyListeners();
  }

  Future<void> restore() async {
    session = await credentials.load();
    if (session != null) {
      await _wireSync();
    } else {
      await _startOffline();
    }
    notifyListeners();
  }

  Future<void> _startOffline() async {
    final scheduler = ReminderScheduler(store: store);
    reminders = scheduler;
    unawaited(scheduler.start());
  }

  Future<void> connect({
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
        await habits.clearMirror();
        await countdowns.clearMirror();
        await focus.clearMirror();
      }

      final next = Session(
        baseUrl: normalized,
        username: user,
        password: password,
        deviceId: deviceId,
      );
      await credentials.save(next);
      session = next;
      await _wireSync();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _detachSync();
    syncController?.dispose();
    syncController = null;
    await reminders?.stop(cancelAll: true);
    reminders = null;
    repository.onLocalChange = null;
    await credentials.clear();
    session = null;
    error = null;
    await _startOffline();
    notifyListeners();
  }

  Future<void> syncNow({bool full = false}) async {
    await syncController?.sync(full: full);
  }

  Future<void> _wireSync() async {
    _detachSync();
    syncController?.dispose();
    final previousReminders = reminders;
    reminders = null;
    if (previousReminders != null) {
      await previousReminders.stop(cancelAll: true);
    }
    final current = session!;
    // Local-only write queues (habits, countdowns) are replayed here, in the
    // background sync pass. Pages never touch the network for writes.
    final habitApi = HabitApi(
      baseUrl: current.baseUrl,
      username: current.username,
      password: current.password,
    );
    final countdownApi = CountdownApi(
      baseUrl: current.baseUrl,
      username: current.username,
      password: current.password,
    );
    final focusApi = FocusApi(
      baseUrl: current.baseUrl,
      username: current.username,
      password: current.password,
    );
    _habitApi = habitApi;
    _countdownApi = countdownApi;
    _focusApi = focusApi;
    final engine = SyncEngine(
      store: store,
      api: HttpSyncApi(
        baseUrl: current.baseUrl,
        username: current.username,
        password: current.password,
      ),
      deviceId: current.deviceId,
      queueFlushers: [habitApi.flush, countdownApi.flush, focusApi.flush],
      mirrorPullers: [
        () async => habits.replaceMirror(await habitApi.fetch()),
        () async => countdowns.replaceMirror(await countdownApi.fetch()),
        () async => focus.replaceMirror(await focusApi.fetch()),
      ],
    );
    final controller = SyncController(engine: engine, store: store);
    repository.onLocalChange = controller.requestSync;
    habits.onLocalWrite = controller.requestSync;
    countdowns.onLocalWrite = controller.requestSync;
    focus.onLocalWrite = controller.requestSync;
    syncController = controller;
    _syncListener = notifyListeners;
    controller.addListener(_syncListener!);
    unawaited(controller.start());

    final scheduler = ReminderScheduler(store: store);
    reminders = scheduler;
    unawaited(scheduler.start());
  }

  void _detachSync() {
    final listener = _syncListener;
    if (listener != null) {
      syncController?.removeListener(listener);
      _syncListener = null;
    }
    habits.onLocalWrite = null;
    countdowns.onLocalWrite = null;
    focus.onLocalWrite = null;
    _habitApi?.close();
    _habitApi = null;
    _countdownApi?.close();
    _countdownApi = null;
    _focusApi?.close();
    _focusApi = null;
  }

  @override
  void dispose() {
    _detachSync();
    syncController?.dispose();
    unawaited(reminders?.stop());
    habits.dispose();
    countdowns.dispose();
    focus.dispose();
    super.dispose();
  }
}
