import 'dart:convert';

import 'package:caldav_free/data/countdowns/countdown_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('countdown API lists, creates and updates records', () async {
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
      }
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
        request.method == 'POST' ? 201 : 200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = CountdownApi(
      baseUrl: 'http://example.test/',
      username: 'demo',
      password: 'secret',
      client: client,
    );
    final items = await api.fetch();
    expect(items.single.name, '旅行');
    expect(items.single.pinned, isTrue);
    expect(items.single.days, 67);

    final draft = CountdownDraft(
      name: '新年',
      date: DateTime(2027, 1, 1),
      type: 'festival',
      repeat: 'yearly',
      pinned: false,
      color: '#66BB6A',
      remark: '一起跨年',
    );
    final created = await api.create(draft);
    expect(created.id, 2);
    final updated = await api.update(2, draft);
    expect(updated.name, '新年');
    expect(calls, [
      'GET /api/sync/countdowns',
      'POST /api/sync/countdowns',
      'PATCH /api/sync/countdowns/2',
    ]);
    api.close();
  });
}
