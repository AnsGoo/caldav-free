import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/design/app_theme.dart';
import 'package:caldav_free/design/components.dart';
import 'package:caldav_free/features/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _scrollKey = Key('sheet-scroll');

Future<void> _openTallSheet(
  WidgetTester tester, {
  required Size logicalSize,
  required double topInset,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(logicalSize.width * 3, logicalSize.height * 3);
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = FakeViewPadding(top: topInset * 3, bottom: 21 * 3);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  addTearDown(tester.view.reset);

  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Builder(
        builder: (context) {
          ctx = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );

  showAppSheet<void>(
    context: ctx,
    isScrollControlled: true,
    builder: (_) => SingleChildScrollView(
      key: _scrollKey,
      child: const SizedBox(height: 2000, width: double.infinity),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tall sheets stay below the notch so the scrim is tappable', (
    tester,
  ) async {
    // 竖屏刘海 59dp + 键盘 320dp：内容极高，弹窗也不能顶到屏幕最上方。
    await _openTallSheet(
      tester,
      logicalSize: const Size(402, 874),
      topInset: 59,
      keyboard: 320,
    );

    final sheetTop = tester.getRect(find.byKey(_scrollKey)).top;
    expect(sheetTop, greaterThanOrEqualTo(59));
    expect(tester.takeException(), isNull);
  });

  testWidgets('new countdown sheet can be dismissed from the top', (
    tester,
  ) async {
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

    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 21 * 3);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320 * 3);
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

    await tester.tap(find.byIcon(Icons.hourglass_bottom_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('新建倒数日'), findsWidgets);
    expect(tester.takeException(), isNull);

    // 顶部遮罩仍然可点，弹窗能关掉。
    await tester.tapAt(const Offset(201, 20));
    await tester.pumpAndSettle();
    expect(find.text('新建倒数日'), findsNothing);

    // 弹窗关闭动画 / 延迟释放的 controller 收尾，避免留下 pending timer。
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a tap above the sheet dismisses it', (tester) async {
    await _openTallSheet(
      tester,
      logicalSize: const Size(402, 874),
      topInset: 59,
      keyboard: 320,
    );

    // 顶部露出的遮罩区域可以点掉弹窗。
    await tester.tapAt(const Offset(201, 20));
    await tester.pumpAndSettle();
    expect(find.byKey(_scrollKey), findsNothing);
  });
}
