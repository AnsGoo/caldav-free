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

Future<void> _openFocus(WidgetTester tester, Size logicalSize) async {
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
  await tester.tap(find.byIcon(Icons.timer_outlined).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('portrait puts the controls under the ring', (tester) async {
    await _openFocus(tester, const Size(402, 874));

    final ring = tester.getRect(find.text('25:00'));
    final start = tester.getRect(find.widgetWithText(FilledButton, '开始'));
    final reset = tester.getRect(find.byTooltip('重置计时'));

    // 都在圆环（倒计时）下方，且开始按钮居中。
    expect(start.top, greaterThan(ring.bottom));
    expect(reset.center.dy, closeTo(start.center.dy, 1));

    await tester.tap(find.widgetWithText(FilledButton, '开始'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, '暂停'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '暂停'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, '开始'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape puts the buttons beside the ring', (tester) async {
    await _openFocus(tester, const Size(874, 402));

    final clock = tester.getRect(find.text('25:00'));
    final start = tester.getRect(find.widgetWithText(FilledButton, '开始'));
    final reset = tester.getRect(find.byTooltip('重置计时'));

    // 开始按钮在左，重置在右，两者相对圆环垂直居中。
    expect(start.right, lessThan(clock.left));
    expect(reset.left, greaterThan(clock.right));
    expect(start.center.dy, closeTo(reset.center.dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset clears the running session', (tester) async {
    await _openFocus(tester, const Size(402, 874));

    await tester.tap(find.widgetWithText(FilledButton, '开始'));
    await tester.pump();
    expect(find.text('专注中'), findsOneWidget);

    await tester.tap(find.byTooltip('重置计时'));
    await tester.pump();

    expect(find.text('准备开始'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
  });
}
