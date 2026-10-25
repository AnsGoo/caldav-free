import 'dart:convert';

import 'package:caldav_free/data/habits/habit_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('habit API fetches habits and check-ins', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/sync/habits');
      expect(request.headers['Authorization'], startsWith('Basic '));
      return http.Response(
        jsonEncode({
          'habits': [
            {
              'id': 1,
              'name': '喝水',
              'color': '#4772fa',
              'goal': 8,
              'step': 1,
              'unit': '杯',
              'frequency': '{"type":"daily"}',
              'status': 0,
              'dueToday': true,
              'doneToday': false,
              'currentStreak': 3,
              'maxStreak': 9,
              'totalCheckIns': 30,
            },
          ],
          'checkins': [
            {
              'habitId': 1,
              'checkinStamp': 20261025,
              'value': 3,
              'goal': 8,
              'status': 0,
            },
          ],
          'sections': [],
          'preferences': {'showInToday': true},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = HabitApi(
      baseUrl: 'http://example.test/',
      username: 'demo',
      password: 'secret',
      client: client,
    );
    final snapshot = await api.fetch();
    final habit = snapshot.habits.single;
    expect(habit.name, '喝水');
    expect(habit.goal, 8);
    expect(habit.currentStreak, 3);
    expect(habit.dueToday, true);
    expect(snapshot.checkins.single.value, 3);
    expect(snapshot.checkins.single.done, false);
    api.close();
  });

  test('habit API posts check-in and create requests', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.method == 'POST' && request.url.path.endsWith('/checkin')) {
        expect(jsonDecode(request.body)['stamp'], 20261025);
        return http.Response('{}', 200);
      }
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['name'], '早起');
      return http.Response(
        jsonEncode({
          'habit': {'id': 2, 'name': '早起', 'status': 0},
        }),
        201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = HabitApi(
      baseUrl: 'http://example.test',
      username: 'demo',
      password: 'secret',
      client: client,
    );
    await api.checkin(1, 20261025);
    final created = await api.create(
      const HabitDraft(name: '早起', color: '#22c55e'),
    );
    expect(created.id, 2);
    expect(calls, ['POST /api/sync/habits/1/checkin', 'POST /api/sync/habits']);
    api.close();
  });
}
