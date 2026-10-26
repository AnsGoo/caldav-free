import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/ids.dart';
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

  factory HabitDraft.fromJson(Map<String, dynamic> json) => HabitDraft(
    name: (json['name'] ?? '').toString(),
    color: (json['color'] ?? '').toString(),
    icon: (json['icon'] ?? '').toString(),
    sectionId: _int(json['sectionId']),
    goal: _double(json['goal'], 1),
    step: _double(json['step'], 1),
    unit: (json['unit'] ?? 'Count').toString(),
    frequency: (json['frequency'] ?? '{"type":"daily","weekdays":[0,1,2,3,4,5,6]}').toString(),
    targetDays: _int(json['targetDays']),
    style: (json['style'] ?? 'check').toString(),
    status: _int(json['status']),
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

  /// Server snapshot plus local habits/check-ins still queued, so an offline
  /// create keeps showing after a refresh instead of blinking out.
  Future<HabitSnapshot> load() async {
    final snapshot = await fetch();
    return _overlayPending(snapshot);
  }

  Future<HabitSnapshot> _overlayPending(HabitSnapshot snapshot) async {
    final queue = await _queue;
    if (queue.isEmpty) return snapshot;
    final ops = await queue.items();
    final byId = <int, HabitItem>{for (final h in snapshot.habits) h.id: h};
    final checkinPatch = <String, double>{};
    final removed = <int>{};
    for (final op in ops) {
      switch (op.action) {
        case 'create':
          final payload = op.payload;
          if (payload != null) {
            byId[op.habitId] = _optimisticItem(op.habitId, HabitDraft.fromJson(payload));
          }
        case 'update':
          final payload = op.payload;
          final existing = byId[op.habitId];
          if (payload != null && existing != null) {
            byId[op.habitId] = _optimisticItem(
              op.habitId,
              HabitDraft.fromJson(payload),
            ).copyWith(
              currentStreak: existing.currentStreak,
              maxStreak: existing.maxStreak,
              totalCheckIns: existing.totalCheckIns,
              dueToday: existing.dueToday,
              doneToday: existing.doneToday,
            );
          }
        case 'delete':
          byId.remove(op.habitId);
          removed.add(op.habitId);
        case 'checkin':
          final stamp = op.stamp;
          if (stamp != null && !removed.contains(op.habitId)) {
            checkinPatch['${op.habitId}:$stamp'] = 1;
          }
        default:
          continue;
      }
    }
    final checkins = [
      for (final c in snapshot.checkins)
        if (!checkinPatch.containsKey('${c.habitId}:${c.stamp}')) c,
    ];
    for (final key in checkinPatch.keys) {
      final parts = key.split(':');
      checkins.add(
        HabitCheckinItem(
          habitId: int.parse(parts[0]),
          stamp: int.parse(parts[1]),
          value: 1,
          goal: byId[int.parse(parts[0])]?.goal ?? 1,
          status: 2,
        ),
      );
    }
    final habits = byId.values.toList()
      ..sort((a, b) {
        final order = a.sectionId.compareTo(b.sectionId);
        return order != 0 ? order : a.name.compareTo(b.name);
      });
    return HabitSnapshot(
      habits: habits,
      checkins: checkins,
      sections: snapshot.sections,
      preferences: snapshot.preferences,
    );
  }

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
    final queue = await _queue;
    final tempId = _newTempId();
    await queue.add(
      HabitPendingOp(
        opId: newSyncId(),
        action: 'create',
        habitId: tempId,
        payload: draft.toJson(),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return _optimisticItem(tempId, draft);
  }

  Future<HabitItem> update(int id, HabitDraft draft) async {
    final queue = await _queue;
    if (id < 0) {
      final rewritten = await queue.replaceCreatePayload(id, draft.toJson());
      if (!rewritten) {
        await queue.add(
          HabitPendingOp(
            opId: newSyncId(),
            action: 'create',
            habitId: id,
            payload: draft.toJson(),
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    } else {
      await queue.add(
        HabitPendingOp(
          opId: newSyncId(),
          action: 'update',
          habitId: id,
          payload: draft.toJson(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    return _optimisticItem(id, draft);
  }

  Future<void> delete(int id) async {
    final queue = await _queue;
    if (id < 0) {
      await queue.cancelTemp(id);
      return;
    }
    await queue.add(
      HabitPendingOp(
        opId: newSyncId(),
        action: 'delete',
        habitId: id,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> checkin(int id, int stamp) async {
    final queue = await _queue;
    await queue.add(
      HabitPendingOp(
        opId: newSyncId(),
        action: 'checkin',
        habitId: id,
        stamp: stamp,
        createdAt: DateTime.now().toUtc(),
      ),
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

  static int _newTempId() =>
      -(DateTime.now().microsecondsSinceEpoch * 10 + Random.secure().nextInt(10));

  static HabitItem _optimisticItem(int id, HabitDraft draft) => HabitItem(
    id: id,
    name: draft.name,
    icon: draft.icon,
    color: draft.color,
    sectionId: draft.sectionId,
    goal: draft.goal,
    step: draft.step,
    unit: draft.unit,
    frequency: draft.frequency,
    status: draft.status,
    dueToday: true,
    doneToday: false,
    currentStreak: 0,
    maxStreak: 0,
    totalCheckIns: 0,
    targetDays: draft.targetDays,
    completedCycles: 0,
    startDate: 0,
  );

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
