/// Field-level merge for tasks. Pure functions only: no IO, no Flutter.
library;

/// Merge a locally edited task into the latest server state.
///
/// [localFields] is the set of wire field names touched by the pending outbox
/// patch. Local values win for exactly those fields; every other field comes
/// from the server. This is the client half of the protocol's conflict
/// contract: the server never merges, it returns a snapshot and lets the
/// client decide.
Map<String, dynamic> mergeTaskMaps({
  required Map<String, dynamic> local,
  required Map<String, dynamic> remote,
  required Set<String> localFields,
  bool localDeleted = false,
}) {
  final merged = Map<String, dynamic>.of(remote);
  for (final field in localFields) {
    if (field == 'completed' ||
        field == 'completedAt' ||
        field == 'deleted' ||
        field == 'deletedAt') {
      continue;
    }
    merged[field] = local[field];
  }

  final localTouchedCompletion =
      localFields.contains('completed') || localFields.contains('completedAt');
  if (localTouchedCompletion) {
    merged['completed'] = local['completed'] == true;
    merged['completedAt'] = local['completedAt'];
  } else {
    // Concurrent completion: whoever finished first wins.
    final localCompletedAt = _parseDate(local['completedAt']);
    final remoteCompletedAt = _parseDate(remote['completedAt']);
    final earliest = _earlier(localCompletedAt, remoteCompletedAt);
    merged['completed'] = earliest != null;
    merged['completedAt'] = earliest?.toUtc().toIso8601String();
  }

  // Deletion wins, whether it came from this device or another one.
  if (localDeleted || remote['deleted'] == true) {
    merged['deleted'] = true;
    merged['deletedAt'] = remote['deletedAt'] ??
        local['deletedAt'] ??
        DateTime.now().toUtc().toIso8601String();
  }

  return merged;
}

/// Lists are read-only in P0, but pulls can still race with a future local
/// edit. Keep the same shape as [mergeTaskMaps] for consistency.
Map<String, dynamic> mergeListMaps({
  required Map<String, dynamic> local,
  required Map<String, dynamic> remote,
  required Set<String> localFields,
}) {
  final merged = Map<String, dynamic>.of(remote);
  for (final field in localFields) {
    merged[field] = local[field];
  }
  return merged;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}

DateTime? _earlier(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}
