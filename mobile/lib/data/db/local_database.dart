import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/models.dart';

part 'local_database.g.dart';

/// Column names and types mirror the server's GORM models in
/// `internal/store` (`sync_id`, `order_index`, `modified_at`, ...). Complex
/// values (tags, reminder offsets, checklists, patches) live in a single TEXT
/// column encoded as JSON: the server uses comma-separated TEXT, but client
/// tags may contain commas.
///
/// Ids stay the client-owned ULID (`sync_id`), which is the primary key here;
/// the server's autoincrement integer ids are never persisted locally.
@TableIndex(name: 'idx_task_list', columns: {#listId})
@TableIndex(name: 'idx_task_section', columns: {#sectionId})
@TableIndex(name: 'idx_task_due', columns: {#dueAt})
@TableIndex(name: 'idx_task_deleted', columns: {#deleted})
@DataClassName('TaskRow')
class Tasks extends Table {
  TextColumn get syncId => text().named('sync_id')();

  TextColumn get listId =>
      text().named('list_id').withDefault(const Constant(''))();

  TextColumn get parentId => text().named('parent_id').nullable()();

  TextColumn get sectionId => text().named('section_id').nullable()();

  TextColumn get title => text().withDefault(const Constant(''))();

  TextColumn get notes => text().withDefault(const Constant(''))();

  TextColumn get notesFormat =>
      text().named('notes_format').withDefault(const Constant('text'))();

  TextColumn get kind => text().withDefault(const Constant('TASK'))();

  IntColumn get priority => integer().withDefault(const Constant(0))();

  DateTimeColumn get startAt => dateTime().named('start_at').nullable()();

  DateTimeColumn get dueAt => dateTime().named('due_at').nullable()();

  BoolColumn get allDay =>
      boolean().named('all_day').withDefault(const Constant(false))();

  TextColumn get recurrence => text().withDefault(const Constant(''))();

  TextColumn get reminderOffsets =>
      text().named('reminder_offsets').withDefault(const Constant('[]'))();

  TextColumn get tags => text().withDefault(const Constant('[]'))();

  TextColumn get checklist => text().withDefault(const Constant('[]'))();

  TextColumn get assignee => text().withDefault(const Constant(''))();

  DateTimeColumn get completedAt =>
      dateTime().named('completed_at').nullable()();

  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  IntColumn get orderIndex =>
      integer().named('order_index').withDefault(const Constant(0))();

  TextColumn get vtodoEtag =>
      text().named('vtodo_etag').withDefault(const Constant(''))();

  IntColumn get version => integer().withDefault(const Constant(0))();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at').nullable()();

  DateTimeColumn get modifiedAt => dateTime().named('modified_at')();

  /// Local-only flag: the row still has a queued push operation.
  BoolColumn get localDirty =>
      boolean().named('dirty').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {syncId};
}

@TableIndex(name: 'idx_tasklist_folder', columns: {#folderId})
@DataClassName('TaskListRow')
class TaskLists extends Table {
  TextColumn get syncId => text().named('sync_id')();

  TextColumn get folderId => text().named('folder_id').nullable()();

  TextColumn get name => text().withDefault(const Constant(''))();

  TextColumn get color => text().withDefault(const Constant(''))();

  TextColumn get kind => text().withDefault(const Constant('TASK'))();

  IntColumn get orderIndex =>
      integer().named('order_index').withDefault(const Constant(0))();

  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  BoolColumn get isInbox =>
      boolean().named('is_inbox').withDefault(const Constant(false))();

  TextColumn get etag => text().withDefault(const Constant(''))();

  IntColumn get version => integer().withDefault(const Constant(0))();

  DateTimeColumn get modifiedAt => dateTime().named('modified_at')();

  @override
  Set<Column> get primaryKey => {syncId};
}

@TableIndex(name: 'idx_tasksection_list', columns: {#listId})
@DataClassName('TaskSectionRow')
class TaskSections extends Table {
  TextColumn get syncId => text().named('sync_id')();

  TextColumn get listId =>
      text().named('list_id').withDefault(const Constant(''))();

  TextColumn get name => text().withDefault(const Constant(''))();

  IntColumn get orderIndex =>
      integer().named('order_index').withDefault(const Constant(0))();

  TextColumn get etag => text().withDefault(const Constant(''))();

  IntColumn get version => integer().withDefault(const Constant(0))();

  DateTimeColumn get modifiedAt => dateTime().named('modified_at')();

  @override
  Set<Column> get primaryKey => {syncId};
}

@DataClassName('FolderRow')
class Folders extends Table {
  TextColumn get syncId => text().named('sync_id')();

  TextColumn get name => text().withDefault(const Constant(''))();

  IntColumn get orderIndex =>
      integer().named('order_index').withDefault(const Constant(0))();

  TextColumn get etag => text().withDefault(const Constant(''))();

  IntColumn get version => integer().withDefault(const Constant(0))();

  DateTimeColumn get modifiedAt => dateTime().named('modified_at')();

  @override
  Set<Column> get primaryKey => {syncId};
}

/// Client push journal, one row per queued operation (server `SyncOp`).
@TableIndex(name: 'idx_outbox_entity', columns: {#entity, #entityId})
@TableIndex(name: 'idx_outbox_next_try', columns: {#nextTryAt})
@DataClassName('OutboxRow')
class Outbox extends Table {
  TextColumn get opId => text().named('op_id')();

  TextColumn get entity => text().withDefault(const Constant(''))();

  TextColumn get entityId =>
      text().named('entity_id').withDefault(const Constant(''))();

  /// `put` or `delete`.
  TextColumn get op => text().withDefault(const Constant(''))();

  TextColumn get patch => text().withDefault(const Constant('{}'))();

  TextColumn get baseEtag => text().named('base_etag').nullable()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get nextTryAt =>
      dateTime().named('next_try_at').withDefault(currentDateAndTime)();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {opId};
}

@DataClassName('ConflictRow')
class Conflicts extends Table {
  TextColumn get entity => text()();

  TextColumn get entityId => text().named('entity_id')();

  TextColumn get localPatch =>
      text().named('local_patch').withDefault(const Constant('{}'))();

  TextColumn get remote => text().withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {entity, entityId};
}

/// Local-only write queue for habits (checked in offline, replayed by the
/// background sync pass). `seq` is the FIFO order the queue relies on.
@TableIndex(name: 'idx_habitoutbox_op', columns: {#opId}, unique: true)
@DataClassName('HabitOutboxRow')
class HabitOutbox extends Table {
  IntColumn get seq => integer().autoIncrement()();

  TextColumn get opId => text().named('op_id')();

  TextColumn get action => text().withDefault(const Constant(''))();

  IntColumn get habitId => integer().named('habit_id')();

  TextColumn get payload => text().nullable()();

  IntColumn get stamp => integer().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {seq};
}

/// Same shape as [HabitOutbox], for countdowns.
@TableIndex(name: 'idx_countdownoutbox_op', columns: {#opId}, unique: true)
@DataClassName('CountdownOutboxRow')
class CountdownOutbox extends Table {
  IntColumn get seq => integer().autoIncrement()();

  TextColumn get opId => text().named('op_id')();

  TextColumn get action => text().withDefault(const Constant(''))();

  IntColumn get countdownId => integer().named('countdown_id')();

  TextColumn get payload => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {seq};
}

/// Local mirror of the server habit workspace (`internal/store/habits.go`).
/// The background sync pass replaces these rows; the habits page reads only
/// them, so it renders offline without a network round-trip.
@TableIndex(name: 'idx_habit_section', columns: {#sectionId})
@DataClassName('HabitRow')
class Habits extends Table {
  IntColumn get id => integer()();

  TextColumn get name => text().withDefault(const Constant(''))();

  TextColumn get icon => text().withDefault(const Constant(''))();

  TextColumn get color => text().withDefault(const Constant('#97E38B'))();

  IntColumn get sectionId =>
      integer().named('section_id').withDefault(const Constant(0))();

  IntColumn get status => integer().withDefault(const Constant(0))();

  RealColumn get goal => real().withDefault(const Constant(1))();

  RealColumn get step => real().withDefault(const Constant(1))();

  TextColumn get unit => text().withDefault(const Constant('Count'))();

  TextColumn get frequency => text().withDefault(const Constant('{}'))();

  IntColumn get startDate =>
      integer().named('start_date').withDefault(const Constant(0))();

  IntColumn get targetDays =>
      integer().named('target_days').withDefault(const Constant(0))();

  IntColumn get completedCycles =>
      integer().named('completed_cycles').withDefault(const Constant(0))();

  /// Values the server derives per request (streaks, today state). Cached so
  /// the mirror can render the same numbers offline.
  IntColumn get totalCheckIns =>
      integer().named('total_check_ins').withDefault(const Constant(0))();

  IntColumn get currentStreak =>
      integer().named('current_streak').withDefault(const Constant(0))();

  IntColumn get maxStreak =>
      integer().named('max_streak').withDefault(const Constant(0))();

  BoolColumn get dueToday =>
      boolean().named('due_today').withDefault(const Constant(false))();

  BoolColumn get doneToday =>
      boolean().named('done_today').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HabitCheckinRow')
class HabitCheckins extends Table {
  IntColumn get habitId => integer().named('habit_id')();

  IntColumn get checkinStamp => integer().named('checkin_stamp')();

  RealColumn get value => real().withDefault(const Constant(0))();

  RealColumn get goal => real().withDefault(const Constant(0))();

  IntColumn get status => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {habitId, checkinStamp};
}

@DataClassName('HabitSectionRow')
class HabitSections extends Table {
  IntColumn get id => integer()();

  TextColumn get name => text().withDefault(const Constant(''))();

  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local mirror of `internal/store/countdown.go:CountdownEvent`, plus the
/// derived fields the server computes per request.
@DataClassName('CountdownRow')
class Countdowns extends Table {
  IntColumn get id => integer()();

  TextColumn get name => text().withDefault(const Constant(''))();

  TextColumn get type => text().withDefault(const Constant('countdown'))();

  IntColumn get date => integer().withDefault(const Constant(0))();

  TextColumn get repeat => text().withDefault(const Constant('none'))();

  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  IntColumn get status => integer().withDefault(const Constant(0))();

  TextColumn get color => text().withDefault(const Constant('#92D0FF'))();

  TextColumn get icon => text().withDefault(const Constant('⏳'))();

  TextColumn get remark => text().withDefault(const Constant(''))();

  IntColumn get days => integer().withDefault(const Constant(0))();

  IntColumn get hours => integer().withDefault(const Constant(0))();

  IntColumn get minutes => integer().withDefault(const Constant(0))();

  IntColumn get seconds => integer().withDefault(const Constant(0))();

  TextColumn get state => text().withDefault(const Constant('future'))();

  IntColumn get occurrenceDate =>
      integer().named('occurrence_date').withDefault(const Constant(0))();

  IntColumn get age => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key/value store for the sync cursor and UI preferences.
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

const String cursorKey = 'cursor';
const String syncedAtKey = 'synced_at';
const String accentKey = 'accent';

/// Habit display preferences (server `HabitPreference`, a single row per user)
/// are cached as one JSON value rather than a table of scalars.
const String habitPreferencesKey = 'habit_preferences';

@DriftDatabase(
  tables: [
    Tasks,
    TaskLists,
    TaskSections,
    Folders,
    Outbox,
    Conflicts,
    HabitOutbox,
    CountdownOutbox,
    Habits,
    HabitCheckins,
    HabitSections,
    Countdowns,
    Meta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.file(String path) : super(_openFile(path));

  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (details) => details.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // v2: habit/countdown read mirrors.
        await migrator.createTable(habits);
        await migrator.createTable(habitCheckins);
        await migrator.createTable(habitSections);
        await migrator.createTable(countdowns);
      }
    },
  );

  Future<String?> metaValue(String key) async {
    final row = await (select(
      meta,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> putMeta(String key, String value) => into(meta).insert(
    MetaRow(key: key, value: value),
    onConflict: DoUpdate((_) => MetaRow(key: key, value: value)),
  );

  Future<void> deleteMeta(String key) =>
      (delete(meta)..where((t) => t.key.equals(key))).go();
}

LazyDatabase _openFile(String path) {
  final file = File(path);
  return LazyDatabase(() async {
    final parent = file.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Same durability settings the server's SQLite DSN uses.
        db.execute('PRAGMA journal_mode = WAL');
        db.execute('PRAGMA busy_timeout = 5000');
        db.execute('PRAGMA synchronous = NORMAL');
      },
    );
  });
}

AppDatabase? _shared;
String? _sharedPath;

/// Process-wide database for the app data directory. The task store and both
/// local-first write queues share one connection, so their writes serialize
/// instead of contending on the SQLite file lock.
AppDatabase sharedAppDatabase(String path) {
  final existing = _shared;
  if (existing != null && _sharedPath == path) return existing;
  final database = AppDatabase.file(path);
  _shared = database;
  _sharedPath = path;
  return database;
}

Future<void> closeSharedAppDatabase() async {
  final database = _shared;
  _shared = null;
  _sharedPath = null;
  if (database != null) await database.close();
}

String _encodeList(List<String> values) => jsonEncode(values);

List<String> _decodeStringList(String raw) {
  final decoded = _tryDecode(raw);
  if (decoded is! List) return const [];
  return decoded.map((value) => '$value').toList(growable: false);
}

String _encodeIntList(List<int> values) => jsonEncode(values);

List<int> _decodeIntList(String raw) {
  final decoded = _tryDecode(raw);
  if (decoded is! List) return const [];
  return decoded.map((value) => value is num ? value.toInt() : 0).toList();
}

String _encodeChecklist(List<ChecklistItem> items) =>
    jsonEncode(items.map((item) => item.toJson()).toList());

List<ChecklistItem> _decodeChecklist(String raw) {
  final decoded = _tryDecode(raw);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map<String, dynamic>>()
      .map(ChecklistItem.fromJson)
      .toList(growable: false);
}

Object? _tryDecode(String raw) {
  if (raw.isEmpty) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

extension TaskDbRow on TaskItem {
  TaskRow toRow({required bool dirty}) => TaskRow(
    syncId: id,
    listId: listId,
    parentId: parentId,
    sectionId: sectionId,
    title: title,
    notes: notes,
    notesFormat: notesFormat,
    kind: taskKindToWire(kind),
    priority: priority,
    startAt: startAt,
    dueAt: dueAt,
    allDay: allDay,
    recurrence: recurrence,
    reminderOffsets: _encodeIntList(reminderOffsets),
    tags: _encodeList(tags),
    checklist: _encodeChecklist(checklist),
    assignee: assignee,
    completedAt: completedAt,
    pinned: pinned,
    orderIndex: sortOrder,
    vtodoEtag: etag,
    version: version,
    deleted: deleted,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: updatedAt,
    localDirty: dirty,
  );
}

extension TaskRowModel on TaskRow {
  TaskItem toModel() => TaskItem(
    id: syncId,
    listId: listId,
    parentId: parentId,
    sectionId: sectionId,
    title: title,
    notes: notes,
    notesFormat: notesFormat,
    kind: taskKindFromWire(kind),
    priority: priority,
    startAt: startAt,
    dueAt: dueAt,
    allDay: allDay,
    recurrence: recurrence,
    reminderOffsets: _decodeIntList(reminderOffsets),
    tags: _decodeStringList(tags),
    checklist: _decodeChecklist(checklist),
    assignee: assignee,
    completedAt: completedAt,
    pinned: pinned,
    sortOrder: orderIndex,
    deleted: deleted,
    deletedAt: deletedAt,
    etag: vtodoEtag,
    version: version,
    createdAt: createdAt,
    updatedAt: modifiedAt,
  );

  bool get dirty => localDirty;
}

extension TaskListDbRow on TaskListItem {
  TaskListRow toRow() => TaskListRow(
    syncId: id,
    folderId: folderId,
    name: name,
    color: color,
    kind: taskKindToWire(kind),
    orderIndex: sortOrder,
    pinned: pinned,
    isInbox: isInbox,
    etag: etag,
    version: version,
    modifiedAt: updatedAt,
  );
}

extension TaskListRowModel on TaskListRow {
  TaskListItem toModel() => TaskListItem(
    id: syncId,
    folderId: folderId,
    name: name,
    color: color,
    kind: taskKindFromWire(kind),
    sortOrder: orderIndex,
    pinned: pinned,
    isInbox: isInbox,
    etag: etag,
    version: version,
    updatedAt: modifiedAt,
  );
}

extension TaskSectionDbRow on TaskSection {
  TaskSectionRow toRow() => TaskSectionRow(
    syncId: id,
    listId: listId,
    name: name,
    orderIndex: sortOrder,
    etag: etag,
    version: version,
    modifiedAt: updatedAt,
  );
}

extension TaskSectionRowModel on TaskSectionRow {
  TaskSection toModel() => TaskSection(
    id: syncId,
    listId: listId,
    name: name,
    sortOrder: orderIndex,
    etag: etag,
    version: version,
    updatedAt: modifiedAt,
  );
}

extension FolderDbRow on FolderItem {
  FolderRow toRow() => FolderRow(
    syncId: id,
    name: name,
    orderIndex: sortOrder,
    etag: etag,
    version: version,
    modifiedAt: updatedAt,
  );
}

extension FolderRowModel on FolderRow {
  FolderItem toModel() => FolderItem(
    id: syncId,
    name: name,
    sortOrder: orderIndex,
    etag: etag,
    version: version,
    updatedAt: modifiedAt,
  );
}

/// JSON payload helpers shared by the write queues and the outbox journal.
String encodeJsonObject(Map<String, dynamic>? payload) =>
    payload == null ? '' : jsonEncode(payload);

Map<String, dynamic>? decodeJsonObject(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final decoded = _tryDecode(raw);
  return decoded is Map<String, dynamic> ? decoded : null;
}
