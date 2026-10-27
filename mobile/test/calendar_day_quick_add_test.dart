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
  Future<LocalStore> pumpCalendar(
    WidgetTester tester,
    String view, {
    Size? surface,
  }) async {
    if (surface != null) {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = surface;
      addTearDown(tester.view.reset);
    }
    final store = LocalStore.memory();
    await store.saveList(
      TaskListItem(
        id: 'inbox-1',
        name: '收集箱',
        isInbox: true,
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
        child: const MaterialApp(home: CalendarPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<CalendarView>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(view));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('the day view FAB quick-adds an all-day task for that day', (
    tester,
  ) async {
    final store = await pumpCalendar(
      tester,
      '日视图',
      surface: const Size(390, 844),
    );
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);

    await tester.tap(find.byIcon(Icons.playlist_add_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '看牙医');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    final created = store.allTasks().single;
    expect(created.title, '看牙医');
    expect(created.listId, 'inbox-1');
    expect(created.allDay, isTrue);
    expect(created.dueAt, day);
    expect(store.pendingCount, 1);
    expect(
      store.pendingOp('task', created.id)?.patch['due'],
      day.toUtc().toIso8601String(),
    );
  });

  testWidgets('cancelling the day composer writes nothing', (tester) async {
    final store = await pumpCalendar(tester, '日视图');

    await tester.tap(find.byIcon(Icons.playlist_add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '算了');
    await tester.tap(find.byTooltip('取消'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(store.allTasks(), isEmpty);
    expect(store.pendingCount, 0);
  });

  testWidgets('other views keep the event FAB only', (tester) async {
    await pumpCalendar(tester, '月视图');

    expect(find.byIcon(Icons.playlist_add_rounded), findsNothing);
  });
}
