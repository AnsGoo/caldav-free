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

Future<void> _pumpLandscape(WidgetTester tester, FakeViewPadding padding) async {
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

  tester.view.physicalSize = const Size(2622, 1206); // 874 x 402
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = padding;
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
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  // 刘海可能在左侧也可能在右侧；快速添加条两种方向都应铺到屏幕右边缘。
  for (final (name, padding) in [
    ('notch on the left', const FakeViewPadding(left: 59 * 3, bottom: 21 * 3)),
    ('notch on the right', const FakeViewPadding(right: 59 * 3, bottom: 21 * 3)),
  ]) {
    testWidgets('quick add bar fills the width with $name', (tester) async {
      await _pumpLandscape(tester, padding);

      final send = tester.getRect(find.byTooltip('添加任务'));
      // 12dp 外边距 + 6dp 容器内边距 ≈ 18dp，再加按钮自身的视觉留白。
      expect(874 - send.right, closeTo(22, 1.5));
      expect(send.width, closeTo(40, 0.6));
    });
  }
}
