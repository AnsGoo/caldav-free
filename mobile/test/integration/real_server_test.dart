import 'dart:convert';
import 'dart:io';

import 'package:caldav_free/core/ids.dart';
import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/remote/sync_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Real-server regression for the P0 network layer.
///
/// Run with a live backend:
///   CALDAV_SYNC_BASE=http://127.0.0.1:5232 \
///   CALDAV_SYNC_USER=admin CALDAV_SYNC_PASS=... \
///   flutter test test/integration/real_server_test.dart
void main() {
  final base = Platform.environment['CALDAV_SYNC_BASE'] ?? '';
  final user = Platform.environment['CALDAV_SYNC_USER'] ?? 'admin';
  final password = Platform.environment['CALDAV_SYNC_PASS'] ?? '';
  if (base.isEmpty || password.isEmpty) {
    test('real server e2e', () {}, skip: 'set CALDAV_SYNC_BASE/PASS to run');
    return;
  }

  test('real server: list create, task move and list delete', () async {
    final api = HttpSyncApi(baseUrl: base, username: user, password: password);
    addTearDown(api.close);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final listId = newSyncId();
    final taskId = newSyncId();

    final initial = await api.pull(since: '0');
    final inboxId = initial.lists
        .firstWhere((list) => list['isInbox'] == true)['id'] as String;

    final createdList = (await api.push(
      ops: [
        OutboxOp(
          opId: newSyncId(),
          entity: 'list',
          entityId: listId,
          action: 'create',
          patch: {'name': 'P1 列表 $stamp', 'color': '#22c55e'},
        ),
      ],
      deviceId: 'p0-e2e',
    ))
        .single;
    expect(createdList.status, 'ok', reason: createdList.errorMessage);
    final listEtag = createdList.etag;

    final createdTask = (await api.push(
      ops: [
        OutboxOp(
          opId: newSyncId(),
          entity: 'task',
          entityId: taskId,
          action: 'create',
          patch: {'title': '列表任务 $stamp', 'listId': listId},
        ),
      ],
      deviceId: 'p0-e2e',
    ))
        .single;
    expect(createdTask.status, 'ok', reason: createdTask.errorMessage);

    final page = await api.pull(since: '0');
    final list = page.lists.firstWhere((json) => json['id'] == listId);
    expect(list['name'], 'P1 列表 $stamp');
    final task = TaskItem.fromWireJson(
      page.tasks.firstWhere((json) => json['id'] == taskId),
    );
    expect(task.listId, listId);

    final deleted = (await api.push(
      ops: [
        OutboxOp(
          opId: newSyncId(),
          entity: 'list',
          entityId: listId,
          action: 'delete',
          baseEtag: listEtag,
          patch: const {},
        ),
      ],
      deviceId: 'p0-e2e',
    ))
        .single;
    expect(deleted.status, 'ok');

    final after = await api.pull(since: '0');
    final moved = TaskItem.fromWireJson(
      after.tasks.firstWhere((json) => json['id'] == taskId),
    );
    expect(moved.listId, inboxId);
    final tombstone = after.tombstones.any(
      (item) => item.entity == 'list' && item.id == listId,
    );
    expect(tombstone, true);
  });

  test('real server: folder create, list assignment and folder delete',
      () async {
    final api = HttpSyncApi(baseUrl: base, username: user, password: password);
    addTearDown(api.close);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final folderId = newSyncId();
    final listId = newSyncId();

    final createdFolder = (await api.push(
      ops: [
        OutboxOp(
          opId: newSyncId(),
          entity: 'folder',
          entityId: folderId,
          action: 'create',
          patch: {'name': 'P1 文件夹 $stamp', 'order': 1},
        ),
      ],
      deviceId: 'p0-e2e',
    ))
        .single;
    expect(createdFolder.status, 'ok', reason: createdFolder.errorMessage);
    final folderEtag = createdFolder.etag;

    final createdList = (await api.push(
      ops: [
        OutboxOp(
          opId: newSyncId(),
          entity: 'list',
          entityId: listId,
          action: 'create',
          patch: {
            'name': 'P1 文件夹清单 $stamp',
            'color': '#8b5cf6',
            'folderId': folderId,
          },
        ),
      ],
      deviceId: 'p0-e2e',
    ))
        .single;
    expect(createdList.status, 'ok', reason: createdList.errorMessage);

    final page = await api.pull(since: '0');
    final folder = page.folders.firstWhere((json) => json['id'] == folderId);
    expect(folder['name'], 'P1 文件夹 $stamp');
    final list = page.lists.firstWhere((json) => json['id'] == listId);
    expect(list['folderId'], folderId);

    final deleted = (await api.push(
      ops: [
        OutboxOp(
          opId: newSyncId(),
          entity: 'folder',
          entityId: folderId,
          action: 'delete',
          baseEtag: folderEtag,
          patch: const {},
        ),
      ],
      deviceId: 'p0-e2e',
    ))
        .single;
    expect(deleted.status, 'ok');

    final after = await api.pull(since: '0');
    final ungrouped = after.lists.firstWhere((json) => json['id'] == listId);
    expect(ungrouped['folderId'], isNull);
    expect(
      after.tombstones.any(
        (item) => item.entity == 'folder' && item.id == folderId,
      ),
      true,
    );
  });

  test('real server: create, conflict, idempotency, CalDAV import, delete',
      () async {
    final api = HttpSyncApi(baseUrl: base, username: user, password: password);
    addTearDown(api.close);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final taskId = newSyncId();

    final initial = await api.pull(since: '0');
    final inbox = initial.lists.firstWhere((list) => list['isInbox'] == true);
    final inboxId = inbox['id'] as String;

    final createOp = OutboxOp(
      opId: newSyncId(),
      entity: 'task',
      entityId: taskId,
      action: 'create',
      patch: {
        'listId': inboxId,
        'title': 'P0 E2E $stamp',
        'notes': 'v1',
        'due': '2026-11-01T09:00:00Z',
        'allDay': false,
        'priority': 2,
        'tags': ['p0', 'e2e'],
        'checklist': [
          {'id': 'step-1', 'title': '第一步', 'done': false},
        ],
      },
    );
    final created = (await api.push(ops: [createOp], deviceId: 'p0-e2e'))
        .single;
    expect(created.status, 'ok', reason: created.errorMessage);
    final etag1 = created.etag;

    final afterCreate = await api.pull(since: '0');
    final remote = afterCreate.tasks.firstWhere((json) => json['id'] == taskId);
    final parsed = TaskItem.fromWireJson(remote);
    expect(parsed.title, 'P0 E2E $stamp');
    expect(parsed.priority, 2);
    expect(parsed.dueAt, DateTime.utc(2026, 11, 1, 9));
    expect(parsed.allDay, false);
    expect(parsed.tags, containsAll(['p0', 'e2e']));
    expect(parsed.checklist.single.title, '第一步');
    expect(parsed.checklist.single.done, false);
    expect(parsed.etag, etag1);

    final updateOp = OutboxOp(
      opId: newSyncId(),
      entity: 'task',
      entityId: taskId,
      action: 'update',
      baseEtag: etag1,
      patch: {'title': 'P0 A $stamp'},
    );
    final update = await api.push(
      ops: [updateOp],
      deviceId: 'p0-e2e',
    );
    expect(update.single.status, 'ok');
    final etag2 = update.single.etag;

    final stale = await api.push(
      ops: [
        OutboxOp(
          opId: newSyncId(),
          entity: 'task',
          entityId: taskId,
          action: 'update',
          baseEtag: etag1,
          patch: {'notes': 'P0 B $stamp'},
        ),
      ],
      deviceId: 'p0-e2e',
    );
    expect(stale.single.status, 'conflict');
    expect(stale.single.entityJson?['title'], 'P0 A $stamp');

    final retry = await api.push(
      ops: [
        OutboxOp(
          opId: newSyncId(),
          entity: 'task',
          entityId: taskId,
          action: 'update',
          baseEtag: etag2,
          patch: {'notes': 'P0 B $stamp'},
        ),
      ],
      deviceId: 'p0-e2e',
    );
    expect(retry.single.status, 'ok');
    final etag3 = retry.single.etag;

    // Replaying the first update's opId returns the stored result.
    final replay = await api.push(ops: [updateOp], deviceId: 'p0-e2e');
    expect(replay.single.status, 'ok');
    expect(replay.single.etag, etag2);
    final stillFresh = await api.pull(since: '0');
    final current = TaskItem.fromWireJson(
      stillFresh.tasks.firstWhere((json) => json['id'] == taskId),
    );
    expect(current.title, 'P0 A $stamp');
    expect(current.notes, 'P0 B $stamp');

    final wrong = HttpSyncApi(
      baseUrl: base,
      username: user,
      password: 'definitely-wrong',
    );
    addTearDown(wrong.close);
    await expectLater(
      wrong.pull(since: '0'),
      throwsA(isA<SyncApiException>()),
    );

    // A CalDAV client writes a VTODO; refresh=1 imports it into the journal.
    final href = 'p0-e2e-$stamp.ics';
    final ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//caldav-free//p0-e2e//EN',
      'BEGIN:VTODO',
      'UID:p0-e2e-$stamp',
      'DTSTAMP:20261025T000000Z',
      'SUMMARY:来自 CalDAV P0 $stamp',
      'STATUS:NEEDS-ACTION',
      'END:VTODO',
      'END:VCALENDAR',
    ].join('\r\n');
    final put = await http.put(
      Uri.parse('$base/calendars/$user/caldav-tasks/$href'),
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$user:$password'))}',
        'Content-Type': 'text/calendar; charset=utf-8',
      },
      body: ics,
    );
    expect(put.statusCode, anyOf(201, 204));

    final refreshed = await api.pull(
      since: afterCreate.cursor,
      refresh: true,
    );
    final imported = refreshed.tasks.firstWhere(
      (json) => (json['title'] ?? '').toString().startsWith('来自 CalDAV P0'),
      orElse: () => <String, dynamic>{},
    );
    expect(imported['id'], isNotNull);

    final deleted = await api.push(
      ops: [
        OutboxOp(
          opId: newSyncId(),
          entity: 'task',
          entityId: taskId,
          action: 'delete',
          baseEtag: etag3,
          patch: const {},
        ),
      ],
      deviceId: 'p0-e2e',
    );
    expect(deleted.single.status, 'ok');

    final afterDelete = await api.pull(since: '0');
    final tomb = TaskItem.fromWireJson(
      afterDelete.tasks.firstWhere((json) => json['id'] == taskId),
    );
    expect(tomb.deleted, true);
  });
}
