import 'dart:convert';

import 'package:caldav_free/data/calendar/calendar_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('calendar API parses sources, events and task occurrences', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/sync/calendar');
      expect(request.url.queryParameters['from'], isNotEmpty);
      expect(request.headers['Authorization'], startsWith('Basic '));
      return http.Response(
        jsonEncode({
          'calendars': [
            {'id': 3, 'name': '工作日历', 'color': '#4772fa'},
          ],
          'events': [
            {
              'id': '3:cal.ics:1',
              'uid': 'evt-1',
              'href': 'evt-1.ics',
              'calendarId': 3,
              'calendarName': '工作日历',
              'color': '#4772fa',
              'summary': '周会',
              'location': '会议室',
              'description': '同步进度',
              'start': '2026-10-26T02:00:00Z',
              'end': '2026-10-26T03:00:00Z',
              'allDay': false,
              'recurring': true,
              'rrule': 'FREQ=WEEKLY',
              'attendees': ['a@example.com'],
              'reminders': [10, 0],
            },
          ],
          'tasks': [
            {
              'id': 9,
              'syncId': 'task-sync-1',
              'title': '写周报',
              'listName': '工作',
              'listColor': '#22c55e',
              'due': '2026-10-26T10:00:00Z',
              'priority': 2,
              'virtual': false,
            },
          ],
          'from': '2026-10-01T00:00:00Z',
          'to': '2026-11-01T00:00:00Z',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = CalendarApi(
      baseUrl: 'http://example.test/',
      username: 'demo',
      password: 'secret',
      client: client,
    );

    final snapshot = await api.fetch(
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 11, 1),
    );

    expect(snapshot.sources.single.name, '工作日历');
    final event = snapshot.events.single;
    expect(event.summary, '周会');
    expect(event.start, DateTime.utc(2026, 10, 26, 2));
    expect(event.recurring, true);
    expect(event.href, 'evt-1.ics');
    expect(event.rrule, 'FREQ=WEEKLY');
    expect(event.attendees, ['a@example.com']);
    expect(event.reminders, [10, 0]);
    final task = snapshot.tasks.single;
    expect(task.syncId, 'task-sync-1');
    expect(task.title, '写周报');
    expect(task.due, DateTime.utc(2026, 10, 26, 10));
    expect(task.listName, '工作');
    api.close();
  });

  test('calendar almanac parses lunar, solar terms and festivals', () async {
    final api = CalendarApi(
      baseUrl: 'http://example.test',
      username: 'demo',
      password: 'secret',
      client: MockClient((request) async {
        expect(request.url.path, '/api/sync/calendar/almanac');
        return http.Response(
          jsonEncode({
            'days': [
              {
                'date': '2026-10-01',
                'lunar': '八月廿一',
                'jieQi': '',
                'festival': '国庆节',
                'label': '国庆节',
              },
              {
                'date': '2026-10-08',
                'lunar': '八月廿八',
                'jieQi': '寒露',
                'festival': '',
                'label': '寒露',
              },
              {
                'date': '2026-10-09',
                'lunar': '八月廿九',
                'jieQi': '',
                'festival': '',
                'label': '八月廿九',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final days = await api.fetchAlmanac(
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 10, 10),
    );
    expect(days['2026-10-01']?.label, '国庆节');
    expect(days['2026-10-01']?.special, true);
    expect(days['2026-10-08']?.jieQi, '寒露');
    expect(days['2026-10-09']?.special, false);
    api.close();
  });

  test('calendar API surfaces server errors', () async {
    final api = CalendarApi(
      baseUrl: 'http://example.test',
      username: 'demo',
      password: 'wrong',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode('{"error":"用户名或密码错误"}'),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await expectLater(
      api.fetch(from: DateTime.utc(2026, 10, 1), to: DateTime.utc(2026, 11, 1)),
      throwsA(
        isA<CalendarApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    api.close();
  });
}
