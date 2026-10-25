import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class HabitItem {
  const HabitItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.sectionId,
    required this.goal,
    required this.step,
    required this.unit,
    required this.frequency,
    required this.status,
    required this.dueToday,
    required this.doneToday,
    required this.currentStreak,
    required this.maxStreak,
    required this.totalCheckIns,
    required this.targetDays,
    required this.completedCycles,
    required this.startDate,
  });

  final int id;
  final String name;
  final String icon;
  final String color;
  final int sectionId;
  final double goal;
  final double step;
  final String unit;
  final String frequency;
  final int status;
  final bool dueToday;
  final bool doneToday;
  final int currentStreak;
  final int maxStreak;
  final int totalCheckIns;
  final int targetDays;
  final int completedCycles;
  final int startDate;

  bool get archived => status == 1;

  factory HabitItem.fromJson(Map<String, dynamic> json) => HabitItem(
    id: _int(json['id']),
    name: (json['name'] ?? '').toString(),
    icon: (json['icon'] ?? '').toString(),
    color: (json['color'] ?? '').toString(),
    sectionId: _int(json['sectionId']),
    goal: _double(json['goal'], 1),
    step: _double(json['step'], 1),
    unit: (json['unit'] ?? 'Count').toString(),
    frequency: (json['frequency'] ?? '{}').toString(),
    status: _int(json['status']),
    dueToday: json['dueToday'] == true,
    doneToday: json['doneToday'] == true,
    currentStreak: _int(json['currentStreak']),
    maxStreak: _int(json['maxStreak']),
    totalCheckIns: _int(json['totalCheckIns']),
    targetDays: _int(json['targetDays']),
    completedCycles: _int(json['completedCycles']),
    startDate: _int(json['startDate']),
  );

  HabitItem copyWith({
    bool? dueToday,
    bool? doneToday,
    int? currentStreak,
    int? maxStreak,
    int? totalCheckIns,
  }) => HabitItem(
    id: id,
    name: name,
    icon: icon,
    color: color,
    sectionId: sectionId,
    goal: goal,
    step: step,
    unit: unit,
    frequency: frequency,
    status: status,
    dueToday: dueToday ?? this.dueToday,
    doneToday: doneToday ?? this.doneToday,
    currentStreak: currentStreak ?? this.currentStreak,
    maxStreak: maxStreak ?? this.maxStreak,
    totalCheckIns: totalCheckIns ?? this.totalCheckIns,
    targetDays: targetDays,
    completedCycles: completedCycles,
    startDate: startDate,
  );
}

class HabitCheckinItem {
  const HabitCheckinItem({
    required this.habitId,
    required this.stamp,
    required this.value,
    required this.goal,
    required this.status,
  });

  final int habitId;
  final int stamp;
  final double value;
  final double goal;
  final int status;

  bool get done => status == 2;

  factory HabitCheckinItem.fromJson(Map<String, dynamic> json) =>
      HabitCheckinItem(
        habitId: _int(json['habitId']),
        stamp: _int(json['checkinStamp']),
        value: _double(json['value'], 0),
        goal: _double(json['goal'], 0),
        status: _int(json['status']),
      );
}

class HabitSnapshot {
  const HabitSnapshot({
    required this.habits,
    required this.checkins,
    required this.sections,
    required this.preferences,
  });

  final List<HabitItem> habits;
  final List<HabitCheckinItem> checkins;
  final List<Map<String, dynamic>> sections;
  final Map<String, dynamic> preferences;
}

class HabitDraft {
  const HabitDraft({
    required this.name,
    required this.color,
    this.icon = '',
    this.sectionId = 0,
    this.goal = 1,
    this.step = 1,
    this.unit = 'Count',
    this.frequency = '{"type":"daily","weekdays":[0,1,2,3,4,5,6]}',
    this.targetDays = 0,
    this.style = 'check',
    this.status = 0,
  });

  final String name;
  final String color;
  final String icon;
  final int sectionId;
  final double goal;
  final double step;
  final String unit;
  final String frequency;
  final int targetDays;
  final String style;
  final int status;

  Map<String, dynamic> toJson() => {
    'name': name,
    'icon': icon,
    'color': color,
    'sectionId': sectionId,
    'goal': goal,
    'step': step,
    'unit': unit,
    'frequency': frequency,
    'targetDays': targetDays,
    'style': style,
    'status': status,
    'recordEnable': false,
  };
}

class HabitApi {
  HabitApi({
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

  Future<HabitSnapshot> fetch() async {
    final body = await _request('GET', '/api/sync/habits');
    final rawCheckins = body['checkins'];
    final checkinRows = <Map<String, dynamic>>[];
    if (rawCheckins is List) {
      checkinRows.addAll(rawCheckins.whereType<Map<String, dynamic>>());
    } else if (rawCheckins is Map<String, dynamic>) {
      for (final value in rawCheckins.values) {
        if (value is List) {
          checkinRows.addAll(value.whereType<Map<String, dynamic>>());
        }
      }
    }
    return HabitSnapshot(
      habits: (body['habits'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HabitItem.fromJson)
          .toList(growable: false),
      checkins: checkinRows
          .map(HabitCheckinItem.fromJson)
          .toList(growable: false),
      sections: (body['sections'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      preferences: body['preferences'] is Map<String, dynamic>
          ? body['preferences'] as Map<String, dynamic>
          : const {},
    );
  }

  Future<HabitItem> create(HabitDraft draft) async {
    final body = await _request(
      'POST',
      '/api/sync/habits',
      payload: draft.toJson(),
    );
    return HabitItem.fromJson(
      (body['habit'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Future<HabitItem> update(int id, HabitDraft draft) async {
    final body = await _request(
      'PATCH',
      '/api/sync/habits/$id',
      payload: draft.toJson(),
    );
    return HabitItem.fromJson(
      (body['habit'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Future<void> delete(int id) async {
    await _request('DELETE', '/api/sync/habits/$id');
  }

  Future<void> checkin(int id, int stamp) async {
    await _request(
      'POST',
      '/api/sync/habits/$id/checkin',
      payload: {'stamp': stamp},
    );
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
        .timeout(const Duration(seconds: 30));
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
      throw HabitApiException(
        message == null || message.isEmpty
            ? '习惯服务返回 HTTP ${response.statusCode}'
            : message,
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  void close() => _client.close();
}

class HabitApiException implements Exception {
  HabitApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
