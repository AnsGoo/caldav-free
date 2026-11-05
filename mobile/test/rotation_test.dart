import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/core/ui_utils.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/design/app_theme.dart';
import 'package:caldav_free/design/components.dart';
import 'package:caldav_free/features/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _destinations = [
  AppNavDestination(
    icon: Icons.checklist_rounded,
    selectedIcon: Icons.checklist_rtl_rounded,
    label: '任务',
  ),
  AppNavDestination(
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    label: '日历',
  ),
];

Future<void> _pumpShell(
  WidgetTester tester,
  Size size, {
  FakeViewPadding? padding,
}) async {
  final store = LocalStore.memory();
  final now = DateTime.now().toUtc();
  await store.saveList(
    TaskListItem(id: 'inbox-1', name: '收集箱', isInbox: true, updatedAt: now),
  );
  final app =
      AppState(
          store: store,
          credentials: MemoryCredentialsStore(),
          repository: TaskRepository(store),
        )
        ..session = Session(
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

void main() {
  testWidgets('the side rail survives a landscape phone height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(914, 411)),
          child: Scaffold(
            body: Row(
              children: [
                AppSideNav(
                  index: 1,
                  destinations: _destinations,
                  onSelected: (_) {},
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('任务'), findsOneWidget);
    expect(find.bySemanticsLabel('日历'), findsOneWidget);
  });

  testWidgets('landscape swaps the bottom bar for the rail', (tester) async {
    await _pumpShell(tester, const Size(2400, 1080));

    expect(find.byType(AppSideNav), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });

  testWidgets('landscape title sits above the list pane like other pages', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(2400, 1080)); // 800 x 360 logical

    final rail = tester.getRect(find.byType(AppSideNav));
    final title = tester.getRect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first,
    );

    // 所有页面统一：标题紧贴图标栏 20dp，位于清单面板上方。
    expect(title.left, closeTo(rail.right + 20, 0.6));
  });

  testWidgets('landscape safe area is consumed once by the rail', (
    tester,
  ) async {
    // iPhone 横屏：左侧刘海安全区约 59dp。侧栏已经用 SafeArea 占用这段空间，
    // 页面若再吃一次，标题会整体右移一个刘海宽度。
    await _pumpShell(
      tester,
      const Size(2622, 1206),
      padding: const FakeViewPadding(left: 59 * 3, bottom: 21 * 3),
    );

    final rail = tester.getRect(find.byType(AppSideNav));
    final title = tester.getRect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first,
    );

    expect(rail.right, closeTo(59 + 64, 0.6));
    // 标题 = 侧栏右边缘 + 20 缩进，不能再叠加安全区。
    expect(title.left, closeTo(rail.right + 20, 0.6));
  });

  testWidgets('every page title lines up in landscape', (tester) async {
    await _pumpShell(
      tester,
      const Size(2622, 1206),
      padding: const FakeViewPadding(left: 59 * 3, bottom: 21 * 3),
    );

    final rail = tester.getRect(find.byType(AppSideNav));
    const tabs = [
      (Icons.calendar_month_outlined, '日历'),
      (Icons.local_fire_department_outlined, '习惯'),
      (Icons.timer_outlined, '专注'),
      (Icons.hourglass_bottom_rounded, '倒数日'),
      (Icons.summarize_outlined, '摘要'),
      (Icons.checklist_rounded, '任务'),
    ];

    for (final (icon, label) in tabs) {
      await tester.tap(find.byIcon(icon).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final title = tester.getRect(
        find.descendant(of: find.byType(AppBar), matching: find.text(label)),
      );

      expect(
        title.left,
        closeTo(rail.right + 20, 0.6),
        reason: '$label 的标题没有和其他页面对齐',
      );
    }
  });

  testWidgets('portrait keeps the bottom bar', (tester) async {
    await _pumpShell(tester, const Size(1080, 2400));

    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.byType(AppSideNav), findsNothing);
  });

  testWidgets('bottom bar avatar aligns with tab icons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            index: 0,
            destinations: _destinations,
            onSelected: (_) {},
            onSettings: () {},
            userInitial: 'D',
          ),
        ),
      ),
    );

    final avatar = tester.getCenter(find.byTooltip('设置'));
    final icon = tester.getCenter(find.byIcon(Icons.checklist_rtl_rounded));
    expect(avatar.dy, closeTo(icon.dy, 0.1));
  });

  Future<void> pumpTitleProbe(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: Builder(
              builder: (context) => compactAppBarTitle(
                context,
                title: const Text('习惯', key: Key('probe-title')),
                subtitle: const Text('12 项', key: Key('probe-subtitle')),
              ),
            ),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets('landscape puts the subtitle on the title row', (tester) async {
    await pumpTitleProbe(tester, const Size(2400, 1080)); // 800 x 360 logical

    final title = tester.getRect(find.byKey(const Key('probe-title')));
    final subtitle = tester.getRect(find.byKey(const Key('probe-subtitle')));

    // Same line: the subtitle's vertical centre falls inside the title's band.
    expect(subtitle.center.dy, inInclusiveRange(title.top, title.bottom));
    expect(subtitle.left, greaterThan(title.right));
  });

  testWidgets('portrait keeps the subtitle on the title row', (tester) async {
    await pumpTitleProbe(tester, const Size(1080, 2400));

    final title = tester.getRect(find.byKey(const Key('probe-title')));
    final subtitle = tester.getRect(find.byKey(const Key('probe-subtitle')));

    // 同一行：副标题的垂直中心落在标题的行高范围内，且在右侧。
    expect(subtitle.center.dy, inInclusiveRange(title.top, title.bottom));
    expect(subtitle.left, greaterThan(title.right));
  });
}
