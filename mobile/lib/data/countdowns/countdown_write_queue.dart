import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DoNothing, OrderingTerm, Value;
import 'package:path/path.dart' as p;

import '../storage_paths.dart';
import '../db/local_database.dart';

class CountdownPendingOp {
  const CountdownPendingOp({
    required this.opId,
    required this.action,
    required this.countdownId,
    this.payload,
    required this.createdAt,
  });

  final String opId;

  /// One of `create`, `update`, `delete`.
  final String action;

  /// Negative ids are client-issued temp ids for unsynced creates.
  final int countdownId;

  /// Full countdown draft fields; also used to render pending items offline.
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'opId': opId,
    'action': action,
    'countdownId': countdownId,
    if (payload != null) 'payload': payload,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory CountdownPendingOp.fromJson(Map<String, dynamic> json) =>
      CountdownPendingOp(
        opId: (json['opId'] ?? '').toString(),
        action: (json['action'] ?? '').toString(),
        countdownId: json['countdownId'] is num
            ? (json['countdownId'] as num).toInt()
            : int.tryParse(json['countdownId']?.toString() ?? '') ?? 0,
        payload: json['payload'] is Map<String, dynamic>
            ? json['payload'] as Map<String, dynamic>
            : null,
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toUtc() ??
            DateTime.now().toUtc(),
      );
}

/// Durable FIFO queue of countdown writes that could not reach the server.
///
/// Same storage and semantics as the habit queue: rows in the shared SQLite
/// database, in insertion order. A countdownId below zero is a client-issued
/// temporary id; it is rewritten to the server id when the pending create
/// replays successfully.
class CountdownWriteQueue {
  CountdownWriteQueue._(this._db, [this._legacyFile]);

  /// Memory-only queue for tests: ops live in the map, no database, no IO.
  factory CountdownWriteQueue.inMemory() => CountdownWriteQueue._(null);

  /// Database-backed queue at an explicit path for tests.
  factory CountdownWriteQueue.forPath(
    String dbPath, {
    File? legacyFile,
    bool ownsDatabase = true,
  }) => CountdownWriteQueue._(
    ownsDatabase ? AppDatabase.file(dbPath) : sharedAppDatabase(dbPath),
    legacyFile,
  );

  Future<void> close() async => _db?.close();

  static CountdownWriteQueue? _shared;

  static Future<CountdownWriteQueue> shared() async {
    final existing = _shared;
    if (existing != null) return existing;
    final directory = await appStorageDirectory();
    final queue = CountdownWriteQueue._(
      sharedAppDatabase(p.join(directory.path, 'caldav_free.db')),
      File(p.join(directory.path, 'caldav_countdown_queue.json')),
    );
    await queue._ensureLoaded();
    _shared = queue;
    return queue;
  }

  final AppDatabase? _db;
  final File? _legacyFile;
  final List<CountdownPendingOp> _ops = [];
  Future<void>? _loading;

  bool get isEmpty => _ops.isEmpty;

  Future<void> _ensureLoaded() async {
    if (_db == null) return;
    final inFlight = _loading;
    if (inFlight != null) return inFlight;
    _loading = () async {
      final db = _db;
      for (final row in await (db.select(
        db.countdownOutbox,
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
    List<CountdownPendingOp> imported = const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      final ops = decoded is Map<String, dynamic> ? decoded['ops'] : null;
      if (ops is List) {
        imported = ops
            .whereType<Map<String, dynamic>>()
            .map(CountdownPendingOp.fromJson)
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

  CountdownPendingOp _opFrom(CountdownOutboxRow row) => CountdownPendingOp(
    opId: row.opId,
    action: row.action,
    countdownId: row.countdownId,
    payload: decodeJsonObject(row.payload),
    createdAt: row.createdAt,
  );

  Future<void> _insert(CountdownPendingOp op) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.countdownOutbox)
        .insert(
          CountdownOutboxCompanion.insert(
            opId: op.opId,
            action: Value(op.action),
            countdownId: op.countdownId,
            payload: Value(encodeJsonObject(op.payload)),
            createdAt: Value(op.createdAt),
          ),
          onConflict: DoNothing(),
        );
  }

  Future<void> add(CountdownPendingOp op) async {
    await _ensureLoaded();
    _ops.add(op);
    await _insert(op);
  }

  Future<List<CountdownPendingOp>> items() async {
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
      db.countdownOutbox,
    )..where((row) => row.opId.equals(opId))).go();
  }

  Future<void> replaceCountdownId(int tempId, int realId) async {
    await _ensureLoaded();
    var changed = false;
    for (var i = 0; i < _ops.length; i++) {
      final op = _ops[i];
      if (op.countdownId != tempId) continue;
      _ops[i] = CountdownPendingOp(
        opId: op.opId,
        action: op.action,
        countdownId: realId,
        payload: op.payload,
        createdAt: op.createdAt,
      );
      changed = true;
    }
    if (!changed) return;
    final db = _db;
    if (db == null) return;
    await (db.update(db.countdownOutbox)
          ..where((row) => row.countdownId.equals(tempId)))
        .write(CountdownOutboxCompanion(countdownId: Value(realId)));
  }

  /// Drops every queued op for an unsynced temp countdown (create undone).
  Future<void> cancelTemp(int tempId) async {
    await _ensureLoaded();
    if (tempId >= 0) return;
    final before = _ops.length;
    _ops.removeWhere((op) => op.countdownId == tempId);
    if (_ops.length == before) return;
    final db = _db;
    if (db == null) return;
    await (db.delete(
      db.countdownOutbox,
    )..where((row) => row.countdownId.equals(tempId))).go();
  }

  /// Rewrites the payload of the pending create for a temp countdown.
  /// Returns false when no queued create exists.
  Future<bool> replaceCreatePayload(
    int tempId,
    Map<String, dynamic> payload,
  ) async {
    await _ensureLoaded();
    for (var i = 0; i < _ops.length; i++) {
      final op = _ops[i];
      if (op.action != 'create' || op.countdownId != tempId) continue;
      _ops[i] = CountdownPendingOp(
        opId: op.opId,
        action: op.action,
        countdownId: op.countdownId,
        payload: payload,
        createdAt: op.createdAt,
      );
      final db = _db;
      if (db != null) {
        await (db.update(
          db.countdownOutbox,
        )..where((row) => row.opId.equals(op.opId))).write(
          CountdownOutboxCompanion(payload: Value(encodeJsonObject(payload))),
        );
      }
      return true;
    }
    return false;
  }
}
