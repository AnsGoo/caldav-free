// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesFormatMeta = const VerificationMeta(
    'notesFormat',
  );
  @override
  late final GeneratedColumn<String> notesFormat = GeneratedColumn<String>(
    'notes_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('TASK'),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _recurrenceMeta = const VerificationMeta(
    'recurrence',
  );
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
    'recurrence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _reminderOffsetsMeta = const VerificationMeta(
    'reminderOffsets',
  );
  @override
  late final GeneratedColumn<String> reminderOffsets = GeneratedColumn<String>(
    'reminder_offsets',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _checklistMeta = const VerificationMeta(
    'checklist',
  );
  @override
  late final GeneratedColumn<String> checklist = GeneratedColumn<String>(
    'checklist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _assigneeMeta = const VerificationMeta(
    'assignee',
  );
  @override
  late final GeneratedColumn<String> assignee = GeneratedColumn<String>(
    'assignee',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _vtodoEtagMeta = const VerificationMeta(
    'vtodoEtag',
  );
  @override
  late final GeneratedColumn<String> vtodoEtag = GeneratedColumn<String>(
    'vtodo_etag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDirtyMeta = const VerificationMeta(
    'localDirty',
  );
  @override
  late final GeneratedColumn<bool> localDirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    syncId,
    listId,
    parentId,
    sectionId,
    title,
    notes,
    notesFormat,
    kind,
    priority,
    startAt,
    dueAt,
    allDay,
    recurrence,
    reminderOffsets,
    tags,
    checklist,
    assignee,
    completedAt,
    pinned,
    orderIndex,
    vtodoEtag,
    version,
    deleted,
    deletedAt,
    createdAt,
    modifiedAt,
    localDirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('notes_format')) {
      context.handle(
        _notesFormatMeta,
        notesFormat.isAcceptableOrUnknown(
          data['notes_format']!,
          _notesFormatMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('recurrence')) {
      context.handle(
        _recurrenceMeta,
        recurrence.isAcceptableOrUnknown(data['recurrence']!, _recurrenceMeta),
      );
    }
    if (data.containsKey('reminder_offsets')) {
      context.handle(
        _reminderOffsetsMeta,
        reminderOffsets.isAcceptableOrUnknown(
          data['reminder_offsets']!,
          _reminderOffsetsMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('checklist')) {
      context.handle(
        _checklistMeta,
        checklist.isAcceptableOrUnknown(data['checklist']!, _checklistMeta),
      );
    }
    if (data.containsKey('assignee')) {
      context.handle(
        _assigneeMeta,
        assignee.isAcceptableOrUnknown(data['assignee']!, _assigneeMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('vtodo_etag')) {
      context.handle(
        _vtodoEtagMeta,
        vtodoEtag.isAcceptableOrUnknown(data['vtodo_etag']!, _vtodoEtagMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _localDirtyMeta,
        localDirty.isAcceptableOrUnknown(data['dirty']!, _localDirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncId};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      notesFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes_format'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      ),
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      recurrence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence'],
      )!,
      reminderOffsets: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_offsets'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      checklist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checklist'],
      )!,
      assignee: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assignee'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      vtodoEtag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vtodo_etag'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      )!,
      localDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final String syncId;
  final String listId;
  final String? parentId;
  final String? sectionId;
  final String title;
  final String notes;
  final String notesFormat;
  final String kind;
  final int priority;
  final DateTime? startAt;
  final DateTime? dueAt;
  final bool allDay;
  final String recurrence;
  final String reminderOffsets;
  final String tags;
  final String checklist;
  final String assignee;
  final DateTime? completedAt;
  final bool pinned;
  final int orderIndex;
  final String vtodoEtag;
  final int version;
  final bool deleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime modifiedAt;

  /// Local-only flag: the row still has a queued push operation.
  final bool localDirty;
  const TaskRow({
    required this.syncId,
    required this.listId,
    this.parentId,
    this.sectionId,
    required this.title,
    required this.notes,
    required this.notesFormat,
    required this.kind,
    required this.priority,
    this.startAt,
    this.dueAt,
    required this.allDay,
    required this.recurrence,
    required this.reminderOffsets,
    required this.tags,
    required this.checklist,
    required this.assignee,
    this.completedAt,
    required this.pinned,
    required this.orderIndex,
    required this.vtodoEtag,
    required this.version,
    required this.deleted,
    this.deletedAt,
    this.createdAt,
    required this.modifiedAt,
    required this.localDirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_id'] = Variable<String>(syncId);
    map['list_id'] = Variable<String>(listId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    map['title'] = Variable<String>(title);
    map['notes'] = Variable<String>(notes);
    map['notes_format'] = Variable<String>(notesFormat);
    map['kind'] = Variable<String>(kind);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || startAt != null) {
      map['start_at'] = Variable<DateTime>(startAt);
    }
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['all_day'] = Variable<bool>(allDay);
    map['recurrence'] = Variable<String>(recurrence);
    map['reminder_offsets'] = Variable<String>(reminderOffsets);
    map['tags'] = Variable<String>(tags);
    map['checklist'] = Variable<String>(checklist);
    map['assignee'] = Variable<String>(assignee);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['pinned'] = Variable<bool>(pinned);
    map['order_index'] = Variable<int>(orderIndex);
    map['vtodo_etag'] = Variable<String>(vtodoEtag);
    map['version'] = Variable<int>(version);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['modified_at'] = Variable<DateTime>(modifiedAt);
    map['dirty'] = Variable<bool>(localDirty);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      syncId: Value(syncId),
      listId: Value(listId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      sectionId: sectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionId),
      title: Value(title),
      notes: Value(notes),
      notesFormat: Value(notesFormat),
      kind: Value(kind),
      priority: Value(priority),
      startAt: startAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startAt),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      allDay: Value(allDay),
      recurrence: Value(recurrence),
      reminderOffsets: Value(reminderOffsets),
      tags: Value(tags),
      checklist: Value(checklist),
      assignee: Value(assignee),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      pinned: Value(pinned),
      orderIndex: Value(orderIndex),
      vtodoEtag: Value(vtodoEtag),
      version: Value(version),
      deleted: Value(deleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      modifiedAt: Value(modifiedAt),
      localDirty: Value(localDirty),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      syncId: serializer.fromJson<String>(json['syncId']),
      listId: serializer.fromJson<String>(json['listId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String>(json['notes']),
      notesFormat: serializer.fromJson<String>(json['notesFormat']),
      kind: serializer.fromJson<String>(json['kind']),
      priority: serializer.fromJson<int>(json['priority']),
      startAt: serializer.fromJson<DateTime?>(json['startAt']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      recurrence: serializer.fromJson<String>(json['recurrence']),
      reminderOffsets: serializer.fromJson<String>(json['reminderOffsets']),
      tags: serializer.fromJson<String>(json['tags']),
      checklist: serializer.fromJson<String>(json['checklist']),
      assignee: serializer.fromJson<String>(json['assignee']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      vtodoEtag: serializer.fromJson<String>(json['vtodoEtag']),
      version: serializer.fromJson<int>(json['version']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      modifiedAt: serializer.fromJson<DateTime>(json['modifiedAt']),
      localDirty: serializer.fromJson<bool>(json['localDirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncId': serializer.toJson<String>(syncId),
      'listId': serializer.toJson<String>(listId),
      'parentId': serializer.toJson<String?>(parentId),
      'sectionId': serializer.toJson<String?>(sectionId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String>(notes),
      'notesFormat': serializer.toJson<String>(notesFormat),
      'kind': serializer.toJson<String>(kind),
      'priority': serializer.toJson<int>(priority),
      'startAt': serializer.toJson<DateTime?>(startAt),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'allDay': serializer.toJson<bool>(allDay),
      'recurrence': serializer.toJson<String>(recurrence),
      'reminderOffsets': serializer.toJson<String>(reminderOffsets),
      'tags': serializer.toJson<String>(tags),
      'checklist': serializer.toJson<String>(checklist),
      'assignee': serializer.toJson<String>(assignee),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'pinned': serializer.toJson<bool>(pinned),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'vtodoEtag': serializer.toJson<String>(vtodoEtag),
      'version': serializer.toJson<int>(version),
      'deleted': serializer.toJson<bool>(deleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'modifiedAt': serializer.toJson<DateTime>(modifiedAt),
      'localDirty': serializer.toJson<bool>(localDirty),
    };
  }

  TaskRow copyWith({
    String? syncId,
    String? listId,
    Value<String?> parentId = const Value.absent(),
    Value<String?> sectionId = const Value.absent(),
    String? title,
    String? notes,
    String? notesFormat,
    String? kind,
    int? priority,
    Value<DateTime?> startAt = const Value.absent(),
    Value<DateTime?> dueAt = const Value.absent(),
    bool? allDay,
    String? recurrence,
    String? reminderOffsets,
    String? tags,
    String? checklist,
    String? assignee,
    Value<DateTime?> completedAt = const Value.absent(),
    bool? pinned,
    int? orderIndex,
    String? vtodoEtag,
    int? version,
    bool? deleted,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? modifiedAt,
    bool? localDirty,
  }) => TaskRow(
    syncId: syncId ?? this.syncId,
    listId: listId ?? this.listId,
    parentId: parentId.present ? parentId.value : this.parentId,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    notesFormat: notesFormat ?? this.notesFormat,
    kind: kind ?? this.kind,
    priority: priority ?? this.priority,
    startAt: startAt.present ? startAt.value : this.startAt,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    allDay: allDay ?? this.allDay,
    recurrence: recurrence ?? this.recurrence,
    reminderOffsets: reminderOffsets ?? this.reminderOffsets,
    tags: tags ?? this.tags,
    checklist: checklist ?? this.checklist,
    assignee: assignee ?? this.assignee,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    pinned: pinned ?? this.pinned,
    orderIndex: orderIndex ?? this.orderIndex,
    vtodoEtag: vtodoEtag ?? this.vtodoEtag,
    version: version ?? this.version,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    localDirty: localDirty ?? this.localDirty,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      listId: data.listId.present ? data.listId.value : this.listId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      notesFormat: data.notesFormat.present
          ? data.notesFormat.value
          : this.notesFormat,
      kind: data.kind.present ? data.kind.value : this.kind,
      priority: data.priority.present ? data.priority.value : this.priority,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      reminderOffsets: data.reminderOffsets.present
          ? data.reminderOffsets.value
          : this.reminderOffsets,
      tags: data.tags.present ? data.tags.value : this.tags,
      checklist: data.checklist.present ? data.checklist.value : this.checklist,
      assignee: data.assignee.present ? data.assignee.value : this.assignee,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      vtodoEtag: data.vtodoEtag.present ? data.vtodoEtag.value : this.vtodoEtag,
      version: data.version.present ? data.version.value : this.version,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      localDirty: data.localDirty.present
          ? data.localDirty.value
          : this.localDirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('syncId: $syncId, ')
          ..write('listId: $listId, ')
          ..write('parentId: $parentId, ')
          ..write('sectionId: $sectionId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('notesFormat: $notesFormat, ')
          ..write('kind: $kind, ')
          ..write('priority: $priority, ')
          ..write('startAt: $startAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('allDay: $allDay, ')
          ..write('recurrence: $recurrence, ')
          ..write('reminderOffsets: $reminderOffsets, ')
          ..write('tags: $tags, ')
          ..write('checklist: $checklist, ')
          ..write('assignee: $assignee, ')
          ..write('completedAt: $completedAt, ')
          ..write('pinned: $pinned, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('vtodoEtag: $vtodoEtag, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('localDirty: $localDirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    syncId,
    listId,
    parentId,
    sectionId,
    title,
    notes,
    notesFormat,
    kind,
    priority,
    startAt,
    dueAt,
    allDay,
    recurrence,
    reminderOffsets,
    tags,
    checklist,
    assignee,
    completedAt,
    pinned,
    orderIndex,
    vtodoEtag,
    version,
    deleted,
    deletedAt,
    createdAt,
    modifiedAt,
    localDirty,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.syncId == this.syncId &&
          other.listId == this.listId &&
          other.parentId == this.parentId &&
          other.sectionId == this.sectionId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.notesFormat == this.notesFormat &&
          other.kind == this.kind &&
          other.priority == this.priority &&
          other.startAt == this.startAt &&
          other.dueAt == this.dueAt &&
          other.allDay == this.allDay &&
          other.recurrence == this.recurrence &&
          other.reminderOffsets == this.reminderOffsets &&
          other.tags == this.tags &&
          other.checklist == this.checklist &&
          other.assignee == this.assignee &&
          other.completedAt == this.completedAt &&
          other.pinned == this.pinned &&
          other.orderIndex == this.orderIndex &&
          other.vtodoEtag == this.vtodoEtag &&
          other.version == this.version &&
          other.deleted == this.deleted &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.modifiedAt == this.modifiedAt &&
          other.localDirty == this.localDirty);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<String> syncId;
  final Value<String> listId;
  final Value<String?> parentId;
  final Value<String?> sectionId;
  final Value<String> title;
  final Value<String> notes;
  final Value<String> notesFormat;
  final Value<String> kind;
  final Value<int> priority;
  final Value<DateTime?> startAt;
  final Value<DateTime?> dueAt;
  final Value<bool> allDay;
  final Value<String> recurrence;
  final Value<String> reminderOffsets;
  final Value<String> tags;
  final Value<String> checklist;
  final Value<String> assignee;
  final Value<DateTime?> completedAt;
  final Value<bool> pinned;
  final Value<int> orderIndex;
  final Value<String> vtodoEtag;
  final Value<int> version;
  final Value<bool> deleted;
  final Value<DateTime?> deletedAt;
  final Value<DateTime?> createdAt;
  final Value<DateTime> modifiedAt;
  final Value<bool> localDirty;
  final Value<int> rowid;
  const TasksCompanion({
    this.syncId = const Value.absent(),
    this.listId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.notesFormat = const Value.absent(),
    this.kind = const Value.absent(),
    this.priority = const Value.absent(),
    this.startAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.reminderOffsets = const Value.absent(),
    this.tags = const Value.absent(),
    this.checklist = const Value.absent(),
    this.assignee = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.pinned = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.vtodoEtag = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.localDirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String syncId,
    this.listId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.notesFormat = const Value.absent(),
    this.kind = const Value.absent(),
    this.priority = const Value.absent(),
    this.startAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.reminderOffsets = const Value.absent(),
    this.tags = const Value.absent(),
    this.checklist = const Value.absent(),
    this.assignee = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.pinned = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.vtodoEtag = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime modifiedAt,
    this.localDirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : syncId = Value(syncId),
       modifiedAt = Value(modifiedAt);
  static Insertable<TaskRow> custom({
    Expression<String>? syncId,
    Expression<String>? listId,
    Expression<String>? parentId,
    Expression<String>? sectionId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<String>? notesFormat,
    Expression<String>? kind,
    Expression<int>? priority,
    Expression<DateTime>? startAt,
    Expression<DateTime>? dueAt,
    Expression<bool>? allDay,
    Expression<String>? recurrence,
    Expression<String>? reminderOffsets,
    Expression<String>? tags,
    Expression<String>? checklist,
    Expression<String>? assignee,
    Expression<DateTime>? completedAt,
    Expression<bool>? pinned,
    Expression<int>? orderIndex,
    Expression<String>? vtodoEtag,
    Expression<int>? version,
    Expression<bool>? deleted,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? modifiedAt,
    Expression<bool>? localDirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncId != null) 'sync_id': syncId,
      if (listId != null) 'list_id': listId,
      if (parentId != null) 'parent_id': parentId,
      if (sectionId != null) 'section_id': sectionId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (notesFormat != null) 'notes_format': notesFormat,
      if (kind != null) 'kind': kind,
      if (priority != null) 'priority': priority,
      if (startAt != null) 'start_at': startAt,
      if (dueAt != null) 'due_at': dueAt,
      if (allDay != null) 'all_day': allDay,
      if (recurrence != null) 'recurrence': recurrence,
      if (reminderOffsets != null) 'reminder_offsets': reminderOffsets,
      if (tags != null) 'tags': tags,
      if (checklist != null) 'checklist': checklist,
      if (assignee != null) 'assignee': assignee,
      if (completedAt != null) 'completed_at': completedAt,
      if (pinned != null) 'pinned': pinned,
      if (orderIndex != null) 'order_index': orderIndex,
      if (vtodoEtag != null) 'vtodo_etag': vtodoEtag,
      if (version != null) 'version': version,
      if (deleted != null) 'deleted': deleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (localDirty != null) 'dirty': localDirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? syncId,
    Value<String>? listId,
    Value<String?>? parentId,
    Value<String?>? sectionId,
    Value<String>? title,
    Value<String>? notes,
    Value<String>? notesFormat,
    Value<String>? kind,
    Value<int>? priority,
    Value<DateTime?>? startAt,
    Value<DateTime?>? dueAt,
    Value<bool>? allDay,
    Value<String>? recurrence,
    Value<String>? reminderOffsets,
    Value<String>? tags,
    Value<String>? checklist,
    Value<String>? assignee,
    Value<DateTime?>? completedAt,
    Value<bool>? pinned,
    Value<int>? orderIndex,
    Value<String>? vtodoEtag,
    Value<int>? version,
    Value<bool>? deleted,
    Value<DateTime?>? deletedAt,
    Value<DateTime?>? createdAt,
    Value<DateTime>? modifiedAt,
    Value<bool>? localDirty,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      syncId: syncId ?? this.syncId,
      listId: listId ?? this.listId,
      parentId: parentId ?? this.parentId,
      sectionId: sectionId ?? this.sectionId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      notesFormat: notesFormat ?? this.notesFormat,
      kind: kind ?? this.kind,
      priority: priority ?? this.priority,
      startAt: startAt ?? this.startAt,
      dueAt: dueAt ?? this.dueAt,
      allDay: allDay ?? this.allDay,
      recurrence: recurrence ?? this.recurrence,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      tags: tags ?? this.tags,
      checklist: checklist ?? this.checklist,
      assignee: assignee ?? this.assignee,
      completedAt: completedAt ?? this.completedAt,
      pinned: pinned ?? this.pinned,
      orderIndex: orderIndex ?? this.orderIndex,
      vtodoEtag: vtodoEtag ?? this.vtodoEtag,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      localDirty: localDirty ?? this.localDirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (notesFormat.present) {
      map['notes_format'] = Variable<String>(notesFormat.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (reminderOffsets.present) {
      map['reminder_offsets'] = Variable<String>(reminderOffsets.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (checklist.present) {
      map['checklist'] = Variable<String>(checklist.value);
    }
    if (assignee.present) {
      map['assignee'] = Variable<String>(assignee.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (vtodoEtag.present) {
      map['vtodo_etag'] = Variable<String>(vtodoEtag.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (localDirty.present) {
      map['dirty'] = Variable<bool>(localDirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('syncId: $syncId, ')
          ..write('listId: $listId, ')
          ..write('parentId: $parentId, ')
          ..write('sectionId: $sectionId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('notesFormat: $notesFormat, ')
          ..write('kind: $kind, ')
          ..write('priority: $priority, ')
          ..write('startAt: $startAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('allDay: $allDay, ')
          ..write('recurrence: $recurrence, ')
          ..write('reminderOffsets: $reminderOffsets, ')
          ..write('tags: $tags, ')
          ..write('checklist: $checklist, ')
          ..write('assignee: $assignee, ')
          ..write('completedAt: $completedAt, ')
          ..write('pinned: $pinned, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('vtodoEtag: $vtodoEtag, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('localDirty: $localDirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskListsTable extends TaskLists
    with TableInfo<$TaskListsTable, TaskListRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('TASK'),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isInboxMeta = const VerificationMeta(
    'isInbox',
  );
  @override
  late final GeneratedColumn<bool> isInbox = GeneratedColumn<bool>(
    'is_inbox',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_inbox" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    syncId,
    folderId,
    name,
    color,
    kind,
    orderIndex,
    pinned,
    isInbox,
    etag,
    version,
    modifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskListRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('is_inbox')) {
      context.handle(
        _isInboxMeta,
        isInbox.isAcceptableOrUnknown(data['is_inbox']!, _isInboxMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncId};
  @override
  TaskListRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskListRow(
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      isInbox: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_inbox'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      )!,
    );
  }

  @override
  $TaskListsTable createAlias(String alias) {
    return $TaskListsTable(attachedDatabase, alias);
  }
}

class TaskListRow extends DataClass implements Insertable<TaskListRow> {
  final String syncId;
  final String? folderId;
  final String name;
  final String color;
  final String kind;
  final int orderIndex;
  final bool pinned;
  final bool isInbox;
  final String etag;
  final int version;
  final DateTime modifiedAt;
  const TaskListRow({
    required this.syncId,
    this.folderId,
    required this.name,
    required this.color,
    required this.kind,
    required this.orderIndex,
    required this.pinned,
    required this.isInbox,
    required this.etag,
    required this.version,
    required this.modifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_id'] = Variable<String>(syncId);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['kind'] = Variable<String>(kind);
    map['order_index'] = Variable<int>(orderIndex);
    map['pinned'] = Variable<bool>(pinned);
    map['is_inbox'] = Variable<bool>(isInbox);
    map['etag'] = Variable<String>(etag);
    map['version'] = Variable<int>(version);
    map['modified_at'] = Variable<DateTime>(modifiedAt);
    return map;
  }

  TaskListsCompanion toCompanion(bool nullToAbsent) {
    return TaskListsCompanion(
      syncId: Value(syncId),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      name: Value(name),
      color: Value(color),
      kind: Value(kind),
      orderIndex: Value(orderIndex),
      pinned: Value(pinned),
      isInbox: Value(isInbox),
      etag: Value(etag),
      version: Value(version),
      modifiedAt: Value(modifiedAt),
    );
  }

  factory TaskListRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskListRow(
      syncId: serializer.fromJson<String>(json['syncId']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      kind: serializer.fromJson<String>(json['kind']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      isInbox: serializer.fromJson<bool>(json['isInbox']),
      etag: serializer.fromJson<String>(json['etag']),
      version: serializer.fromJson<int>(json['version']),
      modifiedAt: serializer.fromJson<DateTime>(json['modifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncId': serializer.toJson<String>(syncId),
      'folderId': serializer.toJson<String?>(folderId),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'kind': serializer.toJson<String>(kind),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'pinned': serializer.toJson<bool>(pinned),
      'isInbox': serializer.toJson<bool>(isInbox),
      'etag': serializer.toJson<String>(etag),
      'version': serializer.toJson<int>(version),
      'modifiedAt': serializer.toJson<DateTime>(modifiedAt),
    };
  }

  TaskListRow copyWith({
    String? syncId,
    Value<String?> folderId = const Value.absent(),
    String? name,
    String? color,
    String? kind,
    int? orderIndex,
    bool? pinned,
    bool? isInbox,
    String? etag,
    int? version,
    DateTime? modifiedAt,
  }) => TaskListRow(
    syncId: syncId ?? this.syncId,
    folderId: folderId.present ? folderId.value : this.folderId,
    name: name ?? this.name,
    color: color ?? this.color,
    kind: kind ?? this.kind,
    orderIndex: orderIndex ?? this.orderIndex,
    pinned: pinned ?? this.pinned,
    isInbox: isInbox ?? this.isInbox,
    etag: etag ?? this.etag,
    version: version ?? this.version,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );
  TaskListRow copyWithCompanion(TaskListsCompanion data) {
    return TaskListRow(
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      kind: data.kind.present ? data.kind.value : this.kind,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      isInbox: data.isInbox.present ? data.isInbox.value : this.isInbox,
      etag: data.etag.present ? data.etag.value : this.etag,
      version: data.version.present ? data.version.value : this.version,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskListRow(')
          ..write('syncId: $syncId, ')
          ..write('folderId: $folderId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('kind: $kind, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('pinned: $pinned, ')
          ..write('isInbox: $isInbox, ')
          ..write('etag: $etag, ')
          ..write('version: $version, ')
          ..write('modifiedAt: $modifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    syncId,
    folderId,
    name,
    color,
    kind,
    orderIndex,
    pinned,
    isInbox,
    etag,
    version,
    modifiedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskListRow &&
          other.syncId == this.syncId &&
          other.folderId == this.folderId &&
          other.name == this.name &&
          other.color == this.color &&
          other.kind == this.kind &&
          other.orderIndex == this.orderIndex &&
          other.pinned == this.pinned &&
          other.isInbox == this.isInbox &&
          other.etag == this.etag &&
          other.version == this.version &&
          other.modifiedAt == this.modifiedAt);
}

class TaskListsCompanion extends UpdateCompanion<TaskListRow> {
  final Value<String> syncId;
  final Value<String?> folderId;
  final Value<String> name;
  final Value<String> color;
  final Value<String> kind;
  final Value<int> orderIndex;
  final Value<bool> pinned;
  final Value<bool> isInbox;
  final Value<String> etag;
  final Value<int> version;
  final Value<DateTime> modifiedAt;
  final Value<int> rowid;
  const TaskListsCompanion({
    this.syncId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.kind = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.pinned = const Value.absent(),
    this.isInbox = const Value.absent(),
    this.etag = const Value.absent(),
    this.version = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskListsCompanion.insert({
    required String syncId,
    this.folderId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.kind = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.pinned = const Value.absent(),
    this.isInbox = const Value.absent(),
    this.etag = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime modifiedAt,
    this.rowid = const Value.absent(),
  }) : syncId = Value(syncId),
       modifiedAt = Value(modifiedAt);
  static Insertable<TaskListRow> custom({
    Expression<String>? syncId,
    Expression<String>? folderId,
    Expression<String>? name,
    Expression<String>? color,
    Expression<String>? kind,
    Expression<int>? orderIndex,
    Expression<bool>? pinned,
    Expression<bool>? isInbox,
    Expression<String>? etag,
    Expression<int>? version,
    Expression<DateTime>? modifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncId != null) 'sync_id': syncId,
      if (folderId != null) 'folder_id': folderId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (kind != null) 'kind': kind,
      if (orderIndex != null) 'order_index': orderIndex,
      if (pinned != null) 'pinned': pinned,
      if (isInbox != null) 'is_inbox': isInbox,
      if (etag != null) 'etag': etag,
      if (version != null) 'version': version,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskListsCompanion copyWith({
    Value<String>? syncId,
    Value<String?>? folderId,
    Value<String>? name,
    Value<String>? color,
    Value<String>? kind,
    Value<int>? orderIndex,
    Value<bool>? pinned,
    Value<bool>? isInbox,
    Value<String>? etag,
    Value<int>? version,
    Value<DateTime>? modifiedAt,
    Value<int>? rowid,
  }) {
    return TaskListsCompanion(
      syncId: syncId ?? this.syncId,
      folderId: folderId ?? this.folderId,
      name: name ?? this.name,
      color: color ?? this.color,
      kind: kind ?? this.kind,
      orderIndex: orderIndex ?? this.orderIndex,
      pinned: pinned ?? this.pinned,
      isInbox: isInbox ?? this.isInbox,
      etag: etag ?? this.etag,
      version: version ?? this.version,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (isInbox.present) {
      map['is_inbox'] = Variable<bool>(isInbox.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskListsCompanion(')
          ..write('syncId: $syncId, ')
          ..write('folderId: $folderId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('kind: $kind, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('pinned: $pinned, ')
          ..write('isInbox: $isInbox, ')
          ..write('etag: $etag, ')
          ..write('version: $version, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskSectionsTable extends TaskSections
    with TableInfo<$TaskSectionsTable, TaskSectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskSectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    syncId,
    listId,
    name,
    orderIndex,
    etag,
    version,
    modifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_sections';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskSectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncId};
  @override
  TaskSectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskSectionRow(
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      )!,
    );
  }

  @override
  $TaskSectionsTable createAlias(String alias) {
    return $TaskSectionsTable(attachedDatabase, alias);
  }
}

class TaskSectionRow extends DataClass implements Insertable<TaskSectionRow> {
  final String syncId;
  final String listId;
  final String name;
  final int orderIndex;
  final String etag;
  final int version;
  final DateTime modifiedAt;
  const TaskSectionRow({
    required this.syncId,
    required this.listId,
    required this.name,
    required this.orderIndex,
    required this.etag,
    required this.version,
    required this.modifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_id'] = Variable<String>(syncId);
    map['list_id'] = Variable<String>(listId);
    map['name'] = Variable<String>(name);
    map['order_index'] = Variable<int>(orderIndex);
    map['etag'] = Variable<String>(etag);
    map['version'] = Variable<int>(version);
    map['modified_at'] = Variable<DateTime>(modifiedAt);
    return map;
  }

  TaskSectionsCompanion toCompanion(bool nullToAbsent) {
    return TaskSectionsCompanion(
      syncId: Value(syncId),
      listId: Value(listId),
      name: Value(name),
      orderIndex: Value(orderIndex),
      etag: Value(etag),
      version: Value(version),
      modifiedAt: Value(modifiedAt),
    );
  }

  factory TaskSectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskSectionRow(
      syncId: serializer.fromJson<String>(json['syncId']),
      listId: serializer.fromJson<String>(json['listId']),
      name: serializer.fromJson<String>(json['name']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      etag: serializer.fromJson<String>(json['etag']),
      version: serializer.fromJson<int>(json['version']),
      modifiedAt: serializer.fromJson<DateTime>(json['modifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncId': serializer.toJson<String>(syncId),
      'listId': serializer.toJson<String>(listId),
      'name': serializer.toJson<String>(name),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'etag': serializer.toJson<String>(etag),
      'version': serializer.toJson<int>(version),
      'modifiedAt': serializer.toJson<DateTime>(modifiedAt),
    };
  }

  TaskSectionRow copyWith({
    String? syncId,
    String? listId,
    String? name,
    int? orderIndex,
    String? etag,
    int? version,
    DateTime? modifiedAt,
  }) => TaskSectionRow(
    syncId: syncId ?? this.syncId,
    listId: listId ?? this.listId,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    etag: etag ?? this.etag,
    version: version ?? this.version,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );
  TaskSectionRow copyWithCompanion(TaskSectionsCompanion data) {
    return TaskSectionRow(
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      listId: data.listId.present ? data.listId.value : this.listId,
      name: data.name.present ? data.name.value : this.name,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      etag: data.etag.present ? data.etag.value : this.etag,
      version: data.version.present ? data.version.value : this.version,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskSectionRow(')
          ..write('syncId: $syncId, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('etag: $etag, ')
          ..write('version: $version, ')
          ..write('modifiedAt: $modifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(syncId, listId, name, orderIndex, etag, version, modifiedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskSectionRow &&
          other.syncId == this.syncId &&
          other.listId == this.listId &&
          other.name == this.name &&
          other.orderIndex == this.orderIndex &&
          other.etag == this.etag &&
          other.version == this.version &&
          other.modifiedAt == this.modifiedAt);
}

class TaskSectionsCompanion extends UpdateCompanion<TaskSectionRow> {
  final Value<String> syncId;
  final Value<String> listId;
  final Value<String> name;
  final Value<int> orderIndex;
  final Value<String> etag;
  final Value<int> version;
  final Value<DateTime> modifiedAt;
  final Value<int> rowid;
  const TaskSectionsCompanion({
    this.syncId = const Value.absent(),
    this.listId = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.etag = const Value.absent(),
    this.version = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskSectionsCompanion.insert({
    required String syncId,
    this.listId = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.etag = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime modifiedAt,
    this.rowid = const Value.absent(),
  }) : syncId = Value(syncId),
       modifiedAt = Value(modifiedAt);
  static Insertable<TaskSectionRow> custom({
    Expression<String>? syncId,
    Expression<String>? listId,
    Expression<String>? name,
    Expression<int>? orderIndex,
    Expression<String>? etag,
    Expression<int>? version,
    Expression<DateTime>? modifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncId != null) 'sync_id': syncId,
      if (listId != null) 'list_id': listId,
      if (name != null) 'name': name,
      if (orderIndex != null) 'order_index': orderIndex,
      if (etag != null) 'etag': etag,
      if (version != null) 'version': version,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskSectionsCompanion copyWith({
    Value<String>? syncId,
    Value<String>? listId,
    Value<String>? name,
    Value<int>? orderIndex,
    Value<String>? etag,
    Value<int>? version,
    Value<DateTime>? modifiedAt,
    Value<int>? rowid,
  }) {
    return TaskSectionsCompanion(
      syncId: syncId ?? this.syncId,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      etag: etag ?? this.etag,
      version: version ?? this.version,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskSectionsCompanion(')
          ..write('syncId: $syncId, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('etag: $etag, ')
          ..write('version: $version, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, FolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    syncId,
    name,
    orderIndex,
    etag,
    version,
    modifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncId};
  @override
  FolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderRow(
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      )!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class FolderRow extends DataClass implements Insertable<FolderRow> {
  final String syncId;
  final String name;
  final int orderIndex;
  final String etag;
  final int version;
  final DateTime modifiedAt;
  const FolderRow({
    required this.syncId,
    required this.name,
    required this.orderIndex,
    required this.etag,
    required this.version,
    required this.modifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_id'] = Variable<String>(syncId);
    map['name'] = Variable<String>(name);
    map['order_index'] = Variable<int>(orderIndex);
    map['etag'] = Variable<String>(etag);
    map['version'] = Variable<int>(version);
    map['modified_at'] = Variable<DateTime>(modifiedAt);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      syncId: Value(syncId),
      name: Value(name),
      orderIndex: Value(orderIndex),
      etag: Value(etag),
      version: Value(version),
      modifiedAt: Value(modifiedAt),
    );
  }

  factory FolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderRow(
      syncId: serializer.fromJson<String>(json['syncId']),
      name: serializer.fromJson<String>(json['name']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      etag: serializer.fromJson<String>(json['etag']),
      version: serializer.fromJson<int>(json['version']),
      modifiedAt: serializer.fromJson<DateTime>(json['modifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncId': serializer.toJson<String>(syncId),
      'name': serializer.toJson<String>(name),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'etag': serializer.toJson<String>(etag),
      'version': serializer.toJson<int>(version),
      'modifiedAt': serializer.toJson<DateTime>(modifiedAt),
    };
  }

  FolderRow copyWith({
    String? syncId,
    String? name,
    int? orderIndex,
    String? etag,
    int? version,
    DateTime? modifiedAt,
  }) => FolderRow(
    syncId: syncId ?? this.syncId,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    etag: etag ?? this.etag,
    version: version ?? this.version,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );
  FolderRow copyWithCompanion(FoldersCompanion data) {
    return FolderRow(
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      name: data.name.present ? data.name.value : this.name,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      etag: data.etag.present ? data.etag.value : this.etag,
      version: data.version.present ? data.version.value : this.version,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderRow(')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('etag: $etag, ')
          ..write('version: $version, ')
          ..write('modifiedAt: $modifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(syncId, name, orderIndex, etag, version, modifiedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderRow &&
          other.syncId == this.syncId &&
          other.name == this.name &&
          other.orderIndex == this.orderIndex &&
          other.etag == this.etag &&
          other.version == this.version &&
          other.modifiedAt == this.modifiedAt);
}

class FoldersCompanion extends UpdateCompanion<FolderRow> {
  final Value<String> syncId;
  final Value<String> name;
  final Value<int> orderIndex;
  final Value<String> etag;
  final Value<int> version;
  final Value<DateTime> modifiedAt;
  final Value<int> rowid;
  const FoldersCompanion({
    this.syncId = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.etag = const Value.absent(),
    this.version = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String syncId,
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.etag = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime modifiedAt,
    this.rowid = const Value.absent(),
  }) : syncId = Value(syncId),
       modifiedAt = Value(modifiedAt);
  static Insertable<FolderRow> custom({
    Expression<String>? syncId,
    Expression<String>? name,
    Expression<int>? orderIndex,
    Expression<String>? etag,
    Expression<int>? version,
    Expression<DateTime>? modifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncId != null) 'sync_id': syncId,
      if (name != null) 'name': name,
      if (orderIndex != null) 'order_index': orderIndex,
      if (etag != null) 'etag': etag,
      if (version != null) 'version': version,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? syncId,
    Value<String>? name,
    Value<int>? orderIndex,
    Value<String>? etag,
    Value<int>? version,
    Value<DateTime>? modifiedAt,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      syncId: syncId ?? this.syncId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      etag: etag ?? this.etag,
      version: version ?? this.version,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('etag: $etag, ')
          ..write('version: $version, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _patchMeta = const VerificationMeta('patch');
  @override
  late final GeneratedColumn<String> patch = GeneratedColumn<String>(
    'patch',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _baseEtagMeta = const VerificationMeta(
    'baseEtag',
  );
  @override
  late final GeneratedColumn<String> baseEtag = GeneratedColumn<String>(
    'base_etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextTryAtMeta = const VerificationMeta(
    'nextTryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextTryAt = GeneratedColumn<DateTime>(
    'next_try_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    opId,
    entity,
    entityId,
    op,
    patch,
    baseEtag,
    attempts,
    nextTryAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    }
    if (data.containsKey('patch')) {
      context.handle(
        _patchMeta,
        patch.isAcceptableOrUnknown(data['patch']!, _patchMeta),
      );
    }
    if (data.containsKey('base_etag')) {
      context.handle(
        _baseEtagMeta,
        baseEtag.isAcceptableOrUnknown(data['base_etag']!, _baseEtagMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_try_at')) {
      context.handle(
        _nextTryAtMeta,
        nextTryAt.isAcceptableOrUnknown(data['next_try_at']!, _nextTryAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {opId};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      patch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patch'],
      )!,
      baseEtag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_etag'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextTryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_try_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final String opId;
  final String entity;
  final String entityId;

  /// `put` or `delete`.
  final String op;
  final String patch;
  final String? baseEtag;
  final int attempts;
  final DateTime nextTryAt;
  final DateTime createdAt;
  const OutboxRow({
    required this.opId,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.patch,
    this.baseEtag,
    required this.attempts,
    required this.nextTryAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['op_id'] = Variable<String>(opId);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['op'] = Variable<String>(op);
    map['patch'] = Variable<String>(patch);
    if (!nullToAbsent || baseEtag != null) {
      map['base_etag'] = Variable<String>(baseEtag);
    }
    map['attempts'] = Variable<int>(attempts);
    map['next_try_at'] = Variable<DateTime>(nextTryAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      opId: Value(opId),
      entity: Value(entity),
      entityId: Value(entityId),
      op: Value(op),
      patch: Value(patch),
      baseEtag: baseEtag == null && nullToAbsent
          ? const Value.absent()
          : Value(baseEtag),
      attempts: Value(attempts),
      nextTryAt: Value(nextTryAt),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      opId: serializer.fromJson<String>(json['opId']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      op: serializer.fromJson<String>(json['op']),
      patch: serializer.fromJson<String>(json['patch']),
      baseEtag: serializer.fromJson<String?>(json['baseEtag']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextTryAt: serializer.fromJson<DateTime>(json['nextTryAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'opId': serializer.toJson<String>(opId),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'op': serializer.toJson<String>(op),
      'patch': serializer.toJson<String>(patch),
      'baseEtag': serializer.toJson<String?>(baseEtag),
      'attempts': serializer.toJson<int>(attempts),
      'nextTryAt': serializer.toJson<DateTime>(nextTryAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxRow copyWith({
    String? opId,
    String? entity,
    String? entityId,
    String? op,
    String? patch,
    Value<String?> baseEtag = const Value.absent(),
    int? attempts,
    DateTime? nextTryAt,
    DateTime? createdAt,
  }) => OutboxRow(
    opId: opId ?? this.opId,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    op: op ?? this.op,
    patch: patch ?? this.patch,
    baseEtag: baseEtag.present ? baseEtag.value : this.baseEtag,
    attempts: attempts ?? this.attempts,
    nextTryAt: nextTryAt ?? this.nextTryAt,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      opId: data.opId.present ? data.opId.value : this.opId,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      op: data.op.present ? data.op.value : this.op,
      patch: data.patch.present ? data.patch.value : this.patch,
      baseEtag: data.baseEtag.present ? data.baseEtag.value : this.baseEtag,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextTryAt: data.nextTryAt.present ? data.nextTryAt.value : this.nextTryAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('opId: $opId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('patch: $patch, ')
          ..write('baseEtag: $baseEtag, ')
          ..write('attempts: $attempts, ')
          ..write('nextTryAt: $nextTryAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    opId,
    entity,
    entityId,
    op,
    patch,
    baseEtag,
    attempts,
    nextTryAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.opId == this.opId &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.op == this.op &&
          other.patch == this.patch &&
          other.baseEtag == this.baseEtag &&
          other.attempts == this.attempts &&
          other.nextTryAt == this.nextTryAt &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<String> opId;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> op;
  final Value<String> patch;
  final Value<String?> baseEtag;
  final Value<int> attempts;
  final Value<DateTime> nextTryAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.opId = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.op = const Value.absent(),
    this.patch = const Value.absent(),
    this.baseEtag = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextTryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String opId,
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.op = const Value.absent(),
    this.patch = const Value.absent(),
    this.baseEtag = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextTryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : opId = Value(opId);
  static Insertable<OutboxRow> custom({
    Expression<String>? opId,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? op,
    Expression<String>? patch,
    Expression<String>? baseEtag,
    Expression<int>? attempts,
    Expression<DateTime>? nextTryAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (opId != null) 'op_id': opId,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (op != null) 'op': op,
      if (patch != null) 'patch': patch,
      if (baseEtag != null) 'base_etag': baseEtag,
      if (attempts != null) 'attempts': attempts,
      if (nextTryAt != null) 'next_try_at': nextTryAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? opId,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? op,
    Value<String>? patch,
    Value<String?>? baseEtag,
    Value<int>? attempts,
    Value<DateTime>? nextTryAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      opId: opId ?? this.opId,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      op: op ?? this.op,
      patch: patch ?? this.patch,
      baseEtag: baseEtag ?? this.baseEtag,
      attempts: attempts ?? this.attempts,
      nextTryAt: nextTryAt ?? this.nextTryAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (patch.present) {
      map['patch'] = Variable<String>(patch.value);
    }
    if (baseEtag.present) {
      map['base_etag'] = Variable<String>(baseEtag.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextTryAt.present) {
      map['next_try_at'] = Variable<DateTime>(nextTryAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('opId: $opId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('patch: $patch, ')
          ..write('baseEtag: $baseEtag, ')
          ..write('attempts: $attempts, ')
          ..write('nextTryAt: $nextTryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConflictsTable extends Conflicts
    with TableInfo<$ConflictsTable, ConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPatchMeta = const VerificationMeta(
    'localPatch',
  );
  @override
  late final GeneratedColumn<String> localPatch = GeneratedColumn<String>(
    'local_patch',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _remoteMeta = const VerificationMeta('remote');
  @override
  late final GeneratedColumn<String> remote = GeneratedColumn<String>(
    'remote',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entity,
    entityId,
    localPatch,
    remote,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('local_patch')) {
      context.handle(
        _localPatchMeta,
        localPatch.isAcceptableOrUnknown(data['local_patch']!, _localPatchMeta),
      );
    }
    if (data.containsKey('remote')) {
      context.handle(
        _remoteMeta,
        remote.isAcceptableOrUnknown(data['remote']!, _remoteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, entityId};
  @override
  ConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConflictRow(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      localPatch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_patch'],
      )!,
      remote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ConflictsTable createAlias(String alias) {
    return $ConflictsTable(attachedDatabase, alias);
  }
}

class ConflictRow extends DataClass implements Insertable<ConflictRow> {
  final String entity;
  final String entityId;
  final String localPatch;
  final String remote;
  final DateTime createdAt;
  const ConflictRow({
    required this.entity,
    required this.entityId,
    required this.localPatch,
    required this.remote,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['local_patch'] = Variable<String>(localPatch);
    map['remote'] = Variable<String>(remote);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ConflictsCompanion toCompanion(bool nullToAbsent) {
    return ConflictsCompanion(
      entity: Value(entity),
      entityId: Value(entityId),
      localPatch: Value(localPatch),
      remote: Value(remote),
      createdAt: Value(createdAt),
    );
  }

  factory ConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConflictRow(
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      localPatch: serializer.fromJson<String>(json['localPatch']),
      remote: serializer.fromJson<String>(json['remote']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'localPatch': serializer.toJson<String>(localPatch),
      'remote': serializer.toJson<String>(remote),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ConflictRow copyWith({
    String? entity,
    String? entityId,
    String? localPatch,
    String? remote,
    DateTime? createdAt,
  }) => ConflictRow(
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    localPatch: localPatch ?? this.localPatch,
    remote: remote ?? this.remote,
    createdAt: createdAt ?? this.createdAt,
  );
  ConflictRow copyWithCompanion(ConflictsCompanion data) {
    return ConflictRow(
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      localPatch: data.localPatch.present
          ? data.localPatch.value
          : this.localPatch,
      remote: data.remote.present ? data.remote.value : this.remote,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConflictRow(')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('localPatch: $localPatch, ')
          ..write('remote: $remote, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(entity, entityId, localPatch, remote, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConflictRow &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.localPatch == this.localPatch &&
          other.remote == this.remote &&
          other.createdAt == this.createdAt);
}

class ConflictsCompanion extends UpdateCompanion<ConflictRow> {
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> localPatch;
  final Value<String> remote;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ConflictsCompanion({
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.localPatch = const Value.absent(),
    this.remote = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConflictsCompanion.insert({
    required String entity,
    required String entityId,
    this.localPatch = const Value.absent(),
    this.remote = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       entityId = Value(entityId);
  static Insertable<ConflictRow> custom({
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? localPatch,
    Expression<String>? remote,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (localPatch != null) 'local_patch': localPatch,
      if (remote != null) 'remote': remote,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConflictsCompanion copyWith({
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? localPatch,
    Value<String>? remote,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ConflictsCompanion(
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      localPatch: localPatch ?? this.localPatch,
      remote: remote ?? this.remote,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (localPatch.present) {
      map['local_patch'] = Variable<String>(localPatch.value);
    }
    if (remote.present) {
      map['remote'] = Variable<String>(remote.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictsCompanion(')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('localPatch: $localPatch, ')
          ..write('remote: $remote, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitOutboxTable extends HabitOutbox
    with TableInfo<$HabitOutboxTable, HabitOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<int> habitId = GeneratedColumn<int>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stampMeta = const VerificationMeta('stamp');
  @override
  late final GeneratedColumn<int> stamp = GeneratedColumn<int>(
    'stamp',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    opId,
    action,
    habitId,
    payload,
    stamp,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('stamp')) {
      context.handle(
        _stampMeta,
        stamp.isAcceptableOrUnknown(data['stamp']!, _stampMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  HabitOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitOutboxRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}habit_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      stamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stamp'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HabitOutboxTable createAlias(String alias) {
    return $HabitOutboxTable(attachedDatabase, alias);
  }
}

class HabitOutboxRow extends DataClass implements Insertable<HabitOutboxRow> {
  final int seq;
  final String opId;
  final String action;
  final int habitId;
  final String? payload;
  final int? stamp;
  final DateTime createdAt;
  const HabitOutboxRow({
    required this.seq,
    required this.opId,
    required this.action,
    required this.habitId,
    this.payload,
    this.stamp,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['op_id'] = Variable<String>(opId);
    map['action'] = Variable<String>(action);
    map['habit_id'] = Variable<int>(habitId);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    if (!nullToAbsent || stamp != null) {
      map['stamp'] = Variable<int>(stamp);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HabitOutboxCompanion toCompanion(bool nullToAbsent) {
    return HabitOutboxCompanion(
      seq: Value(seq),
      opId: Value(opId),
      action: Value(action),
      habitId: Value(habitId),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      stamp: stamp == null && nullToAbsent
          ? const Value.absent()
          : Value(stamp),
      createdAt: Value(createdAt),
    );
  }

  factory HabitOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitOutboxRow(
      seq: serializer.fromJson<int>(json['seq']),
      opId: serializer.fromJson<String>(json['opId']),
      action: serializer.fromJson<String>(json['action']),
      habitId: serializer.fromJson<int>(json['habitId']),
      payload: serializer.fromJson<String?>(json['payload']),
      stamp: serializer.fromJson<int?>(json['stamp']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'opId': serializer.toJson<String>(opId),
      'action': serializer.toJson<String>(action),
      'habitId': serializer.toJson<int>(habitId),
      'payload': serializer.toJson<String?>(payload),
      'stamp': serializer.toJson<int?>(stamp),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HabitOutboxRow copyWith({
    int? seq,
    String? opId,
    String? action,
    int? habitId,
    Value<String?> payload = const Value.absent(),
    Value<int?> stamp = const Value.absent(),
    DateTime? createdAt,
  }) => HabitOutboxRow(
    seq: seq ?? this.seq,
    opId: opId ?? this.opId,
    action: action ?? this.action,
    habitId: habitId ?? this.habitId,
    payload: payload.present ? payload.value : this.payload,
    stamp: stamp.present ? stamp.value : this.stamp,
    createdAt: createdAt ?? this.createdAt,
  );
  HabitOutboxRow copyWithCompanion(HabitOutboxCompanion data) {
    return HabitOutboxRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      opId: data.opId.present ? data.opId.value : this.opId,
      action: data.action.present ? data.action.value : this.action,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      payload: data.payload.present ? data.payload.value : this.payload,
      stamp: data.stamp.present ? data.stamp.value : this.stamp,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitOutboxRow(')
          ..write('seq: $seq, ')
          ..write('opId: $opId, ')
          ..write('action: $action, ')
          ..write('habitId: $habitId, ')
          ..write('payload: $payload, ')
          ..write('stamp: $stamp, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(seq, opId, action, habitId, payload, stamp, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitOutboxRow &&
          other.seq == this.seq &&
          other.opId == this.opId &&
          other.action == this.action &&
          other.habitId == this.habitId &&
          other.payload == this.payload &&
          other.stamp == this.stamp &&
          other.createdAt == this.createdAt);
}

class HabitOutboxCompanion extends UpdateCompanion<HabitOutboxRow> {
  final Value<int> seq;
  final Value<String> opId;
  final Value<String> action;
  final Value<int> habitId;
  final Value<String?> payload;
  final Value<int?> stamp;
  final Value<DateTime> createdAt;
  const HabitOutboxCompanion({
    this.seq = const Value.absent(),
    this.opId = const Value.absent(),
    this.action = const Value.absent(),
    this.habitId = const Value.absent(),
    this.payload = const Value.absent(),
    this.stamp = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  HabitOutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String opId,
    this.action = const Value.absent(),
    required int habitId,
    this.payload = const Value.absent(),
    this.stamp = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : opId = Value(opId),
       habitId = Value(habitId);
  static Insertable<HabitOutboxRow> custom({
    Expression<int>? seq,
    Expression<String>? opId,
    Expression<String>? action,
    Expression<int>? habitId,
    Expression<String>? payload,
    Expression<int>? stamp,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (opId != null) 'op_id': opId,
      if (action != null) 'action': action,
      if (habitId != null) 'habit_id': habitId,
      if (payload != null) 'payload': payload,
      if (stamp != null) 'stamp': stamp,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  HabitOutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? opId,
    Value<String>? action,
    Value<int>? habitId,
    Value<String?>? payload,
    Value<int?>? stamp,
    Value<DateTime>? createdAt,
  }) {
    return HabitOutboxCompanion(
      seq: seq ?? this.seq,
      opId: opId ?? this.opId,
      action: action ?? this.action,
      habitId: habitId ?? this.habitId,
      payload: payload ?? this.payload,
      stamp: stamp ?? this.stamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<int>(habitId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (stamp.present) {
      map['stamp'] = Variable<int>(stamp.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitOutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('opId: $opId, ')
          ..write('action: $action, ')
          ..write('habitId: $habitId, ')
          ..write('payload: $payload, ')
          ..write('stamp: $stamp, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CountdownOutboxTable extends CountdownOutbox
    with TableInfo<$CountdownOutboxTable, CountdownOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CountdownOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _countdownIdMeta = const VerificationMeta(
    'countdownId',
  );
  @override
  late final GeneratedColumn<int> countdownId = GeneratedColumn<int>(
    'countdown_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    opId,
    action,
    countdownId,
    payload,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'countdown_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<CountdownOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    }
    if (data.containsKey('countdown_id')) {
      context.handle(
        _countdownIdMeta,
        countdownId.isAcceptableOrUnknown(
          data['countdown_id']!,
          _countdownIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countdownIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  CountdownOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CountdownOutboxRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      countdownId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}countdown_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CountdownOutboxTable createAlias(String alias) {
    return $CountdownOutboxTable(attachedDatabase, alias);
  }
}

class CountdownOutboxRow extends DataClass
    implements Insertable<CountdownOutboxRow> {
  final int seq;
  final String opId;
  final String action;
  final int countdownId;
  final String? payload;
  final DateTime createdAt;
  const CountdownOutboxRow({
    required this.seq,
    required this.opId,
    required this.action,
    required this.countdownId,
    this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['op_id'] = Variable<String>(opId);
    map['action'] = Variable<String>(action);
    map['countdown_id'] = Variable<int>(countdownId);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CountdownOutboxCompanion toCompanion(bool nullToAbsent) {
    return CountdownOutboxCompanion(
      seq: Value(seq),
      opId: Value(opId),
      action: Value(action),
      countdownId: Value(countdownId),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory CountdownOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CountdownOutboxRow(
      seq: serializer.fromJson<int>(json['seq']),
      opId: serializer.fromJson<String>(json['opId']),
      action: serializer.fromJson<String>(json['action']),
      countdownId: serializer.fromJson<int>(json['countdownId']),
      payload: serializer.fromJson<String?>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'opId': serializer.toJson<String>(opId),
      'action': serializer.toJson<String>(action),
      'countdownId': serializer.toJson<int>(countdownId),
      'payload': serializer.toJson<String?>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CountdownOutboxRow copyWith({
    int? seq,
    String? opId,
    String? action,
    int? countdownId,
    Value<String?> payload = const Value.absent(),
    DateTime? createdAt,
  }) => CountdownOutboxRow(
    seq: seq ?? this.seq,
    opId: opId ?? this.opId,
    action: action ?? this.action,
    countdownId: countdownId ?? this.countdownId,
    payload: payload.present ? payload.value : this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  CountdownOutboxRow copyWithCompanion(CountdownOutboxCompanion data) {
    return CountdownOutboxRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      opId: data.opId.present ? data.opId.value : this.opId,
      action: data.action.present ? data.action.value : this.action,
      countdownId: data.countdownId.present
          ? data.countdownId.value
          : this.countdownId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CountdownOutboxRow(')
          ..write('seq: $seq, ')
          ..write('opId: $opId, ')
          ..write('action: $action, ')
          ..write('countdownId: $countdownId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(seq, opId, action, countdownId, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CountdownOutboxRow &&
          other.seq == this.seq &&
          other.opId == this.opId &&
          other.action == this.action &&
          other.countdownId == this.countdownId &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class CountdownOutboxCompanion extends UpdateCompanion<CountdownOutboxRow> {
  final Value<int> seq;
  final Value<String> opId;
  final Value<String> action;
  final Value<int> countdownId;
  final Value<String?> payload;
  final Value<DateTime> createdAt;
  const CountdownOutboxCompanion({
    this.seq = const Value.absent(),
    this.opId = const Value.absent(),
    this.action = const Value.absent(),
    this.countdownId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CountdownOutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String opId,
    this.action = const Value.absent(),
    required int countdownId,
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : opId = Value(opId),
       countdownId = Value(countdownId);
  static Insertable<CountdownOutboxRow> custom({
    Expression<int>? seq,
    Expression<String>? opId,
    Expression<String>? action,
    Expression<int>? countdownId,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (opId != null) 'op_id': opId,
      if (action != null) 'action': action,
      if (countdownId != null) 'countdown_id': countdownId,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CountdownOutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? opId,
    Value<String>? action,
    Value<int>? countdownId,
    Value<String?>? payload,
    Value<DateTime>? createdAt,
  }) {
    return CountdownOutboxCompanion(
      seq: seq ?? this.seq,
      opId: opId ?? this.opId,
      action: action ?? this.action,
      countdownId: countdownId ?? this.countdownId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (countdownId.present) {
      map['countdown_id'] = Variable<int>(countdownId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CountdownOutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('opId: $opId, ')
          ..write('action: $action, ')
          ..write('countdownId: $countdownId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $HabitsTable extends Habits with TableInfo<$HabitsTable, HabitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#97E38B'),
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<int> sectionId = GeneratedColumn<int>(
    'section_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<double> goal = GeneratedColumn<double>(
    'goal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _stepMeta = const VerificationMeta('step');
  @override
  late final GeneratedColumn<double> step = GeneratedColumn<double>(
    'step',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Count'),
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _remindersMeta = const VerificationMeta(
    'reminders',
  );
  @override
  late final GeneratedColumn<String> reminders = GeneratedColumn<String>(
    'reminders',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _recordEnableMeta = const VerificationMeta(
    'recordEnable',
  );
  @override
  late final GeneratedColumn<bool> recordEnable = GeneratedColumn<bool>(
    'record_enable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("record_enable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _exDatesMeta = const VerificationMeta(
    'exDates',
  );
  @override
  late final GeneratedColumn<String> exDates = GeneratedColumn<String>(
    'ex_dates',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
    'style',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('check'),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<int> startDate = GeneratedColumn<int>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _targetDaysMeta = const VerificationMeta(
    'targetDays',
  );
  @override
  late final GeneratedColumn<int> targetDays = GeneratedColumn<int>(
    'target_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedCyclesMeta = const VerificationMeta(
    'completedCycles',
  );
  @override
  late final GeneratedColumn<int> completedCycles = GeneratedColumn<int>(
    'completed_cycles',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalCheckInsMeta = const VerificationMeta(
    'totalCheckIns',
  );
  @override
  late final GeneratedColumn<int> totalCheckIns = GeneratedColumn<int>(
    'total_check_ins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentStreakMeta = const VerificationMeta(
    'currentStreak',
  );
  @override
  late final GeneratedColumn<int> currentStreak = GeneratedColumn<int>(
    'current_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxStreakMeta = const VerificationMeta(
    'maxStreak',
  );
  @override
  late final GeneratedColumn<int> maxStreak = GeneratedColumn<int>(
    'max_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueTodayMeta = const VerificationMeta(
    'dueToday',
  );
  @override
  late final GeneratedColumn<bool> dueToday = GeneratedColumn<bool>(
    'due_today',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("due_today" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _doneTodayMeta = const VerificationMeta(
    'doneToday',
  );
  @override
  late final GeneratedColumn<bool> doneToday = GeneratedColumn<bool>(
    'done_today',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done_today" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    color,
    sectionId,
    status,
    goal,
    step,
    unit,
    frequency,
    reminders,
    recordEnable,
    exDates,
    style,
    startDate,
    targetDays,
    completedCycles,
    totalCheckIns,
    currentStreak,
    maxStreak,
    dueToday,
    doneToday,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habits';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('goal')) {
      context.handle(
        _goalMeta,
        goal.isAcceptableOrUnknown(data['goal']!, _goalMeta),
      );
    }
    if (data.containsKey('step')) {
      context.handle(
        _stepMeta,
        step.isAcceptableOrUnknown(data['step']!, _stepMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    }
    if (data.containsKey('reminders')) {
      context.handle(
        _remindersMeta,
        reminders.isAcceptableOrUnknown(data['reminders']!, _remindersMeta),
      );
    }
    if (data.containsKey('record_enable')) {
      context.handle(
        _recordEnableMeta,
        recordEnable.isAcceptableOrUnknown(
          data['record_enable']!,
          _recordEnableMeta,
        ),
      );
    }
    if (data.containsKey('ex_dates')) {
      context.handle(
        _exDatesMeta,
        exDates.isAcceptableOrUnknown(data['ex_dates']!, _exDatesMeta),
      );
    }
    if (data.containsKey('style')) {
      context.handle(
        _styleMeta,
        style.isAcceptableOrUnknown(data['style']!, _styleMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('target_days')) {
      context.handle(
        _targetDaysMeta,
        targetDays.isAcceptableOrUnknown(data['target_days']!, _targetDaysMeta),
      );
    }
    if (data.containsKey('completed_cycles')) {
      context.handle(
        _completedCyclesMeta,
        completedCycles.isAcceptableOrUnknown(
          data['completed_cycles']!,
          _completedCyclesMeta,
        ),
      );
    }
    if (data.containsKey('total_check_ins')) {
      context.handle(
        _totalCheckInsMeta,
        totalCheckIns.isAcceptableOrUnknown(
          data['total_check_ins']!,
          _totalCheckInsMeta,
        ),
      );
    }
    if (data.containsKey('current_streak')) {
      context.handle(
        _currentStreakMeta,
        currentStreak.isAcceptableOrUnknown(
          data['current_streak']!,
          _currentStreakMeta,
        ),
      );
    }
    if (data.containsKey('max_streak')) {
      context.handle(
        _maxStreakMeta,
        maxStreak.isAcceptableOrUnknown(data['max_streak']!, _maxStreakMeta),
      );
    }
    if (data.containsKey('due_today')) {
      context.handle(
        _dueTodayMeta,
        dueToday.isAcceptableOrUnknown(data['due_today']!, _dueTodayMeta),
      );
    }
    if (data.containsKey('done_today')) {
      context.handle(
        _doneTodayMeta,
        doneToday.isAcceptableOrUnknown(data['done_today']!, _doneTodayMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HabitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}section_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      goal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}goal'],
      )!,
      step: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}step'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      reminders: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminders'],
      )!,
      recordEnable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}record_enable'],
      )!,
      exDates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ex_dates'],
      )!,
      style: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_date'],
      )!,
      targetDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_days'],
      )!,
      completedCycles: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_cycles'],
      )!,
      totalCheckIns: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_check_ins'],
      )!,
      currentStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_streak'],
      )!,
      maxStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_streak'],
      )!,
      dueToday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}due_today'],
      )!,
      doneToday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done_today'],
      )!,
    );
  }

  @override
  $HabitsTable createAlias(String alias) {
    return $HabitsTable(attachedDatabase, alias);
  }
}

class HabitRow extends DataClass implements Insertable<HabitRow> {
  final int id;
  final String name;
  final String icon;
  final String color;
  final int sectionId;
  final int status;
  final double goal;
  final double step;
  final String unit;
  final String frequency;
  final String reminders;
  final bool recordEnable;
  final String exDates;
  final String style;
  final int startDate;
  final int targetDays;
  final int completedCycles;

  /// Values the server derives per request (streaks, today state). Cached so
  /// the mirror can render the same numbers offline.
  final int totalCheckIns;
  final int currentStreak;
  final int maxStreak;
  final bool dueToday;
  final bool doneToday;
  const HabitRow({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.sectionId,
    required this.status,
    required this.goal,
    required this.step,
    required this.unit,
    required this.frequency,
    required this.reminders,
    required this.recordEnable,
    required this.exDates,
    required this.style,
    required this.startDate,
    required this.targetDays,
    required this.completedCycles,
    required this.totalCheckIns,
    required this.currentStreak,
    required this.maxStreak,
    required this.dueToday,
    required this.doneToday,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<String>(color);
    map['section_id'] = Variable<int>(sectionId);
    map['status'] = Variable<int>(status);
    map['goal'] = Variable<double>(goal);
    map['step'] = Variable<double>(step);
    map['unit'] = Variable<String>(unit);
    map['frequency'] = Variable<String>(frequency);
    map['reminders'] = Variable<String>(reminders);
    map['record_enable'] = Variable<bool>(recordEnable);
    map['ex_dates'] = Variable<String>(exDates);
    map['style'] = Variable<String>(style);
    map['start_date'] = Variable<int>(startDate);
    map['target_days'] = Variable<int>(targetDays);
    map['completed_cycles'] = Variable<int>(completedCycles);
    map['total_check_ins'] = Variable<int>(totalCheckIns);
    map['current_streak'] = Variable<int>(currentStreak);
    map['max_streak'] = Variable<int>(maxStreak);
    map['due_today'] = Variable<bool>(dueToday);
    map['done_today'] = Variable<bool>(doneToday);
    return map;
  }

  HabitsCompanion toCompanion(bool nullToAbsent) {
    return HabitsCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value(icon),
      color: Value(color),
      sectionId: Value(sectionId),
      status: Value(status),
      goal: Value(goal),
      step: Value(step),
      unit: Value(unit),
      frequency: Value(frequency),
      reminders: Value(reminders),
      recordEnable: Value(recordEnable),
      exDates: Value(exDates),
      style: Value(style),
      startDate: Value(startDate),
      targetDays: Value(targetDays),
      completedCycles: Value(completedCycles),
      totalCheckIns: Value(totalCheckIns),
      currentStreak: Value(currentStreak),
      maxStreak: Value(maxStreak),
      dueToday: Value(dueToday),
      doneToday: Value(doneToday),
    );
  }

  factory HabitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<String>(json['color']),
      sectionId: serializer.fromJson<int>(json['sectionId']),
      status: serializer.fromJson<int>(json['status']),
      goal: serializer.fromJson<double>(json['goal']),
      step: serializer.fromJson<double>(json['step']),
      unit: serializer.fromJson<String>(json['unit']),
      frequency: serializer.fromJson<String>(json['frequency']),
      reminders: serializer.fromJson<String>(json['reminders']),
      recordEnable: serializer.fromJson<bool>(json['recordEnable']),
      exDates: serializer.fromJson<String>(json['exDates']),
      style: serializer.fromJson<String>(json['style']),
      startDate: serializer.fromJson<int>(json['startDate']),
      targetDays: serializer.fromJson<int>(json['targetDays']),
      completedCycles: serializer.fromJson<int>(json['completedCycles']),
      totalCheckIns: serializer.fromJson<int>(json['totalCheckIns']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      maxStreak: serializer.fromJson<int>(json['maxStreak']),
      dueToday: serializer.fromJson<bool>(json['dueToday']),
      doneToday: serializer.fromJson<bool>(json['doneToday']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<String>(color),
      'sectionId': serializer.toJson<int>(sectionId),
      'status': serializer.toJson<int>(status),
      'goal': serializer.toJson<double>(goal),
      'step': serializer.toJson<double>(step),
      'unit': serializer.toJson<String>(unit),
      'frequency': serializer.toJson<String>(frequency),
      'reminders': serializer.toJson<String>(reminders),
      'recordEnable': serializer.toJson<bool>(recordEnable),
      'exDates': serializer.toJson<String>(exDates),
      'style': serializer.toJson<String>(style),
      'startDate': serializer.toJson<int>(startDate),
      'targetDays': serializer.toJson<int>(targetDays),
      'completedCycles': serializer.toJson<int>(completedCycles),
      'totalCheckIns': serializer.toJson<int>(totalCheckIns),
      'currentStreak': serializer.toJson<int>(currentStreak),
      'maxStreak': serializer.toJson<int>(maxStreak),
      'dueToday': serializer.toJson<bool>(dueToday),
      'doneToday': serializer.toJson<bool>(doneToday),
    };
  }

  HabitRow copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
    int? sectionId,
    int? status,
    double? goal,
    double? step,
    String? unit,
    String? frequency,
    String? reminders,
    bool? recordEnable,
    String? exDates,
    String? style,
    int? startDate,
    int? targetDays,
    int? completedCycles,
    int? totalCheckIns,
    int? currentStreak,
    int? maxStreak,
    bool? dueToday,
    bool? doneToday,
  }) => HabitRow(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    sectionId: sectionId ?? this.sectionId,
    status: status ?? this.status,
    goal: goal ?? this.goal,
    step: step ?? this.step,
    unit: unit ?? this.unit,
    frequency: frequency ?? this.frequency,
    reminders: reminders ?? this.reminders,
    recordEnable: recordEnable ?? this.recordEnable,
    exDates: exDates ?? this.exDates,
    style: style ?? this.style,
    startDate: startDate ?? this.startDate,
    targetDays: targetDays ?? this.targetDays,
    completedCycles: completedCycles ?? this.completedCycles,
    totalCheckIns: totalCheckIns ?? this.totalCheckIns,
    currentStreak: currentStreak ?? this.currentStreak,
    maxStreak: maxStreak ?? this.maxStreak,
    dueToday: dueToday ?? this.dueToday,
    doneToday: doneToday ?? this.doneToday,
  );
  HabitRow copyWithCompanion(HabitsCompanion data) {
    return HabitRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      status: data.status.present ? data.status.value : this.status,
      goal: data.goal.present ? data.goal.value : this.goal,
      step: data.step.present ? data.step.value : this.step,
      unit: data.unit.present ? data.unit.value : this.unit,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      reminders: data.reminders.present ? data.reminders.value : this.reminders,
      recordEnable: data.recordEnable.present
          ? data.recordEnable.value
          : this.recordEnable,
      exDates: data.exDates.present ? data.exDates.value : this.exDates,
      style: data.style.present ? data.style.value : this.style,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      targetDays: data.targetDays.present
          ? data.targetDays.value
          : this.targetDays,
      completedCycles: data.completedCycles.present
          ? data.completedCycles.value
          : this.completedCycles,
      totalCheckIns: data.totalCheckIns.present
          ? data.totalCheckIns.value
          : this.totalCheckIns,
      currentStreak: data.currentStreak.present
          ? data.currentStreak.value
          : this.currentStreak,
      maxStreak: data.maxStreak.present ? data.maxStreak.value : this.maxStreak,
      dueToday: data.dueToday.present ? data.dueToday.value : this.dueToday,
      doneToday: data.doneToday.present ? data.doneToday.value : this.doneToday,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('sectionId: $sectionId, ')
          ..write('status: $status, ')
          ..write('goal: $goal, ')
          ..write('step: $step, ')
          ..write('unit: $unit, ')
          ..write('frequency: $frequency, ')
          ..write('reminders: $reminders, ')
          ..write('recordEnable: $recordEnable, ')
          ..write('exDates: $exDates, ')
          ..write('style: $style, ')
          ..write('startDate: $startDate, ')
          ..write('targetDays: $targetDays, ')
          ..write('completedCycles: $completedCycles, ')
          ..write('totalCheckIns: $totalCheckIns, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('maxStreak: $maxStreak, ')
          ..write('dueToday: $dueToday, ')
          ..write('doneToday: $doneToday')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    icon,
    color,
    sectionId,
    status,
    goal,
    step,
    unit,
    frequency,
    reminders,
    recordEnable,
    exDates,
    style,
    startDate,
    targetDays,
    completedCycles,
    totalCheckIns,
    currentStreak,
    maxStreak,
    dueToday,
    doneToday,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.sectionId == this.sectionId &&
          other.status == this.status &&
          other.goal == this.goal &&
          other.step == this.step &&
          other.unit == this.unit &&
          other.frequency == this.frequency &&
          other.reminders == this.reminders &&
          other.recordEnable == this.recordEnable &&
          other.exDates == this.exDates &&
          other.style == this.style &&
          other.startDate == this.startDate &&
          other.targetDays == this.targetDays &&
          other.completedCycles == this.completedCycles &&
          other.totalCheckIns == this.totalCheckIns &&
          other.currentStreak == this.currentStreak &&
          other.maxStreak == this.maxStreak &&
          other.dueToday == this.dueToday &&
          other.doneToday == this.doneToday);
}

class HabitsCompanion extends UpdateCompanion<HabitRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> icon;
  final Value<String> color;
  final Value<int> sectionId;
  final Value<int> status;
  final Value<double> goal;
  final Value<double> step;
  final Value<String> unit;
  final Value<String> frequency;
  final Value<String> reminders;
  final Value<bool> recordEnable;
  final Value<String> exDates;
  final Value<String> style;
  final Value<int> startDate;
  final Value<int> targetDays;
  final Value<int> completedCycles;
  final Value<int> totalCheckIns;
  final Value<int> currentStreak;
  final Value<int> maxStreak;
  final Value<bool> dueToday;
  final Value<bool> doneToday;
  const HabitsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.status = const Value.absent(),
    this.goal = const Value.absent(),
    this.step = const Value.absent(),
    this.unit = const Value.absent(),
    this.frequency = const Value.absent(),
    this.reminders = const Value.absent(),
    this.recordEnable = const Value.absent(),
    this.exDates = const Value.absent(),
    this.style = const Value.absent(),
    this.startDate = const Value.absent(),
    this.targetDays = const Value.absent(),
    this.completedCycles = const Value.absent(),
    this.totalCheckIns = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.maxStreak = const Value.absent(),
    this.dueToday = const Value.absent(),
    this.doneToday = const Value.absent(),
  });
  HabitsCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.status = const Value.absent(),
    this.goal = const Value.absent(),
    this.step = const Value.absent(),
    this.unit = const Value.absent(),
    this.frequency = const Value.absent(),
    this.reminders = const Value.absent(),
    this.recordEnable = const Value.absent(),
    this.exDates = const Value.absent(),
    this.style = const Value.absent(),
    this.startDate = const Value.absent(),
    this.targetDays = const Value.absent(),
    this.completedCycles = const Value.absent(),
    this.totalCheckIns = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.maxStreak = const Value.absent(),
    this.dueToday = const Value.absent(),
    this.doneToday = const Value.absent(),
  });
  static Insertable<HabitRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<int>? sectionId,
    Expression<int>? status,
    Expression<double>? goal,
    Expression<double>? step,
    Expression<String>? unit,
    Expression<String>? frequency,
    Expression<String>? reminders,
    Expression<bool>? recordEnable,
    Expression<String>? exDates,
    Expression<String>? style,
    Expression<int>? startDate,
    Expression<int>? targetDays,
    Expression<int>? completedCycles,
    Expression<int>? totalCheckIns,
    Expression<int>? currentStreak,
    Expression<int>? maxStreak,
    Expression<bool>? dueToday,
    Expression<bool>? doneToday,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (sectionId != null) 'section_id': sectionId,
      if (status != null) 'status': status,
      if (goal != null) 'goal': goal,
      if (step != null) 'step': step,
      if (unit != null) 'unit': unit,
      if (frequency != null) 'frequency': frequency,
      if (reminders != null) 'reminders': reminders,
      if (recordEnable != null) 'record_enable': recordEnable,
      if (exDates != null) 'ex_dates': exDates,
      if (style != null) 'style': style,
      if (startDate != null) 'start_date': startDate,
      if (targetDays != null) 'target_days': targetDays,
      if (completedCycles != null) 'completed_cycles': completedCycles,
      if (totalCheckIns != null) 'total_check_ins': totalCheckIns,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (maxStreak != null) 'max_streak': maxStreak,
      if (dueToday != null) 'due_today': dueToday,
      if (doneToday != null) 'done_today': doneToday,
    });
  }

  HabitsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? icon,
    Value<String>? color,
    Value<int>? sectionId,
    Value<int>? status,
    Value<double>? goal,
    Value<double>? step,
    Value<String>? unit,
    Value<String>? frequency,
    Value<String>? reminders,
    Value<bool>? recordEnable,
    Value<String>? exDates,
    Value<String>? style,
    Value<int>? startDate,
    Value<int>? targetDays,
    Value<int>? completedCycles,
    Value<int>? totalCheckIns,
    Value<int>? currentStreak,
    Value<int>? maxStreak,
    Value<bool>? dueToday,
    Value<bool>? doneToday,
  }) {
    return HabitsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sectionId: sectionId ?? this.sectionId,
      status: status ?? this.status,
      goal: goal ?? this.goal,
      step: step ?? this.step,
      unit: unit ?? this.unit,
      frequency: frequency ?? this.frequency,
      reminders: reminders ?? this.reminders,
      recordEnable: recordEnable ?? this.recordEnable,
      exDates: exDates ?? this.exDates,
      style: style ?? this.style,
      startDate: startDate ?? this.startDate,
      targetDays: targetDays ?? this.targetDays,
      completedCycles: completedCycles ?? this.completedCycles,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      dueToday: dueToday ?? this.dueToday,
      doneToday: doneToday ?? this.doneToday,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<int>(sectionId.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (goal.present) {
      map['goal'] = Variable<double>(goal.value);
    }
    if (step.present) {
      map['step'] = Variable<double>(step.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (reminders.present) {
      map['reminders'] = Variable<String>(reminders.value);
    }
    if (recordEnable.present) {
      map['record_enable'] = Variable<bool>(recordEnable.value);
    }
    if (exDates.present) {
      map['ex_dates'] = Variable<String>(exDates.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<int>(startDate.value);
    }
    if (targetDays.present) {
      map['target_days'] = Variable<int>(targetDays.value);
    }
    if (completedCycles.present) {
      map['completed_cycles'] = Variable<int>(completedCycles.value);
    }
    if (totalCheckIns.present) {
      map['total_check_ins'] = Variable<int>(totalCheckIns.value);
    }
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
    }
    if (maxStreak.present) {
      map['max_streak'] = Variable<int>(maxStreak.value);
    }
    if (dueToday.present) {
      map['due_today'] = Variable<bool>(dueToday.value);
    }
    if (doneToday.present) {
      map['done_today'] = Variable<bool>(doneToday.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('sectionId: $sectionId, ')
          ..write('status: $status, ')
          ..write('goal: $goal, ')
          ..write('step: $step, ')
          ..write('unit: $unit, ')
          ..write('frequency: $frequency, ')
          ..write('reminders: $reminders, ')
          ..write('recordEnable: $recordEnable, ')
          ..write('exDates: $exDates, ')
          ..write('style: $style, ')
          ..write('startDate: $startDate, ')
          ..write('targetDays: $targetDays, ')
          ..write('completedCycles: $completedCycles, ')
          ..write('totalCheckIns: $totalCheckIns, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('maxStreak: $maxStreak, ')
          ..write('dueToday: $dueToday, ')
          ..write('doneToday: $doneToday')
          ..write(')'))
        .toString();
  }
}

class $HabitCheckinsTable extends HabitCheckins
    with TableInfo<$HabitCheckinsTable, HabitCheckinRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitCheckinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<int> habitId = GeneratedColumn<int>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkinStampMeta = const VerificationMeta(
    'checkinStamp',
  );
  @override
  late final GeneratedColumn<int> checkinStamp = GeneratedColumn<int>(
    'checkin_stamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<double> goal = GeneratedColumn<double>(
    'goal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    habitId,
    checkinStamp,
    value,
    goal,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_checkins';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitCheckinRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('checkin_stamp')) {
      context.handle(
        _checkinStampMeta,
        checkinStamp.isAcceptableOrUnknown(
          data['checkin_stamp']!,
          _checkinStampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checkinStampMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('goal')) {
      context.handle(
        _goalMeta,
        goal.isAcceptableOrUnknown(data['goal']!, _goalMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {habitId, checkinStamp};
  @override
  HabitCheckinRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitCheckinRow(
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}habit_id'],
      )!,
      checkinStamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checkin_stamp'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      goal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}goal'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $HabitCheckinsTable createAlias(String alias) {
    return $HabitCheckinsTable(attachedDatabase, alias);
  }
}

class HabitCheckinRow extends DataClass implements Insertable<HabitCheckinRow> {
  final int habitId;
  final int checkinStamp;
  final double value;
  final double goal;
  final int status;
  const HabitCheckinRow({
    required this.habitId,
    required this.checkinStamp,
    required this.value,
    required this.goal,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['habit_id'] = Variable<int>(habitId);
    map['checkin_stamp'] = Variable<int>(checkinStamp);
    map['value'] = Variable<double>(value);
    map['goal'] = Variable<double>(goal);
    map['status'] = Variable<int>(status);
    return map;
  }

  HabitCheckinsCompanion toCompanion(bool nullToAbsent) {
    return HabitCheckinsCompanion(
      habitId: Value(habitId),
      checkinStamp: Value(checkinStamp),
      value: Value(value),
      goal: Value(goal),
      status: Value(status),
    );
  }

  factory HabitCheckinRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitCheckinRow(
      habitId: serializer.fromJson<int>(json['habitId']),
      checkinStamp: serializer.fromJson<int>(json['checkinStamp']),
      value: serializer.fromJson<double>(json['value']),
      goal: serializer.fromJson<double>(json['goal']),
      status: serializer.fromJson<int>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'habitId': serializer.toJson<int>(habitId),
      'checkinStamp': serializer.toJson<int>(checkinStamp),
      'value': serializer.toJson<double>(value),
      'goal': serializer.toJson<double>(goal),
      'status': serializer.toJson<int>(status),
    };
  }

  HabitCheckinRow copyWith({
    int? habitId,
    int? checkinStamp,
    double? value,
    double? goal,
    int? status,
  }) => HabitCheckinRow(
    habitId: habitId ?? this.habitId,
    checkinStamp: checkinStamp ?? this.checkinStamp,
    value: value ?? this.value,
    goal: goal ?? this.goal,
    status: status ?? this.status,
  );
  HabitCheckinRow copyWithCompanion(HabitCheckinsCompanion data) {
    return HabitCheckinRow(
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      checkinStamp: data.checkinStamp.present
          ? data.checkinStamp.value
          : this.checkinStamp,
      value: data.value.present ? data.value.value : this.value,
      goal: data.goal.present ? data.goal.value : this.goal,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitCheckinRow(')
          ..write('habitId: $habitId, ')
          ..write('checkinStamp: $checkinStamp, ')
          ..write('value: $value, ')
          ..write('goal: $goal, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(habitId, checkinStamp, value, goal, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitCheckinRow &&
          other.habitId == this.habitId &&
          other.checkinStamp == this.checkinStamp &&
          other.value == this.value &&
          other.goal == this.goal &&
          other.status == this.status);
}

class HabitCheckinsCompanion extends UpdateCompanion<HabitCheckinRow> {
  final Value<int> habitId;
  final Value<int> checkinStamp;
  final Value<double> value;
  final Value<double> goal;
  final Value<int> status;
  final Value<int> rowid;
  const HabitCheckinsCompanion({
    this.habitId = const Value.absent(),
    this.checkinStamp = const Value.absent(),
    this.value = const Value.absent(),
    this.goal = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitCheckinsCompanion.insert({
    required int habitId,
    required int checkinStamp,
    this.value = const Value.absent(),
    this.goal = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : habitId = Value(habitId),
       checkinStamp = Value(checkinStamp);
  static Insertable<HabitCheckinRow> custom({
    Expression<int>? habitId,
    Expression<int>? checkinStamp,
    Expression<double>? value,
    Expression<double>? goal,
    Expression<int>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (habitId != null) 'habit_id': habitId,
      if (checkinStamp != null) 'checkin_stamp': checkinStamp,
      if (value != null) 'value': value,
      if (goal != null) 'goal': goal,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitCheckinsCompanion copyWith({
    Value<int>? habitId,
    Value<int>? checkinStamp,
    Value<double>? value,
    Value<double>? goal,
    Value<int>? status,
    Value<int>? rowid,
  }) {
    return HabitCheckinsCompanion(
      habitId: habitId ?? this.habitId,
      checkinStamp: checkinStamp ?? this.checkinStamp,
      value: value ?? this.value,
      goal: goal ?? this.goal,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (habitId.present) {
      map['habit_id'] = Variable<int>(habitId.value);
    }
    if (checkinStamp.present) {
      map['checkin_stamp'] = Variable<int>(checkinStamp.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (goal.present) {
      map['goal'] = Variable<double>(goal.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitCheckinsCompanion(')
          ..write('habitId: $habitId, ')
          ..write('checkinStamp: $checkinStamp, ')
          ..write('value: $value, ')
          ..write('goal: $goal, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitSectionsTable extends HabitSections
    with TableInfo<$HabitSectionsTable, HabitSectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitSectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_sections';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitSectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HabitSectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitSectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $HabitSectionsTable createAlias(String alias) {
    return $HabitSectionsTable(attachedDatabase, alias);
  }
}

class HabitSectionRow extends DataClass implements Insertable<HabitSectionRow> {
  final int id;
  final String name;
  final int sortOrder;
  const HabitSectionRow({
    required this.id,
    required this.name,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  HabitSectionsCompanion toCompanion(bool nullToAbsent) {
    return HabitSectionsCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
    );
  }

  factory HabitSectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitSectionRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  HabitSectionRow copyWith({int? id, String? name, int? sortOrder}) =>
      HabitSectionRow(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  HabitSectionRow copyWithCompanion(HabitSectionsCompanion data) {
    return HabitSectionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitSectionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitSectionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class HabitSectionsCompanion extends UpdateCompanion<HabitSectionRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> sortOrder;
  const HabitSectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  HabitSectionsCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  static Insertable<HabitSectionRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  HabitSectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? sortOrder,
  }) {
    return HabitSectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitSectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $CountdownsTable extends Countdowns
    with TableInfo<$CountdownsTable, CountdownRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CountdownsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('countdown'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repeatMeta = const VerificationMeta('repeat');
  @override
  late final GeneratedColumn<String> repeat = GeneratedColumn<String>(
    'repeat',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#92D0FF'),
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('⏳'),
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _daysMeta = const VerificationMeta('days');
  @override
  late final GeneratedColumn<int> days = GeneratedColumn<int>(
    'days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hoursMeta = const VerificationMeta('hours');
  @override
  late final GeneratedColumn<int> hours = GeneratedColumn<int>(
    'hours',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _minutesMeta = const VerificationMeta(
    'minutes',
  );
  @override
  late final GeneratedColumn<int> minutes = GeneratedColumn<int>(
    'minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _secondsMeta = const VerificationMeta(
    'seconds',
  );
  @override
  late final GeneratedColumn<int> seconds = GeneratedColumn<int>(
    'seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('future'),
  );
  static const VerificationMeta _occurrenceDateMeta = const VerificationMeta(
    'occurrenceDate',
  );
  @override
  late final GeneratedColumn<int> occurrenceDate = GeneratedColumn<int>(
    'occurrence_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    date,
    repeat,
    pinned,
    status,
    color,
    icon,
    remark,
    days,
    hours,
    minutes,
    seconds,
    state,
    occurrenceDate,
    age,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'countdowns';
  @override
  VerificationContext validateIntegrity(
    Insertable<CountdownRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('repeat')) {
      context.handle(
        _repeatMeta,
        repeat.isAcceptableOrUnknown(data['repeat']!, _repeatMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('days')) {
      context.handle(
        _daysMeta,
        days.isAcceptableOrUnknown(data['days']!, _daysMeta),
      );
    }
    if (data.containsKey('hours')) {
      context.handle(
        _hoursMeta,
        hours.isAcceptableOrUnknown(data['hours']!, _hoursMeta),
      );
    }
    if (data.containsKey('minutes')) {
      context.handle(
        _minutesMeta,
        minutes.isAcceptableOrUnknown(data['minutes']!, _minutesMeta),
      );
    }
    if (data.containsKey('seconds')) {
      context.handle(
        _secondsMeta,
        seconds.isAcceptableOrUnknown(data['seconds']!, _secondsMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('occurrence_date')) {
      context.handle(
        _occurrenceDateMeta,
        occurrenceDate.isAcceptableOrUnknown(
          data['occurrence_date']!,
          _occurrenceDateMeta,
        ),
      );
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CountdownRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CountdownRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      )!,
      repeat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      )!,
      days: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days'],
      )!,
      hours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hours'],
      )!,
      minutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minutes'],
      )!,
      seconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seconds'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      occurrenceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrence_date'],
      )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      )!,
    );
  }

  @override
  $CountdownsTable createAlias(String alias) {
    return $CountdownsTable(attachedDatabase, alias);
  }
}

class CountdownRow extends DataClass implements Insertable<CountdownRow> {
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
  const CountdownRow({
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
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['date'] = Variable<int>(date);
    map['repeat'] = Variable<String>(repeat);
    map['pinned'] = Variable<bool>(pinned);
    map['status'] = Variable<int>(status);
    map['color'] = Variable<String>(color);
    map['icon'] = Variable<String>(icon);
    map['remark'] = Variable<String>(remark);
    map['days'] = Variable<int>(days);
    map['hours'] = Variable<int>(hours);
    map['minutes'] = Variable<int>(minutes);
    map['seconds'] = Variable<int>(seconds);
    map['state'] = Variable<String>(state);
    map['occurrence_date'] = Variable<int>(occurrenceDate);
    map['age'] = Variable<int>(age);
    return map;
  }

  CountdownsCompanion toCompanion(bool nullToAbsent) {
    return CountdownsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      date: Value(date),
      repeat: Value(repeat),
      pinned: Value(pinned),
      status: Value(status),
      color: Value(color),
      icon: Value(icon),
      remark: Value(remark),
      days: Value(days),
      hours: Value(hours),
      minutes: Value(minutes),
      seconds: Value(seconds),
      state: Value(state),
      occurrenceDate: Value(occurrenceDate),
      age: Value(age),
    );
  }

  factory CountdownRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CountdownRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      date: serializer.fromJson<int>(json['date']),
      repeat: serializer.fromJson<String>(json['repeat']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      status: serializer.fromJson<int>(json['status']),
      color: serializer.fromJson<String>(json['color']),
      icon: serializer.fromJson<String>(json['icon']),
      remark: serializer.fromJson<String>(json['remark']),
      days: serializer.fromJson<int>(json['days']),
      hours: serializer.fromJson<int>(json['hours']),
      minutes: serializer.fromJson<int>(json['minutes']),
      seconds: serializer.fromJson<int>(json['seconds']),
      state: serializer.fromJson<String>(json['state']),
      occurrenceDate: serializer.fromJson<int>(json['occurrenceDate']),
      age: serializer.fromJson<int>(json['age']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'date': serializer.toJson<int>(date),
      'repeat': serializer.toJson<String>(repeat),
      'pinned': serializer.toJson<bool>(pinned),
      'status': serializer.toJson<int>(status),
      'color': serializer.toJson<String>(color),
      'icon': serializer.toJson<String>(icon),
      'remark': serializer.toJson<String>(remark),
      'days': serializer.toJson<int>(days),
      'hours': serializer.toJson<int>(hours),
      'minutes': serializer.toJson<int>(minutes),
      'seconds': serializer.toJson<int>(seconds),
      'state': serializer.toJson<String>(state),
      'occurrenceDate': serializer.toJson<int>(occurrenceDate),
      'age': serializer.toJson<int>(age),
    };
  }

  CountdownRow copyWith({
    int? id,
    String? name,
    String? type,
    int? date,
    String? repeat,
    bool? pinned,
    int? status,
    String? color,
    String? icon,
    String? remark,
    int? days,
    int? hours,
    int? minutes,
    int? seconds,
    String? state,
    int? occurrenceDate,
    int? age,
  }) => CountdownRow(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    date: date ?? this.date,
    repeat: repeat ?? this.repeat,
    pinned: pinned ?? this.pinned,
    status: status ?? this.status,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    remark: remark ?? this.remark,
    days: days ?? this.days,
    hours: hours ?? this.hours,
    minutes: minutes ?? this.minutes,
    seconds: seconds ?? this.seconds,
    state: state ?? this.state,
    occurrenceDate: occurrenceDate ?? this.occurrenceDate,
    age: age ?? this.age,
  );
  CountdownRow copyWithCompanion(CountdownsCompanion data) {
    return CountdownRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      date: data.date.present ? data.date.value : this.date,
      repeat: data.repeat.present ? data.repeat.value : this.repeat,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      status: data.status.present ? data.status.value : this.status,
      color: data.color.present ? data.color.value : this.color,
      icon: data.icon.present ? data.icon.value : this.icon,
      remark: data.remark.present ? data.remark.value : this.remark,
      days: data.days.present ? data.days.value : this.days,
      hours: data.hours.present ? data.hours.value : this.hours,
      minutes: data.minutes.present ? data.minutes.value : this.minutes,
      seconds: data.seconds.present ? data.seconds.value : this.seconds,
      state: data.state.present ? data.state.value : this.state,
      occurrenceDate: data.occurrenceDate.present
          ? data.occurrenceDate.value
          : this.occurrenceDate,
      age: data.age.present ? data.age.value : this.age,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CountdownRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('repeat: $repeat, ')
          ..write('pinned: $pinned, ')
          ..write('status: $status, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('remark: $remark, ')
          ..write('days: $days, ')
          ..write('hours: $hours, ')
          ..write('minutes: $minutes, ')
          ..write('seconds: $seconds, ')
          ..write('state: $state, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('age: $age')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    date,
    repeat,
    pinned,
    status,
    color,
    icon,
    remark,
    days,
    hours,
    minutes,
    seconds,
    state,
    occurrenceDate,
    age,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CountdownRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.date == this.date &&
          other.repeat == this.repeat &&
          other.pinned == this.pinned &&
          other.status == this.status &&
          other.color == this.color &&
          other.icon == this.icon &&
          other.remark == this.remark &&
          other.days == this.days &&
          other.hours == this.hours &&
          other.minutes == this.minutes &&
          other.seconds == this.seconds &&
          other.state == this.state &&
          other.occurrenceDate == this.occurrenceDate &&
          other.age == this.age);
}

class CountdownsCompanion extends UpdateCompanion<CountdownRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<int> date;
  final Value<String> repeat;
  final Value<bool> pinned;
  final Value<int> status;
  final Value<String> color;
  final Value<String> icon;
  final Value<String> remark;
  final Value<int> days;
  final Value<int> hours;
  final Value<int> minutes;
  final Value<int> seconds;
  final Value<String> state;
  final Value<int> occurrenceDate;
  final Value<int> age;
  const CountdownsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
    this.repeat = const Value.absent(),
    this.pinned = const Value.absent(),
    this.status = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.remark = const Value.absent(),
    this.days = const Value.absent(),
    this.hours = const Value.absent(),
    this.minutes = const Value.absent(),
    this.seconds = const Value.absent(),
    this.state = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    this.age = const Value.absent(),
  });
  CountdownsCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
    this.repeat = const Value.absent(),
    this.pinned = const Value.absent(),
    this.status = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.remark = const Value.absent(),
    this.days = const Value.absent(),
    this.hours = const Value.absent(),
    this.minutes = const Value.absent(),
    this.seconds = const Value.absent(),
    this.state = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    this.age = const Value.absent(),
  });
  static Insertable<CountdownRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<int>? date,
    Expression<String>? repeat,
    Expression<bool>? pinned,
    Expression<int>? status,
    Expression<String>? color,
    Expression<String>? icon,
    Expression<String>? remark,
    Expression<int>? days,
    Expression<int>? hours,
    Expression<int>? minutes,
    Expression<int>? seconds,
    Expression<String>? state,
    Expression<int>? occurrenceDate,
    Expression<int>? age,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (date != null) 'date': date,
      if (repeat != null) 'repeat': repeat,
      if (pinned != null) 'pinned': pinned,
      if (status != null) 'status': status,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (remark != null) 'remark': remark,
      if (days != null) 'days': days,
      if (hours != null) 'hours': hours,
      if (minutes != null) 'minutes': minutes,
      if (seconds != null) 'seconds': seconds,
      if (state != null) 'state': state,
      if (occurrenceDate != null) 'occurrence_date': occurrenceDate,
      if (age != null) 'age': age,
    });
  }

  CountdownsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<int>? date,
    Value<String>? repeat,
    Value<bool>? pinned,
    Value<int>? status,
    Value<String>? color,
    Value<String>? icon,
    Value<String>? remark,
    Value<int>? days,
    Value<int>? hours,
    Value<int>? minutes,
    Value<int>? seconds,
    Value<String>? state,
    Value<int>? occurrenceDate,
    Value<int>? age,
  }) {
    return CountdownsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      date: date ?? this.date,
      repeat: repeat ?? this.repeat,
      pinned: pinned ?? this.pinned,
      status: status ?? this.status,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      remark: remark ?? this.remark,
      days: days ?? this.days,
      hours: hours ?? this.hours,
      minutes: minutes ?? this.minutes,
      seconds: seconds ?? this.seconds,
      state: state ?? this.state,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      age: age ?? this.age,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (repeat.present) {
      map['repeat'] = Variable<String>(repeat.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (days.present) {
      map['days'] = Variable<int>(days.value);
    }
    if (hours.present) {
      map['hours'] = Variable<int>(hours.value);
    }
    if (minutes.present) {
      map['minutes'] = Variable<int>(minutes.value);
    }
    if (seconds.present) {
      map['seconds'] = Variable<int>(seconds.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (occurrenceDate.present) {
      map['occurrence_date'] = Variable<int>(occurrenceDate.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CountdownsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('repeat: $repeat, ')
          ..write('pinned: $pinned, ')
          ..write('status: $status, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('remark: $remark, ')
          ..write('days: $days, ')
          ..write('hours: $hours, ')
          ..write('minutes: $minutes, ')
          ..write('seconds: $seconds, ')
          ..write('state: $state, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('age: $age')
          ..write(')'))
        .toString();
  }
}

class $FocusSessionsTable extends FocusSessions
    with TableInfo<$FocusSessionsTable, FocusSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pomodoro'),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pomodoroCountMeta = const VerificationMeta(
    'pomodoroCount',
  );
  @override
  late final GeneratedColumn<int> pomodoroCount = GeneratedColumn<int>(
    'pomodoro_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    mode,
    startedAt,
    endedAt,
    durationSeconds,
    pomodoroCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FocusSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('pomodoro_count')) {
      context.handle(
        _pomodoroCountMeta,
        pomodoroCount.isAcceptableOrUnknown(
          data['pomodoro_count']!,
          _pomodoroCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      pomodoroCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pomodoro_count'],
      )!,
    );
  }

  @override
  $FocusSessionsTable createAlias(String alias) {
    return $FocusSessionsTable(attachedDatabase, alias);
  }
}

class FocusSessionRow extends DataClass implements Insertable<FocusSessionRow> {
  final int id;
  final String title;
  final String mode;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int pomodoroCount;
  const FocusSessionRow({
    required this.id,
    required this.title,
    required this.mode,
    this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.pomodoroCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['pomodoro_count'] = Variable<int>(pomodoroCount);
    return map;
  }

  FocusSessionsCompanion toCompanion(bool nullToAbsent) {
    return FocusSessionsCompanion(
      id: Value(id),
      title: Value(title),
      mode: Value(mode),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      durationSeconds: Value(durationSeconds),
      pomodoroCount: Value(pomodoroCount),
    );
  }

  factory FocusSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusSessionRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      mode: serializer.fromJson<String>(json['mode']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      pomodoroCount: serializer.fromJson<int>(json['pomodoroCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'mode': serializer.toJson<String>(mode),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'pomodoroCount': serializer.toJson<int>(pomodoroCount),
    };
  }

  FocusSessionRow copyWith({
    int? id,
    String? title,
    String? mode,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> endedAt = const Value.absent(),
    int? durationSeconds,
    int? pomodoroCount,
  }) => FocusSessionRow(
    id: id ?? this.id,
    title: title ?? this.title,
    mode: mode ?? this.mode,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    pomodoroCount: pomodoroCount ?? this.pomodoroCount,
  );
  FocusSessionRow copyWithCompanion(FocusSessionsCompanion data) {
    return FocusSessionRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      mode: data.mode.present ? data.mode.value : this.mode,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      pomodoroCount: data.pomodoroCount.present
          ? data.pomodoroCount.value
          : this.pomodoroCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('mode: $mode, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('pomodoroCount: $pomodoroCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    mode,
    startedAt,
    endedAt,
    durationSeconds,
    pomodoroCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusSessionRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.mode == this.mode &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationSeconds == this.durationSeconds &&
          other.pomodoroCount == this.pomodoroCount);
}

class FocusSessionsCompanion extends UpdateCompanion<FocusSessionRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> mode;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> durationSeconds;
  final Value<int> pomodoroCount;
  const FocusSessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.mode = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.pomodoroCount = const Value.absent(),
  });
  FocusSessionsCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.mode = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.pomodoroCount = const Value.absent(),
  });
  static Insertable<FocusSessionRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? mode,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationSeconds,
    Expression<int>? pomodoroCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (mode != null) 'mode': mode,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (pomodoroCount != null) 'pomodoro_count': pomodoroCount,
    });
  }

  FocusSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? mode,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? durationSeconds,
    Value<int>? pomodoroCount,
  }) {
    return FocusSessionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      mode: mode ?? this.mode,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (pomodoroCount.present) {
      map['pomodoro_count'] = Variable<int>(pomodoroCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('mode: $mode, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('pomodoroCount: $pomodoroCount')
          ..write(')'))
        .toString();
  }
}

class $FocusOutboxTable extends FocusOutbox
    with TableInfo<$FocusOutboxTable, FocusOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    opId,
    action,
    sessionId,
    payload,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<FocusOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  FocusOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusOutboxRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FocusOutboxTable createAlias(String alias) {
    return $FocusOutboxTable(attachedDatabase, alias);
  }
}

class FocusOutboxRow extends DataClass implements Insertable<FocusOutboxRow> {
  final int seq;
  final String opId;
  final String action;
  final int sessionId;
  final String? payload;
  final DateTime createdAt;
  const FocusOutboxRow({
    required this.seq,
    required this.opId,
    required this.action,
    required this.sessionId,
    this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['op_id'] = Variable<String>(opId);
    map['action'] = Variable<String>(action);
    map['session_id'] = Variable<int>(sessionId);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FocusOutboxCompanion toCompanion(bool nullToAbsent) {
    return FocusOutboxCompanion(
      seq: Value(seq),
      opId: Value(opId),
      action: Value(action),
      sessionId: Value(sessionId),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory FocusOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusOutboxRow(
      seq: serializer.fromJson<int>(json['seq']),
      opId: serializer.fromJson<String>(json['opId']),
      action: serializer.fromJson<String>(json['action']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      payload: serializer.fromJson<String?>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'opId': serializer.toJson<String>(opId),
      'action': serializer.toJson<String>(action),
      'sessionId': serializer.toJson<int>(sessionId),
      'payload': serializer.toJson<String?>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FocusOutboxRow copyWith({
    int? seq,
    String? opId,
    String? action,
    int? sessionId,
    Value<String?> payload = const Value.absent(),
    DateTime? createdAt,
  }) => FocusOutboxRow(
    seq: seq ?? this.seq,
    opId: opId ?? this.opId,
    action: action ?? this.action,
    sessionId: sessionId ?? this.sessionId,
    payload: payload.present ? payload.value : this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  FocusOutboxRow copyWithCompanion(FocusOutboxCompanion data) {
    return FocusOutboxRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      opId: data.opId.present ? data.opId.value : this.opId,
      action: data.action.present ? data.action.value : this.action,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusOutboxRow(')
          ..write('seq: $seq, ')
          ..write('opId: $opId, ')
          ..write('action: $action, ')
          ..write('sessionId: $sessionId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(seq, opId, action, sessionId, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusOutboxRow &&
          other.seq == this.seq &&
          other.opId == this.opId &&
          other.action == this.action &&
          other.sessionId == this.sessionId &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class FocusOutboxCompanion extends UpdateCompanion<FocusOutboxRow> {
  final Value<int> seq;
  final Value<String> opId;
  final Value<String> action;
  final Value<int> sessionId;
  final Value<String?> payload;
  final Value<DateTime> createdAt;
  const FocusOutboxCompanion({
    this.seq = const Value.absent(),
    this.opId = const Value.absent(),
    this.action = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FocusOutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String opId,
    this.action = const Value.absent(),
    required int sessionId,
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : opId = Value(opId),
       sessionId = Value(sessionId);
  static Insertable<FocusOutboxRow> custom({
    Expression<int>? seq,
    Expression<String>? opId,
    Expression<String>? action,
    Expression<int>? sessionId,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (opId != null) 'op_id': opId,
      if (action != null) 'action': action,
      if (sessionId != null) 'session_id': sessionId,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FocusOutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? opId,
    Value<String>? action,
    Value<int>? sessionId,
    Value<String?>? payload,
    Value<DateTime>? createdAt,
  }) {
    return FocusOutboxCompanion(
      seq: seq ?? this.seq,
      opId: opId ?? this.opId,
      action: action ?? this.action,
      sessionId: sessionId ?? this.sessionId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusOutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('opId: $opId, ')
          ..write('action: $action, ')
          ..write('sessionId: $sessionId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $TaskListsTable taskLists = $TaskListsTable(this);
  late final $TaskSectionsTable taskSections = $TaskSectionsTable(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $ConflictsTable conflicts = $ConflictsTable(this);
  late final $HabitOutboxTable habitOutbox = $HabitOutboxTable(this);
  late final $CountdownOutboxTable countdownOutbox = $CountdownOutboxTable(
    this,
  );
  late final $HabitsTable habits = $HabitsTable(this);
  late final $HabitCheckinsTable habitCheckins = $HabitCheckinsTable(this);
  late final $HabitSectionsTable habitSections = $HabitSectionsTable(this);
  late final $CountdownsTable countdowns = $CountdownsTable(this);
  late final $FocusSessionsTable focusSessions = $FocusSessionsTable(this);
  late final $FocusOutboxTable focusOutbox = $FocusOutboxTable(this);
  late final $MetaTable meta = $MetaTable(this);
  late final Index idxTaskList = Index(
    'idx_task_list',
    'CREATE INDEX idx_task_list ON tasks (list_id)',
  );
  late final Index idxTaskSection = Index(
    'idx_task_section',
    'CREATE INDEX idx_task_section ON tasks (section_id)',
  );
  late final Index idxTaskDue = Index(
    'idx_task_due',
    'CREATE INDEX idx_task_due ON tasks (due_at)',
  );
  late final Index idxTaskDeleted = Index(
    'idx_task_deleted',
    'CREATE INDEX idx_task_deleted ON tasks (deleted)',
  );
  late final Index idxTasklistFolder = Index(
    'idx_tasklist_folder',
    'CREATE INDEX idx_tasklist_folder ON task_lists (folder_id)',
  );
  late final Index idxTasksectionList = Index(
    'idx_tasksection_list',
    'CREATE INDEX idx_tasksection_list ON task_sections (list_id)',
  );
  late final Index idxOutboxEntity = Index(
    'idx_outbox_entity',
    'CREATE INDEX idx_outbox_entity ON outbox (entity, entity_id)',
  );
  late final Index idxOutboxNextTry = Index(
    'idx_outbox_next_try',
    'CREATE INDEX idx_outbox_next_try ON outbox (next_try_at)',
  );
  late final Index idxHabitoutboxOp = Index(
    'idx_habitoutbox_op',
    'CREATE UNIQUE INDEX idx_habitoutbox_op ON habit_outbox (op_id)',
  );
  late final Index idxCountdownoutboxOp = Index(
    'idx_countdownoutbox_op',
    'CREATE UNIQUE INDEX idx_countdownoutbox_op ON countdown_outbox (op_id)',
  );
  late final Index idxHabitSection = Index(
    'idx_habit_section',
    'CREATE INDEX idx_habit_section ON habits (section_id)',
  );
  late final Index idxFocusStarted = Index(
    'idx_focus_started',
    'CREATE INDEX idx_focus_started ON focus_sessions (started_at)',
  );
  late final Index idxFocusoutboxOp = Index(
    'idx_focusoutbox_op',
    'CREATE UNIQUE INDEX idx_focusoutbox_op ON focus_outbox (op_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tasks,
    taskLists,
    taskSections,
    folders,
    outbox,
    conflicts,
    habitOutbox,
    countdownOutbox,
    habits,
    habitCheckins,
    habitSections,
    countdowns,
    focusSessions,
    focusOutbox,
    meta,
    idxTaskList,
    idxTaskSection,
    idxTaskDue,
    idxTaskDeleted,
    idxTasklistFolder,
    idxTasksectionList,
    idxOutboxEntity,
    idxOutboxNextTry,
    idxHabitoutboxOp,
    idxCountdownoutboxOp,
    idxHabitSection,
    idxFocusStarted,
    idxFocusoutboxOp,
  ];
}

typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  required String syncId,
  Value<String> listId,
  Value<String?> parentId,
  Value<String?> sectionId,
  Value<String> title,
  Value<String> notes,
  Value<String> notesFormat,
  Value<String> kind,
  Value<int> priority,
  Value<DateTime?> startAt,
  Value<DateTime?> dueAt,
  Value<bool> allDay,
  Value<String> recurrence,
  Value<String> reminderOffsets,
  Value<String> tags,
  Value<String> checklist,
  Value<String> assignee,
  Value<DateTime?> completedAt,
  Value<bool> pinned,
  Value<int> orderIndex,
  Value<String> vtodoEtag,
  Value<int> version,
  Value<bool> deleted,
  Value<DateTime?> deletedAt,
  Value<DateTime?> createdAt,
  required DateTime modifiedAt,
  Value<bool> localDirty,
  Value<int> rowid,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<String> syncId,
  Value<String> listId,
  Value<String?> parentId,
  Value<String?> sectionId,
  Value<String> title,
  Value<String> notes,
  Value<String> notesFormat,
  Value<String> kind,
  Value<int> priority,
  Value<DateTime?> startAt,
  Value<DateTime?> dueAt,
  Value<bool> allDay,
  Value<String> recurrence,
  Value<String> reminderOffsets,
  Value<String> tags,
  Value<String> checklist,
  Value<String> assignee,
  Value<DateTime?> completedAt,
  Value<bool> pinned,
  Value<int> orderIndex,
  Value<String> vtodoEtag,
  Value<int> version,
  Value<bool> deleted,
  Value<DateTime?> deletedAt,
  Value<DateTime?> createdAt,
  Value<DateTime> modifiedAt,
  Value<bool> localDirty,
  Value<int> rowid,
});

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notesFormat => $composableBuilder(
    column: $table.notesFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderOffsets => $composableBuilder(
    column: $table.reminderOffsets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checklist => $composableBuilder(
    column: $table.checklist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assignee => $composableBuilder(
    column: $table.assignee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vtodoEtag => $composableBuilder(
    column: $table.vtodoEtag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notesFormat => $composableBuilder(
    column: $table.notesFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderOffsets => $composableBuilder(
    column: $table.reminderOffsets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checklist => $composableBuilder(
    column: $table.checklist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assignee => $composableBuilder(
    column: $table.assignee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vtodoEtag => $composableBuilder(
    column: $table.vtodoEtag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get notesFormat => $composableBuilder(
    column: $table.notesFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderOffsets => $composableBuilder(
    column: $table.reminderOffsets,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get checklist =>
      $composableBuilder(column: $table.checklist, builder: (column) => column);

  GeneratedColumn<String> get assignee =>
      $composableBuilder(column: $table.assignee, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vtodoEtag =>
      $composableBuilder(column: $table.vtodoEtag, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => column,
  );
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, BaseReferences<_$AppDatabase, $TasksTable, TaskRow>),
          TaskRow,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> syncId = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> notesFormat = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<DateTime?> startAt = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String> recurrence = const Value.absent(),
                Value<String> reminderOffsets = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> checklist = const Value.absent(),
                Value<String> assignee = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> vtodoEtag = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> modifiedAt = const Value.absent(),
                Value<bool> localDirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                syncId: syncId,
                listId: listId,
                parentId: parentId,
                sectionId: sectionId,
                title: title,
                notes: notes,
                notesFormat: notesFormat,
                kind: kind,
                priority: priority,
                startAt: startAt,
                dueAt: dueAt,
                allDay: allDay,
                recurrence: recurrence,
                reminderOffsets: reminderOffsets,
                tags: tags,
                checklist: checklist,
                assignee: assignee,
                completedAt: completedAt,
                pinned: pinned,
                orderIndex: orderIndex,
                vtodoEtag: vtodoEtag,
                version: version,
                deleted: deleted,
                deletedAt: deletedAt,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                localDirty: localDirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String syncId,
                Value<String> listId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> notesFormat = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<DateTime?> startAt = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String> recurrence = const Value.absent(),
                Value<String> reminderOffsets = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> checklist = const Value.absent(),
                Value<String> assignee = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> vtodoEtag = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime modifiedAt,
                Value<bool> localDirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                syncId: syncId,
                listId: listId,
                parentId: parentId,
                sectionId: sectionId,
                title: title,
                notes: notes,
                notesFormat: notesFormat,
                kind: kind,
                priority: priority,
                startAt: startAt,
                dueAt: dueAt,
                allDay: allDay,
                recurrence: recurrence,
                reminderOffsets: reminderOffsets,
                tags: tags,
                checklist: checklist,
                assignee: assignee,
                completedAt: completedAt,
                pinned: pinned,
                orderIndex: orderIndex,
                vtodoEtag: vtodoEtag,
                version: version,
                deleted: deleted,
                deletedAt: deletedAt,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                localDirty: localDirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, TaskRow>(table),
                  BaseReferences<_$AppDatabase, $TasksTable, TaskRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, BaseReferences<_$AppDatabase, $TasksTable, TaskRow>),
      TaskRow,
      PrefetchHooks Function()
    >;
typedef $$TaskListsTableCreateCompanionBuilder = TaskListsCompanion Function({
  required String syncId,
  Value<String?> folderId,
  Value<String> name,
  Value<String> color,
  Value<String> kind,
  Value<int> orderIndex,
  Value<bool> pinned,
  Value<bool> isInbox,
  Value<String> etag,
  Value<int> version,
  required DateTime modifiedAt,
  Value<int> rowid,
});
typedef $$TaskListsTableUpdateCompanionBuilder = TaskListsCompanion Function({
  Value<String> syncId,
  Value<String?> folderId,
  Value<String> name,
  Value<String> color,
  Value<String> kind,
  Value<int> orderIndex,
  Value<bool> pinned,
  Value<bool> isInbox,
  Value<String> etag,
  Value<int> version,
  Value<DateTime> modifiedAt,
  Value<int> rowid,
});

class $$TaskListsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInbox => $composableBuilder(
    column: $table.isInbox,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskListsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInbox => $composableBuilder(
    column: $table.isInbox,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<bool> get isInbox =>
      $composableBuilder(column: $table.isInbox, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );
}

class $$TaskListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskListsTable,
          TaskListRow,
          $$TaskListsTableFilterComposer,
          $$TaskListsTableOrderingComposer,
          $$TaskListsTableAnnotationComposer,
          $$TaskListsTableCreateCompanionBuilder,
          $$TaskListsTableUpdateCompanionBuilder,
          (
            TaskListRow,
            BaseReferences<_$AppDatabase, $TaskListsTable, TaskListRow>,
          ),
          TaskListRow,
          PrefetchHooks Function()
        > {
  $$TaskListsTableTableManager(_$AppDatabase db, $TaskListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> syncId = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<bool> isInbox = const Value.absent(),
                Value<String> etag = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> modifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskListsCompanion(
                syncId: syncId,
                folderId: folderId,
                name: name,
                color: color,
                kind: kind,
                orderIndex: orderIndex,
                pinned: pinned,
                isInbox: isInbox,
                etag: etag,
                version: version,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String syncId,
                Value<String?> folderId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<bool> isInbox = const Value.absent(),
                Value<String> etag = const Value.absent(),
                Value<int> version = const Value.absent(),
                required DateTime modifiedAt,
                Value<int> rowid = const Value.absent(),
              }) => TaskListsCompanion.insert(
                syncId: syncId,
                folderId: folderId,
                name: name,
                color: color,
                kind: kind,
                orderIndex: orderIndex,
                pinned: pinned,
                isInbox: isInbox,
                etag: etag,
                version: version,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskListsTable, TaskListRow>(table),
                  BaseReferences<_$AppDatabase, $TaskListsTable, TaskListRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskListsTable,
      TaskListRow,
      $$TaskListsTableFilterComposer,
      $$TaskListsTableOrderingComposer,
      $$TaskListsTableAnnotationComposer,
      $$TaskListsTableCreateCompanionBuilder,
      $$TaskListsTableUpdateCompanionBuilder,
      (
        TaskListRow,
        BaseReferences<_$AppDatabase, $TaskListsTable, TaskListRow>,
      ),
      TaskListRow,
      PrefetchHooks Function()
    >;
typedef $$TaskSectionsTableCreateCompanionBuilder =
    TaskSectionsCompanion Function({
      required String syncId,
      Value<String> listId,
      Value<String> name,
      Value<int> orderIndex,
      Value<String> etag,
      Value<int> version,
      required DateTime modifiedAt,
      Value<int> rowid,
    });
typedef $$TaskSectionsTableUpdateCompanionBuilder =
    TaskSectionsCompanion Function({
      Value<String> syncId,
      Value<String> listId,
      Value<String> name,
      Value<int> orderIndex,
      Value<String> etag,
      Value<int> version,
      Value<DateTime> modifiedAt,
      Value<int> rowid,
    });

class $$TaskSectionsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskSectionsTable> {
  $$TaskSectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskSectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskSectionsTable> {
  $$TaskSectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskSectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskSectionsTable> {
  $$TaskSectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );
}

class $$TaskSectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskSectionsTable,
          TaskSectionRow,
          $$TaskSectionsTableFilterComposer,
          $$TaskSectionsTableOrderingComposer,
          $$TaskSectionsTableAnnotationComposer,
          $$TaskSectionsTableCreateCompanionBuilder,
          $$TaskSectionsTableUpdateCompanionBuilder,
          (
            TaskSectionRow,
            BaseReferences<_$AppDatabase, $TaskSectionsTable, TaskSectionRow>,
          ),
          TaskSectionRow,
          PrefetchHooks Function()
        > {
  $$TaskSectionsTableTableManager(_$AppDatabase db, $TaskSectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskSectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskSectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskSectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> syncId = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> etag = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> modifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskSectionsCompanion(
                syncId: syncId,
                listId: listId,
                name: name,
                orderIndex: orderIndex,
                etag: etag,
                version: version,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String syncId,
                Value<String> listId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> etag = const Value.absent(),
                Value<int> version = const Value.absent(),
                required DateTime modifiedAt,
                Value<int> rowid = const Value.absent(),
              }) => TaskSectionsCompanion.insert(
                syncId: syncId,
                listId: listId,
                name: name,
                orderIndex: orderIndex,
                etag: etag,
                version: version,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskSectionsTable, TaskSectionRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TaskSectionsTable,
                    TaskSectionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskSectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskSectionsTable,
      TaskSectionRow,
      $$TaskSectionsTableFilterComposer,
      $$TaskSectionsTableOrderingComposer,
      $$TaskSectionsTableAnnotationComposer,
      $$TaskSectionsTableCreateCompanionBuilder,
      $$TaskSectionsTableUpdateCompanionBuilder,
      (
        TaskSectionRow,
        BaseReferences<_$AppDatabase, $TaskSectionsTable, TaskSectionRow>,
      ),
      TaskSectionRow,
      PrefetchHooks Function()
    >;
typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  required String syncId,
  Value<String> name,
  Value<int> orderIndex,
  Value<String> etag,
  Value<int> version,
  required DateTime modifiedAt,
  Value<int> rowid,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<String> syncId,
  Value<String> name,
  Value<int> orderIndex,
  Value<String> etag,
  Value<int> version,
  Value<DateTime> modifiedAt,
  Value<int> rowid,
});

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          FolderRow,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (FolderRow, BaseReferences<_$AppDatabase, $FoldersTable, FolderRow>),
          FolderRow,
          PrefetchHooks Function()
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> syncId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> etag = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> modifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                syncId: syncId,
                name: name,
                orderIndex: orderIndex,
                etag: etag,
                version: version,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String syncId,
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> etag = const Value.absent(),
                Value<int> version = const Value.absent(),
                required DateTime modifiedAt,
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                syncId: syncId,
                name: name,
                orderIndex: orderIndex,
                etag: etag,
                version: version,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoldersTable, FolderRow>(table),
                  BaseReferences<_$AppDatabase, $FoldersTable, FolderRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      FolderRow,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (FolderRow, BaseReferences<_$AppDatabase, $FoldersTable, FolderRow>),
      FolderRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String opId,
  Value<String> entity,
  Value<String> entityId,
  Value<String> op,
  Value<String> patch,
  Value<String?> baseEtag,
  Value<int> attempts,
  Value<DateTime> nextTryAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> opId,
  Value<String> entity,
  Value<String> entityId,
  Value<String> op,
  Value<String> patch,
  Value<String?> baseEtag,
  Value<int> attempts,
  Value<DateTime> nextTryAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patch => $composableBuilder(
    column: $table.patch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseEtag => $composableBuilder(
    column: $table.baseEtag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextTryAt => $composableBuilder(
    column: $table.nextTryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patch => $composableBuilder(
    column: $table.patch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseEtag => $composableBuilder(
    column: $table.baseEtag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextTryAt => $composableBuilder(
    column: $table.nextTryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get patch =>
      $composableBuilder(column: $table.patch, builder: (column) => column);

  GeneratedColumn<String> get baseEtag =>
      $composableBuilder(column: $table.baseEtag, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextTryAt =>
      $composableBuilder(column: $table.nextTryAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> opId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> patch = const Value.absent(),
                Value<String?> baseEtag = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> nextTryAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                opId: opId,
                entity: entity,
                entityId: entityId,
                op: op,
                patch: patch,
                baseEtag: baseEtag,
                attempts: attempts,
                nextTryAt: nextTryAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String opId,
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> patch = const Value.absent(),
                Value<String?> baseEtag = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> nextTryAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                opId: opId,
                entity: entity,
                entityId: entityId,
                op: op,
                patch: patch,
                baseEtag: baseEtag,
                attempts: attempts,
                nextTryAt: nextTryAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxRow>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$ConflictsTableCreateCompanionBuilder = ConflictsCompanion Function({
  required String entity,
  required String entityId,
  Value<String> localPatch,
  Value<String> remote,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ConflictsTableUpdateCompanionBuilder = ConflictsCompanion Function({
  Value<String> entity,
  Value<String> entityId,
  Value<String> localPatch,
  Value<String> remote,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $ConflictsTable> {
  $$ConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPatch => $composableBuilder(
    column: $table.localPatch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remote => $composableBuilder(
    column: $table.remote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConflictsTable> {
  $$ConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPatch => $composableBuilder(
    column: $table.localPatch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remote => $composableBuilder(
    column: $table.remote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConflictsTable> {
  $$ConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get localPatch => $composableBuilder(
    column: $table.localPatch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remote =>
      $composableBuilder(column: $table.remote, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConflictsTable,
          ConflictRow,
          $$ConflictsTableFilterComposer,
          $$ConflictsTableOrderingComposer,
          $$ConflictsTableAnnotationComposer,
          $$ConflictsTableCreateCompanionBuilder,
          $$ConflictsTableUpdateCompanionBuilder,
          (
            ConflictRow,
            BaseReferences<_$AppDatabase, $ConflictsTable, ConflictRow>,
          ),
          ConflictRow,
          PrefetchHooks Function()
        > {
  $$ConflictsTableTableManager(_$AppDatabase db, $ConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> localPatch = const Value.absent(),
                Value<String> remote = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConflictsCompanion(
                entity: entity,
                entityId: entityId,
                localPatch: localPatch,
                remote: remote,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                required String entityId,
                Value<String> localPatch = const Value.absent(),
                Value<String> remote = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConflictsCompanion.insert(
                entity: entity,
                entityId: entityId,
                localPatch: localPatch,
                remote: remote,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConflictsTable, ConflictRow>(table),
                  BaseReferences<_$AppDatabase, $ConflictsTable, ConflictRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConflictsTable,
      ConflictRow,
      $$ConflictsTableFilterComposer,
      $$ConflictsTableOrderingComposer,
      $$ConflictsTableAnnotationComposer,
      $$ConflictsTableCreateCompanionBuilder,
      $$ConflictsTableUpdateCompanionBuilder,
      (
        ConflictRow,
        BaseReferences<_$AppDatabase, $ConflictsTable, ConflictRow>,
      ),
      ConflictRow,
      PrefetchHooks Function()
    >;
typedef $$HabitOutboxTableCreateCompanionBuilder =
    HabitOutboxCompanion Function({
      Value<int> seq,
      required String opId,
      Value<String> action,
      required int habitId,
      Value<String?> payload,
      Value<int?> stamp,
      Value<DateTime> createdAt,
    });
typedef $$HabitOutboxTableUpdateCompanionBuilder =
    HabitOutboxCompanion Function({
      Value<int> seq,
      Value<String> opId,
      Value<String> action,
      Value<int> habitId,
      Value<String?> payload,
      Value<int?> stamp,
      Value<DateTime> createdAt,
    });

class $$HabitOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $HabitOutboxTable> {
  $$HabitOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitOutboxTable> {
  $$HabitOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitOutboxTable> {
  $$HabitOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<int> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get stamp =>
      $composableBuilder(column: $table.stamp, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$HabitOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitOutboxTable,
          HabitOutboxRow,
          $$HabitOutboxTableFilterComposer,
          $$HabitOutboxTableOrderingComposer,
          $$HabitOutboxTableAnnotationComposer,
          $$HabitOutboxTableCreateCompanionBuilder,
          $$HabitOutboxTableUpdateCompanionBuilder,
          (
            HabitOutboxRow,
            BaseReferences<_$AppDatabase, $HabitOutboxTable, HabitOutboxRow>,
          ),
          HabitOutboxRow,
          PrefetchHooks Function()
        > {
  $$HabitOutboxTableTableManager(_$AppDatabase db, $HabitOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> opId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<int> habitId = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<int?> stamp = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => HabitOutboxCompanion(
                seq: seq,
                opId: opId,
                action: action,
                habitId: habitId,
                payload: payload,
                stamp: stamp,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String opId,
                Value<String> action = const Value.absent(),
                required int habitId,
                Value<String?> payload = const Value.absent(),
                Value<int?> stamp = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => HabitOutboxCompanion.insert(
                seq: seq,
                opId: opId,
                action: action,
                habitId: habitId,
                payload: payload,
                stamp: stamp,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitOutboxTable, HabitOutboxRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $HabitOutboxTable,
                    HabitOutboxRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitOutboxTable,
      HabitOutboxRow,
      $$HabitOutboxTableFilterComposer,
      $$HabitOutboxTableOrderingComposer,
      $$HabitOutboxTableAnnotationComposer,
      $$HabitOutboxTableCreateCompanionBuilder,
      $$HabitOutboxTableUpdateCompanionBuilder,
      (
        HabitOutboxRow,
        BaseReferences<_$AppDatabase, $HabitOutboxTable, HabitOutboxRow>,
      ),
      HabitOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$CountdownOutboxTableCreateCompanionBuilder =
    CountdownOutboxCompanion Function({
      Value<int> seq,
      required String opId,
      Value<String> action,
      required int countdownId,
      Value<String?> payload,
      Value<DateTime> createdAt,
    });
typedef $$CountdownOutboxTableUpdateCompanionBuilder =
    CountdownOutboxCompanion Function({
      Value<int> seq,
      Value<String> opId,
      Value<String> action,
      Value<int> countdownId,
      Value<String?> payload,
      Value<DateTime> createdAt,
    });

class $$CountdownOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $CountdownOutboxTable> {
  $$CountdownOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get countdownId => $composableBuilder(
    column: $table.countdownId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CountdownOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $CountdownOutboxTable> {
  $$CountdownOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get countdownId => $composableBuilder(
    column: $table.countdownId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CountdownOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $CountdownOutboxTable> {
  $$CountdownOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<int> get countdownId => $composableBuilder(
    column: $table.countdownId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CountdownOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CountdownOutboxTable,
          CountdownOutboxRow,
          $$CountdownOutboxTableFilterComposer,
          $$CountdownOutboxTableOrderingComposer,
          $$CountdownOutboxTableAnnotationComposer,
          $$CountdownOutboxTableCreateCompanionBuilder,
          $$CountdownOutboxTableUpdateCompanionBuilder,
          (
            CountdownOutboxRow,
            BaseReferences<
              _$AppDatabase,
              $CountdownOutboxTable,
              CountdownOutboxRow
            >,
          ),
          CountdownOutboxRow,
          PrefetchHooks Function()
        > {
  $$CountdownOutboxTableTableManager(
    _$AppDatabase db,
    $CountdownOutboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CountdownOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CountdownOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CountdownOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> opId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<int> countdownId = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CountdownOutboxCompanion(
                seq: seq,
                opId: opId,
                action: action,
                countdownId: countdownId,
                payload: payload,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String opId,
                Value<String> action = const Value.absent(),
                required int countdownId,
                Value<String?> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CountdownOutboxCompanion.insert(
                seq: seq,
                opId: opId,
                action: action,
                countdownId: countdownId,
                payload: payload,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CountdownOutboxTable, CountdownOutboxRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CountdownOutboxTable,
                    CountdownOutboxRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CountdownOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CountdownOutboxTable,
      CountdownOutboxRow,
      $$CountdownOutboxTableFilterComposer,
      $$CountdownOutboxTableOrderingComposer,
      $$CountdownOutboxTableAnnotationComposer,
      $$CountdownOutboxTableCreateCompanionBuilder,
      $$CountdownOutboxTableUpdateCompanionBuilder,
      (
        CountdownOutboxRow,
        BaseReferences<
          _$AppDatabase,
          $CountdownOutboxTable,
          CountdownOutboxRow
        >,
      ),
      CountdownOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$HabitsTableCreateCompanionBuilder = HabitsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> icon,
  Value<String> color,
  Value<int> sectionId,
  Value<int> status,
  Value<double> goal,
  Value<double> step,
  Value<String> unit,
  Value<String> frequency,
  Value<String> reminders,
  Value<bool> recordEnable,
  Value<String> exDates,
  Value<String> style,
  Value<int> startDate,
  Value<int> targetDays,
  Value<int> completedCycles,
  Value<int> totalCheckIns,
  Value<int> currentStreak,
  Value<int> maxStreak,
  Value<bool> dueToday,
  Value<bool> doneToday,
});
typedef $$HabitsTableUpdateCompanionBuilder = HabitsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> icon,
  Value<String> color,
  Value<int> sectionId,
  Value<int> status,
  Value<double> goal,
  Value<double> step,
  Value<String> unit,
  Value<String> frequency,
  Value<String> reminders,
  Value<bool> recordEnable,
  Value<String> exDates,
  Value<String> style,
  Value<int> startDate,
  Value<int> targetDays,
  Value<int> completedCycles,
  Value<int> totalCheckIns,
  Value<int> currentStreak,
  Value<int> maxStreak,
  Value<bool> dueToday,
  Value<bool> doneToday,
});

class $$HabitsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get step => $composableBuilder(
    column: $table.step,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get recordEnable => $composableBuilder(
    column: $table.recordEnable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exDates => $composableBuilder(
    column: $table.exDates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetDays => $composableBuilder(
    column: $table.targetDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedCycles => $composableBuilder(
    column: $table.completedCycles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCheckIns => $composableBuilder(
    column: $table.totalCheckIns,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxStreak => $composableBuilder(
    column: $table.maxStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dueToday => $composableBuilder(
    column: $table.dueToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get doneToday => $composableBuilder(
    column: $table.doneToday,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get step => $composableBuilder(
    column: $table.step,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get recordEnable => $composableBuilder(
    column: $table.recordEnable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exDates => $composableBuilder(
    column: $table.exDates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetDays => $composableBuilder(
    column: $table.targetDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedCycles => $composableBuilder(
    column: $table.completedCycles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCheckIns => $composableBuilder(
    column: $table.totalCheckIns,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxStreak => $composableBuilder(
    column: $table.maxStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dueToday => $composableBuilder(
    column: $table.dueToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get doneToday => $composableBuilder(
    column: $table.doneToday,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get goal =>
      $composableBuilder(column: $table.goal, builder: (column) => column);

  GeneratedColumn<double> get step =>
      $composableBuilder(column: $table.step, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<String> get reminders =>
      $composableBuilder(column: $table.reminders, builder: (column) => column);

  GeneratedColumn<bool> get recordEnable => $composableBuilder(
    column: $table.recordEnable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exDates =>
      $composableBuilder(column: $table.exDates, builder: (column) => column);

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<int> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<int> get targetDays => $composableBuilder(
    column: $table.targetDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedCycles => $composableBuilder(
    column: $table.completedCycles,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCheckIns => $composableBuilder(
    column: $table.totalCheckIns,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxStreak =>
      $composableBuilder(column: $table.maxStreak, builder: (column) => column);

  GeneratedColumn<bool> get dueToday =>
      $composableBuilder(column: $table.dueToday, builder: (column) => column);

  GeneratedColumn<bool> get doneToday =>
      $composableBuilder(column: $table.doneToday, builder: (column) => column);
}

class $$HabitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitsTable,
          HabitRow,
          $$HabitsTableFilterComposer,
          $$HabitsTableOrderingComposer,
          $$HabitsTableAnnotationComposer,
          $$HabitsTableCreateCompanionBuilder,
          $$HabitsTableUpdateCompanionBuilder,
          (HabitRow, BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>),
          HabitRow,
          PrefetchHooks Function()
        > {
  $$HabitsTableTableManager(_$AppDatabase db, $HabitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int> sectionId = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<double> goal = const Value.absent(),
                Value<double> step = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<String> reminders = const Value.absent(),
                Value<bool> recordEnable = const Value.absent(),
                Value<String> exDates = const Value.absent(),
                Value<String> style = const Value.absent(),
                Value<int> startDate = const Value.absent(),
                Value<int> targetDays = const Value.absent(),
                Value<int> completedCycles = const Value.absent(),
                Value<int> totalCheckIns = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> maxStreak = const Value.absent(),
                Value<bool> dueToday = const Value.absent(),
                Value<bool> doneToday = const Value.absent(),
              }) => HabitsCompanion(
                id: id,
                name: name,
                icon: icon,
                color: color,
                sectionId: sectionId,
                status: status,
                goal: goal,
                step: step,
                unit: unit,
                frequency: frequency,
                reminders: reminders,
                recordEnable: recordEnable,
                exDates: exDates,
                style: style,
                startDate: startDate,
                targetDays: targetDays,
                completedCycles: completedCycles,
                totalCheckIns: totalCheckIns,
                currentStreak: currentStreak,
                maxStreak: maxStreak,
                dueToday: dueToday,
                doneToday: doneToday,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int> sectionId = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<double> goal = const Value.absent(),
                Value<double> step = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<String> reminders = const Value.absent(),
                Value<bool> recordEnable = const Value.absent(),
                Value<String> exDates = const Value.absent(),
                Value<String> style = const Value.absent(),
                Value<int> startDate = const Value.absent(),
                Value<int> targetDays = const Value.absent(),
                Value<int> completedCycles = const Value.absent(),
                Value<int> totalCheckIns = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> maxStreak = const Value.absent(),
                Value<bool> dueToday = const Value.absent(),
                Value<bool> doneToday = const Value.absent(),
              }) => HabitsCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                color: color,
                sectionId: sectionId,
                status: status,
                goal: goal,
                step: step,
                unit: unit,
                frequency: frequency,
                reminders: reminders,
                recordEnable: recordEnable,
                exDates: exDates,
                style: style,
                startDate: startDate,
                targetDays: targetDays,
                completedCycles: completedCycles,
                totalCheckIns: totalCheckIns,
                currentStreak: currentStreak,
                maxStreak: maxStreak,
                dueToday: dueToday,
                doneToday: doneToday,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitsTable, HabitRow>(table),
                  BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitsTable,
      HabitRow,
      $$HabitsTableFilterComposer,
      $$HabitsTableOrderingComposer,
      $$HabitsTableAnnotationComposer,
      $$HabitsTableCreateCompanionBuilder,
      $$HabitsTableUpdateCompanionBuilder,
      (HabitRow, BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>),
      HabitRow,
      PrefetchHooks Function()
    >;
typedef $$HabitCheckinsTableCreateCompanionBuilder =
    HabitCheckinsCompanion Function({
      required int habitId,
      required int checkinStamp,
      Value<double> value,
      Value<double> goal,
      Value<int> status,
      Value<int> rowid,
    });
typedef $$HabitCheckinsTableUpdateCompanionBuilder =
    HabitCheckinsCompanion Function({
      Value<int> habitId,
      Value<int> checkinStamp,
      Value<double> value,
      Value<double> goal,
      Value<int> status,
      Value<int> rowid,
    });

class $$HabitCheckinsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitCheckinsTable> {
  $$HabitCheckinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkinStamp => $composableBuilder(
    column: $table.checkinStamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitCheckinsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitCheckinsTable> {
  $$HabitCheckinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkinStamp => $composableBuilder(
    column: $table.checkinStamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitCheckinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitCheckinsTable> {
  $$HabitCheckinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<int> get checkinStamp => $composableBuilder(
    column: $table.checkinStamp,
    builder: (column) => column,
  );

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<double> get goal =>
      $composableBuilder(column: $table.goal, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$HabitCheckinsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitCheckinsTable,
          HabitCheckinRow,
          $$HabitCheckinsTableFilterComposer,
          $$HabitCheckinsTableOrderingComposer,
          $$HabitCheckinsTableAnnotationComposer,
          $$HabitCheckinsTableCreateCompanionBuilder,
          $$HabitCheckinsTableUpdateCompanionBuilder,
          (
            HabitCheckinRow,
            BaseReferences<_$AppDatabase, $HabitCheckinsTable, HabitCheckinRow>,
          ),
          HabitCheckinRow,
          PrefetchHooks Function()
        > {
  $$HabitCheckinsTableTableManager(_$AppDatabase db, $HabitCheckinsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitCheckinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitCheckinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitCheckinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> habitId = const Value.absent(),
                Value<int> checkinStamp = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<double> goal = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitCheckinsCompanion(
                habitId: habitId,
                checkinStamp: checkinStamp,
                value: value,
                goal: goal,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int habitId,
                required int checkinStamp,
                Value<double> value = const Value.absent(),
                Value<double> goal = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitCheckinsCompanion.insert(
                habitId: habitId,
                checkinStamp: checkinStamp,
                value: value,
                goal: goal,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitCheckinsTable, HabitCheckinRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $HabitCheckinsTable,
                    HabitCheckinRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitCheckinsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitCheckinsTable,
      HabitCheckinRow,
      $$HabitCheckinsTableFilterComposer,
      $$HabitCheckinsTableOrderingComposer,
      $$HabitCheckinsTableAnnotationComposer,
      $$HabitCheckinsTableCreateCompanionBuilder,
      $$HabitCheckinsTableUpdateCompanionBuilder,
      (
        HabitCheckinRow,
        BaseReferences<_$AppDatabase, $HabitCheckinsTable, HabitCheckinRow>,
      ),
      HabitCheckinRow,
      PrefetchHooks Function()
    >;
typedef $$HabitSectionsTableCreateCompanionBuilder =
    HabitSectionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> sortOrder,
    });
typedef $$HabitSectionsTableUpdateCompanionBuilder =
    HabitSectionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> sortOrder,
    });

class $$HabitSectionsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitSectionsTable> {
  $$HabitSectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitSectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitSectionsTable> {
  $$HabitSectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitSectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitSectionsTable> {
  $$HabitSectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$HabitSectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitSectionsTable,
          HabitSectionRow,
          $$HabitSectionsTableFilterComposer,
          $$HabitSectionsTableOrderingComposer,
          $$HabitSectionsTableAnnotationComposer,
          $$HabitSectionsTableCreateCompanionBuilder,
          $$HabitSectionsTableUpdateCompanionBuilder,
          (
            HabitSectionRow,
            BaseReferences<_$AppDatabase, $HabitSectionsTable, HabitSectionRow>,
          ),
          HabitSectionRow,
          PrefetchHooks Function()
        > {
  $$HabitSectionsTableTableManager(_$AppDatabase db, $HabitSectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitSectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitSectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitSectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => HabitSectionsCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => HabitSectionsCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitSectionsTable, HabitSectionRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $HabitSectionsTable,
                    HabitSectionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitSectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitSectionsTable,
      HabitSectionRow,
      $$HabitSectionsTableFilterComposer,
      $$HabitSectionsTableOrderingComposer,
      $$HabitSectionsTableAnnotationComposer,
      $$HabitSectionsTableCreateCompanionBuilder,
      $$HabitSectionsTableUpdateCompanionBuilder,
      (
        HabitSectionRow,
        BaseReferences<_$AppDatabase, $HabitSectionsTable, HabitSectionRow>,
      ),
      HabitSectionRow,
      PrefetchHooks Function()
    >;
typedef $$CountdownsTableCreateCompanionBuilder = CountdownsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> type,
  Value<int> date,
  Value<String> repeat,
  Value<bool> pinned,
  Value<int> status,
  Value<String> color,
  Value<String> icon,
  Value<String> remark,
  Value<int> days,
  Value<int> hours,
  Value<int> minutes,
  Value<int> seconds,
  Value<String> state,
  Value<int> occurrenceDate,
  Value<int> age,
});
typedef $$CountdownsTableUpdateCompanionBuilder = CountdownsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> type,
  Value<int> date,
  Value<String> repeat,
  Value<bool> pinned,
  Value<int> status,
  Value<String> color,
  Value<String> icon,
  Value<String> remark,
  Value<int> days,
  Value<int> hours,
  Value<int> minutes,
  Value<int> seconds,
  Value<String> state,
  Value<int> occurrenceDate,
  Value<int> age,
});

class $$CountdownsTableFilterComposer
    extends Composer<_$AppDatabase, $CountdownsTable> {
  $$CountdownsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hours => $composableBuilder(
    column: $table.hours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minutes => $composableBuilder(
    column: $table.minutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seconds => $composableBuilder(
    column: $table.seconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CountdownsTableOrderingComposer
    extends Composer<_$AppDatabase, $CountdownsTable> {
  $$CountdownsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hours => $composableBuilder(
    column: $table.hours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minutes => $composableBuilder(
    column: $table.minutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seconds => $composableBuilder(
    column: $table.seconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CountdownsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CountdownsTable> {
  $$CountdownsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get repeat =>
      $composableBuilder(column: $table.repeat, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<int> get days =>
      $composableBuilder(column: $table.days, builder: (column) => column);

  GeneratedColumn<int> get hours =>
      $composableBuilder(column: $table.hours, builder: (column) => column);

  GeneratedColumn<int> get minutes =>
      $composableBuilder(column: $table.minutes, builder: (column) => column);

  GeneratedColumn<int> get seconds =>
      $composableBuilder(column: $table.seconds, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);
}

class $$CountdownsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CountdownsTable,
          CountdownRow,
          $$CountdownsTableFilterComposer,
          $$CountdownsTableOrderingComposer,
          $$CountdownsTableAnnotationComposer,
          $$CountdownsTableCreateCompanionBuilder,
          $$CountdownsTableUpdateCompanionBuilder,
          (
            CountdownRow,
            BaseReferences<_$AppDatabase, $CountdownsTable, CountdownRow>,
          ),
          CountdownRow,
          PrefetchHooks Function()
        > {
  $$CountdownsTableTableManager(_$AppDatabase db, $CountdownsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CountdownsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CountdownsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CountdownsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> date = const Value.absent(),
                Value<String> repeat = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> remark = const Value.absent(),
                Value<int> days = const Value.absent(),
                Value<int> hours = const Value.absent(),
                Value<int> minutes = const Value.absent(),
                Value<int> seconds = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> occurrenceDate = const Value.absent(),
                Value<int> age = const Value.absent(),
              }) => CountdownsCompanion(
                id: id,
                name: name,
                type: type,
                date: date,
                repeat: repeat,
                pinned: pinned,
                status: status,
                color: color,
                icon: icon,
                remark: remark,
                days: days,
                hours: hours,
                minutes: minutes,
                seconds: seconds,
                state: state,
                occurrenceDate: occurrenceDate,
                age: age,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> date = const Value.absent(),
                Value<String> repeat = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> remark = const Value.absent(),
                Value<int> days = const Value.absent(),
                Value<int> hours = const Value.absent(),
                Value<int> minutes = const Value.absent(),
                Value<int> seconds = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> occurrenceDate = const Value.absent(),
                Value<int> age = const Value.absent(),
              }) => CountdownsCompanion.insert(
                id: id,
                name: name,
                type: type,
                date: date,
                repeat: repeat,
                pinned: pinned,
                status: status,
                color: color,
                icon: icon,
                remark: remark,
                days: days,
                hours: hours,
                minutes: minutes,
                seconds: seconds,
                state: state,
                occurrenceDate: occurrenceDate,
                age: age,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CountdownsTable, CountdownRow>(table),
                  BaseReferences<_$AppDatabase, $CountdownsTable, CountdownRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CountdownsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CountdownsTable,
      CountdownRow,
      $$CountdownsTableFilterComposer,
      $$CountdownsTableOrderingComposer,
      $$CountdownsTableAnnotationComposer,
      $$CountdownsTableCreateCompanionBuilder,
      $$CountdownsTableUpdateCompanionBuilder,
      (
        CountdownRow,
        BaseReferences<_$AppDatabase, $CountdownsTable, CountdownRow>,
      ),
      CountdownRow,
      PrefetchHooks Function()
    >;
typedef $$FocusSessionsTableCreateCompanionBuilder =
    FocusSessionsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> mode,
      Value<DateTime?> startedAt,
      Value<DateTime?> endedAt,
      Value<int> durationSeconds,
      Value<int> pomodoroCount,
    });
typedef $$FocusSessionsTableUpdateCompanionBuilder =
    FocusSessionsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> mode,
      Value<DateTime?> startedAt,
      Value<DateTime?> endedAt,
      Value<int> durationSeconds,
      Value<int> pomodoroCount,
    });

class $$FocusSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pomodoroCount => $composableBuilder(
    column: $table.pomodoroCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FocusSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pomodoroCount => $composableBuilder(
    column: $table.pomodoroCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FocusSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pomodoroCount => $composableBuilder(
    column: $table.pomodoroCount,
    builder: (column) => column,
  );
}

class $$FocusSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FocusSessionsTable,
          FocusSessionRow,
          $$FocusSessionsTableFilterComposer,
          $$FocusSessionsTableOrderingComposer,
          $$FocusSessionsTableAnnotationComposer,
          $$FocusSessionsTableCreateCompanionBuilder,
          $$FocusSessionsTableUpdateCompanionBuilder,
          (
            FocusSessionRow,
            BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSessionRow>,
          ),
          FocusSessionRow,
          PrefetchHooks Function()
        > {
  $$FocusSessionsTableTableManager(_$AppDatabase db, $FocusSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> pomodoroCount = const Value.absent(),
              }) => FocusSessionsCompanion(
                id: id,
                title: title,
                mode: mode,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                pomodoroCount: pomodoroCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> pomodoroCount = const Value.absent(),
              }) => FocusSessionsCompanion.insert(
                id: id,
                title: title,
                mode: mode,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                pomodoroCount: pomodoroCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FocusSessionsTable, FocusSessionRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FocusSessionsTable,
                    FocusSessionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FocusSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FocusSessionsTable,
      FocusSessionRow,
      $$FocusSessionsTableFilterComposer,
      $$FocusSessionsTableOrderingComposer,
      $$FocusSessionsTableAnnotationComposer,
      $$FocusSessionsTableCreateCompanionBuilder,
      $$FocusSessionsTableUpdateCompanionBuilder,
      (
        FocusSessionRow,
        BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSessionRow>,
      ),
      FocusSessionRow,
      PrefetchHooks Function()
    >;
typedef $$FocusOutboxTableCreateCompanionBuilder =
    FocusOutboxCompanion Function({
      Value<int> seq,
      required String opId,
      Value<String> action,
      required int sessionId,
      Value<String?> payload,
      Value<DateTime> createdAt,
    });
typedef $$FocusOutboxTableUpdateCompanionBuilder =
    FocusOutboxCompanion Function({
      Value<int> seq,
      Value<String> opId,
      Value<String> action,
      Value<int> sessionId,
      Value<String?> payload,
      Value<DateTime> createdAt,
    });

class $$FocusOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $FocusOutboxTable> {
  $$FocusOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FocusOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusOutboxTable> {
  $$FocusOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FocusOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusOutboxTable> {
  $$FocusOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<int> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FocusOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FocusOutboxTable,
          FocusOutboxRow,
          $$FocusOutboxTableFilterComposer,
          $$FocusOutboxTableOrderingComposer,
          $$FocusOutboxTableAnnotationComposer,
          $$FocusOutboxTableCreateCompanionBuilder,
          $$FocusOutboxTableUpdateCompanionBuilder,
          (
            FocusOutboxRow,
            BaseReferences<_$AppDatabase, $FocusOutboxTable, FocusOutboxRow>,
          ),
          FocusOutboxRow,
          PrefetchHooks Function()
        > {
  $$FocusOutboxTableTableManager(_$AppDatabase db, $FocusOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> opId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FocusOutboxCompanion(
                seq: seq,
                opId: opId,
                action: action,
                sessionId: sessionId,
                payload: payload,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String opId,
                Value<String> action = const Value.absent(),
                required int sessionId,
                Value<String?> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FocusOutboxCompanion.insert(
                seq: seq,
                opId: opId,
                action: action,
                sessionId: sessionId,
                payload: payload,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FocusOutboxTable, FocusOutboxRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FocusOutboxTable,
                    FocusOutboxRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FocusOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FocusOutboxTable,
      FocusOutboxRow,
      $$FocusOutboxTableFilterComposer,
      $$FocusOutboxTableOrderingComposer,
      $$FocusOutboxTableAnnotationComposer,
      $$FocusOutboxTableCreateCompanionBuilder,
      $$FocusOutboxTableUpdateCompanionBuilder,
      (
        FocusOutboxRow,
        BaseReferences<_$AppDatabase, $FocusOutboxTable, FocusOutboxRow>,
      ),
      FocusOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder = MetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$MetaTableUpdateCompanionBuilder = MetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaRow,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaTable, MetaRow>(table),
                  BaseReferences<_$AppDatabase, $MetaTable, MetaRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaRow,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$TaskListsTableTableManager get taskLists =>
      $$TaskListsTableTableManager(_db, _db.taskLists);
  $$TaskSectionsTableTableManager get taskSections =>
      $$TaskSectionsTableTableManager(_db, _db.taskSections);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$ConflictsTableTableManager get conflicts =>
      $$ConflictsTableTableManager(_db, _db.conflicts);
  $$HabitOutboxTableTableManager get habitOutbox =>
      $$HabitOutboxTableTableManager(_db, _db.habitOutbox);
  $$CountdownOutboxTableTableManager get countdownOutbox =>
      $$CountdownOutboxTableTableManager(_db, _db.countdownOutbox);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db, _db.habits);
  $$HabitCheckinsTableTableManager get habitCheckins =>
      $$HabitCheckinsTableTableManager(_db, _db.habitCheckins);
  $$HabitSectionsTableTableManager get habitSections =>
      $$HabitSectionsTableTableManager(_db, _db.habitSections);
  $$CountdownsTableTableManager get countdowns =>
      $$CountdownsTableTableManager(_db, _db.countdowns);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db, _db.focusSessions);
  $$FocusOutboxTableTableManager get focusOutbox =>
      $$FocusOutboxTableTableManager(_db, _db.focusOutbox);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
}
