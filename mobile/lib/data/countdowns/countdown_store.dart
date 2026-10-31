import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show DoUpdate;
import 'package:flutter/foundation.dart';

import '../../core/ids.dart';
import '../db/local_database.dart';
import 'countdown_api.dart';
import 'countdown_write_queue.dart';

/// Countdown data as the app sees it: a SQLite mirror of the server rows plus
/// the durable queue of local writes not yet pushed.
///
/// Reads are synchronous and network-free so the countdown page renders its
/// first frame from local data; the background sync pass calls
/// [replaceMirror].
class CountdownStore extends ChangeNotifier {
  CountdownStore._(this._db, this._queue);

  static Future<CountdownStore> open({
    AppDatabase? database,
    CountdownWriteQueue? queue,
  }) async {
    final store = CountdownStore._(
      database,
      queue ?? await CountdownWriteQueue.shared(),
    );
    await store._ensureLoaded();
    return store;
  }

  factory CountdownStore.inMemory({CountdownWriteQueue? queue}) {
    final store = CountdownStore._(
      null,
      queue ?? CountdownWriteQueue.inMemory(),
    );
    store._loaded = true;
    return store;
  }

  final AppDatabase? _db;
  final CountdownWriteQueue _queue;

  /// Asked to schedule the background sync pass after a local write. Set by
  /// the app wiring; the store itself never touches the network.
  void Function()? onLocalWrite;

  List<CountdownItem> _items = const [];
  List<CountdownPendingOp> _ops = const [];
  bool _loaded = false;
  Future<void>? _loading;

  List<CountdownItem> get items => _overlay(_items);

  bool get hasMirror => _items.isNotEmpty;

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
    _items = (await db.select(db.countdowns).get())
        .map((row) => row.toModel())
        .toList(growable: false);
  }

  // ------------------------------------------------------------- local writes

  Future<CountdownItem> create(CountdownDraft draft) async {
    final tempId =
        -(DateTime.now().microsecondsSinceEpoch * 10 + _random.nextInt(10));
    final payload = draft.toJson();
    await _enqueue(
      CountdownPendingOp(
        opId: newSyncId(),
        action: 'create',
        countdownId: tempId,
        payload: payload,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return CountdownApi.buildOptimisticItem(tempId, payload);
  }

  Future<CountdownItem> update(int id, CountdownDraft draft) async {
    final payload = draft.toJson();
    if (id < 0) {
      final replaced = await _queue.replaceCreatePayload(id, payload);
      if (replaced) {
        await _reloadOps();
        notifyListeners();
      } else {
        await _enqueue(
          CountdownPendingOp(
            opId: newSyncId(),
            action: 'create',
            countdownId: id,
            payload: payload,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    } else {
      await _enqueue(
        CountdownPendingOp(
          opId: newSyncId(),
          action: 'update',
          countdownId: id,
          payload: payload,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    return CountdownApi.buildOptimisticItem(id, payload);
  }

  Future<void> delete(int id) async {
    if (id < 0) {
      await _queue.cancelTemp(id);
      await _reloadOps();
      notifyListeners();
      return;
    }
    await _enqueue(
      CountdownPendingOp(
        opId: newSyncId(),
        action: 'delete',
        countdownId: id,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _enqueue(CountdownPendingOp op) async {
    await _queue.add(op);
    await _reloadOps();
    notifyListeners();
    onLocalWrite?.call();
  }

  Future<void> _reloadOps() async {
    _ops = await _queue.items();
  }

  // -------------------------------------------------------------- background

  Future<void> replaceMirror(List<CountdownItem> server) async {
    _items = server;
    await _reloadOps();
    final db = _db;
    if (db != null) {
      await db.transaction(() async {
        await db.delete(db.countdowns).go();
        for (final item in server) {
          final row = item.toRow();
          await db
              .into(db.countdowns)
              .insert(row, onConflict: DoUpdate((_) => row));
        }
      });
    }
    notifyListeners();
  }

  Future<void> clearMirror() async {
    _items = const [];
    final db = _db;
    if (db != null) await db.delete(db.countdowns).go();
    notifyListeners();
  }

  /// Queue ops are replayed in FIFO order, so overlaying an already overlaid
  /// list stays idempotent and never duplicates a pending item.
  List<CountdownItem> _overlay(List<CountdownItem> base) {
    if (_ops.isEmpty) return base;
    final byId = <int, CountdownItem>{
      for (final item in base)
        if (!item.id.isNegative) item.id: item,
    };
    for (final op in _ops) {
      switch (op.action) {
        case 'delete':
          byId.remove(op.countdownId);
        case 'update':
          final payload = op.payload;
          if (payload == null) continue;
          final existing = byId[op.countdownId];
          byId[op.countdownId] = existing == null
              ? CountdownApi.buildOptimisticItem(op.countdownId, payload)
              : _patched(existing, payload);
        case 'create':
          final payload = op.payload;
          if (payload == null) continue;
          byId[op.countdownId] = CountdownApi.buildOptimisticItem(
            op.countdownId,
            payload,
          );
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return a.occurrenceDate.compareTo(b.occurrenceDate);
      });
    return merged;
  }

  static CountdownItem _patched(
    CountdownItem item,
    Map<String, dynamic> patch,
  ) => CountdownApi.patchedItem(item, patch);

  static final _random = Random.secure();
}

extension CountdownMirrorRow on CountdownItem {
  CountdownRow toRow() => CountdownRow(
    id: id,
    name: name,
    type: type,
    date: date,
    calendar: calendar,
    lunarMonth: lunarMonth,
    lunarDay: lunarDay,
    lunarLeap: lunarLeap,
    lunarYear: lunarYear,
    style: style,
    background: background,
    reminders: jsonEncode(reminders),
    reminderTime: reminderTime,
    ignoreYear: ignoreYear,
    showAge: showAge,
    dateDisplayFormat: dateDisplayFormat,
    daysOption: daysOption,
    hasBackground: hasBackground,
    backgroundUrl: backgroundUrl,
    repeat: repeat,
    pinned: pinned,
    status: status,
    color: color,
    icon: icon,
    remark: remark,
    days: days,
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    state: state,
    occurrenceDate: occurrenceDate,
    age: age,
  );
}

extension CountdownMirrorModel on CountdownRow {
  CountdownItem toModel() => CountdownItem(
    id: id,
    name: name,
    type: type,
    date: date,
    repeat: repeat,
    pinned: pinned,
    status: status,
    color: color,
    icon: icon,
    remark: remark,
    days: days,
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    state: state,
    occurrenceDate: occurrenceDate,
    age: age,
    calendar: calendar,
    lunarMonth: lunarMonth,
    lunarDay: lunarDay,
    lunarLeap: lunarLeap,
    lunarYear: lunarYear,
    style: style,
    background: background,
    reminders: _decodeReminders(reminders),
    reminderTime: reminderTime,
    ignoreYear: ignoreYear,
    showAge: showAge,
    dateDisplayFormat: dateDisplayFormat,
    daysOption: daysOption,
    hasBackground: hasBackground,
    backgroundUrl: backgroundUrl,
  );
}

List<int> _decodeReminders(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .map((item) => item is int ? item : int.tryParse('$item') ?? 0)
          .toList(growable: false);
    }
  } on FormatException {
    return const <int>[];
  }
  return const <int>[];
}
