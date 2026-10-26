import 'dart:convert';

import 'package:caldav_free/data/habits/habit_api.dart';
import 'package:caldav_free/data/habits/habit_write_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

HabitApi buildApi(
  http.Client client,
  HabitWriteQueue queue,
) =>
    HabitApi(
      baseUrl: 'http://localhost:5232',
      username: 'admin',
      password: 'admin',
      client: client,
      writeQueue: queue,
    );

http.Response jsonResponse(Map<String, Object?> body) =>
    http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});

void main() {
  const draft = HabitDraft(name: '跑步', color: '#FF0000');

  test('offline create returns temp item and queues the op', () async {
    final queue = HabitWriteQueue.inMemory();
    final api = buildApi(
      MockClient((_) async => throw http.ClientException('refused')),
      queue,
    );
    final item = await api.create(draft);
    expect(item.id, lessThan(0));
    expect(item.name, '跑步');
    final ops = await queue.items();
    expect(ops, hasLength(1));
    expect(ops.single.action, 'create');
  });

  test('fetch replays queued writes once the server is reachable', () async {
    final queue = HabitWriteQueue.inMemory();
    var online = false;
    final requests = <String>[];
    final client = MockClient((request) async {
      if (!online) throw http.ClientException('refused');
      requests.add('${request.method} ${request.url.path}');
      switch (request.url.path) {
        case '/api/sync/habits':
          if (request.method == 'POST') {
            return jsonResponse({
              'habit': {...draft.toJson(), 'id': 42},
            });
          }
          return jsonResponse({
            'habits': [
              {...draft.toJson(), 'id': 42},
            ],
            'checkins': [],
            'sections': [],
          });
        default:
          return jsonResponse({});
      }
    });
    final api = buildApi(client, queue);

    final tempItem = await api.create(draft);
    expect(tempItem.id, lessThan(0));
    await api.checkin(tempItem.id, 20261026);
    expect((await queue.items()).map((op) => op.action), [
      'create',
      'checkin',
    ]);

    online = true;
    final snapshot = await api.fetch();

    expect(
      requests,
      containsAllInOrder([
        'POST /api/sync/habits',
        'POST /api/sync/habits/42/checkin',
        'GET /api/sync/habits',
      ]),
    );
    expect(await queue.items(), isEmpty);
    expect(snapshot.habits.single.id, 42);
  });

  test('deleting an unsynced temp habit cancels its queued create', () async {
    final queue = HabitWriteQueue.inMemory();
    final api = buildApi(
      MockClient((_) async => throw http.ClientException('refused')),
      queue,
    );
    final item = await api.create(draft);
    await api.delete(item.id);
    expect(await queue.items(), isEmpty);
  });

  test('editing an unsynced temp habit rewrites the queued create', () async {
    final queue = HabitWriteQueue.inMemory();
    final api = buildApi(
      MockClient((_) async => throw http.ClientException('refused')),
      queue,
    );
    final item = await api.create(draft);
    await api.update(item.id, const HabitDraft(name: '游泳', color: '#00FF00'));
    final ops = await queue.items();
    expect(ops, hasLength(1));
    expect(ops.single.payload!['name'], '游泳');
  });
}
