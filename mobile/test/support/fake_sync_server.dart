import 'package:caldav_free/data/remote/sync_api.dart';

/// In-memory implementation of the Go server's sync contract. It intentionally
/// mirrors the real semantics that matter to the client:
///
/// * per-entity ETags (`v<seq>`),
/// * one journal row per write, collapsed per entity on pull,
/// * `(opId)` idempotency including conflict/error results,
/// * soft-deleted tasks in pull responses.
class FakeSyncServer {
  FakeSyncServer() {
    _ensureInbox();
  }

  final Map<String, Map<String, dynamic>> tasks = {};
  final Map<String, Map<String, dynamic>> lists = {};
  final List<_Change> _changes = [];
  final Map<String, PushResult> _opResults = {};

  int _seq = 0;
  int pushCalls = 0;
  int pullCalls = 0;
  int appliedOps = 0;

  String get inboxId => lists.values.firstWhere((list) => list['isInbox'] == true)['id'] as String;

  void _ensureInbox() {
    if (lists.values.any((list) => list['isInbox'] == true)) return;
    final id = '01inbox000000000000000000';
    final now = _now();
    final json = <String, dynamic>{
      'id': id,
      'name': '收集箱',
      'color': '#4772fa',
      'kind': 'TASK',
      'order': 0,
      'pinned': false,
      'isInbox': true,
      'createdAt': now,
      'modifiedAt': now,
    };
    lists[id] = json;
    _touch('list', id);
  }

  Future<PullPage> pull({
    required String since,
    int limit = 500,
    bool refresh = false,
  }) async {
    pullCalls++;
    final sinceSeq = int.tryParse(since) ?? 0;
    final latest = <String, _Change>{};
    for (final change in _changes) {
      if (change.seq <= sinceSeq) continue;
      latest['${change.entity}:${change.id}'] = change;
    }
    final ordered = latest.values.toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final page = ordered.take(limit).toList(growable: false);
    final hasMore = ordered.length > page.length;

    final taskJson = <Map<String, dynamic>>[];
    final listJson = <Map<String, dynamic>>[];
    final tombstones = <Tombstone>[];
    for (final change in page) {
      if (change.entity == 'task') {
        final json = tasks[change.id];
        if (json == null) {
          tombstones.add(Tombstone(
            entity: 'task',
            id: change.id,
            deletedAt: _now(),
          ));
        } else {
          taskJson.add(Map<String, dynamic>.from(json));
        }
      } else if (change.entity == 'list') {
        final json = lists[change.id];
        if (json == null) {
          tombstones.add(Tombstone(
            entity: 'list',
            id: change.id,
            deletedAt: _now(),
          ));
        } else {
          listJson.add(Map<String, dynamic>.from(json));
        }
      }
    }

    return PullPage(
      cursor: page.isEmpty ? '$sinceSeq' : '${page.last.seq}',
      hasMore: hasMore,
      tasks: taskJson,
      lists: listJson,
      tombstones: tombstones,
    );
  }

  Future<List<PushResult>> push({
    required List<OutboxOp> ops,
    required String deviceId,
  }) async {
    pushCalls++;
    final results = <PushResult>[];
    for (final op in ops) {
      final cached = _opResults[op.opId];
      if (cached != null) {
        results.add(cached);
        continue;
      }
      final result = _apply(op);
      _opResults[op.opId] = result;
      results.add(result);
    }
    return results;
  }

  PushResult _apply(OutboxOp op) {
    final entity = op.entity == 'list' ? 'list' : 'task';
    final current =
        entity == 'task' ? tasks[op.entityId] : lists[op.entityId];

    switch (op.action) {
      case 'create':
        if (current != null) {
          return _conflict(op, entity, current);
        }
        if (entity == 'task') {
          final title = (op.patch['title'] ?? '').toString().trim();
          if (title.isEmpty) {
            return _error(op, entity, 'invalid_patch', 'title is required');
          }
          final listId = (op.patch['listId'] ?? inboxId).toString();
          if (!lists.containsKey(listId)) {
            return _error(op, entity, 'invalid_patch', 'list not found');
          }
          final now = _now();
          final json = <String, dynamic>{
            'id': op.entityId,
            'listId': listId,
            'title': title,
            'notes': '',
            'notesFormat': 'text',
            'kind': 'TASK',
            'priority': 0,
            'allDay': false,
            'recurrence': '',
            'reminderOffsets': <int>[],
            'tags': <String>[],
            'checklist': <dynamic>[],
            'assignee': '',
            'completed': false,
            'pinned': false,
            'order': 0,
            'deleted': false,
            'createdAt': now,
            'modifiedAt': now,
          };
          _applyPatch(json, op.patch);
          tasks[op.entityId] = json;
          _touch('task', op.entityId);
          appliedOps++;
          return _ok(op, entity, json);
        }
        final name = (op.patch['name'] ?? '').toString().trim();
        if (name.isEmpty) {
          return _error(op, entity, 'invalid_patch', 'name is required');
        }
        final json = <String, dynamic>{
          'id': op.entityId,
          'name': name,
          'color': '#4772fa',
          'kind': 'TASK',
          'order': 0,
          'pinned': false,
          'isInbox': false,
          'modifiedAt': _now(),
        };
        lists[op.entityId] = json;
        _touch('list', op.entityId);
        appliedOps++;
        return _ok(op, entity, json);

      case 'update':
        if (current == null) return _gone(op, entity);
        if (entity == 'task' && current['deleted'] == true) {
          return _gone(op, entity);
        }
        if (_baseMismatch(op, current)) {
          return _conflict(op, entity, current);
        }
        _applyPatch(current, op.patch);
        _touch(entity, op.entityId);
        appliedOps++;
        return _ok(op, entity, current);

      case 'delete':
        if (current == null) return _gone(op, entity);
        if (_baseMismatch(op, current)) {
          return _conflict(op, entity, current);
        }
        if (entity == 'task') {
          current['deleted'] = true;
          current['deletedAt'] = _now();
          _touch('task', op.entityId);
          appliedOps++;
          return _ok(op, entity, current);
        }
        // Deleting a list moves its tasks to the inbox, like the Go server.
        for (final entry in tasks.entries) {
          if (entry.value['listId'] == op.entityId) {
            entry.value['listId'] = inboxId;
            _touch('task', entry.key);
          }
        }
        lists.remove(op.entityId);
        _log('list', op.entityId);
        appliedOps++;
        return PushResult(
          opId: op.opId,
          entity: 'list',
          entityId: op.entityId,
          status: 'ok',
        );

      default:
        return _error(op, entity, 'invalid_operation', 'unknown action');
    }
  }

