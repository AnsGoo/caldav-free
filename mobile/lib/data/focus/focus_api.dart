import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class FocusPreferences {
  const FocusPreferences({
    this.pomodoroMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakInterval = 4,
    this.dailyGoal = 4,
  });

  final int pomodoroMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int longBreakInterval;
  final int dailyGoal;

  factory FocusPreferences.fromJson(Map<String, dynamic> json) =>
      FocusPreferences(
        pomodoroMinutes: _int(json['pomodoroMinutes'], 25),
        shortBreakMinutes: _int(json['shortBreakMinutes'], 5),
        longBreakMinutes: _int(json['longBreakMinutes'], 15),
        longBreakInterval: _int(json['longBreakInterval'], 4),
        dailyGoal: _int(json['dailyGoal'], 4),
      );
}

class FocusStats {
  const FocusStats({
    this.todayPomodoroCount = 0,
    this.todayFocusMinutes = 0,
    this.totalPomodoroCount = 0,
    this.totalFocusMinutes = 0,
    this.todayFocusSeconds = 0,
    this.goal = 4,
  });

  final int todayPomodoroCount;
  final int todayFocusMinutes;
  final int totalPomodoroCount;
  final int totalFocusMinutes;
  final int todayFocusSeconds;
  final int goal;

  factory FocusStats.fromJson(Map<String, dynamic> json) => FocusStats(
    todayPomodoroCount: _int(json['todayPomodoroCount'], 0),
    todayFocusMinutes: _int(json['todayFocusMinutes'], 0),
    totalPomodoroCount: _int(json['totalPomodoroCount'], 0),
    totalFocusMinutes: _int(json['totalFocusMinutes'], 0),
    todayFocusSeconds: _int(json['todayFocusSeconds'], 0),
    goal: _int(json['dailyGoal'], 4),
  );
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.title,
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });

  final int id;
  final String title;
  final String mode;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
    id: _int(json['id'], 0),
    title: (json['title'] ?? '').toString(),
    mode: (json['mode'] ?? '').toString(),
    startedAt: _date(json['startedAt']),
    endedAt: _date(json['endedAt']),
    durationSeconds: _int(json['durationSeconds'], 0),
  );
}

class FocusDash {
  const FocusDash({
    required this.preferences,
    required this.stats,
    required this.sessions,
  });

  final FocusPreferences preferences;
  final FocusStats stats;
  final List<FocusSession> sessions;
}

class FocusApi {
  FocusApi({
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

  Future<FocusDash> fetch() async {
    final body = await _request('GET', '/api/sync/focus');
    final preferences = body['preferences'];
    final stats = body['stats'];
    return FocusDash(
      preferences: preferences is Map<String, dynamic>
          ? FocusPreferences.fromJson(preferences)
          : const FocusPreferences(),
      stats: stats is Map<String, dynamic>
          ? FocusStats.fromJson(stats)
          : const FocusStats(),
      sessions: (body['sessions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FocusSession.fromJson)
          .toList(growable: false),
    );
  }

  Future<void> saveSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    String mode = 'pomodoro',
    String title = '专注',
    int pomodoroCount = 1,
    String note = '',
  }) async {
    await _request(
      'POST',
      '/api/sync/focus/sessions',
      payload: {
        'mode': mode,
        'title': title,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'durationSeconds': durationSeconds,
        'pomodoroCount': pomodoroCount,
        'note': note,
      },
    );
  }

  Future<void> deleteSession(int id) async {
    await _request('DELETE', '/api/sync/focus/sessions/$id');
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
      throw FocusApiException(
        message == null || message.isEmpty
            ? '专注服务返回 HTTP ${response.statusCode}'
            : message,
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  void close() => _client.close();
}

class FocusApiException implements Exception {
  FocusApiException(this.message, {this.statusCode});

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

DateTime? _date(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}
