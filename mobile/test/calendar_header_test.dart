import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/design/app_theme.dart';
import 'package:caldav_free/features/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> _openCalendar(WidgetTester tester, Size logicalSize) async {
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

  tester.view.physicalSize = Size(
    logicalSize.width * 3,
    logicalSize.height * 3,
  );
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 21 * 3);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const HomeShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.calendar_month_outlined).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('portrait title and arrows share the app bar row', (tester) async {
    await _openCalendar(tester, const Size(402, 874));

    final title = tester.getRect(find.text('日历'));
    final previous = tester.getRect(find.byTooltip('上一段'));
    final refresh = tester.getRect(find.byTooltip('刷新日历'));

    // 标题、左右切换、右侧操作图标在同一高度。
    expect(previous.center.dy, closeTo(title.center.dy, 1));
    expect(refresh.center.dy, closeTo(title.center.dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the standalone today button is gone', (tester) async {
    await _openCalendar(tester, const Size(402, 874));

    expect(find.widgetWithText(TextButton, '今天'), findsNothing);
    // 点区间文字仍然能回到今天。
    expect(find.byTooltip('回到今天'), findsOneWidget);
  });

  testWidgets('landscape keeps the same single row', (tester) async {
    await _openCalendar(tester, const Size(874, 402));

    final title = tester.getRect(find.text('日历'));
    final previous = tester.getRect(find.byTooltip('上一段'));
    expect(previous.center.dy, closeTo(title.center.dy, 1));
    expect(tester.takeException(), isNull);
  });
}
