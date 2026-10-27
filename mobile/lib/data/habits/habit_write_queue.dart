import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DoNothing, OrderingTerm, Value;
import 'package:path/path.dart' as p;

import '../storage_paths.dart';
import '../db/local_database.dart';

class HabitPendingOp {
  const HabitPendingOp({
    required this.opId,
    required this.action,
    required this.habitId,
    this.payload,
    this.stamp,
    required this.createdAt,
  });

  final String opId;
  final String action;
  final int habitId;
  final Map<String, dynamic>? payload;
  final int? stamp;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'opId': opId,
    'action': action,
    'habitId': habitId,
    if (payload != null) 'payload': payload,
    if (stamp != null) 'stamp': stamp,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory HabitPendingOp.fromJson(Map<String, dynamic> json) => HabitPendingOp(
    opId: (json['opId'] ?? '').toString(),
    action: (json['action'] ?? '').toString(),
    habitId: json['habitId'] is num
        ? (json['habitId'] as num).toInt()
        : int.tryParse(json['habitId']?.toString() ?? '') ?? 0,
    payload: json['payload'] is Map<String, dynamic>
        ? json['payload'] as Map<String, dynamic>
        : null,
    stamp: json['stamp'] is num ? (json['stamp'] as num).toInt() : null,
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
  );
}

/// Durable FIFO queue of habit writes that could not reach the server.
///
/// Entries live in the same SQLite database as the task data, in insertion
/// order, and survive app restarts so offline edits sync once connectivity
/// returns. A habitId below zero is a client-issued temporary id; it is
/// rewritten to the server id when the pending create replays successfully.
class HabitWriteQueue {
  HabitWriteQueue._(this._db, [this._legacyFile]);

  /// Memory-only queue for tests.
  factory HabitWriteQueue.inMemory() =>
      HabitWriteQueue._(AppDatabase.memory());

  /// Database-backed queue at an explicit path for tests.
  factory HabitWriteQueue.forPath(
    String dbPath, {
    File? legacyFile,
    bool ownsDatabase = true,
  }) =>
      HabitWriteQueue._(
        ownsDatabase ? AppDatabase.file(dbPath) : sharedAppDatabase(dbPath),
        legacyFile,
      );

  Future<void> close() => _db.close();

  static HabitWriteQueue? _shared;

  static Future<HabitWriteQueue> shared() async {
    final existing = _shared;
    if (existing != null) return existing;
    final directory = await appStorageDirectory();
    final queue = HabitWriteQueue._(
      sharedAppDatabase(p.join(directory.path, 'caldav_free.db')),
      File(p.join(directory.path, 'caldav_habit_queue.json')),
    );
    await queue._ensureLoaded();
    _shared = queue;
    return queue;
  }

  final AppDatabase _db;
  final File? _legacyFile;
  final List<HabitPendingOp> _ops = [];
  Future<void>? _loading;

  bool get isEmpty => _ops.isEmpty;

  Future<void> _ensureLoaded() async {
    final inFlight = _loading;
    if (inFlight != null) return inFlight;
    _loading = () async {
      for (final row in await (_db.select(
        _db.habitOutbox,
      )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get()) {
        final op = _opFrom(row);
        if (op.opId.isNotEmpty && op.action.isNotEmpty) _ops.add(op);
      }
      await _importLegacyFile();
    }();
    return _loading;
  }

  /// One-time upgrade from the pre-SQLite JSON queue file.
  Future<void> _importLegacyFile() async {
    final file = _legacyFile;
    if (file == null || _ops.isNotEmpty || !await file.exists()) return;
    List<HabitPendingOp> imported = const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      final ops = decoded is Map<String, dynamic> ? decoded['ops'] : null;
      if (ops is List) {
        imported = ops
            .whereType<Map<String, dynamic>>()
            .map(HabitPendingOp.fromJson)
            .where((op) => op.opId.isNotEmpty && op.action.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // A corrupt queue file must not brick the page; keep it aside.
    }
    for (final op in imported) {
      _ops.add(op);
      await _insert(op);
    }
    if (imported.isEmpty) return;
    try {
      await file.rename('${file.path}.migrated.bak');
    } on FileSystemException {
      // Another process claimed the import; the rows are already in SQLite.
    }
  }

  HabitPendingOp _opFrom(HabitOutboxRow row) => HabitPendingOp(
    opId: row.opId,
    action: row.action,
    habitId: row.habitId,
    payload: decodeJsonObject(row.payload),
    stamp: row.stamp,
    createdAt: row.createdAt,
  );

  Future<void> _insert(HabitPendingOp op) => _db
      .into(_db.habitOutbox)
      .insert(
        HabitOutboxCompanion.insert(
          opId: op.opId,
          action: Value(op.action),
          habitId: op.habitId,
          payload: Value(encodeJsonObject(op.payload)),
          stamp: Value(op.stamp),
          createdAt: Value(op.createdAt),
        ),
        onConflict: DoNothing(),
      );

  Future<void> add(HabitPendingOp op) async {
    await _ensureLoaded();
    _ops.add(op);
    await _insert(op);
  }

  Future<List<HabitPendingOp>> items() async {
    await _ensureLoaded();
    return List.unmodifiable(_ops);
  }

  Future<void> remove(String opId) async {
    await _ensureLoaded();
    final before = _ops.length;
    _ops.removeWhere((op) => op.opId == opId);
    if (_ops.length == before) return;
    await (_db.delete(_db.habitOutbox)
          ..where((row) => row.opId.equals(opId)))
        .go();
  }

  Future<void> replaceHabitId(int tempId, int realId) async {
    await _ensureLoaded();
    var changed = false;
    for (var i = 0; i < _ops.length; i++) {
      final op = _ops[i];
      if (op.habitId != tempId) continue;
      _ops[i] = HabitPendingOp(
        opId: op.opId,
        action: op.action,
        habitId: realId,
        payload: op.payload,
        stamp: op.stamp,
        createdAt: op.createdAt,
      );
      changed = true;
    }
    if (!changed) return;
    await (_db.update(_db.habitOutbox)
          ..where((row) => row.habitId.equals(tempId)))
        .write(HabitOutboxCompanion(habitId: Value(realId)));
  }

  /// Drops every queued op for an unsynced temp habit (offline create undone).
  Future<void> cancelTemp(int tempId) async {
    await _ensureLoaded();
    if (tempId >= 0) return;
    final before = _ops.length;
    _ops.removeWhere((op) => op.habitId == tempId);
    if (_ops.length == before) return;
    await (_db.delete(_db.habitOutbox)
          ..where((row) => row.habitId.equals(tempId)))
        .go();
  }

  /// Rewrites the payload of the pending create for a temp habit. Returns
  /// false when no queued create exists.
  Future<bool> replaceCreatePayload(
    int tempId,
    Map<String, dynamic> payload,
  ) async {
    await _ensureLoaded();
    for (var i = 0; i < _ops.length; i++) {
      final op = _ops[i];
      if (op.action != 'create' || op.habitId != tempId) continue;
      _ops[i] = HabitPendingOp(
        opId: op.opId,
        action: op.action,
        habitId: op.habitId,
        payload: payload,
        stamp: op.stamp,
        createdAt: op.createdAt,
      );
      await (_db.update(_db.habitOutbox)
            ..where((row) => row.opId.equals(op.opId)))
          .write(
            HabitOutboxCompanion(payload: Value(encodeJsonObject(payload))),
          );
      return true;
    }
    return false;
  }
}
