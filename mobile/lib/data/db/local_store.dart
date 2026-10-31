import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show BooleanExpressionOperators, DoUpdate;
import 'package:path/path.dart' as p;

import '../../core/models.dart';
import '../remote/sync_api.dart';
import '../storage_paths.dart';
import 'local_database.dart';

/// A pending local operation. Stored in the same file as the business data so
/// a crash cannot lose the intent to push.
class OutboxRecord {
  const OutboxRecord({
    required this.opId,
    required this.entity,
    required this.entityId,
    required this.action,
    required this.patch,
    required this.attempts,
    required this.nextTryAt,
    required this.createdAt,
    this.baseEtag,
  });

  final String opId;
  final String entity;
  final String entityId;
  final String action;
  final Map<String, dynamic> patch;
  final String? baseEtag;
  final int attempts;
  final DateTime nextTryAt;
  final DateTime createdAt;

  OutboxOp toApiOp() => OutboxOp(
    opId: opId,
    entity: entity,
    entityId: entityId,
    action: action,
    patch: patch,
    baseEtag: baseEtag,
    attempts: attempts,
  );

  OutboxRecord copyWith({
    String? opId,
    String? action,
    Map<String, dynamic>? patch,
    String? baseEtag,
    bool clearBaseEtag = false,
    int? attempts,
    DateTime? nextTryAt,
  }) {
    return OutboxRecord(
      opId: opId ?? this.opId,
      entity: entity,
      entityId: entityId,
      action: action ?? this.action,
      patch: patch ?? this.patch,
      baseEtag: clearBaseEtag ? null : (baseEtag ?? this.baseEtag),
      attempts: attempts ?? this.attempts,
      nextTryAt: nextTryAt ?? this.nextTryAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'opId': opId,
    'entity': entity,
    'entityId': entityId,
    'action': action,
    'patch': patch,
    if (baseEtag != null) 'baseEtag': baseEtag,
    'attempts': attempts,
    'nextTryAt': nextTryAt.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory OutboxRecord.fromJson(Map<String, dynamic> json) => OutboxRecord(
    opId: (json['opId'] ?? '').toString(),
    entity: (json['entity'] ?? '').toString(),
    entityId: (json['entityId'] ?? '').toString(),
    action: (json['action'] ?? '').toString(),
    patch: json['patch'] is Map<String, dynamic>
        ? json['patch'] as Map<String, dynamic>
        : const {},
    baseEtag: json['baseEtag']?.toString(),
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    nextTryAt: _date(json['nextTryAt']) ?? DateTime.now().toUtc(),
    createdAt: _date(json['createdAt']) ?? DateTime.now().toUtc(),
  );
}

class ConflictRecord {
  const ConflictRecord({
    required this.entity,
    required this.entityId,
    required this.localPatch,
    required this.remote,
    required this.createdAt,
  });

  final String entity;
  final String entityId;
  final Map<String, dynamic> localPatch;
  final Map<String, dynamic> remote;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'entity': entity,
    'entityId': entityId,
    'localPatch': localPatch,
    'remote': remote,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory ConflictRecord.fromJson(Map<String, dynamic> json) => ConflictRecord(
    entity: (json['entity'] ?? '').toString(),
    entityId: (json['entityId'] ?? '').toString(),
    localPatch: json['localPatch'] is Map<String, dynamic>
        ? json['localPatch'] as Map<String, dynamic>
        : const {},
    remote: json['remote'] is Map<String, dynamic>
        ? json['remote'] as Map<String, dynamic>
        : const {},
    createdAt: _date(json['createdAt']) ?? DateTime.now().toUtc(),
  );
}

/// Local-first store.
///
/// Two layers: the maps below answer every read synchronously (the sync engine
/// and the whole UI rely on that), and SQLite via drift is the durable journal
/// underneath. Each mutation updates memory, then writes the touched rows
/// inside one transaction; `batch` collapses a group of mutations into a single
/// transaction and a single change event.
class LocalStore {
  LocalStore._(this._db, this._legacyFile, this._ownsDatabase);

  /// Pure in-memory store: no SQLite, no persistence. Used by widget tests,
  /// whose fake async zone cannot drive a real database connection.
  factory LocalStore.memory() => LocalStore._(null, null, false);

  /// `path` is the legacy JSON data file. It becomes the sibling `.db` SQLite
  /// file; when that database is still empty and the JSON file has content,
  /// the data is imported once and the JSON renamed to `.migrated.bak`.
  static Future<LocalStore> open({String? path}) async {
    final requested =
        path ?? p.join((await appStorageDirectory()).path, 'caldav_free.json');
    final legacy = p.extension(requested) == '.json' ? File(requested) : null;
    final dbPath = '${p.withoutExtension(requested)}.db';
    // An explicit path (tests) gets a private connection; the app's data
    // directory uses the process-wide one shared with the write queues.
    final store = LocalStore._(
      path == null ? sharedAppDatabase(dbPath) : AppDatabase.file(dbPath),
      legacy,
      path != null,
    );
    await store._load();
    return store;
  }

  final AppDatabase? _db;
  final File? _legacyFile;
  final bool _ownsDatabase;

  /// The database behind this store, or null in memory-only mode. Habit and
  /// countdown mirrors open their tables on the same connection.
  AppDatabase? get database => _db;

  final Map<String, TaskItem> _tasks = {};
  final Set<String> _dirtyTasks = {};
  final Map<String, TaskListItem> _lists = {};
  final Map<String, TaskSection> _sections = {};
  final Map<String, FolderItem> _folders = {};
  final Map<String, SavedFilterItem> _filters = {};
  final Map<String, OutboxRecord> _outbox = {};
  final Map<String, ConflictRecord> _conflicts = {};

  /// Ids written or deleted since the last flush. Rows are read back from the
  /// maps at flush time, so a batch only persists its final state.
  final Set<String> _wTasks = {};
  final Set<String> _wLists = {};
  final Set<String> _wSections = {};
  final Set<String> _wFolders = {};
  final Set<String> _wFilters = {};
  final Set<String> _wOutbox = {};
  final Set<String> _wConflicts = {};
  bool _wMeta = false;
  bool _wipe = false;

  /// Tags picked for the PC sidebar; `null` means every tag is shown.
  Set<String>? _sidebarTags;

  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void> _tail = Future<void>.value();

  String _cursor = '0';
  DateTime? _syncedAt;
  String _accent = '#3563F0';

  String get cursor => _cursor;
  DateTime? get syncedAt => _syncedAt;
  String get accent => _accent;
  int get pendingCount => _outbox.length;
  int get failedCount => _outbox.values.where((op) => op.attempts >= 99).length;
  int get conflictCount => _conflicts.length;
  bool get isDirty => _dirtyTasks.isNotEmpty;

  // ------------------------------------------------------------ reads

  TaskItem? task(String id) => _tasks[id];

  List<TaskItem> tasksSnapshot({
    String? listId,
    required bool completed,
    String view = 'all',
    bool manualSort = false,
  }) {
    final start = _todayStartUtc();
    final dayEnd = start.add(const Duration(days: 1));
    final weekEnd = start.add(const Duration(days: 7));
    final items = _tasks.values.where((task) {
      if (task.kind != TaskKind.task ||
          task.deleted ||
          task.completed != completed) {
        return false;
      }
      if (listId != null && task.listId != listId) return false;
      if (completed) return true;
      final due = task.dueAt?.toUtc();
      switch (view) {
        case 'today':
          return due != null && due.isBefore(dayEnd);
        case 'next7':
          return due != null && !due.isBefore(start) && due.isBefore(weekEnd);
        default:
          return true;
      }
    }).toList();
    items.sort(
      completed
          ? _compareCompleted
          : manualSort
          ? _compareManual
          : _compareOpen,
    );
    return items;
  }

  Stream<List<TaskItem>> watchTasks({
    String? listId,
    required bool completed,
    String view = 'all',
    bool manualSort = false,
  }) async* {
    yield tasksSnapshot(
      listId: listId,
      completed: completed,
      view: view,
      manualSort: manualSort,
    );
    await for (final _ in _changes.stream) {
      yield tasksSnapshot(
        listId: listId,
        completed: completed,
        view: view,
        manualSort: manualSort,
      );
    }
  }

  /// All tasks including completed and soft-deleted rows. Used by the reminder
  /// planner, which must also cancel reminders for completed/deleted tasks.
  List<TaskItem> allTasks() => _tasks.values.toList(growable: false);

  Stream<List<TaskItem>> watchAllTasks() async* {
    yield allTasks();
    await for (final _ in _changes.stream) {
      yield allTasks();
    }
  }

  List<TaskItem> trashSnapshot() {
    final items = _tasks.values
        .where((task) => task.kind == TaskKind.task && task.deleted)
        .toList();
    items.sort((a, b) {
      final aAt = a.deletedAt ?? a.updatedAt;
      final bAt = b.deletedAt ?? b.updatedAt;
      return bAt.compareTo(aAt);
    });
    return items;
  }

  Stream<List<TaskItem>> watchTrash() async* {
    yield trashSnapshot();
    await for (final _ in _changes.stream) {
      yield trashSnapshot();
    }
  }

  DateTime _todayStartUtc() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).toUtc();
  }

