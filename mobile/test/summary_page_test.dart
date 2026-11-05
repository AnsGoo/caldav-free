import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/design/app_theme.dart';
import 'package:caldav_free/design/components.dart';
import 'package:caldav_free/features/home/home_shell.dart';
import 'package:caldav_free/features/summary/summary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> _pumpShell(
  WidgetTester tester,
  Size size, {
  FakeViewPadding? padding,
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
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  if (padding != null) tester.view.padding = padding;
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
  await tester.pump();
}

Future<void> _openSummary(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.summarize_outlined).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('summary title matches the other pages in landscape', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      const Size(2622, 1206),
      padding: const FakeViewPadding(left: 59 * 3, bottom: 21 * 3),
    );
    await _openSummary(tester);

    final rail = tester.getRect(find.byType(AppSideNav));
    final titleFinder = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('摘要'),
    );
    final title = tester.getRect(titleFinder);
    final style = tester.widget<Text>(titleFinder).style;

    // 和日历/习惯等页面一致：贴着图标栏 20dp，字号 20。
    expect(title.left, closeTo(rail.right + 20, 0.6));
    expect(style?.fontSize, 20);
  });

  testWidgets('summary actions move into the app bar in landscape', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(2622, 1206));
    await _openSummary(tester);

    // 编辑器顶上那一行工具栏不再出现。
    expect(find.text('摘要编辑器'), findsNothing);
    expect(find.byTooltip('重新生成'), findsOneWidget);
    expect(find.byTooltip('复制摘要'), findsOneWidget);
    expect(find.byTooltip('保存为模板'), findsOneWidget);

    final appBar = tester.getRect(find.byType(AppBar));
    final refresh = tester.getRect(find.byTooltip('重新生成'));
    expect(refresh.center.dy, greaterThan(appBar.top));
    expect(refresh.center.dy, lessThan(appBar.bottom));
  });

  testWidgets('portrait keeps the toolbar row but drops the label', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(1206, 2622));
    await _openSummary(tester);

    expect(find.text('摘要编辑器'), findsNothing);
    // 竖屏按钮仍在编辑器上方，不在 AppBar 里。
    final appBar = tester.getRect(find.byType(AppBar));
    final refresh = tester.getRect(find.byTooltip('重新生成'));
    expect(refresh.center.dy, greaterThan(appBar.bottom));
  });

  testWidgets('summary page renders standalone', (tester) async {
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
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const SummaryPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SummaryPage), findsOneWidget);
  });
}
