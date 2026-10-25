enum TaskKind { task, note }

TaskKind taskKindFromWire(Object? raw) =>
    raw == 'NOTE' ? TaskKind.note : TaskKind.task;

String taskKindToWire(TaskKind kind) =>
    kind == TaskKind.note ? 'NOTE' : 'TASK';

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.title,
    this.done = false,
  });

  final String id;
  final String title;
  final bool done;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        done: json['done'] == true,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  ChecklistItem copyWith({String? id, String? title, bool? done}) =>
      ChecklistItem(
        id: id ?? this.id,
        title: title ?? this.title,
        done: done ?? this.done,
      );
}

/// Local representation of a synced task. Field names mirror the sync
/// protocol so patches and three-way merges stay mechanical.
class TaskItem {
  const TaskItem({
    required this.id,
    required this.listId,
    this.parentId,
    this.sectionId,
    required this.title,
    this.notes = '',
    this.notesFormat = 'text',
    this.kind = TaskKind.task,
    this.priority = 0,
    this.startAt,
    this.dueAt,
    this.allDay = false,
    this.recurrence = '',
    this.reminderOffsets = const [],
    this.tags = const [],
    this.checklist = const [],
    this.assignee = '',
    this.completedAt,
    this.pinned = false,
    this.sortOrder = 0,
    this.deleted = false,
    this.deletedAt,
    this.etag = '',
    this.version = 0,
    this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listId;
  final String? parentId;
  final String? sectionId;
  final String title;
  final String notes;
  final String notesFormat;
  final TaskKind kind;
  final int priority;
  final DateTime? startAt;
  final DateTime? dueAt;
  final bool allDay;
  final String recurrence;
  final List<int> reminderOffsets;
  final List<String> tags;
  final List<ChecklistItem> checklist;
  final String assignee;
  final DateTime? completedAt;
  final bool pinned;
  final int sortOrder;
  final bool deleted;
  final DateTime? deletedAt;
  final String etag;
  final int version;
  final DateTime? createdAt;
  final DateTime updatedAt;

  bool get completed => completedAt != null;

  /// Parses one entity from a pull response or a push result snapshot.
  factory TaskItem.fromWireJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    return TaskItem(
      id: id,
      listId: (json['listId'] ?? '').toString(),
      parentId: _nullableString(json['parentId']),
      sectionId: _nullableString(json['sectionId']),
      title: (json['title'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      notesFormat: (json['notesFormat'] ?? 'text').toString(),
      kind: taskKindFromWire(json['kind']),
      priority: _intValue(json['priority']),
      startAt: _dateValue(json['start']),
      dueAt: _dateValue(json['due']),
      allDay: json['allDay'] == true,
      recurrence: (json['recurrence'] ?? '').toString(),
      reminderOffsets: _intList(json['reminderOffsets']),
      tags: _stringList(json['tags']),
      checklist: (json['checklist'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChecklistItem.fromJson)
          .toList(growable: false),
      assignee: (json['assignee'] ?? '').toString(),
      completedAt: _dateValue(json['completedAt']),
      pinned: json['pinned'] == true,
      sortOrder: _intValue(json['order']),
      deleted: json['deleted'] == true,
      deletedAt: _dateValue(json['deletedAt']),
      etag: (json['etag'] ?? '').toString(),
      version: _intValue(json['version']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['modifiedAt']) ?? DateTime.now().toUtc(),
    );
  }

  /// Full wire representation used for merging and for create patches.
  Map<String, dynamic> toWireJson() => {
        'id': id,
        'listId': listId,
        if (parentId != null) 'parentId': parentId,
        if (sectionId != null) 'sectionId': sectionId,
        'title': title,
        'notes': notes,
        'notesFormat': notesFormat,
        'kind': taskKindToWire(kind),
        'priority': priority,
        if (startAt != null) 'start': startAt!.toUtc().toIso8601String(),
        if (dueAt != null) 'due': dueAt!.toUtc().toIso8601String(),
        'allDay': allDay,
        'recurrence': recurrence,
        'reminderOffsets': reminderOffsets,
        'tags': tags,
        'checklist': checklist.map((item) => item.toJson()).toList(),
        'assignee': assignee,
        'completed': completed,
        if (completedAt != null)
          'completedAt': completedAt!.toUtc().toIso8601String(),
        'pinned': pinned,
        'order': sortOrder,
        'deleted': deleted,
        if (deletedAt != null)
          'deletedAt': deletedAt!.toUtc().toIso8601String(),
        'etag': etag,
        'version': version,
        if (createdAt != null)
          'createdAt': createdAt!.toUtc().toIso8601String(),
        'modifiedAt': updatedAt.toUtc().toIso8601String(),
      };

  TaskItem copyWith({
    String? listId,
    String? parentId,
    bool clearParent = false,
    String? sectionId,
    bool clearSection = false,
    String? title,
    String? notes,
    String? notesFormat,
    TaskKind? kind,
    int? priority,
    DateTime? startAt,
    bool clearStart = false,
    DateTime? dueAt,
    bool clearDue = false,
    bool? allDay,
    String? recurrence,
    List<int>? reminderOffsets,
    List<String>? tags,
    List<ChecklistItem>? checklist,
    String? assignee,
    DateTime? completedAt,
    bool clearCompleted = false,
    bool? pinned,
    int? sortOrder,
    bool? deleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? etag,
    int? version,
    DateTime? updatedAt,
  }) {
    return TaskItem(
      id: id,
      listId: listId ?? this.listId,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      sectionId: clearSection ? null : (sectionId ?? this.sectionId),
      title: title ?? this.title,
      notes: notes ?? this.notes,
      notesFormat: notesFormat ?? this.notesFormat,
      kind: kind ?? this.kind,
      priority: priority ?? this.priority,
      startAt: clearStart ? null : (startAt ?? this.startAt),
      dueAt: clearDue ? null : (dueAt ?? this.dueAt),
      allDay: allDay ?? this.allDay,
      recurrence: recurrence ?? this.recurrence,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      tags: tags ?? this.tags,
      checklist: checklist ?? this.checklist,
      assignee: assignee ?? this.assignee,
      completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
      pinned: pinned ?? this.pinned,
      sortOrder: sortOrder ?? this.sortOrder,
      deleted: deleted ?? this.deleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      etag: etag ?? this.etag,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TaskListItem {
  const TaskListItem({
    required this.id,
    this.folderId,
    required this.name,
    this.color = '',
    this.kind = TaskKind.task,
    this.sortOrder = 0,
    this.pinned = false,
    this.isInbox = false,
    this.etag = '',
    this.version = 0,
    required this.updatedAt,
  });

  final String id;
  final String? folderId;
  final String name;
  final String color;
  final TaskKind kind;
  final int sortOrder;
  final bool pinned;
  final bool isInbox;
  final String etag;
  final int version;
  final DateTime updatedAt;

  factory TaskListItem.fromWireJson(Map<String, dynamic> json) => TaskListItem(
        id: (json['id'] ?? '').toString(),
        folderId: _nullableString(json['folderId']),
        name: (json['name'] ?? '').toString(),
        color: (json['color'] ?? '').toString(),
        kind: taskKindFromWire(json['kind']),
        sortOrder: _intValue(json['order']),
        pinned: json['pinned'] == true,
        isInbox: json['isInbox'] == true,
        etag: (json['etag'] ?? '').toString(),
        version: _intValue(json['version']),
        updatedAt: _dateValue(json['modifiedAt']) ?? DateTime.now().toUtc(),
      );

  Map<String, dynamic> toWireJson() => {
        'id': id,
        if (folderId != null) 'folderId': folderId,
        'name': name,
        'color': color,
        'kind': taskKindToWire(kind),
        'order': sortOrder,
        'pinned': pinned,
        'isInbox': isInbox,
        'etag': etag,
        'version': version,
        'modifiedAt': updatedAt.toUtc().toIso8601String(),
      };

  TaskListItem copyWith({
    String? folderId,
    bool clearFolder = false,
    String? name,
    String? color,
    bool? pinned,
    int? sortOrder,
    String? etag,
    int? version,
    DateTime? updatedAt,
  }) {
    return TaskListItem(
      id: id,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      name: name ?? this.name,
      color: color ?? this.color,
      kind: kind,
      sortOrder: sortOrder ?? this.sortOrder,
      pinned: pinned ?? this.pinned,
      isInbox: isInbox,
      etag: etag ?? this.etag,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateValue(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}

List<int> _intList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item is int ? item : int.tryParse(item.toString()))
      .whereType<int>()
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
