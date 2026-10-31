import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'habit_write_queue.dart';

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
    this.style = 'check',
    this.reminders = const <String>[],
    this.recordEnable = false,
    this.exDates = const <int>[],
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
  final String style;
  final List<String> reminders;
  final bool recordEnable;
  final List<int> exDates;

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
    style: (json['style'] ?? 'check').toString(),
    reminders: _stringList(json['reminders']),
    recordEnable: json['recordEnable'] == true,
    exDates: _intList(json['exDates']),
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
    style: style,
    reminders: reminders,
    recordEnable: recordEnable,
    exDates: exDates,
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
    this.reminders = const <String>[],
    this.recordEnable = false,
    this.startDate = 0,
    this.exDates = const <int>[],
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
  final List<String> reminders;
  final bool recordEnable;
  final int startDate;
  final List<int> exDates;

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
    'reminders': jsonEncode(reminders),
    'recordEnable': recordEnable,
    'startDate': startDate,
    'exDates': jsonEncode(exDates),
  };

  factory HabitDraft.fromJson(Map<String, dynamic> json) => HabitDraft(
    name: (json['name'] ?? '').toString(),
    color: (json['color'] ?? '').toString(),
    icon: (json['icon'] ?? '').toString(),
    sectionId: _int(json['sectionId']),
    goal: _double(json['goal'], 1),
    step: _double(json['step'], 1),
    unit: (json['unit'] ?? 'Count').toString(),
    frequency:
        (json['frequency'] ?? '{"type":"daily","weekdays":[0,1,2,3,4,5,6]}')
            .toString(),
    targetDays: _int(json['targetDays']),
    style: (json['style'] ?? 'check').toString(),
    status: _int(json['status']),
    reminders: _stringList(json['reminders']),
    recordEnable: json['recordEnable'] == true,
    startDate: _int(json['startDate']),
    exDates: _intList(json['exDates']),
  );
}

class HabitApi {
  HabitApi({
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
  final HabitWriteQueue? writeQueue;

  Future<HabitWriteQueue> get _queue async =>
      writeQueue ?? await HabitWriteQueue.shared();

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

  /// Server snapshot for the background sync pass. Pages read the local
  /// mirror in `HabitStore` instead of calling this.
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

  Future<void>? _flushing;

  /// Replays all queued local writes against the server. Serialized so a
  /// background retry and a user refresh cannot push the same op twice.
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
    final remap = <int, int>{};
    for (final op in ops) {
      final habitId = remap[op.habitId] ?? op.habitId;
      try {
        switch (op.action) {
          case 'create':
            final body = await _request(
              'POST',
              '/api/sync/habits',
              payload: op.payload,
            );
            final created = body['habit'];
            final realId = created is Map<String, dynamic>
                ? _int(created['id'])
                : 0;
            if (realId > 0 && op.habitId != realId) {
              remap[op.habitId] = realId;
              await queue.replaceHabitId(op.habitId, realId);
            }
          case 'update':
            await _request(
              'PATCH',
              '/api/sync/habits/$habitId',
              payload: op.payload,
            );
          case 'delete':
            await _request('DELETE', '/api/sync/habits/$habitId');
          case 'checkin':
            await _request(
              'POST',
              '/api/sync/habits/$habitId/checkin',
              payload: {'stamp': op.stamp},
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
  }

  static bool _isUnreachable(Object error) =>
      error is http.ClientException ||
      error is TimeoutException ||
      error is SocketException;

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

List<String> _stringList(Object? value) {
  Object? decoded = value;
  if (value is String) {
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return const <String>[];
    }
  }
  if (decoded is List) {
    return decoded
        .map((item) => item?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

List<int> _intList(Object? value) {
  Object? decoded = value;
  if (value is String) {
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return const <int>[];
    }
  }
  if (decoded is List) {
    return decoded.map(_int).where((item) => item > 0).toList(growable: false);
  }
  return const <int>[];
}
