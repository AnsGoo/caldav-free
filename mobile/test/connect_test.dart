import 'dart:async';

import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/remote/sync_api.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

final _emptyPage = PullPage(
  cursor: '0',
  hasMore: false,
  tasks: [],
  lists: [],
  sections: [],
  folders: [],
  filters: [],
  tombstones: [],
);

/// A transport whose first pull stays pending until the test releases it.
class _ControlledApi implements SyncApi {
  final gate = Completer<PullPage>();
  bool closed = false;

  @override
  Future<PullPage> pull({
    required String since,
    int limit = 500,
    bool refresh = false,
  }) => gate.future;

  @override
  Future<List<PushResult>> push({
    required List<OutboxOp> ops,
    required String deviceId,
  }) async => const [];

  @override
  void close() => closed = true;
}

class _EmptyApi implements SyncApi {
  bool closed = false;

  @override
  Future<PullPage> pull({
    required String since,
    int limit = 500,
    bool refresh = false,
  }) async => _emptyPage;

  @override
  Future<List<PushResult>> push({
    required List<OutboxOp> ops,
    required String deviceId,
  }) async => const [];

  @override
  void close() => closed = true;
}

AppState _app(LocalStore store, CredentialsStore credentials, SyncApi api) {
  return AppState(
    store: store,
    credentials: credentials,
    repository: TaskRepository(store),
    apiFactory: ({
      required String baseUrl,
      required String username,
      required String password,
    }) => api,
  );
}

void main() {
  testWidgets('a failed login stops the spinner and shows the error', (
    tester,
  ) async {
    final store = LocalStore.memory();
    final credentials = MemoryCredentialsStore();
    final api = _ControlledApi();
    final app = _app(store, credentials, api);
    addTearDown(() async {
      await app.reminders?.stop(cancelAll: true);
      app.dispose();
      await store.dispose();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: Scaffold(body: ConnectServerSheet())),
      ),
    );

    await tester.enterText(find.byType(TextField).at(1), 'demo');
    await tester.enterText(find.byType(TextField).at(2), 'wrong');
    await tester.tap(find.text('连接并同步'));
    await tester.pump();

    // While the probe is in flight the button must be busy.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(app.busy, isTrue);

    api.gate.completeError(SyncApiException('用户名或密码错误', statusCode: 401));
    await tester.pump();
    await tester.pump();

    expect(find.text('用户名或密码错误'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('连接并同步'), findsOneWidget);
    expect(app.busy, isFalse);
    expect(app.session, isNull);
    expect(await credentials.load(), isNull);
  });

  testWidgets('a timeout message replaces the raw TimeoutException', (
    tester,
  ) async {
    final store = LocalStore.memory();
    final credentials = MemoryCredentialsStore();
    final api = _ControlledApi();
    final app = _app(store, credentials, api);
    addTearDown(() async {
      await app.reminders?.stop(cancelAll: true);
      app.dispose();
      await store.dispose();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: Scaffold(body: ConnectServerSheet())),
      ),
    );

    await tester.enterText(find.byType(TextField).at(1), 'demo');
    await tester.enterText(find.byType(TextField).at(2), 'secret');
    await tester.tap(find.text('连接并同步'));
    await tester.pump();

    api.gate.completeError(
      SyncApiException('连接服务器超时，请检查地址、网络和 HTTPS 证书', network: true),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('连接服务器超时，请检查地址、网络和 HTTPS 证书'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(app.busy, isFalse);
  });

  test('connect publishes the session only after sync is wired', () async {
    final store = LocalStore.memory();
    final credentials = MemoryCredentialsStore();
    final api = _EmptyApi();
    final app = _app(store, credentials, api);
    addTearDown(() async {
      await app.reminders?.stop(cancelAll: true);
      app.dispose();
      await store.dispose();
    });

    await app.connect(
      baseUrl: 'http://example.test',
      username: 'demo',
      password: 'secret',
    );

    expect(app.session?.username, 'demo');
    expect(app.syncController, isNotNull);
    expect(app.busy, isFalse);
    expect(await credentials.load(), isNotNull);

    await app.disconnect();
  });
}
