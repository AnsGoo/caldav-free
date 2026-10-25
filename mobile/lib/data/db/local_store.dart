import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/models.dart';
import '../storage_paths.dart';
import '../remote/sync_api.dart';

/// A pending local operation. Stored in the same file as the business data so
/// a crash cannot lose the intent to push.
class OutboxRecord {
  const OutboxRecord({
    required this.opId,
    required this.entity,
    required this.entityId,
    required this.action,
    required this.patch,
    required this.attempts,
    required this.nextTryAt,
    required this.createdAt,
    this.baseEtag,
  });

  final String opId;
  final String entity;
  final String entityId;
  final String action;
  final Map<String, dynamic> patch;
  final String? baseEtag;
  final int attempts;
  final DateTime nextTryAt;
  final DateTime createdAt;

  OutboxOp toApiOp() => OutboxOp(
        opId: opId,
        entity: entity,
        entityId: entityId,
        action: action,
        patch: patch,
        baseEtag: baseEtag,
        attempts: attempts,
      );

  OutboxRecord copyWith({
    String? opId,
    String? action,
    Map<String, dynamic>? patch,
    String? baseEtag,
    bool clearBaseEtag = false,
    int? attempts,
    DateTime? nextTryAt,
  }) {
    return OutboxRecord(
      opId: opId ?? this.opId,
      entity: entity,
      entityId: entityId,
      action: action ?? this.action,
      patch: patch ?? this.patch,
      baseEtag: clearBaseEtag ? null : (baseEtag ?? this.baseEtag),
      attempts: attempts ?? this.attempts,
      nextTryAt: nextTryAt ?? this.nextTryAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'entity': entity,
        'entityId': entityId,
        'action': action,
        'patch': patch,
        if (baseEtag != null) 'baseEtag': baseEtag,
        'attempts': attempts,
        'nextTryAt': nextTryAt.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory OutboxRecord.fromJson(Map<String, dynamic> json) => OutboxRecord(
        opId: (json['opId'] ?? '').toString(),
        entity: (json['entity'] ?? '').toString(),
        entityId: (json['entityId'] ?? '').toString(),
        action: (json['action'] ?? '').toString(),
        patch: json['patch'] is Map<String, dynamic>
            ? json['patch'] as Map<String, dynamic>
            : const {},
        baseEtag: json['baseEtag']?.toString(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        nextTryAt: _date(json['nextTryAt']) ?? DateTime.now().toUtc(),
        createdAt: _date(json['createdAt']) ?? DateTime.now().toUtc(),
      );
}

class ConflictRecord {
  const ConflictRecord({
    required this.entity,
    required this.entityId,
    required this.localPatch,
    required this.remote,
    required this.createdAt,
  });

  final String entity;
  final String entityId;
  final Map<String, dynamic> localPatch;
  final Map<String, dynamic> remote;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'entity': entity,
        'entityId': entityId,
        'localPatch': localPatch,
        'remote': remote,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory ConflictRecord.fromJson(Map<String, dynamic> json) => ConflictRecord(
        entity: (json['entity'] ?? '').toString(),
        entityId: (json['entityId'] ?? '').toString(),
        localPatch: json['localPatch'] is Map<String, dynamic>
            ? json['localPatch'] as Map<String, dynamic>
            : const {},
        remote: json['remote'] is Map<String, dynamic>
            ? json['remote'] as Map<String, dynamic>
            : const {},
        createdAt: _date(json['createdAt']) ?? DateTime.now().toUtc(),
      );
}

/// Local-first store for P0.
///
/// The production plan calls for drift/SQLite. That package could not be
/// fetched in the current build environment, so P0 uses an atomic JSON file
/// behind this class. Every caller only sees this API, so swapping in drift
/// later is a storage-layer change, not a sync-engine rewrite.
class LocalStore {
  LocalStore._(this._file);

  factory LocalStore.memory() => LocalStore._(null);

  static Future<LocalStore> open({String? path}) async {
    final filePath =
        path ?? p.join((await appStorageDirectory()).path, 'caldav_free.json');
    final store = LocalStore._(File(filePath));
    await store._load();
    return store;
  }

  final File? _file;

  final Map<String, TaskItem> _tasks = {};
  final Set<String> _dirtyTasks = {};
  final Map<String, TaskListItem> _lists = {};
  final Map<String, OutboxRecord> _outbox = {};
  final Map<String, ConflictRecord> _conflicts = {};

  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void> _tail = Future<void>.value();

  String _cursor = '0';
  DateTime? _syncedAt;

  String get cursor => _cursor;
  DateTime? get syncedAt => _syncedAt;
  int get pendingCount => _outbox.length;
  int get failedCount =>
      _outbox.values.where((op) => op.attempts >= 99).length;
  int get conflictCount => _conflicts.length;
  bool get isDirty => _dirtyTasks.isNotEmpty;

  // ------------------------------------------------------------ reads

  TaskItem? task(String id) => _tasks[id];

  List<TaskItem> tasksSnapshot({String? listId, required bool completed}) {
    final items = _tasks.values
        .where((task) =>
            task.kind == TaskKind.task &&
            !task.deleted &&
            task.completed == completed &&
            (listId == null || task.listId == listId))
        .toList();
    items.sort(completed ? _compareCompleted : _compareOpen);
    return items;
  }

  Stream<List<TaskItem>> watchTasks({
    String? listId,
    required bool completed,
  }) async* {
    yield tasksSnapshot(listId: listId, completed: completed);
    await for (final _ in _changes.stream) {
      yield tasksSnapshot(listId: listId, completed: completed);
    }
  }

  TaskListItem? list(String id) => _lists[id];

  TaskListItem? inbox() {
    for (final list in _lists.values) {
      if (list.isInbox) return list;
    }
    return null;
  }

  List<TaskListItem> listsSnapshot() {
    final items = _lists.values.toList();
    items.sort((a, b) {
      if (a.isInbox != b.isInbox) return a.isInbox ? -1 : 1;
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  Stream<List<TaskListItem>> watchLists() async* {
    yield listsSnapshot();
    await for (final _ in _changes.stream) {
      yield listsSnapshot();
    }
  }

  OutboxRecord? pendingOp(String entity, String entityId) {
    for (final op in _outbox.values) {
      if (op.entity == entity && op.entityId == entityId) return op;
    }
    return null;
  }

  List<OutboxRecord> dueOps({int limit = 100}) {
    final now = DateTime.now().toUtc();
    final ops = _outbox.values
        .where((op) => !op.nextTryAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops.take(limit).toList(growable: false);
  }

  List<ConflictRecord> conflictsSnapshot() =>
      _conflicts.values.toList(growable: false);

  // ------------------------------------------------------------ mutations

  Future<void> saveTask(TaskItem task, {required bool dirty}) {
    return _mutate(() {
      _tasks[task.id] = task;
      if (dirty) {
        _dirtyTasks.add(task.id);
      } else {
        _dirtyTasks.remove(task.id);
      }
    });
  }

  Future<void> hardDeleteTask(String id) {
    return _mutate(() {
      _tasks.remove(id);
      _dirtyTasks.remove(id);
    });
  }

  Future<void> saveList(TaskListItem list, {bool dirty = false}) {
    return _mutate(() {
      _lists[list.id] = list;
    });
  }

  Future<void> hardDeleteList(String id) {
    return _mutate(() {
      _lists.remove(id);
    });
  }

  Future<void> writeCursor(String cursor) {
    return _mutate(() {
      _cursor = cursor.isEmpty ? '0' : cursor;
      _syncedAt = DateTime.now().toUtc();
    });
  }

  Future<void> saveOp({
    required String opId,
    required String entity,
    required String entityId,
    required String action,
    required Map<String, dynamic> patch,
    String? baseEtag,
    int attempts = 0,
    DateTime? nextTryAt,
    DateTime? createdAt,
  }) {
    return _mutate(() {
      final now = DateTime.now().toUtc();
      _outbox[opId] = OutboxRecord(
        opId: opId,
        entity: entity,
        entityId: entityId,
        action: action,
        patch: patch,
        baseEtag: baseEtag,
        attempts: attempts,
        nextTryAt: nextTryAt ?? now,
        createdAt: createdAt ?? now,
      );
    });
  }

  Future<void> removeOp(String opId) {
    return _mutate(() {
      _outbox.remove(opId);
    });
  }

  Future<void> removeOpsForEntity(String entity, String entityId) {
    return _mutate(() {
      _outbox.removeWhere(
        (key, op) => op.entity == entity && op.entityId == entityId,
      );
    });
  }

  Future<void> retryOp({
    required String opId,
    required int attempts,
    required DateTime nextTryAt,
  }) {
    return _mutate(() {
      final op = _outbox[opId];
      if (op == null) return;
      _outbox[opId] =
          op.copyWith(attempts: attempts, nextTryAt: nextTryAt);
    });
  }

  Future<void> replaceOp({
    required String oldOpId,
    required OutboxRecord replacement,
  }) {
    return _mutate(() {
      _outbox.remove(oldOpId);
      _outbox[replacement.opId] = replacement;
    });
  }

  Future<void> recordConflict({
    required String entity,
    required String entityId,
    required Map<String, dynamic> localPatch,
    required Map<String, dynamic> remote,
  }) {
    return _mutate(() {
      _conflicts['$entity:$entityId'] = ConflictRecord(
        entity: entity,
        entityId: entityId,
        localPatch: localPatch,
        remote: remote,
        createdAt: DateTime.now().toUtc(),
      );
    });
  }

  Future<void> clearConflict(String entity, String entityId) {
    return _mutate(() {
      _conflicts.remove('$entity:$entityId');
    });
  }

  Future<void> clearAll() {
    return _mutate(() {
      _tasks.clear();
      _dirtyTasks.clear();
      _lists.clear();
      _outbox.clear();
      _conflicts.clear();
      _cursor = '0';
      _syncedAt = null;
    });
  }

  Future<void> dispose() async {
    unawaited(_changes.close());
  }

  // ------------------------------------------------------------ persistence

  Future<void> _load() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      _cursor = (decoded['cursor'] ?? '0').toString();
      _syncedAt = _date(decoded['syncedAt']);
      final tasks = decoded['tasks'];
      if (tasks is Map<String, dynamic>) {
        for (final entry in tasks.entries) {
          final value = entry.value;
          if (value is! Map<String, dynamic>) continue;
          final data = value['data'];
          if (data is! Map<String, dynamic>) continue;
          _tasks[entry.key] = TaskItem.fromWireJson(data);
          if (value['dirty'] == true) _dirtyTasks.add(entry.key);
        }
      }
      final lists = decoded['lists'];
      if (lists is Map<String, dynamic>) {
        for (final entry in lists.entries) {
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            _lists[entry.key] = TaskListItem.fromWireJson(value);
          }
        }
      }
      final outbox = decoded['outbox'];
      if (outbox is Map<String, dynamic>) {
        for (final entry in outbox.entries) {
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            _outbox[entry.key] = OutboxRecord.fromJson(value);
          }
        }
      }
      final conflicts = decoded['conflicts'];
      if (conflicts is Map<String, dynamic>) {
        for (final entry in conflicts.entries) {
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            _conflicts[entry.key] = ConflictRecord.fromJson(value);
          }
        }
      }
    } on FormatException {
      // Keep the damaged file for inspection and start clean.
      try {
        await file.rename(
          '${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}',
        );
      } on FileSystemException {
        // Ignore; a clean start is still better than failing to boot.
      }
    }
  }

  Map<String, dynamic> _toJson() => {
        'schema': 1,
        'cursor': _cursor,
        if (_syncedAt != null)
          'syncedAt': _syncedAt!.toUtc().toIso8601String(),
        'tasks': _tasks.map(
          (id, task) => MapEntry(id, {
            'dirty': _dirtyTasks.contains(id),
            'data': task.toWireJson(),
          }),
        ),
        'lists': _lists.map((id, list) => MapEntry(id, list.toWireJson())),
        'outbox':
            _outbox.map((id, op) => MapEntry(id, op.toJson())),
        'conflicts': _conflicts.map(
          (id, conflict) => MapEntry(id, conflict.toJson()),
        ),
      };

  Future<T> _mutate<T>(FutureOr<T> Function() action) {
    if (_batching) {
      return Future<T>.sync(() async => await action());
    }
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final value = await action();
        await _persist();
        if (!_changes.isClosed) _changes.add(null);
        completer.complete(value);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  bool _batching = false;

  /// Runs several mutations as one persisted change and one stream event.
  Future<T> batch<T>(Future<T> Function() action) {
    if (_batching) return action();
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      _batching = true;
      try {
        final value = await action();
        await _persist();
        if (!_changes.isClosed) _changes.add(null);
        completer.complete(value);
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _batching = false;
      }
    });
    return completer.future;
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(_toJson()), flush: true);
    await temp.rename(file.path);
  }
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}

int _compareOpen(TaskItem a, TaskItem b) {
  final aDue = a.dueAt;
  final bDue = b.dueAt;
  if (aDue == null && bDue != null) return 1;
  if (aDue != null && bDue == null) return -1;
  if (aDue != null && bDue != null && !aDue.isAtSameMomentAs(bDue)) {
    return aDue.compareTo(bDue);
  }
  final order = a.sortOrder.compareTo(b.sortOrder);
  if (order != 0) return order;
  return a.id.compareTo(b.id);
}

int _compareCompleted(TaskItem a, TaskItem b) {
  final aAt = a.completedAt;
  final bAt = b.completedAt;
  if (aAt != null && bAt != null && !aAt.isAtSameMomentAs(bAt)) {
    return bAt.compareTo(aAt);
  }
  return a.id.compareTo(b.id);
}
