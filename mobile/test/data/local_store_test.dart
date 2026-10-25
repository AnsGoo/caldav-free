import 'dart:io';

import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local create writes a task and one outbox op in a batch', () async {
    final store = LocalStore.memory();
    final repo = TaskRepository(store);
    final task = await repo.createTask(title: '买牛奶', listId: 'list-1');

    expect(store.task(task.id)?.title, '买牛奶');
    expect(store.pendingCount, 1);
    final op = store.pendingOp('task', task.id);
    expect(op?.action, 'create');
    expect(op?.patch['title'], '买牛奶');
    expect(op?.patch['listId'], 'list-1');

    final emitted = await store
        .watchTasks(listId: 'list-1', completed: false)
        .first;
    expect(emitted.single.id, task.id);
    await store.dispose();
  });

  test('deleting a never-synced task removes both task and outbox', () async {
    final store = LocalStore.memory();
    final repo = TaskRepository(store);
    final task = await repo.createTask(title: '临时', listId: 'list-1');

    await repo.deleteTask(task.id);

    expect(store.task(task.id), isNull);
    expect(store.pendingCount, 0);
    await store.dispose();
  });

  test('editing keeps a single op and merges the patch', () async {
    final store = LocalStore.memory();
    final repo = TaskRepository(store);
    final task = await repo.createTask(title: '第一版', listId: 'list-1');

    await repo.updateTitle(task.id, '第二版');
    await repo.updateNotes(task.id, '备注');

    expect(store.pendingCount, 1);
    final op = store.pendingOp('task', task.id)!;
    expect(op.action, 'create');
    expect(op.patch['title'], '第二版');
    expect(op.patch['notes'], '备注');
    await store.dispose();
  });

  test('saveEdits sends only fields changed against the editor baseline',
      () async {
    final store = LocalStore.memory();
    final repo = TaskRepository(store);
    final task = await repo.createTask(title: '原标题', listId: 'list-1');
    // Pretend the create was already acknowledged so this op only contains the
    // editor's fields.
    final createOp = store.pendingOp('task', task.id)!;
    await store.removeOp(createOp.opId);
    final baseline = store.task(task.id)!;

    await repo.saveEdits(
      task.id,
      baseline: baseline,
      title: '新标题',
      notes: baseline.notes,
      dueAt: DateTime.utc(2026, 10, 30),
      allDay: true,
      priority: 3,
      tags: const ['p1', '工作'],
      checklist: const [
        ChecklistItem(id: 'sub-1', title: '第一步'),
      ],
    );

    final op = store.pendingOp('task', task.id)!;
    expect(op.patch['title'], '新标题');
    expect(op.patch['priority'], 3);
    expect(op.patch['allDay'], true);
    expect(op.patch['due'], '2026-10-30T00:00:00.000Z');
    expect(op.patch['tags'], ['p1', '工作']);
    expect(op.patch['checklist'], [
      {'id': 'sub-1', 'title': '第一步', 'done': false},
    ]);
    expect(op.patch.containsKey('notes'), false);

    final local = store.task(task.id)!;
    expect(local.tags, ['p1', '工作']);
    expect(local.priority, 3);
    expect(local.dueAt, DateTime.utc(2026, 10, 30));
    expect(local.checklist.single.title, '第一步');

    // A remote edit to an untouched field must survive a later editor save.
    await store.saveTask(
      local.copyWith(notes: '远端备注'),
      dirty: false,
    );
    await repo.saveEdits(
      task.id,
      baseline: baseline,
      title: '再改标题',
      notes: baseline.notes,
      dueAt: DateTime.utc(2026, 10, 30),
      allDay: true,
      priority: 3,
      tags: const ['p1', '工作'],
      checklist: const [
        ChecklistItem(id: 'sub-1', title: '第一步'),
      ],
    );
    expect(store.task(task.id)!.notes, '远端备注');
    await store.dispose();
  });

  test('toggleChecklistItem updates one subtask', () async {
    final store = LocalStore.memory();
    final repo = TaskRepository(store);
    final task = await repo.createTask(title: '子任务', listId: 'list-1');
    await repo.saveEdits(
      task.id,
      baseline: task,
      title: task.title,
      notes: '',
      dueAt: null,
      allDay: false,
      priority: 0,
      tags: const [],
      checklist: const [
        ChecklistItem(id: 'a', title: 'A'),
        ChecklistItem(id: 'b', title: 'B'),
      ],
    );
    await repo.toggleChecklistItem(task.id, 'b');
    final local = store.task(task.id)!;
    expect(local.checklist.first.done, false);
    expect(local.checklist.last.done, true);
    await store.dispose();
  });

  test('data survives reopening the JSON file', () async {
    final directory = await Directory.systemTemp.createTemp('caldav-store');
    final path = '${directory.path}/store.json';
    final store = await LocalStore.open(path: path);
    final repo = TaskRepository(store);
    final task = await repo.createTask(title: '持久化', listId: 'list-1');
    await store.dispose();

    final reopened = await LocalStore.open(path: path);
    expect(reopened.task(task.id)?.title, '持久化');
    expect(reopened.pendingCount, 1);
    expect(reopened.pendingOp('task', task.id)?.patch['title'], '持久化');
    await reopened.dispose();
    await directory.delete(recursive: true);
  });
}
