import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/features/auth/login_page.dart';
import 'package:caldav_free/features/lists/lists_page.dart';
import 'package:caldav_free/features/search/search_page.dart';
import 'package:caldav_free/features/tasks/tasks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('connect sheet renders the connection form', (tester) async {
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
        child: const MaterialApp(home: Scaffold(body: ConnectServerSheet())),
      ),
    );

    expect(find.text('连接服务器'), findsOneWidget);
    expect(find.text('连接并同步'), findsOneWidget);
  });

  testWidgets('search filters title and notes locally', (tester) async {
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'inbox-1', name: '收集箱', isInbox: true, updatedAt: now),
    );
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
    final app =
        AppState(
            store: store,
            credentials: MemoryCredentialsStore(),
            repository: TaskRepository(store),
          )
          ..session = Session(
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

  testWidgets('global search finds tasks across lists', (tester) async {
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'inbox-1', name: '收集箱', isInbox: true, updatedAt: now),
    );
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: now),
    );
    await store.saveTask(
      TaskItem(
        id: 'task-milk',
        listId: 'inbox-1',
        title: '买牛奶',
        notes: '顺便买面包',
        updatedAt: now,
      ),
      dirty: false,
    );
    await store.saveTask(
      TaskItem(
        id: 'task-report',
        listId: 'work-1',
        title: '写周报',
        updatedAt: now,
      ),
      dirty: false,
    );
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
        child: const MaterialApp(home: SearchPage(loadRemote: false)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('搜索所有内容'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '牛奶');
    await tester.pumpAndSettle();
    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('写周报'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '周报');
    await tester.pumpAndSettle();
    expect(find.text('写周报'), findsOneWidget);
    expect(find.text('买牛奶'), findsNothing);
  });

  testWidgets('layout switcher renders board, matrix and timeline', (
    tester,
  ) async {
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'inbox-1', name: '收集箱', isInbox: true, updatedAt: now),
    );
    await store.saveSection(
      TaskSection(
        id: 'section-doing',
        listId: 'inbox-1',
        name: '进行中',
        updatedAt: now,
      ),
    );
    await store.saveTask(
      TaskItem(
        id: 'task-board',
        listId: 'inbox-1',
        sectionId: 'section-doing',
        title: '看板里的任务',
        priority: 3,
        dueAt: now.add(const Duration(hours: 4)),
        updatedAt: now,
      ),
      dirty: false,
    );
    await store.saveTask(
      TaskItem(
        id: 'task-drag',
        listId: 'inbox-1',
        title: '拖拽任务',
        updatedAt: now,
      ),
      dirty: false,
    );
    final app =
        AppState(
            store: store,
            credentials: MemoryCredentialsStore(),
            repository: TaskRepository(store),
          )
          ..session = Session(
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

    await tester.longPress(find.text('看板里的任务'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsOneWidget);
    await tester.tap(find.byTooltip('取消选择'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('看板'));
    await tester.pumpAndSettle();
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('未分列'), findsOneWidget);
    expect(find.text('看板里的任务'), findsOneWidget);

    final drag = await tester.startGesture(tester.getCenter(find.text('拖拽任务')));
    await tester.pump(const Duration(milliseconds: 700));
    await drag.moveTo(
      tester.getCenter(find.text('进行中')) + const Offset(0, 120),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await drag.up();
    await tester.pumpAndSettle();
    expect(store.task('task-drag')?.sectionId, 'section-doing');

    await tester.tap(find.text('矩阵'));
    await tester.pumpAndSettle();
    expect(find.text('重要且紧急'), findsOneWidget);
    expect(find.text('重要不紧急'), findsOneWidget);
    expect(find.text('紧急不重要'), findsOneWidget);
    expect(find.text('不重要不紧急'), findsOneWidget);
    expect(find.text('看板里的任务'), findsOneWidget);

    await tester.tap(find.text('时间线'));
    await tester.pumpAndSettle();
    expect(find.text('无日期'), findsOneWidget);
    expect(find.text('今天'), findsWidgets);
    expect(find.text('看板里的任务'), findsOneWidget);

    final timelineDrag = await tester.startGesture(
      tester.getCenter(find.text('拖拽任务')),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await timelineDrag.moveTo(
      tester.getCenter(find.text('今天').last) + const Offset(0, 120),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await timelineDrag.up();
    await tester.pumpAndSettle();
    expect(store.task('task-drag')?.dueAt, isNotNull);

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    expect(find.text('本周'), findsOneWidget);
    expect(find.text('下周'), findsOneWidget);

    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(find.text('本月'), findsOneWidget);
  });

  testWidgets('smart views filter by due date', (tester) async {
    final store = LocalStore.memory();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    await store.saveList(
      TaskListItem(
        id: 'inbox-1',
        name: '收集箱',
        isInbox: true,
        updatedAt: now.toUtc(),
      ),
    );
    for (final item in [
      ('today-task', '今天任务', start.add(const Duration(hours: 10))),
      ('tomorrow-task', '明天任务', start.add(const Duration(days: 1, hours: 10))),
      ('later-task', '以后任务', start.add(const Duration(days: 10))),
    ]) {
      await store.saveTask(
        TaskItem(
          id: item.$1,
          listId: 'inbox-1',
          title: item.$2,
          dueAt: item.$3.toUtc(),
          updatedAt: now.toUtc(),
        ),
        dirty: false,
      );
    }
    final app =
        AppState(
            store: store,
            credentials: MemoryCredentialsStore(),
            repository: TaskRepository(store),
          )
          ..session = Session(
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
    expect(find.text('今天任务'), findsOneWidget);
    expect(find.text('明天任务'), findsOneWidget);
    expect(find.text('以后任务'), findsOneWidget);

    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(find.text('今天任务'), findsOneWidget);
    expect(find.text('明天任务'), findsNothing);
    expect(find.text('以后任务'), findsNothing);

    await tester.ensureVisible(find.text('最近 7 天'));
    await tester.tap(find.text('最近 7 天'));
    await tester.pumpAndSettle();
    expect(find.text('今天任务'), findsOneWidget);
    expect(find.text('明天任务'), findsOneWidget);
    expect(find.text('以后任务'), findsNothing);
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

    await tester.tap(find.byTooltip('新建文件夹'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '工作');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.foldersSnapshot().single.name, '工作');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '项目');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('项目'), findsOneWidget);
    expect(store.listsSnapshot().any((list) => list.name == '项目'), true);
    expect(store.pendingCount, 2);

    await tester.tap(find.byTooltip('清单操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动到文件夹'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '工作'));
    await tester.pumpAndSettle();

    expect(
      store.listsSnapshot().single.folderId,
      store.foldersSnapshot().single.id,
    );
  });

  testWidgets('quick add writes through the repository', (tester) async {
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'inbox-1', name: '收集箱', isInbox: true, updatedAt: now),
    );
    await store.saveTask(
      TaskItem(id: 'task-1', listId: 'inbox-1', title: '已有任务', updatedAt: now),
      dirty: false,
    );
    final app =
        AppState(
            store: store,
            credentials: MemoryCredentialsStore(),
            repository: TaskRepository(store),
          )
          ..session = Session(
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
