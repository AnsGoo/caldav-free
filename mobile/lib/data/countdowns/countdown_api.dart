import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/ids.dart';
import 'countdown_write_queue.dart';

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
    this.writeQueue,
  }) : baseUrl = _normalize(baseUrl),
       _client = client ?? http.Client();

  final String baseUrl;
  final String username;
  final String password;
  final http.Client _client;
  final CountdownWriteQueue? writeQueue;

  Future<CountdownWriteQueue> get _queue async =>
      writeQueue ?? await CountdownWriteQueue.shared();

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

  /// Server countdowns plus any local writes still waiting to sync, so
  /// pending edits show up immediately even before the round-trip lands.
  /// Throws when the server is unreachable; callers keep their cached list
  /// and can overlay [overlayPending] on top of it.
  Future<List<CountdownItem>> load() async {
    final remote = await fetch();
    return _applyPending(remote);
  }

  Future<List<CountdownItem>> fetch() async {
    final body = await _request('GET', '/api/sync/countdowns');
    return (body['countdowns'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CountdownItem.fromJson)
        .toList(growable: false);
  }

  /// Re-applies queued local writes over a previously loaded list, used when
  /// a refresh fails and the page keeps its stale snapshot.
  Future<List<CountdownItem>> overlayPending(List<CountdownItem> items) async =>
      _applyPending(items);

  Future<List<CountdownItem>> _applyPending(List<CountdownItem> remote) async {
    final queue = await _queue;
    if (queue.isEmpty) return remote;
    final ops = await queue.items();
    final byId = <int, CountdownItem>{
      for (final item in remote)
        if (!item.id.isNegative) item.id: item,
    };
    // Queue ops are replayed in FIFO order onto the map so overlaying an
    // already-overlaid list (e.g. repeated background retries) is idempotent
    // and never duplicates the pending item.
    for (final op in ops) {
      switch (op.action) {
        case 'delete':
          byId.remove(op.countdownId);
        case 'update':
          final payload = op.payload;
          final existing = byId[op.countdownId];
          if (payload == null) continue;
          if (existing != null) {
            byId[op.countdownId] = _patched(existing, payload);
          } else if (!op.countdownId.isNegative) {
            byId[op.countdownId] = buildOptimisticItem(
              op.countdownId,
              payload,
            );
          }
        case 'create':
          final payload = op.payload;
          if (payload == null) continue;
          byId[op.countdownId] = buildOptimisticItem(op.countdownId, payload);
      }
    }
    final merged = byId.values.toList();
    merged.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return a.occurrenceDate.compareTo(b.occurrenceDate);
    });
    return merged;
  }

  static CountdownItem _patched(CountdownItem item, Map<String, dynamic> p) {
    final date = _int(p['date'], item.date);
    final repeat = (p['repeat'] ?? item.repeat).toString();
    final occurrence = repeat == 'yearly'
        ? _nextYearly(date)
        : date;
    final days = _daysUntil(occurrence);
    return CountdownItem(
      id: item.id,
      name: (p['name'] ?? item.name).toString(),
      type: (p['type'] ?? item.type).toString(),
      date: date,
      repeat: repeat,
      pinned: p['pinned'] is bool ? p['pinned'] as bool : item.pinned,
      status: item.status,
      color: (p['color'] ?? item.color).toString(),
      icon: item.icon,
      remark: (p['remark'] ?? item.remark).toString(),
      days: days.abs(),
      hours: item.hours,
      minutes: item.minutes,
      seconds: item.seconds,
      state: days == 0 ? 'today' : days > 0 ? 'future' : 'past',
      occurrenceDate: occurrence,
      age: item.age,
    );
  }

  /// Local mirror of the server's derived fields, used to render and insert
  /// a countdown before the create round-trip completes.
  static CountdownItem buildOptimisticItem(
    int id,
    Map<String, dynamic> payload,
  ) {
    final date = _int(payload['date'], 0);
    final repeat = (payload['repeat'] ?? 'none').toString();
    final occurrence = repeat == 'yearly' ? _nextYearly(date) : date;
    final days = _daysUntil(occurrence);
    return CountdownItem(
      id: id,
      name: (payload['name'] ?? '').toString(),
      type: (payload['type'] ?? 'countdown').toString(),
      date: date,
      repeat: repeat,
      pinned: payload['pinned'] == true,
      status: 0,
      color: (payload['color'] ?? '#92D0FF').toString(),
      icon: (payload['icon'] ?? '⏳').toString(),
      remark: (payload['remark'] ?? '').toString(),
      days: days.abs(),
      hours: 0,
      minutes: 0,
      seconds: 0,
      state: days == 0 ? 'today' : days > 0 ? 'future' : 'past',
      occurrenceDate: occurrence,
      age: 0,
    );
  }

  static int _stamp(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day;

  static DateTime _dayFromStamp(int stamp) {
    final text = stamp.toString().padLeft(8, '0');
    final year = int.tryParse(text.substring(0, 4)) ?? 2000;
    final month = int.tryParse(text.substring(4, 6)) ?? 1;
    final day = int.tryParse(text.substring(6, 8)) ?? 1;
    return DateTime(year, month, day);
  }

  static int _nextYearly(int dateStamp) {
    final now = DateTime.now();
    final today = _stamp(DateTime(now.year, now.month, now.day));
    final base = _dayFromStamp(dateStamp);
    final thisYear = _stamp(DateTime(now.year, base.month, base.day));
    if (thisYear >= today) return thisYear;
    return _stamp(DateTime(now.year + 1, base.month, base.day));
  }

  static int _daysUntil(int occurrenceStamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _dayFromStamp(occurrenceStamp).difference(today).inDays;
  }

  Future<CountdownItem> create(CountdownDraft draft) async {
    final queue = await _queue;
    final tempId = _newTempId();
    await queue.add(
      CountdownPendingOp(
        opId: newSyncId(),
        action: 'create',
        countdownId: tempId,
        payload: draft.toJson(),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return buildOptimisticItem(tempId, draft.toJson());
  }

  Future<CountdownItem> update(int id, CountdownDraft draft) async {
    final queue = await _queue;
    if (id < 0) {
      final rewritten = await queue.replaceCreatePayload(id, draft.toJson());
      if (!rewritten) {
        await queue.add(
          CountdownPendingOp(
            opId: newSyncId(),
            action: 'create',
            countdownId: id,
            payload: draft.toJson(),
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    } else {
      await queue.add(
        CountdownPendingOp(
          opId: newSyncId(),
          action: 'update',
          countdownId: id,
          payload: draft.toJson(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    return buildOptimisticItem(id, draft.toJson());
  }

  Future<void> delete(int id) async {
    final queue = await _queue;
    if (id < 0) {
      await queue.cancelTemp(id);
      return;
    }
    await queue.add(
      CountdownPendingOp(
        opId: newSyncId(),
        action: 'delete',
        countdownId: id,
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
    final timedOutCreates = <CountdownPendingOp>[];
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
          case 'update':
            await _request(
              'PATCH',
              '/api/sync/countdowns/${op.countdownId}',
              payload: op.payload,
            );
          case 'delete':
            await _request('DELETE', '/api/sync/countdowns/${op.countdownId}');
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

  Future<void> _createRemote(CountdownPendingOp op) async {
    final body = await _request(
      'POST',
      '/api/sync/countdowns',
      payload: op.payload,
    );
    final created = body['countdown'];
    final realId = created is Map<String, dynamic> ? _int(created['id'], 0) : 0;
    if (realId > 0 && op.countdownId != realId) {
      await (await _queue).replaceCountdownId(op.countdownId, realId);
    }
  }

  /// Creates whose POST timed out are dropped when the server already holds
  /// an equivalent record; otherwise they stay queued for the next retry.
  Future<void> _reconcileTimedOutCreates(
    CountdownWriteQueue queue,
    List<CountdownPendingOp> timedOut,
  ) async {
    List<CountdownItem> serverItems;
    try {
      serverItems = await fetch();
    } on Object {
      return;
    }
    for (final op in timedOut) {
      final payload = op.payload;
      if (payload == null) {
        await queue.remove(op.opId);
        continue;
      }
      final stamp = _int(payload['date'], 0);
      final name = (payload['name'] ?? '').toString();
      final type = (payload['type'] ?? 'countdown').toString();
      final synced = serverItems.any(
        (item) =>
            !item.id.isNegative &&
            item.date == stamp &&
            item.name == name &&
            item.type == type,
      );
      if (synced) await queue.remove(op.opId);
    }
  }

  static bool _isUnreachable(Object error) =>
      error is http.ClientException ||
      error is TimeoutException ||
      error is SocketException;

  static bool _timedOut(Object error) => error is TimeoutException;

  static int _newTempId() =>
      -(DateTime.now().microsecondsSinceEpoch * 10 +
        Random.secure().nextInt(10));

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
