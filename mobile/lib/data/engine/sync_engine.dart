import 'dart:math';

import '../../core/ids.dart';
import '../../core/merge.dart';
import '../../core/models.dart';
import '../db/local_store.dart';
import '../remote/sync_api.dart';

class SyncRunResult {
  const SyncRunResult({
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.errors = const [],
  });

  final int pulled;
  final int pushed;
  final int conflicts;
  final int failed;
  final List<String> errors;
}

class _PushStats {
  const _PushStats({
    this.pushed = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.errors = const [],
  });

  final int pushed;
  final int conflicts;
  final int failed;
  final List<String> errors;
}

/// Pull → merge → push → settle engine.
///
/// The engine is pure Dart (no Flutter imports) so the convergence tests can
/// run on a plain VM.
class SyncEngine {
  SyncEngine({
    required this.store,
    required this.api,
    required this.deviceId,
    Duration Function(int attempts)? backoff,
    this.queueFlushers = const [],
  }) : _backoffOverride = backoff;

  final LocalStore store;
  final SyncApi api;
  final String deviceId;
  final Duration Function(int attempts)? _backoffOverride;

  /// Durable local-only write queues (habits, countdowns, ...) replayed by
  /// this background pass instead of by the pages that enqueued them.
  final List<Future<void> Function()> queueFlushers;

  Future<SyncRunResult>? _current;

  /// Releases the HTTP client owned by the API.
  void close() => api.close();

  Future<SyncRunResult> sync({bool full = false}) {
    final running = _current;
    if (running != null) return running;
    late final Future<SyncRunResult> tracked;
    tracked = _run(full: full).whenComplete(() {
      if (identical(_current, tracked)) _current = null;
    });
    _current = tracked;
    return tracked;
  }

  Future<SyncRunResult> _run({required bool full}) async {
    var pulled = 0;
    var pushed = 0;
    var conflicts = 0;
    var failed = 0;
    final errors = <String>[];

    for (final flush in queueFlushers) {
      try {
        await flush();
      } on Object {
        // Queue flushers keep their entries durably and retry on the next
        // background pass; a failing side queue must not sink the main sync.
      }
    }

    pulled += await _pull(full: full);

    // Conflicts produce replacements due immediately; a couple of rounds
    // usually converge in the same sync call.
    for (var round = 0; round < 3; round++) {
      final stats = await _pushRound();
      pushed += stats.pushed;
      conflicts += stats.conflicts;
      failed += stats.failed;
      errors.addAll(stats.errors);
      if (stats.pushed == 0 && stats.conflicts == 0) break;
    }

    if (pushed > 0 || conflicts > 0) {
      pulled += await _pull(full: false);
    }

    return SyncRunResult(
      pulled: pulled,
      pushed: pushed,
      conflicts: conflicts,
      failed: failed,
      errors: errors,
    );
  }

  // ------------------------------------------------------------ pull

  Future<int> _pull({required bool full}) async {
    var cursor = full ? '0' : store.cursor;
    var pulled = 0;
    var first = true;
    while (true) {
      final page = await api.pull(
        since: cursor,
        limit: 500,
        refresh: full && first,
      );
      for (final json in page.tasks) {
        await _mergeRemoteTask(json);
        pulled++;
      }
      for (final json in page.lists) {
        await _mergeRemoteList(json);
        pulled++;
      }
      for (final json in page.sections) {
        await _mergeRemoteSection(json);
        pulled++;
      }
      for (final json in page.folders) {
        await _mergeRemoteFolder(json);
        pulled++;
      }
      for (final tombstone in page.tombstones) {
        await _applyTombstone(tombstone);
        pulled++;
      }
      cursor = page.cursor;
      await store.writeCursor(cursor);
      first = false;
      if (!page.hasMore) break;
    }
    return pulled;
  }

