import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/features/calendar/calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<LocalStore> pump(WidgetTester tester) async {
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
    return store;
  }

  Future<void> useView(WidgetTester tester, String label) async {
    await tester.tap(find.byType(PopupMenuButton<CalendarView>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('long-pressing a month cell quick-adds an all-day task locally', (
    tester,
  ) async {
    final store = await pump(tester);
    await useView(tester, '月视图');
    final day = DateTime(DateTime.now().year, DateTime.now().month, 15);

    await tester.longPress(find.text('15'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '交周报');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    final created = store.allTasks().single;
    expect(created.title, '交周报');
    expect(created.listId, 'inbox-1');
    expect(created.allDay, isTrue);
    expect(created.dueAt, day);
    // The write is queued only: no request is made from the calendar page.
    expect(store.pendingCount, 1);
    expect(
      store.pendingOp('task', created.id)?.patch['due'],
      day.toUtc().toIso8601String(),
    );
  });

  testWidgets('escape cancels the month-cell composer without writing', (
    tester,
  ) async {
    final store = await pump(tester);
    await useView(tester, '月视图');

    await tester.longPress(find.text('15'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不想做');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(store.allTasks(), isEmpty);
    expect(store.pendingCount, 0);
  });

  testWidgets('an empty title leaves no task behind', (tester) async {
    final store = await pump(tester);
    await useView(tester, '月视图');

    await tester.longPress(find.text('15'));
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(store.allTasks(), isEmpty);
    expect(store.pendingCount, 0);
  });
}
