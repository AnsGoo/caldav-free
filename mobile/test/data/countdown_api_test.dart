import 'dart:convert';

import 'package:caldav_free/core/ids.dart';
import 'package:caldav_free/data/countdowns/countdown_api.dart';
import 'package:caldav_free/data/countdowns/countdown_write_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

CountdownDraft _draft() => CountdownDraft(
  name: '新年',
  date: DateTime(2027, 1, 1),
  type: 'festival',
  repeat: 'yearly',
  pinned: false,
  color: '#66BB6A',
  remark: '一起跨年',
);

void main() {
  test('countdown API lists server records', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      return http.Response(
        jsonEncode({
          'countdowns': [
            {
              'id': 1,
              'name': '旅行',
              'type': 'countdown',
              'date': 20261231,
              'repeat': 'none',
              'pinned': true,
              'status': 0,
              'color': '#FF8A65',
              'icon': '✈️',
              'remark': '出发',
              'days': 67,
              'state': 'future',
              'occurrenceDate': 20261231,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = CountdownApi(
      baseUrl: 'http://example.test/',
      username: 'demo',
      password: 'secret',
      client: client,
      writeQueue: CountdownWriteQueue.inMemory(),
    );
    final items = await api.fetch();
    expect(items.single.name, '旅行');
    expect(items.single.pinned, isTrue);
    expect(items.single.days, 67);
    api.close();
  });

  test('writes are queued locally and replayed on flush', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['date'], 20270101);
        expect(body['repeat'], 'yearly');
        return http.Response(
          jsonEncode({
            'countdown': {
              'id': 2,
              'name': body['name'],
              'type': body['type'],
              'date': body['date'],
              'repeat': body['repeat'],
              'pinned': body['pinned'],
              'status': 0,
              'color': body['color'],
              'icon': '⏳',
              'remark': body['remark'],
              'days': 68,
              'state': 'future',
              'occurrenceDate': 20270101,
            },
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({
          'countdowns': [
            {
              'id': 2,
              'name': '新年',
              'type': 'festival',
              'date': 20270101,
              'repeat': 'yearly',
              'pinned': false,
              'status': 0,
              'color': '#66BB6A',
              'icon': '⏳',
              'remark': '一起跨年',
              'days': 68,
              'state': 'future',
              'occurrenceDate': 20270101,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final queue = CountdownWriteQueue.inMemory();
    final api = CountdownApi(
      baseUrl: 'http://example.test',
      username: 'demo',
      password: 'secret',
      client: client,
      writeQueue: queue,
    );

    final created = await api.create(_draft());
    expect(created.id, lessThan(0));
    expect(created.name, '新年');
    expect(queue.isEmpty, isFalse);
    expect(calls, isEmpty);

    final updated = await api.update(created.id, _draft());
    expect(updated.name, '新年');
    // Temp-id edits rewrite the pending create instead of adding an update.
    expect((await queue.items()).where((op) => op.action == 'update'), isEmpty);

    final items = await api.load();
    await api.flush();
    expect(queue.isEmpty, isTrue);
    expect(items.single.id, 2);
    expect(items.single.name, '新年');
    expect(
      calls,
      containsAllInOrder([
        'POST /api/sync/countdowns',
        'GET /api/sync/countdowns',
      ]),
    );
    api.close();
  });

  test('failed write replays stay queued and temps never sync', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'countdowns': [
              {
                'id': 1,
                'name': '旅行',
                'type': 'countdown',
                'date': 20261231,
                'repeat': 'none',
                'pinned': false,
                'status': 0,
                'color': '#FF8A65',
                'icon': '✈️',
                'remark': '',
                'days': 67,
                'state': 'future',
                'occurrenceDate': 20261231,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      throw http.ClientException('unreachable');
    });
    final queue = CountdownWriteQueue.inMemory();
    final api = CountdownApi(
      baseUrl: 'http://example.test',
      username: 'demo',
      password: 'secret',
      client: client,
      writeQueue: queue,
    );

    final created = await api.create(_draft());
    final items = await api.load();
    expect(items.map((item) => item.name), containsAll(['旅行', '新年']));
    expect(items.firstWhere((item) => item.id == created.id).days, isNonNegative);
    // The failed replay keeps the create queued.
    expect((await queue.items()).length, 1);

    await api.delete(created.id);
    expect(queue.isEmpty, isTrue);
    final afterDelete = await api.load();
    expect(afterDelete.map((item) => item.id), isNot(contains(created.id)));
    expect(calls.where((call) => call.startsWith('DELETE')), isEmpty);
    await api.flush();
    api.close();
  });

  test('server rejections drop the op instead of retrying forever', () async {
    final queue = CountdownWriteQueue.inMemory();
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({'error': '名称过长'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({'countdowns': []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = CountdownApi(
      baseUrl: 'http://example.test',
      username: 'demo',
      password: 'secret',
      client: client,
      writeQueue: queue,
    );
    final badOpId = newSyncId();
    await queue.add(
      CountdownPendingOp(
        opId: badOpId,
        action: 'create',
        countdownId: -1,
        payload: _draft().toJson(),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await api.flush();
    expect(queue.isEmpty, isTrue);
    api.close();
  });
}