  Future<void> _mergeRemoteTask(Map<String, dynamic> json) async {
    final remote = TaskItem.fromWireJson(json);
    if (remote.id.isEmpty) return;
    final local = store.task(remote.id);
    final op = store.pendingOp('task', remote.id);

    if (op == null) {
      await store.saveTask(remote, dirty: false);
      return;
    }

    if (remote.deleted) {
      if (op.action == 'delete') {
        // Both sides agree; the goal is already achieved.
        await store.removeOp(op.opId);
        await store.clearConflict('task', remote.id);
        await store.saveTask(remote, dirty: false);
      } else {
        // Deletion wins over a pending edit.
        await store.removeOp(op.opId);
        await store.clearConflict('task', remote.id);
        await store.saveTask(remote, dirty: false);
      }
      return;
    }

    if (op.action == 'delete') {
      final current =
          local ??
          remote.copyWith(deleted: true, deletedAt: DateTime.now().toUtc());
      await store.saveTask(
        current.copyWith(
          deleted: true,
          deletedAt: current.deletedAt ?? DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
        dirty: true,
      );
      return;
    }

    if (local == null) {
      await store.saveTask(remote, dirty: false);
      return;
    }

    final merged = mergeTaskMaps(
      local: local.toWireJson(),
      remote: remote.toWireJson(),
      localFields: op.patch.keys.toSet(),
      localDeleted: local.deleted,
    );
    final item = TaskItem.fromWireJson(merged).copyWith(
      // Keep the base ETag: the server moved underneath us, so push must
      // surface a conflict and merge again with the server's snapshot.
      etag: local.etag,
      version: local.version,
      updatedAt: DateTime.now().toUtc(),
    );
    await store.saveTask(item, dirty: true);
  }

  Future<void> _mergeRemoteFolder(Map<String, dynamic> json) async {
    final remote = FolderItem.fromWireJson(json);
    if (remote.id.isEmpty) return;
    final local = store.folder(remote.id);
    final op = store.pendingOp('folder', remote.id);
    if (local == null || op == null) {
      await store.saveFolder(remote);
      return;
    }
    final merged = mergeListMaps(
      local: local.toWireJson(),
      remote: remote.toWireJson(),
      localFields: op.patch.keys.toSet(),
    );
    await store.saveFolder(FolderItem.fromWireJson(merged));
  }

  Future<void> _mergeRemoteList(Map<String, dynamic> json) async {
    final remote = TaskListItem.fromWireJson(json);
    if (remote.id.isEmpty) return;
    final local = store.list(remote.id);
    final op = store.pendingOp('list', remote.id);
    if (local == null || op == null) {
      await store.saveList(remote);
      return;
    }
    final merged = mergeListMaps(
      local: local.toWireJson(),
      remote: remote.toWireJson(),
      localFields: op.patch.keys.toSet(),
    );
    await store.saveList(TaskListItem.fromWireJson(merged));
  }

  Future<void> _mergeRemoteSection(Map<String, dynamic> json) async {
    final remote = TaskSection.fromWireJson(json);
    if (remote.id.isEmpty) return;
    final local = store.section(remote.id);
    final op = store.pendingOp('section', remote.id);
    if (local == null || op == null) {
      await store.saveSection(remote);
      return;
    }
    final merged = mergeListMaps(
      local: local.toWireJson(),
      remote: remote.toWireJson(),
      localFields: op.patch.keys.toSet(),
    );
    await store.saveSection(TaskSection.fromWireJson(merged));
  }

  Future<void> _applyTombstone(Tombstone tombstone) async {
    switch (tombstone.entity) {
      case 'task':
        await store.removeOpsForEntity('task', tombstone.id);
        await store.clearConflict('task', tombstone.id);
        await store.hardDeleteTask(tombstone.id);
        break;
      case 'list':
        await store.removeOpsForEntity('list', tombstone.id);
        await store.clearConflict('list', tombstone.id);
        await store.hardDeleteList(tombstone.id);
        break;
      case 'section':
        await store.removeOpsForEntity('section', tombstone.id);
        await store.clearConflict('section', tombstone.id);
        await store.hardDeleteSection(tombstone.id);
        break;
      case 'folder':
        await store.removeOpsForEntity('folder', tombstone.id);
        await store.clearConflict('folder', tombstone.id);
        await store.hardDeleteFolder(tombstone.id);
        break;
      default:
        // Filters are not editable in the mobile client yet.
        break;
    }
  }

  // ------------------------------------------------------------ push

  Future<_PushStats> _pushRound() async {
    final ops = store.dueOps();
    if (ops.isEmpty) return const _PushStats();
    // A task created offline may reference a list created in the same batch.
    // Push folders/lists/sections first so the server can resolve references.
    ops.sort((a, b) {
      int rank(OutboxRecord op) => switch (op.entity) {
        'folder' => 0,
        'list' => 1,
        'section' => 2,
        _ => 3,
      };
      final rankA = rank(a);
      final rankB = rank(b);
      if (rankA != rankB) return rankA - rankB;
      final byTime = a.createdAt.compareTo(b.createdAt);
      if (byTime != 0) return byTime;
      return a.opId.compareTo(b.opId);
    });

    List<PushResult> results;
    try {
      results = await api.push(
        ops: ops.map((op) => op.toApiOp()).toList(growable: false),
        deviceId: deviceId,
      );
    } catch (error) {
      // The request may or may not have reached the server. Keeping the same
      // opId is correct: a retry is idempotent if it did.
      await _backoffNetwork(ops);
      rethrow;
    }

    final byId = {for (final result in results) result.opId: result};
    var pushed = 0;
    var conflicts = 0;
    var failed = 0;
    final errors = <String>[];

    for (final op in ops) {
      final result = byId[op.opId];
      if (result == null) {
        await _backoffNetwork([op]);
        failed++;
        errors.add('${op.entity} ${op.entityId}: 服务端未返回结果');
        continue;
      }
      switch (result.status) {
        case 'ok':
          pushed++;
          await _applyOk(op, result);
          break;
        case 'conflict':
          conflicts++;
          await store.recordConflict(
            entity: op.entity,
            entityId: op.entityId,
            localPatch: op.patch,
            remote: result.entityJson ?? const {},
          );
          await _applyConflict(op, result);
          break;
        case 'gone':
          await store.removeOp(op.opId);
          await store.clearConflict(op.entity, op.entityId);
          if (op.entity == 'task') {
            await store.hardDeleteTask(op.entityId);
          } else if (op.entity == 'list') {
            await store.hardDeleteList(op.entityId);
          } else if (op.entity == 'section') {
            await store.hardDeleteSection(op.entityId);
          } else if (op.entity == 'folder') {
            await store.hardDeleteFolder(op.entityId);
          }
          break;
        default:
          failed++;
          final message = result.errorMessage ?? result.errorCode ?? '同步操作失败';
          errors.add('${op.entity} ${op.entityId}: $message');
          await _applyError(op, result);
      }
    }

    return _PushStats(
      pushed: pushed,
      conflicts: conflicts,
      failed: failed,
      errors: errors,
    );
  }

  Future<void> _applyOk(OutboxRecord op, PushResult result) async {
    await store.removeOp(op.opId);
    await store.clearConflict(op.entity, op.entityId);
    // A newer local edit may have arrived while the request was in flight.
    final newer = store.pendingOp(op.entity, op.entityId);
    if (newer != null) return;

    if (op.entity == 'task') {
      if (op.action == 'purge') {
        await store.hardDeleteTask(op.entityId);
        return;
      }
      if (result.entityJson != null) {
        final remote = TaskItem.fromWireJson(result.entityJson!)
            .copyWith(etag: result.etag ?? '', version: result.version);
        await store.saveTask(remote, dirty: false);
        return;
      }
      final local = store.task(op.entityId);
      if (local != null) {
        await store.saveTask(
          local.copyWith(
            etag: result.etag ?? local.etag,
            version: result.version,
            updatedAt: DateTime.now().toUtc(),
          ),
          dirty: false,
        );
      }
      return;
    }
    if (op.entity == 'list') {
      if (op.action == 'delete') {
        await store.hardDeleteList(op.entityId);
      } else if (result.entityJson != null) {
        await store.saveList(TaskListItem.fromWireJson(result.entityJson!));
      }
      return;
    }
    if (op.entity == 'section') {
      if (op.action == 'delete') {
        await store.hardDeleteSection(op.entityId);
      } else if (result.entityJson != null) {
        await store.saveSection(TaskSection.fromWireJson(result.entityJson!));
      }
      return;
    }
    if (op.entity == 'folder') {
      if (op.action == 'delete') {
        await store.hardDeleteFolder(op.entityId);
      } else if (result.entityJson != null) {
        await store.saveFolder(FolderItem.fromWireJson(result.entityJson!));
      }
    }
  }

  Future<void> _applyConflict(OutboxRecord op, PushResult result) async {
    final now = DateTime.now().toUtc();
    final remoteJson = result.entityJson;
    if (remoteJson == null) {
      await store.retryOp(
        opId: op.opId,
        attempts: 99,
        nextTryAt: now.add(const Duration(days: 3650)),
      );
      return;
    }

    if (op.action == 'delete') {
      // Deletion wins; refresh the base ETag and retry the delete.
      final replacement = op.copyWith(
        opId: newSyncId(),
        action: 'delete',
        patch: const {},
        baseEtag: result.etag ?? '',
        attempts: 0,
        nextTryAt: now,
      );
      await store.replaceOp(oldOpId: op.opId, replacement: replacement);
      return;
    }

    if (op.entity == 'task' &&
        (op.action == 'restore' ||
            op.action == 'purge' ||
            op.action == 'skip')) {
      // The task moved on (or a pending delete raced us). Retry against the
      // new revision; these actions are idempotent server-side.
      final replacement = op.copyWith(
        opId: newSyncId(),
        patch: const {},
        baseEtag: result.etag ?? '',
        attempts: 0,
        nextTryAt: now,
      );
      await store.replaceOp(oldOpId: op.opId, replacement: replacement);
      return;
    }

    if (op.entity == 'section') {
      final local = store.section(op.entityId);
      if (local == null) {
        await store.removeOp(op.opId);
        return;
      }
      final merged = mergeListMaps(
        local: local.toWireJson(),
        remote: remoteJson,
        localFields: op.patch.keys.toSet(),
      );
      await store.saveSection(TaskSection.fromWireJson(merged));
      final replacement = op.copyWith(
        opId: newSyncId(),
        action: op.action == 'create' ? 'update' : op.action,
        baseEtag: result.etag ?? '',
        attempts: 0,
        nextTryAt: now,
      );
      await store.replaceOp(oldOpId: op.opId, replacement: replacement);
      return;
    }

    if (op.entity == 'task') {
      final local = store.task(op.entityId);
      if (local == null) {
        await store.removeOp(op.opId);
        return;
      }

      if (local.deleted) {
        final replacement = op.copyWith(
          opId: newSyncId(),
          action: 'delete',
          patch: const {},
          baseEtag: result.etag ?? '',
          attempts: 0,
          nextTryAt: now,
        );
        await store.replaceOp(oldOpId: op.opId, replacement: replacement);
        return;
      }

      final merged = mergeTaskMaps(
        local: local.toWireJson(),
        remote: remoteJson,
        localFields: op.patch.keys.toSet(),
        localDeleted: local.deleted,
      );
      final item = TaskItem.fromWireJson(merged).copyWith(
        etag: result.etag ?? '',
        version: result.version,
        updatedAt: now,
      );
      await store.saveTask(item, dirty: true);

      final wire = item.toWireJson();
      final Map<String, dynamic> retryPatch;
      if (op.action == 'create') {
        retryPatch = {
          for (final key in _createFields)
            if (wire[key] != null) key: wire[key],
        };
      } else {
        retryPatch = {for (final key in op.patch.keys) key: wire[key]};
      }
      final replacement = op.copyWith(
        opId: newSyncId(),
        action: 'update',
        patch: retryPatch,
        baseEtag: result.etag ?? '',
        attempts: 0,
        nextTryAt: now,
      );
      await store.replaceOp(oldOpId: op.opId, replacement: replacement);
      return;
    }

    if (op.entity == 'list') {
      final local = store.list(op.entityId);
      if (local == null) {
        await store.removeOp(op.opId);
        return;
      }
      final merged = mergeListMaps(
        local: local.toWireJson(),
        remote: remoteJson,
        localFields: op.patch.keys.toSet(),
      );
      final item = TaskListItem.fromWireJson(merged);
      await store.saveList(item);
      final replacement = op.copyWith(
        opId: newSyncId(),
        action: 'update',
        patch: {for (final key in op.patch.keys) key: item.toWireJson()[key]},
        baseEtag: result.etag ?? '',
        attempts: 0,
        nextTryAt: now,
      );
      await store.replaceOp(oldOpId: op.opId, replacement: replacement);
      return;
    }

    if (op.entity == 'folder') {
      final local = store.folder(op.entityId);
      if (local == null) {
        await store.removeOp(op.opId);
        return;
      }
      final merged = mergeListMaps(
        local: local.toWireJson(),
        remote: remoteJson,
        localFields: op.patch.keys.toSet(),
      );
      final item = FolderItem.fromWireJson(merged);
      await store.saveFolder(item);
      final replacement = op.copyWith(
        opId: newSyncId(),
        action: 'update',
        patch: {for (final key in op.patch.keys) key: item.toWireJson()[key]},
        baseEtag: result.etag ?? '',
        attempts: 0,
        nextTryAt: now,
      );
      await store.replaceOp(oldOpId: op.opId, replacement: replacement);
    }
  }

  Future<void> _applyError(OutboxRecord op, PushResult result) async {
    final now = DateTime.now().toUtc();
    final code = result.errorCode ?? '';
    const permanent = {
      'invalid_patch',
      'invalid_operation',
      'unsupported',
      'forbidden',
      'inbox_immutable',
      'not_found',
      'already_exists',
    };
    if (permanent.contains(code)) {
      await store.retryOp(
        opId: op.opId,
        attempts: 99,
        nextTryAt: now.add(const Duration(days: 3650)),
      );
      return;
    }

    // The server stored this error under the old opId. A retry must use a new
    // idempotency key or it will replay the error forever.
    final attempts = op.attempts + 1;
    final replacement = op.copyWith(
      opId: newSyncId(),
      attempts: attempts,
      nextTryAt: now.add(_backoff(attempts)),
    );
    await store.replaceOp(oldOpId: op.opId, replacement: replacement);
  }

  Future<void> _backoffNetwork(List<OutboxRecord> ops) async {
    final now = DateTime.now().toUtc();
    for (final op in ops) {
      final attempts = op.attempts + 1;
      await store.retryOp(
        opId: op.opId,
        attempts: attempts,
        nextTryAt: now.add(_backoff(attempts)),
      );
    }
  }

  Duration _backoff(int attempts) {
    final override = _backoffOverride;
    if (override != null) return override(attempts);
    final seconds = min(300, 1 << min(attempts, 8));
    return Duration(seconds: seconds);
  }
}

const _createFields = [
  'listId',
  'parentId',
  'sectionId',
  'title',
  'notes',
  'notesFormat',
  'kind',
  'priority',
  'start',
  'due',
  'allDay',
  'recurrence',
  'reminderOffsets',
  'tags',
  'checklist',
  'assignee',
  'completed',
  'completedAt',
  'pinned',
  'order',
];
