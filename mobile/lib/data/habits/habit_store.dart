import 'dart:math';

import 'package:drift/drift.dart' show DoUpdate;
import 'package:flutter/foundation.dart';

import '../../core/ids.dart';
import '../db/local_database.dart';
import 'habit_api.dart';
import 'habit_write_queue.dart';

/// Habit data as the app sees it: a local SQLite mirror of the server rows
/// plus the durable queue of local writes that have not been pushed yet.
///
/// Reads are synchronous and never touch the network; the background sync pass
/// calls [replaceMirror] and local edits go through [HabitWriteQueue]. That is
/// what lets the habits page render offline on the first frame.
class HabitStore extends ChangeNotifier {
  HabitStore._(this._db, this._queue);

  /// Opens the mirror over the shared database. Pass `database: null` (the
  /// task store's in-memory mode) for a mirror that only lives in RAM.
  static Future<HabitStore> open({
    AppDatabase? database,
    HabitWriteQueue? queue,
  }) async {
    final store = HabitStore._(
      database,
      queue ?? await HabitWriteQueue.shared(),
    );
    await store._ensureLoaded();
    return store;
  }

  /// Synchronous memory-only store for widget tests and offline boot.
  factory HabitStore.inMemory({HabitWriteQueue? queue}) {
    final store = HabitStore._(null, queue ?? HabitWriteQueue.inMemory());
    store._loaded = true;
    return store;
  }

  final AppDatabase? _db;
  final HabitWriteQueue _queue;

  /// Asked to schedule the background sync pass after a local write. Set by
  /// the app wiring; the store itself never touches the network.
  void Function()? onLocalWrite;

  List<HabitItem> _habits = const [];
  List<HabitCheckinItem> _checkins = const [];
  List<Map<String, dynamic>> _sections = const [];
  Map<String, dynamic> _preferences = const {};
  List<HabitPendingOp> _ops = const [];
  bool _loaded = false;
  Future<void>? _loading;

  HabitSnapshot get snapshot => _overlay(
    HabitSnapshot(
      habits: _habits,
      checkins: _checkins,
      sections: _sections,
      preferences: _preferences,
    ),
  );

