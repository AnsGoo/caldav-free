import 'dart:convert';

import 'package:caldav_free/data/focus/focus_api.dart';
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

    await api.saveSession(
      startedAt: DateTime.utc(2026, 10, 25, 10),
      endedAt: DateTime.utc(2026, 10, 25, 10, 25),
      durationSeconds: 1500,
    );
    expect(calls, ['GET /api/sync/focus', 'POST /api/sync/focus/sessions']);
    api.close();
  });
}
