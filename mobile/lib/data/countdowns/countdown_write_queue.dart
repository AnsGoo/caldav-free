import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../storage_paths.dart';

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
/// Entries survive app restarts so offline edits sync once connectivity
/// returns. A countdownId below zero is a client-issued temporary id; it is
/// rewritten to the server id when the pending create replays successfully.
class CountdownWriteQueue {
  CountdownWriteQueue._(this._file);

  /// Memory-only queue for tests.
  factory CountdownWriteQueue.inMemory() {
    final queue = CountdownWriteQueue._(null);
    queue._loaded = true;
    return queue;
  }

  /// File-backed queue at an explicit path for tests.
  factory CountdownWriteQueue.forPath(String path) =>
      CountdownWriteQueue._(File(path));

  static CountdownWriteQueue? _shared;

  static Future<CountdownWriteQueue> shared() async {
    final existing = _shared;
    if (existing != null) return existing;
    final file = File(
      p.join((await appStorageDirectory()).path, 'caldav_countdown_queue.json'),
    );
    final queue = CountdownWriteQueue._(file);
    await queue._ensureLoaded();
    _shared = queue;
    return queue;
  }

  final File? _file;
  final List<CountdownPendingOp> _ops = [];

  bool get isEmpty => _ops.isEmpty;

  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      final ops = decoded is Map<String, dynamic> ? decoded['ops'] : null;
      if (ops is List) {
        for (final value in ops.whereType<Map<String, dynamic>>()) {
          final op = CountdownPendingOp.fromJson(value);
          if (op.opId.isNotEmpty && op.action.isNotEmpty) _ops.add(op);
        }
      }
    } catch (_) {
      // A corrupt queue file must not brick the page; start clean.
      _ops.clear();
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({'ops': _ops.map((op) => op.toJson()).toList()}),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  Future<void> add(CountdownPendingOp op) async {
    await _ensureLoaded();
    _ops.add(op);
    await _save();
  }

  Future<List<CountdownPendingOp>> items() async {
    await _ensureLoaded();
    return List.unmodifiable(_ops);
  }

  Future<void> remove(String opId) async {
    await _ensureLoaded();
    final before = _ops.length;
    _ops.removeWhere((op) => op.opId == opId);
    if (_ops.length != before) await _save();
  }

  Future<void> replaceCountdownId(int tempId, int realId) async {
    await _ensureLoaded();
    var changed = false;
    for (var i = 0; i < _ops.length; i++) {
      final op = _ops[i];
      if (op.countdownId == tempId) {
        _ops[i] = CountdownPendingOp(
          opId: op.opId,
          action: op.action,
          countdownId: realId,
          payload: op.payload,
          createdAt: op.createdAt,
        );
        changed = true;
      }
    }
    if (changed) await _save();
  }

  /// Drops every queued op for an unsynced temp countdown (offline create undone).
  Future<void> cancelTemp(int tempId) async {
    await _ensureLoaded();
    if (tempId >= 0) return;
    final before = _ops.length;
    _ops.removeWhere((op) => op.countdownId == tempId);
    if (_ops.length != before) await _save();
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
      if (op.action == 'create' && op.countdownId == tempId) {
        _ops[i] = CountdownPendingOp(
          opId: op.opId,
          action: op.action,
          countdownId: op.countdownId,
          payload: payload,
          createdAt: op.createdAt,
        );
        await _save();
        return true;
      }
    }
    return false;
  }
}
