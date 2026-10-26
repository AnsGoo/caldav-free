import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../storage_paths.dart';

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
/// Entries survive app restarts so offline edits sync once connectivity
/// returns. A habitId below zero is a client-issued temporary id; it is
/// rewritten to the server id when the pending create replays successfully.
class HabitWriteQueue {
  HabitWriteQueue._(this._file);

  /// Memory-only queue for tests.
  factory HabitWriteQueue.inMemory() {
    final queue = HabitWriteQueue._(null);
    queue._loaded = true;
    return queue;
  }

  /// File-backed queue at an explicit path for tests.
  factory HabitWriteQueue.forPath(String path) =>
      HabitWriteQueue._(File(path));

  static HabitWriteQueue? _shared;

  static Future<HabitWriteQueue> shared() async {
    final existing = _shared;
    if (existing != null) return existing;
    final file = File(p.join((await appStorageDirectory()).path, 'caldav_habit_queue.json'));
    final queue = HabitWriteQueue._(file);
    await queue._ensureLoaded();
    _shared = queue;
    return queue;
  }

  final File? _file;
  final List<HabitPendingOp> _ops = [];

  bool get isEmpty => _ops.isEmpty;

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
          final op = HabitPendingOp.fromJson(value);
          if (op.opId.isNotEmpty && op.action.isNotEmpty) _ops.add(op);
        }
      }
    } catch (_) {
      // A corrupt queue file must not brick the page; start clean.
      _ops.clear();
    }
  }

  bool _loaded = false;

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

  Future<void> add(HabitPendingOp op) async {
    await _ensureLoaded();
    _ops.add(op);
    await _save();
  }

  Future<List<HabitPendingOp>> items() async {
    await _ensureLoaded();
    return List.unmodifiable(_ops);
  }

  Future<void> remove(String opId) async {
    await _ensureLoaded();
    final before = _ops.length;
    _ops.removeWhere((op) => op.opId == opId);
    if (_ops.length != before) await _save();
  }

  Future<void> replaceHabitId(int tempId, int realId) async {
    await _ensureLoaded();
    var changed = false;
    for (var i = 0; i < _ops.length; i++) {
      final op = _ops[i];
      if (op.habitId == tempId) {
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
    }
    if (changed) await _save();
  }

  /// Drops every queued op for an unsynced temp habit (offline create undone).
  Future<void> cancelTemp(int tempId) async {
    await _ensureLoaded();
    if (tempId >= 0) return;
    final before = _ops.length;
    _ops.removeWhere((op) => op.habitId == tempId);
    if (_ops.length != before) await _save();
  }

  /// Rewrites the payload of the pending create for a temp habit. Returns
  /// false when no queued create exists.
  Future<bool> replaceCreatePayload(int tempId, Map<String, dynamic> payload) async {
    await _ensureLoaded();
    for (var i = 0; i < _ops.length; i++) {
      final op = _ops[i];
      if (op.action == 'create' && op.habitId == tempId) {
        _ops[i] = HabitPendingOp(
          opId: op.opId,
          action: op.action,
          habitId: op.habitId,
          payload: payload,
          stamp: op.stamp,
          createdAt: op.createdAt,
        );
        await _save();
        return true;
      }
    }
    return false;
  }
}
