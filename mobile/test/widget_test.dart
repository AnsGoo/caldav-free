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

    FocusManager.instance.primaryFocus?.unfocus();
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
    // 宽屏通过侧栏选择清单，主区不再显示范围筛选条。
    expect(find.text('全部清单'), findsNothing);
    expect(find.text('看板里的任务'), findsOneWidget);
    expect(find.text('未分列'), findsNothing);

    await tester.tap(find.text('收集箱').first);
    await tester.pumpAndSettle();
    // 选定清单后按分列展示
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

  testWidgets('the matrix buckets by priority and hides completed', (
    tester,
  ) async {
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: now),
    );
    Future<void> seed(String id, String title, int priority,
        {bool completed = false, DateTime? due}) => store.saveTask(
      TaskItem(
        id: id,
        listId: 'work-1',
        title: title,
        priority: priority,
        completedAt: completed ? now : null,
        dueAt: due,
        updatedAt: now,
      ),
      dirty: false,
    );
    await seed('p3', '高优先无日期', 3);
    await seed('p2', '中优先今天到期', 2, due: now);
    await seed('p1', '低优先任务', 1);
    await seed('p0', '无优先任务', 0);
    await seed('done', '已完成高优先', 3, completed: true);

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
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('矩阵'));
    await tester.pumpAndSettle();

    Finder inQuadrant(String quadrant, String title) => find.descendant(
      of: find.byKey(ValueKey('matrix-q$quadrant')),
      matching: find.text(title),
    );

    // Web 默认「按优先级」：3→Q1、2→Q2、1→Q3、0→Q4；四象限不展示已完成。
    expect(inQuadrant('0', '高优先无日期'), findsOneWidget);
    expect(find.text('已完成高优先'), findsNothing);
    expect(inQuadrant('1', '中优先今天到期'), findsOneWidget);
    expect(inQuadrant('2', '低优先任务'), findsOneWidget);
    expect(inQuadrant('3', '无优先任务'), findsOneWidget);
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

    await tester.tap(find.text('今天').first);
    await tester.pumpAndSettle();
    expect(find.text('今天任务'), findsOneWidget);
    expect(find.text('明天任务'), findsNothing);
    expect(find.text('以后任务'), findsNothing);

    await tester.ensureVisible(find.text('最近 7 天').first);
    await tester.tap(find.text('最近 7 天').first);
    await tester.pumpAndSettle();
    expect(find.text('今天任务'), findsOneWidget);
    expect(find.text('明天任务'), findsOneWidget);
    expect(find.text('以后任务'), findsNothing);
  });

  testWidgets('completed and trash quick filters scope the task list', (
    tester,
  ) async {
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'inbox-1', name: '收集箱', isInbox: true, updatedAt: now),
    );
    for (final task in [
      TaskItem(
        id: 'task-open',
        listId: 'inbox-1',
        title: '未完成任务',
        updatedAt: now,
      ),
      TaskItem(
        id: 'task-done',
        listId: 'inbox-1',
        title: '已完成任务',
        updatedAt: now,
        completedAt: now,
      ),
      TaskItem(
        id: 'task-trashed',
        listId: 'inbox-1',
        title: '回收站任务',
        updatedAt: now,
        deleted: true,
        deletedAt: now,
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
    expect(find.text('未完成任务'), findsOneWidget);
    expect(find.text('已完成任务'), findsNothing);
    expect(find.text('回收站任务'), findsNothing);

    await tester.ensureVisible(find.text('已完成').first);
    await tester.tap(find.text('已完成').first);
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsOneWidget);
    expect(find.text('未完成任务'), findsNothing);

    // 全部 clears the completed scope again.
    await tester.tap(find.text('全部').first);
    await tester.pumpAndSettle();
    expect(find.text('未完成任务'), findsOneWidget);
    expect(find.text('已完成任务'), findsNothing);

    await tester.tap(find.text('已完成').first);
    await tester.pumpAndSettle();
    // Selecting a list leaves the completed scope too. The completed tile
    // carries a 收集箱 list badge, so target the pane row (.first) explicitly.
    await tester.ensureVisible(find.text('收集箱').first);
    await tester.tap(find.text('收集箱').first);
    await tester.pumpAndSettle();
    expect(find.text('未完成任务'), findsOneWidget);
    expect(find.text('已完成任务'), findsNothing);

    await tester.ensureVisible(find.text('回收站').first);
    await tester.tap(find.text('回收站').first);
    await tester.pumpAndSettle();
    expect(find.text('回收站任务'), findsOneWidget);

    // 回收站现在是页内视图，再次点击侧栏的回收站即可返回。
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('未完成任务'), findsOneWidget);
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

  testWidgets('empty task page shows an empty state instead of a sync prompt', (
    tester,
  ) async {
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
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('这里还没有任务'), findsOneWidget);
    expect(find.text('正在获取清单…'), findsNothing);
    expect(find.text('立即同步'), findsNothing);
    expect(find.text('等待清单同步…'), findsNothing);
    expect(find.text('暂无清单，请先新建清单'), findsOneWidget);
  });

  testWidgets('quick add falls back to the first list without an inbox', (
    tester,
  ) async {
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: now),
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

    expect(find.text('添加到「工作」'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '写周报');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('写周报'), findsOneWidget);
    final added = store.tasksSnapshot(listId: 'work-1', completed: false);
    expect(added.single.title, '写周报');
  });

  testWidgets('list filtering uses the side pane on wide and a funnel on mobile', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    Future<void> pumpTasks(Size size) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = size;
      final store = LocalStore.memory();
      await store.saveList(
        TaskListItem(
          id: 'work-1',
          name: '工作',
          updatedAt: DateTime.now().toUtc(),
        ),
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
          child: const MaterialApp(home: TasksPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    // 宽屏的侧栏已经有视图和清单筛选，主区不再出现范围筛选条。
    await pumpTasks(const Size(1200, 900));
    expect(find.text('范围'), findsNothing);
    expect(find.text('清单'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.byTooltip('清单筛选'), findsNothing);
    expect(find.byTooltip('主题颜色'), findsNothing);
    expect(find.text('管理'), findsNothing);

    // 窄屏没有侧栏，顶部漏斗负责清单筛选，chips 只保留视图。
    await pumpTasks(const Size(390, 844));
    expect(find.text('范围'), findsNothing);
    expect(find.text('今天'), findsOneWidget);
    expect(find.byTooltip('清单筛选'), findsOneWidget);
    await tester.tap(find.byTooltip('清单筛选'));
    await tester.pumpAndSettle();
    expect(find.text('全部清单'), findsOneWidget);
    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();
    expect(find.text('工作'), findsOneWidget);
  });

  testWidgets('the wide sidebar tag chips filter the task list', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: now),
    );
    await store.saveTask(
      TaskItem(
        id: 'tagged',
        listId: 'work-1',
        title: '带标签任务',
        tags: const ['重要'],
        updatedAt: now,
      ),
      dirty: false,
    );
    await store.saveTask(
      TaskItem(
        id: 'plain',
        listId: 'work-1',
        title: '普通任务',
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
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('# 重要'), findsOneWidget);
    expect(find.text('带标签任务'), findsOneWidget);
    expect(find.text('普通任务'), findsOneWidget);

    await tester.tap(find.text('# 重要'));
    await tester.pumpAndSettle();
    expect(find.text('带标签任务'), findsOneWidget);
    expect(find.text('普通任务'), findsNothing);

    // Tapping the active chip again clears the tag filter.
    await tester.tap(find.text('# 重要'));
    await tester.pumpAndSettle();
    expect(find.text('普通任务'), findsOneWidget);
  });

  testWidgets('the wide sidebar can create and delete lists', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: now),
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
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 新建：侧栏标题旁的 + 直接内联输入。
    await tester.tap(find.byTooltip('新建清单'));
    await tester.pumpAndSettle();
    final nameField = find.widgetWithText(TextField, '清单名称，回车创建');
    expect(tester.getSize(nameField).height, lessThan(34));
    await tester.enterText(nameField, '项目');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('项目'), findsOneWidget);
    expect(store.listsSnapshot().any((list) => list.name == '项目'), true);

    // 删除：选中清单后行尾出现删除按钮。
    await tester.tap(find.text('项目'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除清单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(store.listsSnapshot().any((list) => list.name == '项目'), false);
  });

  testWidgets('the wide sidebar tag manager deletes a tag', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: now),
    );
    await store.saveTask(
      TaskItem(
        id: 'tagged',
        listId: 'work-1',
        title: '带标签任务',
        tags: const ['重要', '项目'],
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
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('管理标签'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('# 重要')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('# 项目')),
      findsOneWidget,
    );

    // 原地重命名：行内出现输入框，取消后恢复原样。
    final renameRow = find.byKey(const ValueKey('tag-row-项目'));
    await tester.tap(
      find.descendant(of: renameRow, matching: find.byTooltip('重命名')),
    );
    await tester.pumpAndSettle();
    final inlineField = find.byKey(const Key('tag-manager-rename'));
    expect(inlineField, findsOneWidget);
    await tester.tap(find.byTooltip('取消'));
    await tester.pumpAndSettle();
    expect(inlineField, findsNothing);
    expect(find.descendant(of: dialog, matching: find.text('# 项目')), findsOneWidget);

    final importantRow = find.byKey(const ValueKey('tag-row-重要'));
    await tester.tap(
      find.descendant(of: importantRow, matching: find.byTooltip('删除标签')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(store.task('tagged')!.tags, const ['项目']);
    expect(
      find.descendant(of: dialog, matching: find.text('# 重要')),
      findsNothing,
    );

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('# 重要'), findsNothing);
    expect(find.text('# 项目'), findsOneWidget);
  });

  testWidgets('the tag manager renames a tag inline', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: now),
    );
    await store.saveTask(
      TaskItem(
        id: 'tagged',
        listId: 'work-1',
        title: '带标签任务',
        tags: const ['重要'],
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
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('管理标签'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    final row = find.byKey(const ValueKey('tag-row-重要'));
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('重命名')),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('tag-manager-rename'));
    await tester.enterText(field, '紧急');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.task('tagged')!.tags, const ['紧急']);
    expect(
      find.descendant(of: dialog, matching: find.text('# 紧急')),
      findsOneWidget,
    );
    expect(find.text('# 重要'), findsNothing);
  });

  testWidgets('the tag manager chooses which tags show in the sidebar', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: now),
    );
    await store.saveTask(
      TaskItem(
        id: 'tagged',
        listId: 'work-1',
        title: '带标签任务',
        tags: const ['重要', '项目'],
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
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 未设置时侧栏展示全部标签。
    expect(find.text('# 重要'), findsOneWidget);
    expect(find.text('# 项目'), findsOneWidget);

    await tester.tap(find.byTooltip('管理标签'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('tag-row-项目'));
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('从侧栏移除')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(find.text('# 项目'), findsNothing);
    expect(find.text('# 重要'), findsOneWidget);
    expect(store.sidebarTagsSnapshot(), isNot(contains('项目')));

    // 再勾选回来。
    await tester.tap(find.byTooltip('管理标签'));
    await tester.pumpAndSettle();
    final hiddenRow = find.byKey(const ValueKey('tag-row-项目'));
    await tester.tap(
      find.descendant(of: hiddenRow, matching: find.byTooltip('添加到侧栏')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('# 项目'), findsOneWidget);
  });

  testWidgets('the sidebar creates a saved filter and applies it', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: now),
    );
    await store.saveTask(
      TaskItem(
        id: 'high',
        listId: 'work-1',
        title: '高优先任务',
        priority: 3,
        updatedAt: now,
      ),
      dirty: false,
    );
    await store.saveTask(
      TaskItem(
        id: 'plain',
        listId: 'work-1',
        title: '普通任务',
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
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('普通任务'), findsOneWidget);

    await tester.tap(find.byTooltip('新建筛选器'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)).first,
      '高优先',
    );
    await tester.tap(
      find.descendant(of: dialog, matching: find.widgetWithText(FilterChip, '高')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(store.filtersSnapshot().single.name, '高优先');
    expect(find.text('高优先任务'), findsOneWidget);
    expect(find.text('普通任务'), findsNothing);

    // Tapping the active filter again clears it.
    await tester.tap(find.byTooltip('编辑筛选器'));
    await tester.pumpAndSettle();
    expect(find.text('编辑筛选器'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('the trash opens in the task page and restores tasks', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final store = LocalStore.memory();
    final now = DateTime.now().toUtc();
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: now),
    );
    await store.saveTask(
      TaskItem(
        id: 'deleted',
        listId: 'work-1',
        title: '删掉的任务',
        deleted: true,
        deletedAt: now,
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
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('删掉的任务'), findsNothing);

    await tester.tap(find.text('回收站'));
    await tester.pumpAndSettle();
    // 仍在任务页：标题、页内列表与操作都在。
    expect(find.text('回收站'), findsWidgets);
    expect(find.text('删掉的任务'), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);
    expect(find.text('清空回收站'), findsOneWidget);
    expect(find.text('加载中…'), findsNothing);

    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(store.task('deleted')?.deleted, false);
    expect(find.text('回收站是空的'), findsOneWidget);
  });

  testWidgets('the mobile filter chips keep a compact highlight', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final store = LocalStore.memory();
    await store.saveList(
      TaskListItem(id: 'work-1', name: '工作', updatedAt: DateTime.now().toUtc()),
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
        child: const MaterialApp(home: TasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 高亮只包住文字，不再撑满 44 的筛选条。
    final chip = find
        .ancestor(of: find.text('全部'), matching: find.byType(InkWell))
        .first;
    final size = tester.getSize(chip);
    expect(size.height, lessThan(36));
    expect(size.height, greaterThanOrEqualTo(28));
  });
}
