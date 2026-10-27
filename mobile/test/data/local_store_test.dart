import 'dart:convert';
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

  test(
    'accent choice defaults and updates without touching task data',
    () async {
      final store = LocalStore.memory();
      expect(store.accent, '#3563F0');
      await store.setAccent('#C23B5A');
      expect(store.accent, '#C23B5A');
      await store.dispose();
    },
  );

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

  test('saveEdits sends only fields changed against the editor baseline', () async {
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
      startAt: baseline.startAt,
      dueAt: DateTime.utc(2026, 10, 30),
      allDay: true,
      priority: 3,
      reminderOffsets: baseline.reminderOffsets,
      pinned: baseline.pinned,
      recurrence: baseline.recurrence,
      tags: const ['p1', '工作'],
      checklist: const [ChecklistItem(id: 'sub-1', title: '第一步')],
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
    await store.saveTask(local.copyWith(notes: '远端备注'), dirty: false);
    await repo.saveEdits(
      task.id,
      baseline: baseline,
      title: '再改标题',
      notes: baseline.notes,
      startAt: baseline.startAt,
      dueAt: DateTime.utc(2026, 10, 30),
      allDay: true,
      priority: 3,
      reminderOffsets: baseline.reminderOffsets,
      pinned: baseline.pinned,
      recurrence: baseline.recurrence,
      tags: const ['p1', '工作'],
      checklist: const [ChecklistItem(id: 'sub-1', title: '第一步')],
    );
    expect(store.task(task.id)!.notes, '远端备注');
    await store.dispose();
  });

  test('saveEdits patches start time, reminders and pin state', () async {
    final store = LocalStore.memory();
    final repo = TaskRepository(store);
    final task = await repo.createTask(title: '提醒任务', listId: 'list-1');
    final createOp = store.pendingOp('task', task.id)!;
    await store.removeOp(createOp.opId);
    final baseline = store.task(task.id)!;

    final start = DateTime.utc(2026, 10, 26, 8);
    final due = DateTime.utc(2026, 10, 26, 18);
    await repo.saveEdits(
      task.id,
      baseline: baseline,
      title: baseline.title,
      notes: baseline.notes,
      startAt: start,
      dueAt: due,
      allDay: false,
      priority: 0,
      reminderOffsets: const [60, 5, 5, 20000],
      pinned: true,
      recurrence: 'FREQ=DAILY',
      tags: const [],
      checklist: const [],
    );

    final op = store.pendingOp('task', task.id)!;
    expect(op.patch['start'], '2026-10-26T08:00:00.000Z');
    expect(op.patch['reminderOffsets'], [5, 60]);
    expect(op.patch['pinned'], true);
    expect(op.patch['recurrence'], 'FREQ=DAILY');
    final local = store.task(task.id)!;
    expect(local.startAt, start);
    expect(local.reminderOffsets, [5, 60]);
    expect(local.pinned, true);
    expect(local.recurrence, 'FREQ=DAILY');
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
      startAt: task.startAt,
      dueAt: null,
      allDay: false,
      priority: 0,
      reminderOffsets: task.reminderOffsets,
      pinned: task.pinned,
      recurrence: task.recurrence,
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

  test('batch field helpers patch priority, due and tags', () async {
    final store = LocalStore.memory();
    final repo = TaskRepository(store);
    final task = await repo.createTask(title: '批量字段', listId: 'list-1');

    await repo.updatePriority(task.id, 3);
    final due = DateTime.utc(2026, 11, 5, 9);
    await repo.setDue(task.id, due);
    await repo.addTags(task.id, ['工作', '批量', '工作']);

    final local = store.task(task.id)!;
    expect(local.priority, 3);
    expect(local.dueAt, due);
    expect(local.tags, ['工作', '批量']);
    final op = store.pendingOp('task', task.id)!;
    expect(op.patch['priority'], 3);
    expect(op.patch['due'], '2026-11-05T09:00:00.000Z');
    expect(op.patch['tags'], ['工作', '批量']);
    await store.dispose();
  });

  test('smart views filter by due date', () async {
    final store = LocalStore.memory();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    Future<void> save(String id, String title, DateTime? due) {
      return store.saveTask(
        TaskItem(
          id: id,
          listId: 'list-1',
          title: title,
          dueAt: due,
          updatedAt: DateTime.now().toUtc(),
        ),
        dirty: false,
      );
    }

    await save(
      'overdue',
      '逾期',
      start.subtract(const Duration(days: 1)).toUtc(),
    );
    await save('today', '今天', start.add(const Duration(hours: 10)).toUtc());
    await save(
      'tomorrow',
      '明天',
      start.add(const Duration(days: 1, hours: 10)).toUtc(),
    );
    await save('week', '本周', start.add(const Duration(days: 5)).toUtc());
    await save('later', '以后', start.add(const Duration(days: 10)).toUtc());
    await save('none', '无日期', null);

    List<String> titles(String view) => store
        .tasksSnapshot(completed: false, view: view)
        .map((task) => task.title)
        .toList();

    expect(titles('today'), containsAll(['逾期', '今天']));
    expect(titles('today'), isNot(contains('明天')));
    expect(titles('next7'), containsAll(['今天', '明天', '本周']));
    expect(titles('next7'), isNot(contains('逾期')));
    expect(titles('next7'), isNot(contains('以后')));
    expect(titles('all').length, 6);
    await store.dispose();
  });

  test('data survives reopening the SQLite database', () async {
    final directory = await Directory.systemTemp.createTemp('caldav-store');
    final path = '${directory.path}/store.json';
    final store = await LocalStore.open(path: path);
    final repo = TaskRepository(store);
    final task = await repo.createTask(title: '持久化', listId: 'list-1');
    await store.setAccent('#C23B5A');
    await store.writeCursor('42');
    await store.dispose();

    final reopened = await LocalStore.open(path: path);
    expect(reopened.task(task.id)?.title, '持久化');
    expect(reopened.pendingCount, 1);
    expect(reopened.pendingOp('task', task.id)?.patch['title'], '持久化');
    expect(reopened.accent, '#C23B5A');
    expect(reopened.cursor, '42');
    await reopened.dispose();
    await directory.delete(recursive: true);
  });

  test('deleted rows and cleared lists stay deleted after reopen', () async {
    final directory = await Directory.systemTemp.createTemp('caldav-store');
    final path = '${directory.path}/store.json';
    final store = await LocalStore.open(path: path);
    final repo = TaskRepository(store);
    final keep = await repo.createTask(title: '留下', listId: 'list-1');
    final drop = await repo.createTask(title: '删除', listId: 'list-1');
    await store.saveList(
      TaskListItem(id: 'list-1', name: '清单', updatedAt: DateTime.now()),
    );
    await store.hardDeleteTask(drop.id);
    await store.dispose();

    final reopened = await LocalStore.open(path: path);
    expect(reopened.task(keep.id)?.title, '留下');
    expect(reopened.task(drop.id), isNull);
    expect(reopened.allTasks().map((task) => task.id), isNot(contains(drop.id)));
    expect(reopened.listsSnapshot().single.name, '清单');
    await reopened.dispose();
    await directory.delete(recursive: true);
  });

  test('the legacy JSON file is imported once and kept as a backup', () async {
    final directory = await Directory.systemTemp.createTemp('caldav-store');
    final path = '${directory.path}/store.json';
    final task = TaskItem(
      id: 'task-1',
      listId: 'list-1',
      title: '旧数据',
      tags: const ['有,逗号'],
      reminderOffsets: const [10, 0],
      checklist: const [ChecklistItem(id: 'c-1', title: '子项')],
      updatedAt: DateTime.parse('2026-10-01T00:00:00Z'),
    );
    File(path).writeAsStringSync(
      jsonEncode({
        'schema': 1,
        'cursor': '7',
        'accent': '#123456',
        'tasks': {
          task.id: {'dirty': true, 'data': task.toWireJson()},
        },
        'lists': {
          'list-1': TaskListItem(
            id: 'list-1',
            name: '旧清单',
            updatedAt: DateTime.parse('2026-10-01T00:00:00Z'),
          ).toWireJson(),
        },
        'outbox': {
          'op-1': OutboxRecord(
            opId: 'op-1',
            entity: 'task',
            entityId: task.id,
            action: 'update',
            patch: const {'title': '旧数据'},
            attempts: 3,
            nextTryAt: DateTime.parse('2026-10-01T00:00:00Z'),
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
          ).toJson(),
        },
      }),
    );

    final store = await LocalStore.open(path: path);
    expect(store.cursor, '7');
    expect(store.accent, '#123456');
    expect(store.task(task.id)?.tags, ['有,逗号']);
    expect(store.task(task.id)?.reminderOffsets, [10, 0]);
    expect(store.task(task.id)?.checklist.single.title, '子项');
    expect(store.isDirty, isTrue);
    expect(store.listsSnapshot().single.name, '旧清单');
    expect(store.pendingOp('task', task.id)?.attempts, 3);
    await store.dispose();

    expect(File(path).existsSync(), isFalse);
    expect(File('$path.migrated.bak').existsSync(), isTrue);

    final reopened = await LocalStore.open(path: path);
    expect(reopened.task(task.id)?.title, '旧数据');
    expect(reopened.pendingCount, 1);
    await reopened.dispose();
    await directory.delete(recursive: true);
  });
}
