import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'focus_write_queue.dart';

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

  Map<String, dynamic> toJson() => {
    'pomodoroMinutes': pomodoroMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'longBreakInterval': longBreakInterval,
    'dailyGoal': dailyGoal,
  };
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

  Map<String, dynamic> toJson() => {
    'todayPomodoroCount': todayPomodoroCount,
    'todayFocusMinutes': todayFocusMinutes,
    'totalPomodoroCount': totalPomodoroCount,
    'totalFocusMinutes': totalFocusMinutes,
    'todayFocusSeconds': todayFocusSeconds,
    'dailyGoal': goal,
  };
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.title,
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.pomodoroCount = 0,
  });

  final int id;
  final String title;
  final String mode;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int pomodoroCount;

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
    id: _int(json['id'], 0),
    title: (json['title'] ?? '').toString(),
    mode: (json['mode'] ?? '').toString(),
    startedAt: _date(json['startedAt']),
    endedAt: _date(json['endedAt']),
    durationSeconds: _int(json['durationSeconds'], 0),
    pomodoroCount: _int(json['pomodoroCount'], 0),
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
    this.writeQueue,
  }) : baseUrl = _normalize(baseUrl),
       _client = client ?? http.Client();

  final String baseUrl;
  final String username;
  final String password;
  final http.Client _client;
  final FocusWriteQueue? writeQueue;

  Future<FocusWriteQueue> get _queue async =>
      writeQueue ?? await FocusWriteQueue.shared();

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

  /// Server snapshot for the background sync pass. The focus page reads the
  /// local mirror in `FocusStore` instead of calling this.
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

  Future<void>? _flushing;

  /// Replays all queued local writes against the server. Serialized so a
  /// background retry and a user refresh cannot push the same record twice.
  Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    late final Future<void> tracked;
    tracked = _flushOnce().whenComplete(() {
      if (identical(_flushing, tracked)) _flushing = null;
    });
    _flushing = tracked;
    return tracked;
  }

  Future<void> _flushOnce() async {
    final queue = await _queue;
    if (queue.isEmpty) return;
    final ops = await queue.items();
    final timedOutCreates = <FocusPendingOp>[];
    for (final op in ops) {
      try {
        switch (op.action) {
          case 'create':
            try {
              await _createRemote(op);
            } on Object catch (inner) {
              if (!_timedOut(inner)) rethrow;
              // The server may have committed without us ever seeing the
              // response; reconciling against the list avoids replaying the
              // create into a duplicate record.
              timedOutCreates.add(op);
              continue;
            }
          case 'delete':
            await _request(
              'DELETE',
              '/api/sync/focus/sessions/${op.sessionId}',
            );
          default:
            await queue.remove(op.opId);
            continue;
        }
      } on Object catch (error) {
        if (_isUnreachable(error)) return;
        await queue.remove(op.opId);
        continue;
      }
      await queue.remove(op.opId);
    }
    if (timedOutCreates.isNotEmpty) {
      await _reconcileTimedOutCreates(queue, timedOutCreates);
    }
  }

  Future<void> _createRemote(FocusPendingOp op) async {
    final body = await _request(
      'POST',
      '/api/sync/focus/sessions',
      payload: op.payload,
    );
    final created = body['session'];
    final realId = created is Map<String, dynamic> ? _int(created['id'], 0) : 0;
    if (realId > 0 && op.sessionId != realId) {
      await (await _queue).replaceSessionId(op.sessionId, realId);
    }
  }

  /// Creates whose POST timed out are dropped when the server already holds an
  /// equivalent record; otherwise they stay queued for the next retry.
  Future<void> _reconcileTimedOutCreates(
    FocusWriteQueue queue,
    List<FocusPendingOp> timedOut,
  ) async {
    FocusDash dash;
    try {
      dash = await fetch();
    } on Object {
      return;
    }
    for (final op in timedOut) {
      final payload = op.payload;
      if (payload == null) {
        await queue.remove(op.opId);
        continue;
      }
      final started = (payload['startedAt'] ?? '').toString();
      final seconds = _int(payload['durationSeconds'], 0);
      final synced = dash.sessions.any(
        (session) =>
            !session.id.isNegative &&
            session.durationSeconds == seconds &&
            session.startedAt?.toUtc().toIso8601String() == started,
      );
      if (synced) await queue.remove(op.opId);
    }
  }

  static bool _isUnreachable(Object error) =>
      error is http.ClientException ||
      error is TimeoutException ||
      error is SocketException;

  static bool _timedOut(Object error) => error is TimeoutException;

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
