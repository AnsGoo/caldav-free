import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class CalendarSource {
  const CalendarSource({
    required this.id,
    required this.name,
    required this.color,
  });

  final int id;
  final String name;
  final String color;

  factory CalendarSource.fromJson(Map<String, dynamic> json) => CalendarSource(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: (json['name'] ?? '').toString(),
    color: (json['color'] ?? '').toString(),
  );
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.uid,
    required this.href,
    required this.calendarId,
    required this.calendarName,
    required this.color,
    required this.summary,
    required this.location,
    required this.description,
    required this.start,
    required this.end,
    required this.allDay,
    required this.recurring,
    required this.reminders,
    this.rrule = '',
    this.attendees = const [],
    this.recurrenceId = '',
    this.readOnly = false,
  });

  final String id;
  final String uid;
  final String href;
  final int calendarId;
  final String calendarName;
  final String color;
  final String summary;
  final String location;
  final String description;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final bool recurring;
  final List<int> reminders;
  final String rrule;
  final List<String> attendees;
  final String recurrenceId;
  final bool readOnly;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: (json['id'] ?? '').toString(),
    uid: (json['uid'] ?? '').toString(),
    href: (json['href'] ?? '').toString(),
    calendarId: (json['calendarId'] as num?)?.toInt() ?? 0,
    calendarName: (json['calendarName'] ?? '').toString(),
    color: (json['color'] ?? '').toString(),
    summary: (json['summary'] ?? '').toString(),
    location: (json['location'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    start: _date(json['start']) ?? DateTime.now(),
    end: _date(json['end']) ?? DateTime.now(),
    allDay: json['allDay'] == true,
    recurring: json['recurring'] == true,
    reminders: (json['reminders'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toInt())
        .toList(growable: false),
    rrule: (json['rrule'] ?? '').toString(),
    attendees: (json['attendees'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList(growable: false),
    recurrenceId: (json['recurrenceId'] ?? '').toString(),
    readOnly: json['readonly'] == true,
  );
}

/// A task occurrence returned by the calendar endpoint. `syncId` maps back to
/// the local task store for non-virtual occurrences.
class CalendarTask {
  const CalendarTask({
    required this.id,
    required this.syncId,
    required this.title,
    required this.listName,
    required this.listColor,
    this.start,
    this.due,
    this.allDay = false,
    this.completed = false,
    this.priority = 0,
    this.occurrence = '',
    this.virtual = false,
    this.postponed = false,
    this.recurring = false,
  });

  final int id;
  final String syncId;
  final String title;
  final String listName;
  final String listColor;
  final DateTime? start;
  final DateTime? due;
  final bool allDay;
  final bool completed;
  final int priority;
  final String occurrence;
  final bool virtual;
  final bool postponed;
  final bool recurring;

  DateTime? get when => due ?? start;

  CalendarTask copyWith({bool? completed}) => CalendarTask(
    id: id,
    syncId: syncId,
    title: title,
    listName: listName,
    listColor: listColor,
    start: start,
    due: due,
    allDay: allDay,
    completed: completed ?? this.completed,
    priority: priority,
    occurrence: occurrence,
    virtual: virtual,
    postponed: postponed,
    recurring: recurring,
  );

  factory CalendarTask.fromJson(Map<String, dynamic> json) => CalendarTask(
    id: (json['id'] as num?)?.toInt() ?? 0,
    syncId: (json['syncId'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    listName: (json['listName'] ?? '').toString(),
    listColor: (json['listColor'] ?? '').toString(),
    start: _date(json['start']),
    due: _date(json['due']),
    allDay: json['allDay'] == true,
    completed: json['completed'] == true,
    priority: (json['priority'] as num?)?.toInt() ?? 0,
    occurrence: (json['occurrence'] ?? '').toString(),
    virtual: json['virtual'] == true,
    postponed: json['postponed'] == true,
    recurring: (json['recurrence'] ?? '').toString().isNotEmpty,
  );
}

class CalendarSnapshot {
  const CalendarSnapshot({
    required this.sources,
    required this.events,
    required this.tasks,
    required this.from,
    required this.to,
  });

  final List<CalendarSource> sources;
  final List<CalendarEvent> events;
  final List<CalendarTask> tasks;
  final DateTime from;
  final DateTime to;
}

class CalendarSubscription {
  const CalendarSubscription({
    required this.id,
    required this.name,
    required this.url,
    required this.color,
    this.lastError = '',
    this.lastSynced,
  });

  final int id;
  final String name;
  final String url;
  final String color;
  final String lastError;
  final DateTime? lastSynced;

  factory CalendarSubscription.fromJson(Map<String, dynamic> json) =>
      CalendarSubscription(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        color: (json['color'] ?? '').toString(),
        lastError: (json['lastError'] ?? '').toString(),
        lastSynced: _date(json['lastSynced']),
      );
}

class CalendarApi {
  CalendarApi({
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

  Future<CalendarSnapshot> fetch({
    required DateTime from,
    required DateTime to,
  }) async {
    final uri = Uri.parse('$baseUrl/api/sync/calendar').replace(
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } on FormatException {
        body = const {};
      }
    }
    if (response.statusCode != 200) {
      final message = body['error']?.toString();
      throw CalendarApiException(
        message == null || message.isEmpty
            ? '日历服务返回 HTTP ${response.statusCode}'
            : message,
        statusCode: response.statusCode,
      );
    }
    return CalendarSnapshot(
      sources: (body['calendars'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CalendarSource.fromJson)
          .toList(growable: false),
      events: (body['events'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CalendarEvent.fromJson)
          .toList(growable: false),
      tasks: (body['tasks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CalendarTask.fromJson)
          .toList(growable: false),
      from: _date(body['from']) ?? from.toUtc(),
      to: _date(body['to']) ?? to.toUtc(),
    );
  }

  Future<void> createEvent({
    required int calendarId,
    required String summary,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    String location = '',
    String description = '',
    List<int> reminders = const [],
  }) async {
    await _writeEvent('POST', '/api/sync/events', {
      'calendarId': calendarId,
      'summary': summary,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      'allDay': allDay,
      'location': location,
      'description': description,
      'reminders': reminders,
    });
  }

  Future<void> updateEvent({
    required int calendarId,
    required String href,
    required String summary,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    String location = '',
    String description = '',
    List<int> reminders = const [],
    String rrule = '',
    List<String> attendees = const [],
  }) async {
    await _writeEvent('PUT', '/api/sync/events', {
      'calendarId': calendarId,
      'href': href,
      'summary': summary,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      'allDay': allDay,
      'location': location,
      'description': description,
      'reminders': reminders,
      'rrule': rrule,
      'attendees': attendees,
    });
  }

  Future<void> deleteEvent({
    required int calendarId,
    required String href,
  }) async {
    final uri = Uri.parse('$baseUrl/api/sync/events')
        .replace(queryParameters: {'calendarId': '$calendarId', 'href': href});
    final response = await _client
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CalendarApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> _writeEvent(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.Request(method, uri)
      ..headers.addAll({
        ..._headers,
        'Content-Type': 'application/json; charset=utf-8',
      })
      ..body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CalendarApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<CalendarSubscription>> subscriptions() async {
    final uri = Uri.parse('$baseUrl/api/sync/subscriptions');
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw CalendarApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    final body = _decode(response.body);
    return (body['subscriptions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CalendarSubscription.fromJson)
        .toList(growable: false);
  }

  Future<void> createSubscription({
    required String name,
    required String url,
    String color = '#f0a020',
  }) async {
    await _writeEvent('POST', '/api/sync/subscriptions', {
      'name': name,
      'url': url,
      'color': color,
    });
  }

  Future<void> deleteSubscription(int id) async {
    final uri = Uri.parse('$baseUrl/api/sync/subscriptions/$id');
    final response = await _client
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CalendarApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  Map<String, dynamic> _decode(String text) {
    if (text.isEmpty) return const {};
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  String _errorMessage(http.Response response) {
    if (response.body.isEmpty) {
      return '日历服务返回 HTTP ${response.statusCode}';
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['error']?.toString();
        if (message != null && message.isNotEmpty) return message;
      }
    } on FormatException {
      // Fall through to the generic message.
    }
    return '日历服务返回 HTTP ${response.statusCode}';
  }

  void close() => _client.close();
}

class CalendarApiException implements Exception {
  CalendarApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}
