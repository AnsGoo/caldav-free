import 'dart:io';

import 'package:caldav_free/data/countdowns/countdown_api.dart';
import 'package:caldav_free/data/countdowns/countdown_store.dart';
import 'package:caldav_free/data/countdowns/countdown_write_queue.dart';
import 'package:caldav_free/data/db/local_database.dart';
import 'package:caldav_free/data/focus/focus_api.dart';
import 'package:caldav_free/data/focus/focus_store.dart';
import 'package:caldav_free/data/focus/focus_write_queue.dart';
import 'package:caldav_free/data/habits/habit_api.dart';
import 'package:caldav_free/data/habits/habit_store.dart';
import 'package:caldav_free/data/habits/habit_write_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serverHabit = HabitItem(
    id: 11,
    name: '读书',
    icon: 'book',
    color: '#22c55e',
    sectionId: 3,
    goal: 20,
    step: 5,
    unit: 'Minute',
    frequency: '{"type":"daily"}',
    status: 0,
    dueToday: true,
    doneToday: false,
    currentStreak: 4,
    maxStreak: 9,
    totalCheckIns: 31,
    targetDays: 100,
    completedCycles: 0,
    startDate: 20260901,
  );

  final serverCountdown = CountdownItem(
    id: 5,
    name: '新年',
    type: 'festival',
    date: 20270101,
    repeat: 'yearly',
    pinned: true,
    status: 0,
    color: '#66BB6A',
    icon: '⏳',
    remark: '一起跨年',
    days: 68,
    hours: 0,
    minutes: 0,
    seconds: 0,
    state: 'future',
    occurrenceDate: 20270101,
    age: 0,
  );

  test('habit mirror survives reopening the database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'caldav-habit-mirror',
    );
    final dbPath = '${directory.path}/caldav_free.db';
    final store = await HabitStore.open(
      database: sharedAppDatabase(dbPath),
      queue: HabitWriteQueue.forPath(dbPath, ownsDatabase: false),
    );
    await store.replaceMirror(
      const HabitSnapshot(
        habits: [serverHabit],
        checkins: [
          HabitCheckinItem(
            habitId: 11,
            stamp: 20261020,
            value: 20,
            goal: 20,
            status: 2,
          ),
        ],
        sections: [
          {'id': 3, 'name': '早晨', 'sortOrder': 1},
        ],
        preferences: {'sortType': 'custom'},
      ),
    );
    await store.create(const HabitDraft(name: '跑步', color: '#FF0000'));
    expect(store.snapshot.habits, hasLength(2));
    await closeSharedAppDatabase();

    final reopened = await HabitStore.open(
      database: sharedAppDatabase(dbPath),
      queue: HabitWriteQueue.forPath(dbPath, ownsDatabase: false),
    );
    final snapshot = reopened.snapshot;
    expect(
      snapshot.habits.map((habit) => habit.name),
      containsAll(['读书', '跑步']),
    );
    expect(snapshot.habits.firstWhere((h) => h.name == '读书').currentStreak, 4);
    expect(snapshot.checkins.single.stamp, 20261020);
    expect(snapshot.sections.single['name'], '早晨');
    expect(snapshot.preferences['sortType'], 'custom');
    await closeSharedAppDatabase();
    await directory.delete(recursive: true);
  });

  test(
    'a pushed habit leaves the overlay once the mirror has the real row',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'caldav-habit-sync',
      );
      final dbPath = '${directory.path}/caldav_free.db';
      final queue = HabitWriteQueue.forPath(dbPath, ownsDatabase: false);
      final store = await HabitStore.open(
        database: sharedAppDatabase(dbPath),
        queue: queue,
      );
      final created = await store.create(
        const HabitDraft(name: '跑步', color: '#FF0000'),
      );
      expect(created.id, lessThan(0));
      expect(store.snapshot.habits.single.id, created.id);

      // The background pass replays the queue, then refreshes the mirror with
      // the server row; the temp overlay must not linger next to the real one.
      await queue.replaceHabitId(created.id, 42);
      for (final op in await queue.items()) {
        await queue.remove(op.opId);
      }
      await store.replaceMirror(
        HabitSnapshot(
          habits: [
            HabitItem(
              id: 42,
              name: '跑步',
              icon: '',
              color: '#FF0000',
              sectionId: 0,
              goal: 1,
              step: 1,
              unit: 'Count',
              frequency: '{"type":"daily"}',
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
          checkins: const [],
          sections: const [],
          preferences: const {},
        ),
      );
      expect(store.snapshot.habits.map((habit) => habit.id), [42]);
      await closeSharedAppDatabase();
      await directory.delete(recursive: true);
    },
  );

  test('countdown mirror survives reopening the database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'caldav-countdown-mirror',
    );
    final dbPath = '${directory.path}/caldav_free.db';
    final store = await CountdownStore.open(
      database: sharedAppDatabase(dbPath),
      queue: CountdownWriteQueue.forPath(dbPath, ownsDatabase: false),
    );
    await store.replaceMirror([serverCountdown]);
    final pending = await store.create(
      CountdownDraft(
        name: '旅行',
        date: DateTime(2026, 12, 24),
        type: 'countdown',
        repeat: 'none',
        pinned: false,
        color: '#92D0FF',
        remark: '',
      ),
    );
    expect(store.items, hasLength(2));

    final reopened = await CountdownStore.open(
      database: sharedAppDatabase(dbPath),
      queue: CountdownWriteQueue.forPath(dbPath, ownsDatabase: false),
    );
    final items = reopened.items;
    expect(items.map((item) => item.name), containsAll(['新年', '旅行']));
    expect(items.firstWhere((item) => item.name == '新年').days, 68);
    expect(items.firstWhere((item) => item.id == pending.id).pinned, isFalse);
    expect(reopened.hasMirror, isTrue);
    await closeSharedAppDatabase();
    await directory.delete(recursive: true);
  });

  test('focus mirror survives reopening the database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'caldav-focus-mirror',
    );
    final dbPath = '${directory.path}/caldav_free.db';
    final store = await FocusStore.open(
      database: sharedAppDatabase(dbPath),
      queue: FocusWriteQueue.forPath(dbPath, ownsDatabase: false),
    );
    await store.replaceMirror(
      FocusDash(
        preferences: const FocusPreferences(dailyGoal: 6),
        stats: const FocusStats(totalFocusMinutes: 120),
        sessions: [
          FocusSession(
            id: 3,
            title: '专注',
            mode: 'pomodoro',
            startedAt: DateTime.now(),
            endedAt: DateTime.now(),
            durationSeconds: 1500,
            pomodoroCount: 1,
          ),
        ],
      ),
    );
    await store.saveSession(
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      durationSeconds: 600,
    );
    expect(store.sessions, hasLength(2));
    await closeSharedAppDatabase();

    final reopened = await FocusStore.open(
      database: sharedAppDatabase(dbPath),
      queue: FocusWriteQueue.forPath(dbPath, ownsDatabase: false),
    );
    expect(reopened.sessions, hasLength(2));
    expect(reopened.sessions.first.durationSeconds, anyOf(1500, 600));
    expect(reopened.preferences.dailyGoal, 6);
    // Totals come from the cached server aggregate, today from the rows.
    expect(reopened.stats.totalFocusMinutes, 120);
    expect(reopened.stats.todayFocusSeconds, 2100);
    expect(reopened.stats.goal, 6);
    await closeSharedAppDatabase();
    await directory.delete(recursive: true);
  });

  test('clearing the mirror drops cached server rows', () async {
    final store = HabitStore.inMemory();
    await store.replaceMirror(
      const HabitSnapshot(
        habits: [serverHabit],
        checkins: [],
        sections: [],
        preferences: {},
      ),
    );
    expect(store.hasMirror, isTrue);
    await store.clearMirror();
    expect(store.hasMirror, isFalse);
    expect(store.snapshot.habits, isEmpty);
  });
}
