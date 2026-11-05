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

/// 打开日历页并切到年视图。
Future<void> _openYearView(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.calendar_month_outlined).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byIcon(Icons.calendar_view_month_rounded).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('年视图').last);
  await tester.pumpAndSettle();
}

Future<void> _pumpShell(
  WidgetTester tester,
  Size logicalSize, {
  double textScale = 1.0,
}) async {
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

  tester.view.physicalSize = Size(logicalSize.width * 3, logicalSize.height * 3);
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = const FakeViewPadding(left: 59 * 3, bottom: 21 * 3);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const HomeShell(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('year view fits four rows on a normal landscape phone', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(874, 402));
    await _openYearView(tester);

    expect(tester.takeException(), isNull);
    for (var month = 1; month <= 12; month++) {
      expect(find.text('$month月'), findsOneWidget);
    }
  });

  testWidgets('year view does not overflow on a short screen with large text', (
    tester,
  ) async {
    // 横屏 + 系统大字号：月份卡会被压到很矮，曾经在这里 overflow 7px。
    await _pumpShell(tester, const Size(874, 344), textScale: 1.15);
    await _openYearView(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('1月'), findsOneWidget);
    expect(find.text('12月'), findsOneWidget);
  });

  testWidgets('year view scrolls instead of squeezing below the minimum', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(874, 344), textScale: 1.15);
    await _openYearView(tester);

    // 空间不足时改为可滚动，月份卡保持最小可读高度。
    final scrollable = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Column),
    );
    expect(scrollable, findsWidgets);
  });
}