  TaskListItem? list(String id) => _lists[id];

  TaskListItem? inbox() {
    for (final list in _lists.values) {
      if (list.isInbox) return list;
    }
    return null;
  }

  List<TaskListItem> listsSnapshot() {
    final items = _lists.values.toList();
    items.sort((a, b) {
      if (a.isInbox != b.isInbox) return a.isInbox ? -1 : 1;
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  Stream<List<TaskListItem>> watchLists() async* {
    yield listsSnapshot();
    await for (final _ in _changes.stream) {
      yield listsSnapshot();
    }
  }

  FolderItem? folder(String id) => _folders[id];

  SavedFilterItem? filter(String id) => _filters[id];

  List<SavedFilterItem> filtersSnapshot() {
    final items = _filters.values.toList();
    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  Stream<List<SavedFilterItem>> watchFilters() async* {
    yield filtersSnapshot();
    await for (final _ in _changes.stream) {
      yield filtersSnapshot();
    }
  }

  TaskSection? section(String id) => _sections[id];

  List<TaskSection> sectionsSnapshot({String? listId}) {
    final items = _sections.values
        .where((section) => listId == null || section.listId == listId)
        .toList();
    items.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  Stream<List<TaskSection>> watchSections({String? listId}) async* {
    yield sectionsSnapshot(listId: listId);
    await for (final _ in _changes.stream) {
      yield sectionsSnapshot(listId: listId);
    }
  }

  List<FolderItem> foldersSnapshot() {
    final items = _folders.values.toList();
    items.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  Stream<List<FolderItem>> watchFolders() async* {
    yield foldersSnapshot();
    await for (final _ in _changes.stream) {
      yield foldersSnapshot();
    }
  }

  OutboxRecord? pendingOp(String entity, String entityId) {
    for (final op in _outbox.values) {
      if (op.entity == entity && op.entityId == entityId) return op;
    }
    return null;
  }

  List<OutboxRecord> dueOps({int limit = 100}) {
    final now = DateTime.now().toUtc();
    final ops =
        _outbox.values.where((op) => !op.nextTryAt.isAfter(now)).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops.take(limit).toList(growable: false);
  }

  List<ConflictRecord> conflictsSnapshot() =>
      _conflicts.values.toList(growable: false);

  // ------------------------------------------------------------ mutations

  Future<void> saveTask(TaskItem task, {required bool dirty}) {
    return _mutate(() {
      _tasks[task.id] = task;
      if (dirty) {
        _dirtyTasks.add(task.id);
      } else {
        _dirtyTasks.remove(task.id);
      }
      _wTasks.add(task.id);
    });
  }

  Future<void> hardDeleteTask(String id) {
    return _mutate(() {
      _tasks.remove(id);
      _dirtyTasks.remove(id);
      _wTasks.add(id);
    });
  }

  Future<void> saveList(TaskListItem list, {bool dirty = false}) {
    return _mutate(() {
      _lists[list.id] = list;
      _wLists.add(list.id);
    });
  }

  Future<void> hardDeleteList(String id) {
    return _mutate(() {
      _lists.remove(id);
      _wLists.add(id);
    });
  }

  Future<void> saveFolder(FolderItem folder) {
    return _mutate(() {
      _folders[folder.id] = folder;
      _wFolders.add(folder.id);
    });
  }

  Future<void> saveFilter(SavedFilterItem filter) {
    return _mutate(() {
      _filters[filter.id] = filter;
      _wFilters.add(filter.id);
    });
  }

  Future<void> hardDeleteFilter(String id) {
    return _mutate(() {
      _filters.remove(id);
      _wFilters.add(id);
    });
  }

  Future<void> saveSection(TaskSection section) {
    return _mutate(() {
      _sections[section.id] = section;
      _wSections.add(section.id);
    });
  }

  Future<void> hardDeleteSection(String id) {
    return _mutate(() {
      _sections.remove(id);
      _wSections.add(id);
    });
  }

  Future<void> hardDeleteFolder(String id) {
    return _mutate(() {
      _folders.remove(id);
      _wFolders.add(id);
    });
  }

  Future<void> writeCursor(String cursor) {
    return _mutate(() {
      _cursor = cursor.isEmpty ? '0' : cursor;
      _syncedAt = DateTime.now().toUtc();
      _wMeta = true;
    });
  }

  Future<void> saveOp({
    required String opId,
    required String entity,
    required String entityId,
    required String action,
    required Map<String, dynamic> patch,
    String? baseEtag,
    int attempts = 0,
    DateTime? nextTryAt,
    DateTime? createdAt,
  }) {
    return _mutate(() {
      final now = DateTime.now().toUtc();
      _outbox[opId] = OutboxRecord(
        opId: opId,
        entity: entity,
        entityId: entityId,
        action: action,
        patch: patch,
        baseEtag: baseEtag,
        attempts: attempts,
        nextTryAt: nextTryAt ?? now,
        createdAt: createdAt ?? now,
      );
      _wOutbox.add(opId);
    });
  }

  Future<void> removeOp(String opId) {
    return _mutate(() {
      _outbox.remove(opId);
      _wOutbox.add(opId);
    });
  }

  Future<void> removeOpsForEntity(String entity, String entityId) {
    return _mutate(() {
      _outbox.removeWhere((key, op) {
        final match = op.entity == entity && op.entityId == entityId;
        if (match) _wOutbox.add(key);
        return match;
      });
    });
  }

  Future<void> retryOp({
    required String opId,
    required int attempts,
    required DateTime nextTryAt,
  }) {
    return _mutate(() {
      final op = _outbox[opId];
      if (op == null) return;
      _outbox[opId] = op.copyWith(attempts: attempts, nextTryAt: nextTryAt);
      _wOutbox.add(opId);
    });
  }

  Future<void> replaceOp({
    required String oldOpId,
    required OutboxRecord replacement,
  }) {
    return _mutate(() {
      _outbox.remove(oldOpId);
      _outbox[replacement.opId] = replacement;
      _wOutbox
        ..add(oldOpId)
        ..add(replacement.opId);
    });
  }

  Future<void> recordConflict({
    required String entity,
    required String entityId,
    required Map<String, dynamic> localPatch,
    required Map<String, dynamic> remote,
  }) {
    return _mutate(() {
      _conflicts['$entity:$entityId'] = ConflictRecord(
        entity: entity,
        entityId: entityId,
        localPatch: localPatch,
        remote: remote,
        createdAt: DateTime.now().toUtc(),
      );
      _wConflicts.add('$entity:$entityId');
    });
  }

  Future<void> clearConflict(String entity, String entityId) {
    return _mutate(() {
      _conflicts.remove('$entity:$entityId');
      _wConflicts.add('$entity:$entityId');
    });
  }

  Future<void> setAccent(String value) {
    return _mutate(() {
      _accent = value;
      _wMeta = true;
    });
  }

  /// `null` means the user never customized the sidebar: show every tag.
  List<String>? sidebarTagsSnapshot() => _sidebarTags == null
      ? null
      : List<String>.unmodifiable(_sidebarTags!);

  Future<void> setSidebarTags(Iterable<String> names) {
    final next = <String>{
      for (final name in names)
        if (name.trim().isNotEmpty) name.trim(),
    };
    return _mutate(() {
      _sidebarTags = next;
      _wMeta = true;
    });
  }

  Future<void> clearAll() {
    return _mutate(() {
      _tasks.clear();
      _dirtyTasks.clear();
      _lists.clear();
      _sections.clear();
      _folders.clear();
      _filters.clear();
      _outbox.clear();
      _conflicts.clear();
      _cursor = '0';
      _syncedAt = null;
      _wTasks.clear();
      _wLists.clear();
      _wSections.clear();
      _wFolders.clear();
      _wFilters.clear();
      _wOutbox.clear();
      _wConflicts.clear();
      _sidebarTags = null;
      _wMeta = false;
      _wipe = true;
    });
  }

  Future<void> dispose() async {
    unawaited(_changes.close());
    final db = _db;
    // The in-memory store has nothing to flush; awaiting here would stall the
    // fake-async zone that widget tests run their teardown in.
    if (db == null) return;
    await _tail;
    if (!_ownsDatabase) {
      await closeSharedAppDatabase();
      return;
    }
    await db.close();
  }

  // ------------------------------------------------------------ persistence

  Future<void> _load() async {
    final db = _db;
    if (db == null) return;
    _cursor = await db.metaValue(cursorKey) ?? '0';
    _syncedAt = _date(await db.metaValue(syncedAtKey));
    _accent = await db.metaValue(accentKey) ?? '#3563F0';
    final rawTags = await db.metaValue(sidebarTagsKey);
    if (rawTags != null) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          _sidebarTags = {
            for (final item in decoded)
              if (item?.toString().trim().isNotEmpty ?? false)
                item.toString().trim(),
          };
        }
      } catch (_) {
        // Ignore a malformed selection; fall back to showing every tag.
      }
    }
    for (final row in await db.select(db.tasks).get()) {
      _tasks[row.syncId] = row.toModel();
      if (row.dirty) _dirtyTasks.add(row.syncId);
    }
    for (final row in await db.select(db.taskLists).get()) {
      _lists[row.syncId] = row.toModel();
    }
    for (final row in await db.select(db.taskSections).get()) {
      _sections[row.syncId] = row.toModel();
    }
    for (final row in await db.select(db.folders).get()) {
      _folders[row.syncId] = row.toModel();
    }
    for (final row in await db.select(db.savedFilters).get()) {
      _filters[row.syncId] = row.toModel();
    }
    for (final row in await db.select(db.outbox).get()) {
      _outbox[row.opId] = _outboxFrom(row);
    }
    for (final row in await db.select(db.conflicts).get()) {
      _conflicts['${row.entity}:${row.entityId}'] = _conflictFrom(row);
    }
    await _importLegacyJson();
  }

  /// One-time upgrade from the pre-SQLite JSON file. The imported rows are
  /// flushed into the database and the JSON is kept aside as a backup.
  Future<void> _importLegacyJson() async {
    final file = _legacyFile;
    if (file == null || _hasData() || !await file.exists()) return;
    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return;
      decoded = raw;
    } on FormatException {
      // Keep the damaged file for inspection and start clean.
      try {
        await file.rename(
          '${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}',
        );
      } on FileSystemException {
        // Ignore; a clean start is still better than failing to boot.
      }
      return;
    }
    _cursor = (decoded['cursor'] ?? '0').toString();
    _syncedAt = _date(decoded['syncedAt']);
    _accent = (decoded['accent'] ?? '#3563F0').toString();
    final tasks = decoded['tasks'];
    if (tasks is Map<String, dynamic>) {
      for (final entry in tasks.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        final data = value['data'];
        if (data is! Map<String, dynamic>) continue;
        _tasks[entry.key] = TaskItem.fromWireJson(data);
        if (value['dirty'] == true) _dirtyTasks.add(entry.key);
      }
    }
    for (final key in const ['lists', 'sections', 'folders']) {
      final raw = decoded[key];
      if (raw is! Map<String, dynamic>) continue;
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        switch (key) {
          case 'lists':
            _lists[entry.key] = TaskListItem.fromWireJson(value);
          case 'sections':
            _sections[entry.key] = TaskSection.fromWireJson(value);
          default:
            _folders[entry.key] = FolderItem.fromWireJson(value);
        }
      }
    }
    final outbox = decoded['outbox'];
    if (outbox is Map<String, dynamic>) {
      for (final entry in outbox.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          _outbox[entry.key] = OutboxRecord.fromJson(value);
        }
      }
    }
    final conflicts = decoded['conflicts'];
    if (conflicts is Map<String, dynamic>) {
      for (final entry in conflicts.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          _conflicts[entry.key] = ConflictRecord.fromJson(value);
        }
      }
    }
    _wTasks.addAll(_tasks.keys);
    _wLists.addAll(_lists.keys);
    _wSections.addAll(_sections.keys);
    _wFolders.addAll(_folders.keys);
    _wFilters.addAll(_filters.keys);
    _wOutbox.addAll(_outbox.keys);
    _wConflicts.addAll(_conflicts.keys);
    _wMeta = true;
    await _persist();
    try {
      await file.rename('${file.path}.migrated.bak');
    } on FileSystemException {
      // Another process beat us to it; the data is already in SQLite.
    }
  }

  bool _hasData() =>
      _tasks.isNotEmpty ||
      _lists.isNotEmpty ||
      _sections.isNotEmpty ||
      _folders.isNotEmpty ||
      _filters.isNotEmpty ||
      _outbox.isNotEmpty ||
      _conflicts.isNotEmpty ||
      _cursor != '0';

  OutboxRecord _outboxFrom(OutboxRow row) => OutboxRecord(
    opId: row.opId,
    entity: row.entity,
    entityId: row.entityId,
    action: row.op,
    patch: decodeJsonObject(row.patch) ?? const {},
    baseEtag: row.baseEtag,
    attempts: row.attempts,
    nextTryAt: row.nextTryAt,
    createdAt: row.createdAt,
  );

  OutboxRow _outboxRow(OutboxRecord op) => OutboxRow(
    opId: op.opId,
    entity: op.entity,
    entityId: op.entityId,
    op: op.action,
    patch: encodeJsonObject(op.patch),
    baseEtag: op.baseEtag,
    attempts: op.attempts,
    nextTryAt: op.nextTryAt,
    createdAt: op.createdAt,
  );

  ConflictRecord _conflictFrom(ConflictRow row) => ConflictRecord(
    entity: row.entity,
    entityId: row.entityId,
    localPatch: decodeJsonObject(row.localPatch) ?? const {},
    remote: decodeJsonObject(row.remote) ?? const {},
    createdAt: row.createdAt,
  );

  ConflictRow _conflictRow(ConflictRecord record) => ConflictRow(
    entity: record.entity,
    entityId: record.entityId,
    localPatch: encodeJsonObject(record.localPatch),
    remote: encodeJsonObject(record.remote),
    createdAt: record.createdAt,
  );

  Future<T> _mutate<T>(FutureOr<T> Function() action) {
    if (_batching) {
      return Future<T>.sync(() async => await action());
    }
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final value = await action();
        await _persist();
        if (!_changes.isClosed) _changes.add(null);
        completer.complete(value);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  bool _batching = false;

  /// Runs several mutations as one persisted change and one stream event.
  Future<T> batch<T>(Future<T> Function() action) {
    if (_batching) return action();
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      _batching = true;
      try {
        final value = await action();
        await _persist();
        if (!_changes.isClosed) _changes.add(null);
        completer.complete(value);
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _batching = false;
      }
    });
    return completer.future;
  }

  Future<void> _persist() async {
    final db = _db;
    if (db == null) {
      _wipe = false;
      _wTasks.clear();
      _wLists.clear();
      _wSections.clear();
      _wFolders.clear();
      _wOutbox.clear();
      _wConflicts.clear();
      _wMeta = false;
      return;
    }
    final wipe = _wipe;
    final taskIds = _wTasks.toList();
    final listIds = _wLists.toList();
    final sectionIds = _wSections.toList();
    final folderIds = _wFolders.toList();
    final filterIds = _wFilters.toList();
    final opIds = _wOutbox.toList();
    final conflictKeys = _wConflicts.toList();
    final writeMeta = _wMeta;
    _wipe = false;
    _wTasks.clear();
    _wLists.clear();
    _wSections.clear();
    _wFolders.clear();
    _wFilters.clear();
    _wOutbox.clear();
    _wConflicts.clear();
    _wMeta = false;
    if (!wipe &&
        !writeMeta &&
        taskIds.isEmpty &&
        listIds.isEmpty &&
        sectionIds.isEmpty &&
        folderIds.isEmpty &&
        filterIds.isEmpty &&
        opIds.isEmpty &&
        conflictKeys.isEmpty) {
      return;
    }
    await db.transaction(() async {
      if (wipe) {
        await db.delete(db.tasks).go();
        await db.delete(db.taskLists).go();
        await db.delete(db.taskSections).go();
        await db.delete(db.folders).go();
        await db.delete(db.savedFilters).go();
        await db.delete(db.outbox).go();
        await db.delete(db.conflicts).go();
        await db.delete(db.meta).go();
      }
      for (final id in taskIds) {
        final item = _tasks[id];
        if (item == null) {
          await (db.delete(db.tasks)
                ..where((row) => row.syncId.equals(id)))
              .go();
          continue;
        }
        final row = item.toRow(dirty: _dirtyTasks.contains(id));
        await db
            .into(db.tasks)
            .insert(row, onConflict: DoUpdate((_) => row));
      }
      for (final id in listIds) {
        final item = _lists[id];
        if (item == null) {
          await (db.delete(db.taskLists)
                ..where((row) => row.syncId.equals(id)))
              .go();
          continue;
        }
        final row = item.toRow();
        await db
            .into(db.taskLists)
            .insert(row, onConflict: DoUpdate((_) => row));
      }
      for (final id in sectionIds) {
        final item = _sections[id];
        if (item == null) {
          await (db.delete(db.taskSections)
                ..where((row) => row.syncId.equals(id)))
              .go();
          continue;
        }
        final row = item.toRow();
        await db
            .into(db.taskSections)
            .insert(row, onConflict: DoUpdate((_) => row));
      }
      for (final id in folderIds) {
        final item = _folders[id];
        if (item == null) {
          await (db.delete(db.folders)
                ..where((row) => row.syncId.equals(id)))
              .go();
          continue;
        }
        final row = item.toRow();
        await db
            .into(db.folders)
            .insert(row, onConflict: DoUpdate((_) => row));
      }
      for (final id in filterIds) {
        final item = _filters[id];
        if (item == null) {
          await (db.delete(db.savedFilters)
                ..where((row) => row.syncId.equals(id)))
              .go();
          continue;
        }
        final row = item.toRow();
        await db
            .into(db.savedFilters)
            .insert(row, onConflict: DoUpdate((_) => row));
      }
      for (final id in opIds) {
        final op = _outbox[id];
        if (op == null) {
          await (db.delete(db.outbox)
                ..where((row) => row.opId.equals(id)))
              .go();
          continue;
        }
        final row = _outboxRow(op);
        await db
            .into(db.outbox)
            .insert(row, onConflict: DoUpdate((_) => row));
      }
      for (final key in conflictKeys) {
        final record = _conflicts[key];
        if (record == null) {
          final sep = key.indexOf(':');
          final entity = sep < 0 ? key : key.substring(0, sep);
          final entityId = sep < 0 ? '' : key.substring(sep + 1);
          await (db.delete(db.conflicts)
                ..where(
                  (row) =>
                      row.entity.equals(entity) & row.entityId.equals(entityId),
                ))
              .go();
          continue;
        }
        final row = _conflictRow(record);
        await db
            .into(db.conflicts)
            .insert(row, onConflict: DoUpdate((_) => row));
      }
      if (writeMeta) {
        await db.putMeta(cursorKey, _cursor);
        if (_syncedAt == null) {
          await db.deleteMeta(syncedAtKey);
        } else {
          await db.putMeta(syncedAtKey, _syncedAt!.toUtc().toIso8601String());
        }
        await db.putMeta(accentKey, _accent);
        final sidebarTags = _sidebarTags;
        if (sidebarTags == null) {
          await db.deleteMeta(sidebarTagsKey);
        } else {
          final names = sidebarTags.toList()..sort();
          await db.putMeta(sidebarTagsKey, jsonEncode(names));
        }
      }
    });
  }
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}

int _compareManual(TaskItem a, TaskItem b) {
  final order = a.sortOrder.compareTo(b.sortOrder);
  if (order != 0) return order;
  return a.id.compareTo(b.id);
}

int _compareOpen(TaskItem a, TaskItem b) {
  if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
  final aDue = a.dueAt;
  final bDue = b.dueAt;
  if (aDue == null && bDue != null) return 1;
  if (aDue != null && bDue == null) return -1;
  if (aDue != null && bDue != null && !aDue.isAtSameMomentAs(bDue)) {
    return aDue.compareTo(bDue);
  }
  final order = a.sortOrder.compareTo(b.sortOrder);
  if (order != 0) return order;
  return a.id.compareTo(b.id);
}

int _compareCompleted(TaskItem a, TaskItem b) {
  final aAt = a.completedAt;
  final bAt = b.completedAt;
  if (aAt != null && bAt != null && !aAt.isAtSameMomentAs(bAt)) {
    return bAt.compareTo(aAt);
  }
  return a.id.compareTo(b.id);
}
