import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/design/app_theme.dart';
import 'package:caldav_free/design/components.dart';
import 'package:caldav_free/features/tasks/tasks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> _pump(WidgetTester tester) async {
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

  tester.view.physicalSize = const Size(874 * 3, 402 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const TasksPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('view switcher is an icon menu, not a tab row', (tester) async {
    await _pump(tester);

    // 旧的文字切换条不应再占一行。
    expect(find.byType(AppUnderlineTabs), findsNothing);

    final button = tester.getRect(find.byTooltip('切换视图'));
    final appBar = tester.getRect(find.byType(AppBar));
    // 按钮就在 AppBar 里，没有再单独占一行。
    expect(button.center.dy, inInclusiveRange(appBar.top, appBar.bottom));
  });

  testWidgets('view menu offers all three layouts and switches', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('切换视图'));
    await tester.pumpAndSettle();

    for (final label in const ['列表', '看板', '矩阵']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('看板').last);
    await tester.pumpAndSettle();

    // 切到看板后菜单里应打勾，且页面渲染看板。
    await tester.tap(find.byTooltip('切换视图'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
