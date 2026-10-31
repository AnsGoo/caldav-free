import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One page of the server change feed.
class PullPage {
  PullPage({
    required this.cursor,
    required this.hasMore,
    required this.tasks,
    required this.lists,
    required this.sections,
    required this.folders,
    required this.filters,
    required this.tombstones,
  });

  final String cursor;
  final bool hasMore;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> lists;
  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> folders;
  final List<Map<String, dynamic>> filters;
  final List<Tombstone> tombstones;
}

class Tombstone {
  Tombstone({required this.entity, required this.id, this.deletedAt});

  final String entity;
  final String id;
  final String? deletedAt;
}

/// A pending local operation sent to `/api/sync/push`.
class OutboxOp {
  OutboxOp({
    required this.opId,
    required this.entity,
    required this.entityId,
    required this.action,
    required this.patch,
    this.baseEtag,
    this.attempts = 0,
  });

  final String opId;
  final String entity;
  final String entityId;
  final String action;
  final Map<String, dynamic> patch;
  final String? baseEtag;
  final int attempts;

  Map<String, dynamic> toJson() => {
    'opId': opId,
    'entity': entity,
    'entityId': entityId,
    'action': action,
    if (baseEtag != null && baseEtag!.isNotEmpty) 'baseEtag': baseEtag,
    'patch': patch,
  };
}

/// One per-operation result from `/api/sync/push`.
class PushResult {
  PushResult({
    required this.opId,
    required this.entity,
    required this.entityId,
    required this.status,
    this.etag,
    this.version = 0,
    this.entityJson,
    this.errorCode,
    this.errorMessage,
  });

  final String opId;
  final String entity;
  final String entityId;
  final String status;
  final String? etag;
  final int version;
  final Map<String, dynamic>? entityJson;
  final String? errorCode;
  final String? errorMessage;

  bool get ok => status == 'ok';
  bool get conflict => status == 'conflict';
  bool get gone => status == 'gone';

  factory PushResult.fromJson(Map<String, dynamic> json) => PushResult(
    opId: (json['opId'] ?? '').toString(),
    entity: (json['entityType'] ?? '').toString(),
    entityId: (json['entityId'] ?? '').toString(),
    status: (json['status'] ?? 'error').toString(),
    etag: json['etag']?.toString(),
    version: (json['version'] as num?)?.toInt() ?? 0,
    entityJson: json['entity'] is Map<String, dynamic>
        ? json['entity'] as Map<String, dynamic>
        : null,
    errorCode: (json['error'] as Map<String, dynamic>?)?['code']?.toString(),
    errorMessage: (json['error'] as Map<String, dynamic>?)?['message']
        ?.toString(),
  );
}

class SyncApiException implements Exception {
  SyncApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get unauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Network boundary. Tests use a fake implementation of this interface.
abstract class SyncApi {
  Future<PullPage> pull({
    required String since,
    int limit = 500,
    bool refresh = false,
  });

  Future<List<PushResult>> push({
    required List<OutboxOp> ops,
    required String deviceId,
  });

  void close();
}

class HttpSyncApi implements SyncApi {
  HttpSyncApi({
    required String baseUrl,
    required this.username,
    required this.password,
    http.Client? client,
  }) : baseUrl = normalizeBaseUrl(baseUrl),
       _client = client ?? http.Client();

  final String baseUrl;
  final String username;
  final String password;
  final http.Client _client;

  static String normalizeBaseUrl(String raw) {
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

  @override
  Future<PullPage> pull({
    required String since,
    int limit = 500,
    bool refresh = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/sync/pull').replace(
      queryParameters: {
        'since': since,
        'limit': '$limit',
        if (refresh) 'refresh': '1',
      },
    );
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw SyncApiException(
        _errorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    }
    final tasks = _mapList(body['tasks']);
    final lists = _mapList(body['lists']);
    final sections = _mapList(body['sections']);
    final folders = _mapList(body['folders']);
    final filters = _mapList(body['filters']);
    final tombstones = (body['tombstones'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => Tombstone(
            entity: (item['entity'] ?? '').toString(),
            id: (item['id'] ?? '').toString(),
            deletedAt: item['deletedAt']?.toString(),
          ),
        )
        .toList(growable: false);
    return PullPage(
      cursor: (body['cursor'] ?? since).toString(),
      hasMore: body['hasMore'] == true,
      tasks: tasks,
      lists: lists,
      sections: sections,
      folders: folders,
      filters: filters,
      tombstones: tombstones,
    );
  }

  @override
  Future<List<PushResult>> push({
    required List<OutboxOp> ops,
    required String deviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/sync/push');
    final response = await _client
        .post(
          uri,
          headers: {
            ..._headers,
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'deviceId': deviceId,
            'ops': ops.map((op) => op.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 45));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw SyncApiException(
        _errorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    }
    return (body['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PushResult.fromJson)
        .toList(growable: false);
  }

  @override
  void close() => _client.close();

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  String _errorMessage(Map<String, dynamic> body, int status) {
    final message = body['error']?.toString();
    if (message != null && message.isNotEmpty) return message;
    if (status == 401 || status == 403) return '用户名或密码错误';
    return '同步服务返回 HTTP $status';
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }
}
