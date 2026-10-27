import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/design/components.dart';
import 'package:caldav_free/features/calendar/calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpYearView(WidgetTester tester, Size surface) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = surface;
    addTearDown(tester.view.reset);
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
    await tester.tap(find.text('年视图'));
    await tester.pumpAndSettle();
  }

  testWidgets('the year view frames every month as its own card', (
    tester,
  ) async {
    await pumpYearView(tester, const Size(360, 640));

    // Each framed month carries its own header and item count.
    for (var month = 1; month <= 12; month++) {
      expect(find.text('$month月'), findsOneWidget, reason: '$month月 表头');
    }
    expect(find.text('0 项'), findsNWidgets(12));
    // PC parity: months are hairline-outlined, not filled cards.
    expect(find.byType(AppCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the whole year fits one screen without scrolling', (
    tester,
  ) async {
    await pumpYearView(tester, const Size(360, 640));

    // December is on screen without a single drag, so nothing scrolls.
    final december = tester.getRect(find.text('12月'));
    expect(december.top, greaterThanOrEqualTo(0));
    expect(december.bottom, lessThanOrEqualTo(640));
    expect(find.byType(Scrollable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the year view fits a narrow phone without clipping', (
    tester,
  ) async {
    await pumpYearView(tester, const Size(320, 568));

    for (var month = 1; month <= 12; month++) {
      final rect = tester.getRect(find.text('$month月'));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.bottom, lessThanOrEqualTo(568));
    }
    expect(tester.takeException(), isNull);
  });
}
