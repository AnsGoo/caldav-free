import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/features/auth/login_page.dart';
import 'package:caldav_free/features/lists/lists_page.dart';
import 'package:caldav_free/features/tasks/tasks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('login page renders the connection form', (tester) async {
    final store = LocalStore.memory();
    final app = AppState(
      store: store,
      credentials: MemoryCredentialsStore(),
      repository: TaskRepository(store),
    );
    addTearDown(() async {
      app.dispose();
      await store.dispose();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    expect(find.text('连接你的服务器'), findsOneWidget);
    expect(find.text('登录并同步'), findsOneWidget);
    expect(find.text('caldav-free'), findsOneWidget);
  });

  testWidgets('search filters title and notes locally', (tester) async {
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(TaskListItem(
      id: 'inbox-1',
      name: '收集箱',
      isInbox: true,
      updatedAt: now,
    ));
    for (final task in [
      TaskItem(
        id: 'task-milk',
        listId: 'inbox-1',
        title: '买牛奶',
        notes: '顺便买面包',
        updatedAt: now,
      ),
      TaskItem(
        id: 'task-report',
        listId: 'inbox-1',
        title: '写周报',
        notes: '周五之前',
        updatedAt: now,
      ),
    ]) {
      await store.saveTask(task, dirty: false);
    }
    final app = AppState(
      store: store,
      credentials: MemoryCredentialsStore(),
      repository: TaskRepository(store),
    )..session = Session(
        baseUrl: 'http://example.test',
        username: 'demo',
        password: 'secret',
        deviceId: 'device-test',
      );
    addTearDown(() async {
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
    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('写周报'), findsOneWidget);

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '牛奶');
    await tester.pumpAndSettle();
    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('写周报'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '周五');
    await tester.pumpAndSettle();
    expect(find.text('写周报'), findsOneWidget);
    expect(find.text('买牛奶'), findsNothing);

    await tester.tap(find.byTooltip('关闭搜索'));
    await tester.pumpAndSettle();
    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('写周报'), findsOneWidget);
  });

  testWidgets('create a list from the management page', (tester) async {
    final store = LocalStore.memory();
    final app = AppState(
      store: store,
      credentials: MemoryCredentialsStore(),
      repository: TaskRepository(store),
    );
    addTearDown(() async {
      app.dispose();
      await store.dispose();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: ListsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('还没有清单'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '项目');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('项目'), findsOneWidget);
    expect(store.listsSnapshot().any((list) => list.name == '项目'), true);
    expect(store.pendingCount, 1);
  });

  testWidgets('quick add writes through the repository', (tester) async {
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(TaskListItem(
      id: 'inbox-1',
      name: '收集箱',
      isInbox: true,
      updatedAt: now,
    ));
    await store.saveTask(
      TaskItem(
        id: 'task-1',
        listId: 'inbox-1',
        title: '已有任务',
        updatedAt: now,
      ),
      dirty: false,
    );
    final app = AppState(
      store: store,
      credentials: MemoryCredentialsStore(),
      repository: TaskRepository(store),
    )..session = Session(
        baseUrl: 'http://example.test',
        username: 'demo',
        password: 'secret',
        deviceId: 'device-test',
      );
    addTearDown(() async {
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

    expect(find.text('已有任务'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '新任务');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('新任务'), findsOneWidget);
    expect(store.pendingCount, 1);
  });
}
