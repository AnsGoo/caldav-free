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

  testWidgets('the day view no longer offers a task quick-add FAB', (
    tester,
  ) async {
    await pumpCalendar(tester, '日视图', surface: const Size(390, 844));

    expect(find.byIcon(Icons.playlist_add_rounded), findsNothing);
  });

  testWidgets('other views keep the event FAB only', (tester) async {
    await pumpCalendar(tester, '月视图');

    expect(find.byIcon(Icons.playlist_add_rounded), findsNothing);
  });
}
