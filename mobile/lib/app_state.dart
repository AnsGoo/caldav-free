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

/// Creates the sync transport for one account. Tests inject a fake so login
/// and wiring can be exercised without a network.
typedef SyncApiFactory = SyncApi Function({
  required String baseUrl,
  required String username,
  required String password,
});

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
    SyncApiFactory? apiFactory,
  }) : habits = habits ?? HabitStore.inMemory(),
       countdowns = countdowns ?? CountdownStore.inMemory(),
       focus = focus ?? FocusStore.inMemory(),
       apiFactory = apiFactory ?? _httpSyncApi;

  static SyncApi _httpSyncApi({
    required String baseUrl,
    required String username,
    required String password,
  }) => HttpSyncApi(baseUrl: baseUrl, username: username, password: password);

  final LocalStore store;
  final CredentialsStore credentials;
  final TaskRepository repository;
  final SyncApiFactory apiFactory;

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
      await _wireSync(session!);
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
    if (busy) {
      throw SyncApiException('正在连接服务器，请稍候');
    }
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
    var credentialsSaved = false;
    try {
      final probe = apiFactory(
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
      // Set the flag before writing: a partially written file must still be
      // rolled back if the write throws.
      credentialsSaved = true;
      await credentials.save(next);
      // Wire sync before publishing the session. Otherwise a wiring failure
      // leaves the UI showing "已连接" while nothing ever syncs.
      await _wireSync(next);
      session = next;
    } catch (error) {
      if (credentialsSaved && session == null) {
        await _rollbackFailedConnect();
      }
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Best-effort cleanup when credentials were written but the session could
  /// not be wired. Keeps the device id (logout semantics) so retrying does not
  /// create a new device identity.
  Future<void> _rollbackFailedConnect() async {
    try {
      _detachSync();
      syncController?.dispose();
      syncController = null;
      final scheduler = reminders;
      reminders = null;
      await scheduler
          ?.stop(cancelAll: true)
          .timeout(const Duration(seconds: 2));
    } catch (error) {
      debugPrint('rollback failed login sync failed: $error');
    }
    try {
      await credentials.clear().timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('rollback failed login credentials failed: $error');
      try {
        await credentials.invalidate();
      } catch (invalidateError) {
        debugPrint('invalidate credentials failed: $invalidateError');
      }
    }
  }

  Future<void> disconnect() async {
    final previousReminders = reminders;
    final previousController = syncController;
    reminders = null;
    syncController = null;
    repository.onLocalChange = null;

    // Leave the connected state before any I/O. Cancelling notifications or
    // rewriting credentials can block on a platform channel, and the logout
    // button must still respond immediately in that case.
    session = null;
    error = null;
    notifyListeners();

    try {
      _detachSync();
      previousController?.dispose();
    } catch (error) {
      debugPrint('detach sync on logout failed: $error');
    }

    // Reminder cancellation is best-effort: a platform failure must not leave
    // the client looking signed in.
    try {
      await previousReminders
          ?.stop(cancelAll: true)
          .timeout(const Duration(seconds: 2));
    } on TimeoutException catch (error) {
      debugPrint('cancel reminders on logout timed out: $error');
    } catch (error) {
      debugPrint('cancel reminders on logout failed: $error');
    }

    try {
      await _startOffline();
    } catch (error) {
      debugPrint('start offline reminders after logout failed: $error');
    }
    notifyListeners();

    // Persisted credentials must go, otherwise the next launch signs straight
    // back in. If the normal atomic rewrite hangs or fails, delete the file.
    try {
      await credentials.clear().timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('clear credentials failed: $error');
      await credentials.invalidate();
      rethrow;
    }
  }

  Future<void> syncNow({bool full = false}) async {
    await syncController?.sync(full: full);
  }

  Future<void> _wireSync(Session current) async {
    _detachSync();
    syncController?.dispose();
    syncController = null;
    final previousReminders = reminders;
    reminders = null;
    if (previousReminders != null) {
      // Cancelling platform notifications can block on a channel; the login
      // sheet must never wait on it forever.
      try {
        await previousReminders
            .stop(cancelAll: true)
            .timeout(const Duration(seconds: 3));
      } on TimeoutException catch (error) {
        debugPrint('stop offline reminders before connect timed out: $error');
      } catch (error) {
        debugPrint('stop offline reminders before connect failed: $error');
      }
    }
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
      api: apiFactory(
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
