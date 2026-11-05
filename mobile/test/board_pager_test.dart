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

Future<void> _openBoard(WidgetTester tester, Size logicalSize) async {
  final store = LocalStore.memory();
  final now = DateTime.now().toUtc();
  for (final name in ['收集箱', '工作', '生活']) {
    await store.saveList(
      TaskListItem(
        id: name,
        name: name,
        isInbox: name == '收集箱',
        updatedAt: now,
      ),
    );
  }
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
  tester.view.padding = const FakeViewPadding(left: 59 * 3, bottom: 21 * 3);
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

  await tester.tap(find.byTooltip('切换视图'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('看板').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('landscape merges the pager hint into the group row', (
    tester,
  ) async {
    await _openBoard(tester, const Size(874, 402));

    final groupLabel = tester.getRect(find.text('看板分组'));
    final hint = tester.getRect(find.text('左右滑动切换分组'));

    // 同一行：垂直中心基本重合，且提示在分组标题右侧。
    expect(hint.center.dy, closeTo(groupLabel.center.dy, 8));
    expect(hint.left, greaterThan(groupLabel.right));
    // 页码也在这一行。
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('portrait also merges the hint into the group row', (
    tester,
  ) async {
    await _openBoard(tester, const Size(402, 874));

    final groupLabel = tester.getRect(find.text('看板分组'));
    final hint = tester.getRect(find.text('左右滑动切换分组'));

    expect(hint.center.dy, closeTo(groupLabel.center.dy, 8));
    expect(hint.left, greaterThan(groupLabel.right));
    expect(find.text('1/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
