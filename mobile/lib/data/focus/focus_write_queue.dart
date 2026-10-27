import 'package:drift/drift.dart' show DoNothing, OrderingTerm, Value;
import 'package:path/path.dart' as p;

import '../db/local_database.dart';
import '../storage_paths.dart';

class FocusPendingOp {
  const FocusPendingOp({
    required this.opId,
    required this.action,
    required this.sessionId,
    this.payload,
    required this.createdAt,
  });

  final String opId;

  /// One of `create`, `delete`.
  final String action;

  /// Negative ids are client-issued temp ids for unsynced records.
  final int sessionId;

  /// Full session fields; also used to render the record before it is pushed.
  final Map<String, dynamic>? payload;
  final DateTime createdAt;
}

/// Durable FIFO queue of focus writes that have not reached the server yet.
///
/// Same storage and semantics as the countdown queue: rows in the shared
/// SQLite database, in insertion order. A sessionId below zero is a
/// client-issued temporary id, rewritten to the server id when the pending
/// create replays successfully.
class FocusWriteQueue {
  FocusWriteQueue._(this._db);

  /// Memory-only queue for tests: ops live in the map, no database, no IO.
  factory FocusWriteQueue.inMemory() => FocusWriteQueue._(null);

  /// Database-backed queue at an explicit path for tests.
  factory FocusWriteQueue.forPath(String dbPath, {bool ownsDatabase = true}) =>
      FocusWriteQueue._(
        ownsDatabase ? AppDatabase.file(dbPath) : sharedAppDatabase(dbPath),
      );

  Future<void> close() async => _db?.close();

  static FocusWriteQueue? _shared;

  static Future<FocusWriteQueue> shared() async {
    final existing = _shared;
    if (existing != null) return existing;
    final directory = await appStorageDirectory();
    final queue = FocusWriteQueue._(
      sharedAppDatabase(p.join(directory.path, 'caldav_free.db')),
    );
    await queue._ensureLoaded();
    _shared = queue;
    return queue;
  }

  final AppDatabase? _db;
  final List<FocusPendingOp> _ops = [];
  Future<void>? _loading;

  bool get isEmpty => _ops.isEmpty;

  Future<void> _ensureLoaded() async {
    if (_db == null) return;
    final inFlight = _loading;
    if (inFlight != null) return inFlight;
    _loading = () async {
      final db = _db;
      for (final row in await (db.select(
        db.focusOutbox,
      )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get()) {
        _ops.add(_opFrom(row));
      }
    }();
    return _loading;
  }

  FocusPendingOp _opFrom(FocusOutboxRow row) => FocusPendingOp(
    opId: row.opId,
    action: row.action,
    sessionId: row.sessionId,
    payload: decodeJsonObject(row.payload),
    createdAt: row.createdAt,
  );

  Future<void> _insert(FocusPendingOp op) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.focusOutbox)
        .insert(
          FocusOutboxCompanion.insert(
            opId: op.opId,
            action: Value(op.action),
            sessionId: op.sessionId,
            payload: Value(encodeJsonObject(op.payload)),
            createdAt: Value(op.createdAt),
          ),
          onConflict: DoNothing(),
        );
  }

  Future<void> add(FocusPendingOp op) async {
    await _ensureLoaded();
    _ops.add(op);
    await _insert(op);
  }

  Future<List<FocusPendingOp>> items() async {
    await _ensureLoaded();
    return List.unmodifiable(_ops);
  }

  Future<void> remove(String opId) async {
    await _ensureLoaded();
    final before = _ops.length;
    _ops.removeWhere((op) => op.opId == opId);
    if (_ops.length == before) return;
    final db = _db;
    if (db == null) return;
    await (db.delete(
      db.focusOutbox,
    )..where((row) => row.opId.equals(opId))).go();
  }

  Future<void> replaceSessionId(int tempId, int realId) async {
    await _ensureLoaded();
    var changed = false;
    for (var i = 0; i < _ops.length; i++) {
      final op = _ops[i];
      if (op.sessionId != tempId) continue;
      _ops[i] = FocusPendingOp(
        opId: op.opId,
        action: op.action,
        sessionId: realId,
        payload: op.payload,
        createdAt: op.createdAt,
      );
      changed = true;
    }
    if (!changed) return;
    final db = _db;
    if (db == null) return;
    await (db.update(db.focusOutbox)
          ..where((row) => row.sessionId.equals(tempId)))
        .write(FocusOutboxCompanion(sessionId: Value(realId)));
  }

  /// Drops every queued op for an unsynced temp session (record discarded
  /// before it ever reached the server).
  Future<void> cancelTemp(int tempId) async {
    await _ensureLoaded();
    if (tempId >= 0) return;
    final before = _ops.length;
    _ops.removeWhere((op) => op.sessionId == tempId);
    if (_ops.length == before) return;
    final db = _db;
    if (db == null) return;
    await (db.delete(
      db.focusOutbox,
    )..where((row) => row.sessionId.equals(tempId))).go();
  }
}
