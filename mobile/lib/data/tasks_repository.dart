import '../core/ids.dart';
import '../core/models.dart';
import 'db/local_store.dart';

/// Local writes only. Every mutation updates the local row and the outbox in
/// one persisted batch; the UI never talks to the network directly.
class TaskRepository {
  TaskRepository(this.store);

  final LocalStore store;

  void Function()? onLocalChange;

  Future<TaskItem> createTask({
    required String title,
    required String listId,
  }) async {
    final now = DateTime.now().toUtc();
    final task = TaskItem(
      id: newSyncId(),
      listId: listId,
      title: title.trim(),
      notes: '',
      kind: TaskKind.task,
      updatedAt: now,
      createdAt: now,
    );
    final patch = <String, dynamic>{
      'listId': listId,
      'title': task.title,
      'notes': '',
      'notesFormat': 'text',
      'kind': 'TASK',
      'priority': 0,
      'allDay': false,
      'recurrence': '',
      'reminderOffsets': const <int>[],
      'tags': const <String>[],
      'checklist': const <dynamic>[],
      'assignee': '',
      'completed': false,
      'pinned': false,
    };
    await store.batch(() async {
      await store.saveTask(task, dirty: true);
      await store.saveOp(
        opId: newSyncId(),
        entity: 'task',
        entityId: task.id,
        action: 'create',
        patch: patch,
      );
    });
    onLocalChange?.call();
    return task;
  }

  Future<void> updateTitle(String id, String title) async {
    final task = store.task(id);
    final value = title.trim();
    if (task == null || value.isEmpty || task.title == value) return;
    await _patch(task, {'title': value}, task.copyWith(title: value));
  }

  Future<void> updateNotes(String id, String notes) async {
    final task = store.task(id);
    if (task == null || task.notes == notes) return;
    await _patch(task, {'notes': notes}, task.copyWith(notes: notes));
  }

  Future<void> toggleCompleted(String id) async {
    final task = store.task(id);
    if (task == null) return;
    final now = DateTime.now().toUtc();
    final completedAt = task.completed ? null : now;
    final patch = <String, dynamic>{
      'completed': completedAt != null,
      'completedAt':
          completedAt?.toUtc().toIso8601String(), // explicit null clears
    };
    await _patch(
      task,
      patch,
      task.copyWith(
        completedAt: completedAt,
        clearCompleted: completedAt == null,
      ),
    );
  }

  Future<void> deleteTask(String id) async {
    final task = store.task(id);
    if (task == null) return;
    final existing = store.pendingOp('task', id);
    if (existing?.action == 'create') {
      // Never reached the server: drop both sides locally.
      await store.batch(() async {
        await store.removeOp(existing!.opId);
        await store.hardDeleteTask(id);
        await store.clearConflict('task', id);
      });
      onLocalChange?.call();
      return;
    }
    final now = DateTime.now().toUtc();
    final baseEtag = existing?.baseEtag ?? task.etag;
    await store.batch(() async {
      await store.saveTask(
        task.copyWith(deleted: true, deletedAt: now),
        dirty: true,
      );
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      await store.saveOp(
        opId: newSyncId(),
        entity: 'task',
        entityId: id,
        action: 'delete',
        patch: const {},
        baseEtag: baseEtag,
      );
    });
    onLocalChange?.call();
  }

  Future<void> _patch(
    TaskItem task,
    Map<String, dynamic> patch,
    TaskItem updated,
  ) async {
    final now = DateTime.now().toUtc();
    final existing = store.pendingOp('task', task.id);
    final mergedPatch = <String, dynamic>{
      if (existing != null) ...existing.patch,
      ...patch,
    };
    final action = existing?.action == 'create' ? 'create' : 'update';
    await store.batch(() async {
      await store.saveTask(updated.copyWith(updatedAt: now), dirty: true);
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      // A new local intent always gets a fresh idempotency key: reusing one
      // that the server already answered would replay the old result and drop
      // this edit.
      await store.saveOp(
        opId: newSyncId(),
        entity: 'task',
        entityId: task.id,
        action: action,
        patch: mergedPatch,
        baseEtag: existing?.baseEtag ?? task.etag,
      );
    });
    onLocalChange?.call();
  }
}
