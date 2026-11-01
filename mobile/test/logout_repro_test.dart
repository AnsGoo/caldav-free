import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/features/home/home_shell.dart';
import 'package:caldav_free/features/tasks/tasks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _session = Session(
  baseUrl: 'http://example.test',
  username: 'demo',
  password: 'secret',
  deviceId: 'device-test',
);

Future<void> _stopReminders(AppState app) async {
  await app.reminders?.stop(cancelAll: true);
}

void main() {
  test('disconnect leaves the account even when credential storage throws',
      () async {
    final store = LocalStore.memory();
    final credentials = _ThrowingCredentialsStore(storedSession: _session);
    final app = AppState(
      store: store,
      credentials: credentials,
      repository: TaskRepository(store),
    )..session = _session;
    addTearDown(() async {
      await _stopReminders(app);
      app.dispose();
      await store.dispose();
    });

    await expectLater(app.disconnect(), throwsStateError);

    expect(app.session, isNull);
    expect(credentials.invalidated, isTrue);
  });

  testWidgets('task page exposes a working logout entry', (tester) async {
    final store = LocalStore.memory();
    await store.saveList(
      TaskListItem(
        id: 'inbox-1',
        name: '收集箱',
        isInbox: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    final credentials = MemoryCredentialsStore(storedSession: _session);
    final app = AppState(
      store: store,
      credentials: credentials,
      repository: TaskRepository(store),
    )..session = _session;
    addTearDown(() async {
      await _stopReminders(app);
      app.dispose();
      await store.dispose();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('退出登录'), findsOneWidget);

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '退出登录'));
    await tester.pumpAndSettle();

    expect(app.session, isNull);
    expect(await credentials.load(), isNull);
    await _stopReminders(app);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('settings offers a working logout', (tester) async {
    final store = LocalStore.memory();
    final credentials = MemoryCredentialsStore(storedSession: _session);
    final app = AppState(
      store: store,
      credentials: credentials,
      repository: TaskRepository(store),
    )..session = _session;
    addTearDown(() async {
      await _stopReminders(app);
      app.dispose();
      await store.dispose();
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '退出登录'));
    await tester.pumpAndSettle();

    expect(app.session, isNull);
    expect(await credentials.load(), isNull);
    await _stopReminders(app);
    await tester.pump(const Duration(seconds: 1));
  });
}

class _ThrowingCredentialsStore extends MemoryCredentialsStore {
  _ThrowingCredentialsStore({super.storedSession});

  bool invalidated = false;

  @override
  Future<void> clear() async {
    throw StateError('credential file is read-only');
  }

  @override
  Future<void> invalidate() async {
    invalidated = true;
    await super.clear();
  }
}
