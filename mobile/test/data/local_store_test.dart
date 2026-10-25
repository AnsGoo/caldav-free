import 'dart:io';

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