  /// Whether the mirror has ever been filled (drives the page's empty state).
  bool get hasMirror => _habits.isNotEmpty || _sections.isNotEmpty;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final running = _loading;
    if (running != null) return running;
    final task = _load();
    _loading = task;
    try {
      await task;
    } finally {
      _loading = null;
      _loaded = true;
    }
  }

  Future<void> _load() async {
    _ops = await _queue.items();
    final db = _db;
    if (db == null) return;
    final habits = await db.select(db.habits).get();
    final checkins = await db.select(db.habitCheckins).get();
    final sections = await db.select(db.habitSections).get();
    final prefs = await db.metaValue(habitPreferencesKey);
    _habits = habits.map((row) => row.toModel()).toList(growable: false);
    _checkins = checkins.map((row) => row.toModel()).toList(growable: false);
    _sections = [
      for (final row in sections)
        {'id': row.id, 'name': row.name, 'sortOrder': row.sortOrder},
    ];
    final decoded = prefs == null ? null : decodeJsonObject(prefs);
    _preferences = decoded ?? const {};
  }

  // ------------------------------------------------------------- local writes

  Future<HabitItem> create(HabitDraft draft) async {
    final tempId = _newTempId();
    await _enqueue(
      HabitPendingOp(
        opId: newSyncId(),
        action: 'create',
        habitId: tempId,
        payload: draft.toJson(),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return optimisticItem(tempId, draft);
  }

  Future<HabitItem> update(int id, HabitDraft draft) async {
    if (id < 0) {
      final queue = _queue;
      final replaced = await queue.replaceCreatePayload(id, draft.toJson());
      if (replaced) {
        await _reloadOps();
        notifyListeners();
      } else {
        await _enqueue(
          HabitPendingOp(
            opId: newSyncId(),
            action: 'create',
            habitId: id,
            payload: draft.toJson(),
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    } else {
      await _enqueue(
        HabitPendingOp(
          opId: newSyncId(),
          action: 'update',
          habitId: id,
          payload: draft.toJson(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    return optimisticItem(id, draft);
  }

  Future<void> delete(int id) async {
    if (id < 0) {
      await _queue.cancelTemp(id);
      await _reloadOps();
      notifyListeners();
      return;
    }
    await _enqueue(
      HabitPendingOp(
        opId: newSyncId(),
        action: 'delete',
        habitId: id,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> checkin(int id, int stamp) => _enqueue(
    HabitPendingOp(
      opId: newSyncId(),
      action: 'checkin',
      habitId: id,
      stamp: stamp,
      createdAt: DateTime.now().toUtc(),
    ),
  );

  Future<void> _enqueue(HabitPendingOp op) async {
    await _queue.add(op);
    await _reloadOps();
    notifyListeners();
    onLocalWrite?.call();
  }

  Future<void> _reloadOps() async {
    _ops = await _queue.items();
  }

  // -------------------------------------------------------------- background

  /// Replaces the mirror with the server's snapshot. Called by the sync thread
  /// only; local edits that have not been pushed stay in the queue overlay.
  Future<void> replaceMirror(HabitSnapshot server) async {
    _habits = server.habits;
    _checkins = server.checkins;
    _sections = server.sections;
    _preferences = server.preferences;
    await _reloadOps();
    final db = _db;
    if (db != null) {
      await db.transaction(() async {
        await db.delete(db.habits).go();
        for (final habit in _habits) {
          await db
              .into(db.habits)
              .insert(
                habit.toRow(),
                onConflict: DoUpdate((_) => habit.toRow()),
              );
        }
        await db.delete(db.habitCheckins).go();
        for (final checkin in _checkins) {
          await db
              .into(db.habitCheckins)
              .insert(
                checkin.toRow(),
                onConflict: DoUpdate((_) => checkin.toRow()),
              );
        }
        await db.delete(db.habitSections).go();
        for (final section in _sections) {
          final row = HabitSectionRow(
            id: _int(section['id']),
            name: (section['name'] ?? '').toString(),
            sortOrder: _int(section['sortOrder']),
          );
          await db
              .into(db.habitSections)
              .insert(row, onConflict: DoUpdate((_) => row));
        }
        await db.putMeta(habitPreferencesKey, encodeJsonObject(_preferences));
      });
    }
    notifyListeners();
  }

  /// Drops the cached server rows (connecting to a different account).
  Future<void> clearMirror() async {
    _habits = const [];
    _checkins = const [];
    _sections = const [];
    _preferences = const {};
    final db = _db;
    if (db != null) {
      await db.transaction(() async {
        await db.delete(db.habits).go();
        await db.delete(db.habitCheckins).go();
        await db.delete(db.habitSections).go();
        await db.deleteMeta(habitPreferencesKey);
      });
    }
    notifyListeners();
  }

  HabitSnapshot _overlay(HabitSnapshot base) {
    final ops = _ops;
    if (ops.isEmpty) return base;
    final byId = <int, HabitItem>{
      for (final habit in base.habits) habit.id: habit,
    };
    final checkinPatch = <String, double>{};
    final removed = <int>{};
    for (final op in ops) {
      switch (op.action) {
        case 'create':
          final payload = op.payload;
          if (payload != null) {
            byId[op.habitId] = optimisticItem(
              op.habitId,
              HabitDraft.fromJson(payload),
            );
          }
        case 'update':
          final payload = op.payload;
          final existing = byId[op.habitId];
          if (payload != null) {
            final draft = HabitDraft.fromJson(payload);
            byId[op.habitId] = existing == null
                ? optimisticItem(op.habitId, draft)
                : optimisticItem(op.habitId, draft).copyWith(
                    currentStreak: existing.currentStreak,
                    maxStreak: existing.maxStreak,
                    totalCheckIns: existing.totalCheckIns,
                    dueToday: existing.dueToday,
                    doneToday: existing.doneToday,
                  );
          }
        case 'delete':
          byId.remove(op.habitId);
          removed.add(op.habitId);
        case 'checkin':
          final stamp = op.stamp;
          if (stamp != null && !removed.contains(op.habitId)) {
            checkinPatch['${op.habitId}:$stamp'] = 1;
          }
        default:
          continue;
      }
    }
    final checkins = [
      for (final checkin in base.checkins)
        if (!checkinPatch.containsKey('${checkin.habitId}:${checkin.stamp}'))
          checkin,
    ];
    for (final key in checkinPatch.keys) {
      final parts = key.split(':');
      checkins.add(
        HabitCheckinItem(
          habitId: int.parse(parts[0]),
          stamp: int.parse(parts[1]),
          value: 1,
          goal: byId[int.parse(parts[0])]?.goal ?? 1,
          status: 2,
        ),
      );
    }
    final habits = byId.values.toList()
      ..sort((a, b) {
        final order = a.sectionId.compareTo(b.sectionId);
        return order != 0 ? order : a.name.compareTo(b.name);
      });
    return HabitSnapshot(
      habits: habits,
      checkins: checkins,
      sections: base.sections,
      preferences: base.preferences,
    );
  }

  static int _newTempId() =>
      -(DateTime.now().microsecondsSinceEpoch * 10 + _random.nextInt(10));

  static final _random = Random.secure();
}

extension HabitMirrorRow on HabitItem {
  HabitRow toRow() => HabitRow(
    id: id,
    name: name,
    icon: icon,
    color: color,
    sectionId: sectionId,
    status: status,
    goal: goal,
    step: step,
    unit: unit,
    frequency: frequency,
    startDate: startDate,
    targetDays: targetDays,
    completedCycles: completedCycles,
    totalCheckIns: totalCheckIns,
    currentStreak: currentStreak,
    maxStreak: maxStreak,
    dueToday: dueToday,
    doneToday: doneToday,
  );
}

extension HabitMirrorModel on HabitRow {
  HabitItem toModel() => HabitItem(
    id: id,
    name: name,
    icon: icon,
    color: color,
    sectionId: sectionId,
    goal: goal,
    step: step,
    unit: unit,
    frequency: frequency,
    status: status,
    dueToday: dueToday,
    doneToday: doneToday,
    currentStreak: currentStreak,
    maxStreak: maxStreak,
    totalCheckIns: totalCheckIns,
    targetDays: targetDays,
    completedCycles: completedCycles,
    startDate: startDate,
  );
}

extension HabitCheckinMirrorRow on HabitCheckinItem {
  HabitCheckinRow toRow() => HabitCheckinRow(
    habitId: habitId,
    checkinStamp: stamp,
    value: value,
    goal: goal,
    status: status,
  );
}

extension HabitCheckinMirrorModel on HabitCheckinRow {
  HabitCheckinItem toModel() => HabitCheckinItem(
    habitId: habitId,
    stamp: checkinStamp,
    value: value,
    goal: goal,
    status: status,
  );
}

/// A habit built from a draft, used until the server row arrives.
HabitItem optimisticItem(int id, HabitDraft draft) => HabitItem(
  id: id,
  name: draft.name,
  icon: draft.icon,
  color: draft.color,
  sectionId: draft.sectionId,
  goal: draft.goal,
  step: draft.step,
  unit: draft.unit,
  frequency: draft.frequency,
  status: draft.status,
  dueToday: true,
  doneToday: false,
  currentStreak: 0,
  maxStreak: 0,
  totalCheckIns: 0,
  targetDays: draft.targetDays,
  completedCycles: 0,
  startDate: 0,
);

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
