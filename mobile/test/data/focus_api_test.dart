import 'dart:convert';

import 'package:caldav_free/data/focus/focus_api.dart';
import 'package:caldav_free/data/focus/focus_store.dart';
import 'package:caldav_free/data/focus/focus_write_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('focus API parses dashboard and saves a session', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'preferences': {'pomodoroMinutes': 25, 'dailyGoal': 4},
            'stats': {
              'todayPomodoroCount': 2,
              'todayFocusMinutes': 50,
              'totalPomodoroCount': 10,
              'dailyGoal': 4,
            },
            'sessions': [
              {
                'id': 7,
                'title': '专注',
                'mode': 'pomodoro',
                'startedAt': '2026-10-25T10:00:00Z',
                'endedAt': '2026-10-25T10:25:00Z',
                'durationSeconds': 1500,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['durationSeconds'], 1500);
      expect(body['mode'], 'pomodoro');
      return http.Response('{"session":{"id":8}}', 201);
    });
    final api = FocusApi(
      baseUrl: 'http://example.test/',
      username: 'demo',
      password: 'secret',
      client: client,
    );
    final dash = await api.fetch();
    expect(dash.preferences.pomodoroMinutes, 25);
    expect(dash.stats.todayPomodoroCount, 2);
    expect(dash.sessions.single.durationSeconds, 1500);
    api.close();
  });

  test('focus writes stay queued locally and sync on the background flush', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      return http.Response(
        jsonEncode({
          'session': {'id': 8},
        }),
        201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final queue = FocusWriteQueue.inMemory();
    final api = FocusApi(
      baseUrl: 'http://example.test',
      username: 'demo',
      password: 'secret',
      client: client,
      writeQueue: queue,
    );
    final store = FocusStore.inMemory(queue: queue);
    await store.saveSession(
      startedAt: DateTime.utc(2026, 10, 25, 10),
      endedAt: DateTime.utc(2026, 10, 25, 10, 25),
      durationSeconds: 1500,
    );
    expect(calls, isEmpty);
    // The page only writes locally; the background sync pass replays the queue.
    await api.flush();
    expect(calls, ['POST /api/sync/focus/sessions']);
    api.close();
  });
}
