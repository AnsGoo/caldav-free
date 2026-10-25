import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/engine/sync_engine.dart';
import 'package:caldav_free/data/remote/sync_api.dart';
import 'package:caldav_free/data/tasks_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_sync_server.dart';

class _Client {
  _Client(this.server, this.deviceId) {
    store = LocalStore.memory();
    api = FakeSyncApi(server);
    engine = SyncEngine(
      store: store,
      api: api,
      deviceId: deviceId,
      backoff: (_) => Duration.zero,
    );
    repo = TaskRepository(store);
  }

  final FakeSyncServer server;
  final String deviceId;
  late final LocalStore store;
  late final FakeSyncApi api;
  late final SyncEngine engine;
  late final TaskRepository repo;
}

void main() {
  late FakeSyncServer server;
  late _Client deviceA;
  late _Client deviceB;

  setUp(() {
    server = FakeSyncServer();
    deviceA = _Client(server, 'device-a');
    deviceB = _Client(server, 'device-b');
  });

  tearDown(() async {
    await deviceA.store.dispose();
    await deviceB.store.dispose();
  });

  test('two clients converge after concurrent edits', () async {
    await deviceA.engine.sync(full: true);
    final inbox = deviceA.store.inbox();
    expect(inbox, isNotNull);

    final task = await deviceA.repo.createTask(
      title: '初始标题',
      listId: inbox!.id,
    );
    await deviceA.engine.sync();
    expect(server.tasks[task.id]?['title'], '初始标题');
    expect(deviceA.store.pendingCount, 0);

    await deviceB.engine.sync(full: true);
    expect(deviceB.store.task(task.id)?.title, '初始标题');

    // A edits the title, B edits the notes. B reaches the server first.
    await deviceA.repo.updateTitle(task.id, 'A 改的标题');
    await deviceB.repo.updateNotes(task.id, 'B 改的备注');
    await deviceB.engine.sync();
    expect(server.tasks[task.id]?['title'], '初始标题');
    expect(server.tasks[task.id]?['notes'], 'B 改的备注');

    // A pulls B's notes, conflicts on push, merges and retries with a new
    // opId. Both fields must survive.
    await deviceA.engine.sync();
    expect(deviceA.store.task(task.id)?.title, 'A 改的标题');
    expect(deviceA.store.task(task.id)?.notes, 'B 改的备注');
    expect(deviceA.store.pendingCount, 0);
    expect(deviceA.store.conflictCount, 0);
    expect(server.tasks[task.id]?['title'], 'A 改的标题');
    expect(server.tasks[task.id]?['notes'], 'B 改的备注');

    // B converges on the next pull.
    await deviceB.engine.sync();
    expect(deviceB.store.task(task.id)?.title, 'A 改的标题');
    expect(deviceB.store.task(task.id)?.notes, 'B 改的备注');
  });

  test('due, priority, tags and subtasks round-trip through the protocol',
      () async {
    await deviceA.engine.sync(full: true);
    final task = await deviceA.repo.createTask(
      title: '字段同步',
      listId: deviceA.store.inbox()!.id,
    );
    await deviceA.engine.sync();

    final baseline = deviceA.store.task(task.id)!;
    await deviceA.repo.saveEdits(
      task.id,
      baseline: baseline,
      title: baseline.title,
      notes: '带字段的备注',
      dueAt: DateTime.utc(2026, 11, 1, 9),
      allDay: false,
      priority: 3,
      tags: const ['工作', 'P1'],
      checklist: const [
        ChecklistItem(id: 'step-1', title: '第一步'),
      ],
    );
    await deviceA.engine.sync();
    expect(deviceA.store.pendingCount, 0);

    await deviceB.engine.sync(full: true);
    final remote = deviceB.store.task(task.id)!;
    expect(remote.notes, '带字段的备注');
    expect(remote.dueAt, DateTime.utc(2026, 11, 1, 9));
    expect(remote.allDay, false);
    expect(remote.priority, 3);
    expect(remote.tags, ['工作', 'P1']);
    expect(remote.checklist.single.title, '第一步');

    await deviceB.repo.toggleChecklistItem(task.id, 'step-1');
    await deviceB.engine.sync();
    await deviceA.engine.sync();
    expect(deviceA.store.task(task.id)!.checklist.single.done, true);
  });

  test('offline list + task, rename, move and delete converge', () async {
    await deviceA.engine.sync(full: true);
    final list = await deviceA.repo.createList(name: '项目');
    final task = await deviceA.repo.createTask(
      title: '清单里的任务',
      listId: list.id,
    );
    // The list create must be pushed before the task that references it.
    await deviceA.engine.sync();
    expect(server.lists[list.id]?['name'], '项目');
    expect(server.tasks[task.id]?['listId'], list.id);
    expect(deviceA.store.pendingCount, 0);

    await deviceB.engine.sync(full: true);
    expect(deviceB.store.list(list.id)?.name, '项目');
    expect(deviceB.store.task(task.id)?.listId, list.id);

    await deviceA.repo.updateList(list.id, name: '项目 2');
    await deviceA.engine.sync();
    await deviceB.engine.sync();
    expect(deviceB.store.list(list.id)?.name, '项目 2');

    final archive = await deviceA.repo.createList(name: '归档');
    await deviceA.engine.sync();
    final baseline = deviceA.store.task(task.id)!;
    await deviceA.repo.saveEdits(
      task.id,
      baseline: baseline,
      title: baseline.title,
      notes: baseline.notes,
      dueAt: baseline.dueAt,
      allDay: baseline.allDay,
      priority: baseline.priority,
      tags: baseline.tags,
      checklist: baseline.checklist,
      listId: archive.id,
    );
    await deviceA.engine.sync();
    expect(server.tasks[task.id]?['listId'], archive.id);
    await deviceB.engine.sync();
    expect(deviceB.store.task(task.id)?.listId, archive.id);

    await deviceA.repo.deleteList(archive.id);
    await deviceA.engine.sync();
    expect(server.lists.containsKey(archive.id), false);
    expect(server.tasks[task.id]?['listId'], server.inboxId);

    await deviceB.engine.sync();
    expect(deviceB.store.list(archive.id), isNull);
    expect(deviceB.store.task(task.id)?.listId, deviceB.store.inbox()!.id);
    expect(deviceB.store.task(task.id)?.deleted, false);
  });

  test('network failure keeps the same opId and retries idempotently', () async {
    await deviceA.engine.sync(full: true);
    final task = await deviceA.repo.createTask(
      title: '离线任务',
      listId: deviceA.store.inbox()!.id,
    );
    await deviceA.engine.sync();

    deviceA.api.failNextPush = true;
    await deviceA.repo.updateTitle(task.id, '离线标题');
    final before = deviceA.store.pendingOp('task', task.id)!;

    await expectLater(
      deviceA.engine.sync(),
      throwsA(isA<SyncApiException>()),
    );
    final after = deviceA.store.pendingOp('task', task.id)!;
    expect(after.opId, before.opId);
    expect(after.attempts, 1);
    expect(deviceA.store.task(task.id)?.title, '离线标题');

    await deviceA.engine.sync();
    expect(deviceA.store.pendingCount, 0);
    expect(server.tasks[task.id]?['title'], '离线标题');
  });

  test('delete conflicts are retried and deletion wins', () async {
    await deviceA.engine.sync(full: true);
    final task = await deviceA.repo.createTask(
      title: '要删除',
      listId: deviceA.store.inbox()!.id,
    );
    await deviceA.engine.sync();
    await deviceB.engine.sync(full: true);

    await deviceA.repo.deleteTask(task.id);
    await deviceB.repo.updateNotes(task.id, 'B 又改了');
    await deviceB.engine.sync();

    await deviceA.engine.sync();
    expect(server.tasks[task.id]?['deleted'], true);
    expect(deviceA.store.task(task.id)?.deleted, true);
    expect(deviceA.store.pendingCount, 0);

    await deviceB.engine.sync();
    expect(deviceB.store.task(task.id)?.deleted, true);
  });

  test('creating and deleting before sync touches neither server nor outbox',
      () async {
    await deviceB.engine.sync(full: true);
    final temp = await deviceB.repo.createTask(
      title: '临时',
      listId: deviceB.store.inbox()!.id,
    );
    expect(deviceB.store.pendingCount, 1);
    await deviceB.repo.deleteTask(temp.id);
    expect(deviceB.store.task(temp.id), isNull);
    expect(deviceB.store.pendingCount, 0);
    expect(server.tasks[temp.id], isNull);
  });

  test('opId replay is idempotent on the server contract', () async {
    final before = server.appliedOps;
    final op = OutboxOp(
      opId: '01idem00000000000000000001',
      entity: 'task',
      entityId: '01idemtask0000000000000001',
      action: 'create',
      patch: {'title': '幂等', 'listId': server.inboxId},
    );
    final first = await server.push(ops: [op], deviceId: 'test');
    final second = await server.push(ops: [op], deviceId: 'test');
    expect(first.single.status, 'ok');
    expect(second.single.status, 'ok');
    expect(server.appliedOps, before + 1);
  });

  test('pull paginates and resumes from the returned cursor', () async {
    await deviceA.engine.sync(full: true);
    await deviceA.repo.createTask(
      title: '一',
      listId: deviceA.store.inbox()!.id,
    );
    await deviceA.repo.createTask(
      title: '二',
      listId: deviceA.store.inbox()!.id,
    );
    await deviceA.engine.sync();

    final firstPage = await server.pull(since: '0', limit: 2);
    expect(firstPage.hasMore, true);
    expect(firstPage.tasks.length + firstPage.lists.length, 2);

    final secondPage = await server.pull(
      since: firstPage.cursor,
      limit: 2,
    );
    expect(secondPage.cursor, isNot(firstPage.cursor));
    expect(secondPage.tasks.length + secondPage.lists.length, greaterThan(0));
  });
}
