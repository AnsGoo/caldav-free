import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class CountdownItem {
  const CountdownItem({
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    required this.repeat,
    required this.pinned,
    required this.status,
    required this.color,
    required this.icon,
    required this.remark,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.state,
    required this.occurrenceDate,
    required this.age,
  });

  final int id;
  final String name;
  final String type;
  final int date;
  final String repeat;
  final bool pinned;
  final int status;
  final String color;
  final String icon;
  final String remark;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;
  final String state;
  final int occurrenceDate;
  final int age;

  factory CountdownItem.fromJson(Map<String, dynamic> json) => CountdownItem(
    id: _int(json['id'], 0),
    name: (json['name'] ?? '').toString(),
    type: (json['type'] ?? 'countdown').toString(),
    date: _int(json['date'], 0),
    repeat: (json['repeat'] ?? 'none').toString(),
    pinned: json['pinned'] == true,
    status: _int(json['status'], 0),
    color: (json['color'] ?? '#92D0FF').toString(),
    icon: (json['icon'] ?? '⏳').toString(),
    remark: (json['remark'] ?? '').toString(),
    days: _int(json['days'], 0),
    hours: _int(json['hours'], 0),
    minutes: _int(json['minutes'], 0),
    seconds: _int(json['seconds'], 0),
    state: (json['state'] ?? 'future').toString(),
    occurrenceDate: _int(json['occurrenceDate'], 0),
    age: _int(json['age'], 0),
  );

  bool get isToday => state == 'today';
  bool get isPast => state == 'past';
}

class CountdownDraft {
  const CountdownDraft({
    required this.name,
    required this.date,
    required this.type,
    required this.repeat,
    required this.pinned,
    required this.color,
    required this.remark,
  });

  final String name;
  final DateTime date;
  final String type;
  final String repeat;
  final bool pinned;
  final String color;
  final String remark;

  int get stamp => date.year * 10000 + date.month * 100 + date.day;

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'date': stamp,
    'calendar': 'solar',
    'repeat': repeat,
    'pinned': pinned,
    'color': color,
    'remark': remark,
  };
}

class CountdownApi {
  CountdownApi({
    required String baseUrl,
    required this.username,
    required this.password,
    http.Client? client,
  }) : baseUrl = _normalize(baseUrl),
       _client = client ?? http.Client();

  final String baseUrl;
  final String username;
  final String password;
  final http.Client _client;

  static String _normalize(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Map<String, String> get _headers => {
    'Authorization':
        'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    'Accept': 'application/json',
  };

  Future<List<CountdownItem>> fetch() async {
    final body = await _request('GET', '/api/sync/countdowns');
    return (body['countdowns'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CountdownItem.fromJson)
        .toList(growable: false);
  }

  Future<CountdownItem> create(CountdownDraft draft) async {
    final body = await _request(
      'POST',
      '/api/sync/countdowns',
      payload: draft.toJson(),
    );
    final item = body['countdown'];
    if (item is! Map<String, dynamic>) {
      throw CountdownApiException('创建倒数记录失败：响应缺少倒数值');
    }
    return CountdownItem.fromJson(item);
  }

  Future<CountdownItem> update(int id, CountdownDraft draft) async {
    final body = await _request(
      'PATCH',
      '/api/sync/countdowns/$id',
      payload: draft.toJson(),
    );
    final item = body['countdown'];
    if (item is! Map<String, dynamic>) {
      throw CountdownApiException('更新倒数记录失败：响应缺少倒数值');
    }
    return CountdownItem.fromJson(item);
  }

  Future<void> delete(int id) async {
    await _request('DELETE', '/api/sync/countdowns/$id');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? payload,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.Request(method, uri)
      ..headers.addAll({
        ..._headers,
        if (payload != null) 'Content-Type': 'application/json; charset=utf-8',
      });
    if (payload != null) request.body = jsonEncode(payload);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 10));
    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } on FormatException {
        body = const {};
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body['error']?.toString();
      throw CountdownApiException(
        message == null || message.isEmpty
            ? '倒数服务返回 HTTP ${response.statusCode}'
            : message,
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  void close() => _client.close();
}

class CountdownApiException implements Exception {
  CountdownApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

int _int(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
