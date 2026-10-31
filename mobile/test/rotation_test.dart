import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
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

Future<void> _pumpShell(WidgetTester tester, Size size) async {
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
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const MaterialApp(home: HomeShell()),
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
}
