import 'package:caldav_free/app_state.dart';
import 'package:caldav_free/data/countdowns/countdown_api.dart';
import 'package:caldav_free/data/countdowns/countdown_store.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/habits/habit_api.dart';
import 'package:caldav_free/data/habits/habit_store.dart';
import 'package:caldav_free/data/session/credentials.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:caldav_free/features/countdowns/countdown_page.dart';
import 'package:caldav_free/features/habits/habits_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<AppState> pump(
    WidgetTester tester,
    Widget page, {
    required HabitStore habits,
    required CountdownStore countdowns,
  }) async {
    final store = LocalStore.memory();
    final app = AppState(
      store: store,
      credentials: MemoryCredentialsStore(),
      repository: TaskRepository(store),
      habits: habits,
      countdowns: countdowns,
    );
    addTearDown(() async {
      app.dispose();
      await store.dispose();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(home: page),
      ),
    );
    return app;
  }

  testWidgets('habits page paints local data with no server session', (tester) async {
    final habits = HabitStore.inMemory();
    await habits.create(const HabitDraft(name: '跑步', color: '#FF0000'));
    await pump(tester, const HabitsPage(), habits: habits, countdowns: CountdownStore.inMemory());

    expect(find.text('跑步'), findsOneWidget);
    // The only spinner on this page is a habit card's progress ring; nothing
    // may block the first frame on a network round-trip.
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('服务未连接'), findsNothing);
  });

  testWidgets('habits page repaints when the background mirror refresh lands', (tester) async {
    final habits = HabitStore.inMemory();
    await pump(
      tester,
      const HabitsPage(),
      habits: habits,
      countdowns: CountdownStore.inMemory(),
    );
    expect(find.text('还没有习惯'), findsOneWidget);

    await habits.replaceMirror(
      const HabitSnapshot(
        habits: [
          HabitItem(
            id: 7,
            name: '冥想',
            icon: '',
            color: '#22c55e',
            sectionId: 0,
            goal: 1,
            step: 1,
            unit: 'Count',
            frequency: '{}',
            status: 0,
            dueToday: true,
            doneToday: false,
            currentStreak: 0,
            maxStreak: 0,
            totalCheckIns: 0,
            targetDays: 0,
            completedCycles: 0,
            startDate: 0,
          ),
        ],
        checkins: [],
        sections: [],
        preferences: {},
      ),
    );
    await tester.pump();

    expect(find.text('冥想'), findsOneWidget);
    expect(find.text('还没有习惯'), findsNothing);
  });

  testWidgets('countdown page paints local data with no server session', (tester) async {
    final countdowns = CountdownStore.inMemory();
    await countdowns.create(
      CountdownDraft(
        name: '新年',
        date: DateTime(2027, 1, 1),
        type: 'festival',
        repeat: 'yearly',
        pinned: false,
        color: '#66BB6A',
        remark: '',
      ),
    );
    await pump(
      tester,
      const CountdownPage(),
      habits: HabitStore.inMemory(),
      countdowns: countdowns,
    );

    expect(find.text('新年'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('尚未配置服务器'), findsNothing);
  });
}