  void _applyPatch(Map<String, dynamic> json, Map<String, dynamic> patch) {
    for (final entry in patch.entries) {
      if (entry.key == 'id' ||
          entry.key == 'etag' ||
          entry.key == 'version' ||
          entry.key == 'modifiedAt' ||
          entry.key == 'deleted' ||
          entry.key == 'deletedAt') {
        continue;
      }
      json[entry.key] = entry.value;
    }
    if (patch['completed'] == true && json['completedAt'] == null) {
      json['completedAt'] = _now();
    }
    if (patch['completed'] == false) {
      json['completedAt'] = null;
    }
  }

  bool _baseMismatch(OutboxOp op, Map<String, dynamic> current) {
    final base = op.baseEtag;
    if (base == null || base.isEmpty) return false;
    return base != current['etag'];
  }

  PushResult _ok(OutboxOp op, String entity, Map<String, dynamic> current) {
    return PushResult(
      opId: op.opId,
      entity: entity,
      entityId: op.entityId,
      status: 'ok',
      etag: current['etag']?.toString(),
      version: (current['version'] as num?)?.toInt() ?? 0,
      entityJson: Map<String, dynamic>.from(current),
    );
  }

  PushResult _conflict(
    OutboxOp op,
    String entity,
    Map<String, dynamic> current,
  ) {
    return PushResult(
      opId: op.opId,
      entity: entity,
      entityId: op.entityId,
      status: 'conflict',
      etag: current['etag']?.toString(),
      version: (current['version'] as num?)?.toInt() ?? 0,
      entityJson: Map<String, dynamic>.from(current),
      errorCode: 'etag_mismatch',
      errorMessage: 'entity changed on the server',
    );
  }

  PushResult _gone(OutboxOp op, String entity) => PushResult(
        opId: op.opId,
        entity: entity,
        entityId: op.entityId,
        status: 'gone',
      );

  PushResult _error(
    OutboxOp op,
    String entity,
    String code,
    String message,
  ) =>
      PushResult(
        opId: op.opId,
        entity: entity,
        entityId: op.entityId,
        status: 'error',
        errorCode: code,
        errorMessage: message,
      );

  void _touch(String entity, String id) {
    final json = entity == 'task' ? tasks[id] : lists[id];
    if (json == null) return;
    json['modifiedAt'] = _now();
    _log(entity, id);
    json['version'] = _seq;
    json['etag'] = 'v$_seq';
  }

  void _log(String entity, String id) {
    _seq++;
    _changes.add(_Change(_seq, entity, id));
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}

class _Change {
  _Change(this.seq, this.entity, this.id);

  final int seq;
  final String entity;
  final String id;
}

class FakeSyncApi implements SyncApi {
  FakeSyncApi(this.server);

  final FakeSyncServer server;
  bool failNextPull = false;
  bool failNextPush = false;

  @override
  Future<PullPage> pull({
    required String since,
    int limit = 500,
    bool refresh = false,
  }) async {
    if (failNextPull) {
      failNextPull = false;
      throw SyncApiException('网络中断');
    }
    return server.pull(since: since, limit: limit, refresh: refresh);
  }

  @override
  Future<List<PushResult>> push({
    required List<OutboxOp> ops,
    required String deviceId,
  }) async {
    if (failNextPush) {
      failNextPush = false;
      throw SyncApiException('网络中断');
    }
    return server.push(ops: ops, deviceId: deviceId);
  }

  @override
  void close() {}
}
