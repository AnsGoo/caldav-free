import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/features/calendar/calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // 日程视图一屏三天，给足高度让三段都构建出来。
  Future<void> pumpCalendar(
    WidgetTester tester, {
    required List<TaskItem> tasks,
    String? view,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 1600);
    addTearDown(tester.view.reset);
    final store = LocalStore.memory();
    await store.saveList(
      TaskListItem(
        id: 'work-1',
        name: '工作',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    for (final task in tasks) {
      await store.saveTask(task, dirty: false);
    }
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
        child: const MaterialApp(home: CalendarPage()),
      ),
    );
    await tester.pumpAndSettle();
    if (view == null) return;
    await tester.tap(find.byType(PopupMenuButton<CalendarView>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(view));
    await tester.pumpAndSettle();
  }

  testWidgets('a daily task repeats across the offline schedule', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await pumpCalendar(
      tester,
      tasks: [
        TaskItem(
          id: 'daily',
          listId: 'work-1',
          title: '吃药',
          dueAt: today.toUtc(),
          allDay: true,
          recurrence: 'FREQ=DAILY',
          updatedAt: now.toUtc(),
        ),
      ],
    );

    expect(find.text('1 项'), findsNWidgets(3));
    expect(find.text('吃药'), findsNWidgets(3));
    expect(find.text('暂无安排'), findsNothing);
  });

  testWidgets('a repeat anchored in the future stays out of today', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await pumpCalendar(
      tester,
      tasks: [
        TaskItem(
          id: 'meeting',
          listId: 'work-1',
          title: '晚上十点开会',
          startAt: today.toUtc(),
          dueAt: today.add(const Duration(days: 33)).toUtc(),
          allDay: true,
          recurrence: 'FREQ=DAILY',
          updatedAt: now.toUtc(),
        ),
      ],
    );

    expect(find.text('晚上十点开会'), findsNothing);
    expect(find.text('0 项'), findsNWidgets(3));
  });

  testWidgets('a one-off task still shows once on its due day', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await pumpCalendar(
      tester,
      tasks: [
        TaskItem(
          id: 'single',
          listId: 'work-1',
          title: '交房租',
          dueAt: today.add(const Duration(days: 1, hours: 9)).toUtc(),
          updatedAt: now.toUtc(),
        ),
      ],
    );

    expect(find.text('交房租'), findsOneWidget);
    expect(find.text('0 项'), findsNWidgets(2));
    expect(find.text('1 项'), findsOneWidget);
  });

  testWidgets('a timed repeat anchored in the past reaches today', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await pumpCalendar(
      tester,
      view: '日视图',
      tasks: [
        TaskItem(
          id: 'meeting',
          listId: 'work-1',
          title: '晚上十点开会',
          dueAt: today.subtract(const Duration(days: 5)).add(const Duration(hours: 22)).toUtc(),
          recurrence: 'FREQ=DAILY',
          updatedAt: now.toUtc(),
        ),
      ],
    );

    expect(find.text('晚上十点开会'), findsWidgets);
  });

  testWidgets('an all-day repeat anchored in the past reaches today', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await pumpCalendar(
      tester,
      view: '日视图',
      tasks: [
        TaskItem(
          id: 'daily',
          listId: 'work-1',
          title: '吃药',
          dueAt: today.subtract(const Duration(days: 2)).toUtc(),
          allDay: true,
          recurrence: 'FREQ=DAILY',
          updatedAt: now.toUtc(),
        ),
      ],
    );

    expect(find.text('全天'), findsOneWidget);
    expect(find.text('吃药'), findsWidgets);
  });
}
