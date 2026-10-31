import '../core/ids.dart';
import '../core/models.dart';
import 'db/local_store.dart';

/// Local writes only. Every mutation updates the local row and the outbox in
/// one persisted batch; the UI never talks to the network directly.
class TaskRepository {
  TaskRepository(this.store);

  final LocalStore store;

  void Function()? onLocalChange;

  Future<TaskItem> createTask({
    required String title,
    required String listId,
    int sortOrder = 0,
    DateTime? dueAt,
    bool allDay = false,
  }) async {
    final now = DateTime.now().toUtc();
    final task = TaskItem(
      id: newSyncId(),
      listId: listId,
      title: title.trim(),
      notes: '',
      kind: TaskKind.task,
      dueAt: dueAt,
      allDay: allDay,
      updatedAt: now,
      createdAt: now,
      sortOrder: sortOrder,
    );
    final patch = <String, dynamic>{
      'listId': listId,
      'title': task.title,
      'notes': '',
      'notesFormat': 'text',
      'kind': 'TASK',
      'priority': 0,
      'allDay': allDay,
      'recurrence': '',
      'reminderOffsets': const <int>[],
      'tags': const <String>[],
      'checklist': const <dynamic>[],
      'assignee': '',
      'completed': false,
      'pinned': false,
      'order': sortOrder,
      if (dueAt != null) 'due': dueAt.toUtc().toIso8601String(),
    };
    await store.batch(() async {
      await store.saveTask(task, dirty: true);
      await store.saveOp(
        opId: newSyncId(),
        entity: 'task',
        entityId: task.id,
        action: 'create',
        patch: patch,
      );
    });
    onLocalChange?.call();
    return task;
  }

  Future<void> updateTitle(String id, String title) async {
    final task = store.task(id);
    final value = title.trim();
    if (task == null || value.isEmpty || task.title == value) return;
    await _patch(task, {'title': value}, task.copyWith(title: value));
  }

  Future<void> updateNotes(String id, String notes) async {
    final task = store.task(id);
    if (task == null || task.notes == notes) return;
    await _patch(task, {'notes': notes}, task.copyWith(notes: notes));
  }

  /// Saves the editable task fields as a minimal patch.
  ///
  /// Only fields that actually changed are sent, so a concurrent server edit
  /// to an untouched field survives a later conflict merge.
  Future<void> saveEdits(
    String id, {
    required TaskItem baseline,
    required String title,
    required String notes,
    required DateTime? startAt,
    required DateTime? dueAt,
    required bool allDay,
    required int priority,
    required List<int> reminderOffsets,
    required bool pinned,
    required String recurrence,
    required List<String> tags,
    required List<ChecklistItem> checklist,
    String? listId,
  }) async {
    final current = store.task(id);
    if (current == null) return;
    final newTitle = title.trim();
    if (newTitle.isEmpty) {
      throw const FormatException('任务标题不能为空');
    }
    final normalizedTags = _normalizeTags(tags);
    final patch = <String, dynamic>{};
    var updated = current;

    // Compare with the editor's baseline, not the current row: a remote change
    // to a field the user did not touch must survive.
    if (baseline.title != newTitle) {
      patch['title'] = newTitle;
      updated = updated.copyWith(title: newTitle);
    }
    if (baseline.notes != notes) {
      patch['notes'] = notes;
      updated = updated.copyWith(notes: notes);
    }
    if (!_sameInstant(baseline.startAt, startAt)) {
      patch['start'] = startAt?.toUtc().toIso8601String();
      updated = updated.copyWith(startAt: startAt, clearStart: startAt == null);
    }
    final dueChanged = !_sameInstant(baseline.dueAt, dueAt);
    if (dueChanged || baseline.allDay != allDay) {
      patch['due'] = dueAt?.toUtc().toIso8601String();
      patch['allDay'] = allDay;
      updated = updated.copyWith(
        dueAt: dueAt,
        clearDue: dueAt == null,
        allDay: allDay,
      );
    }
    if (baseline.priority != priority) {
      patch['priority'] = priority;
      updated = updated.copyWith(priority: priority);
    }
    final normalizedReminders = _normalizeReminders(reminderOffsets);
    if (!_sameInts(baseline.reminderOffsets, normalizedReminders)) {
      patch['reminderOffsets'] = normalizedReminders;
      updated = updated.copyWith(reminderOffsets: normalizedReminders);
    }
    if (baseline.pinned != pinned) {
      patch['pinned'] = pinned;
      updated = updated.copyWith(pinned: pinned);
    }
    final normalizedRecurrence = recurrence.trim();
    if (baseline.recurrence != normalizedRecurrence) {
      patch['recurrence'] = normalizedRecurrence;
      updated = updated.copyWith(recurrence: normalizedRecurrence);
    }
    if (listId != null && baseline.listId != listId) {
      final target = store.list(listId);
      if (target == null) {
        throw const FormatException('目标清单不存在');
      }
      patch['listId'] = listId;
      updated = updated.copyWith(listId: listId, clearSection: true);
    }
    if (!_sameTags(baseline.tags, normalizedTags)) {
      patch['tags'] = normalizedTags;
      updated = updated.copyWith(tags: normalizedTags);
    }
    if (!_sameChecklist(baseline.checklist, checklist)) {
      patch['checklist'] = checklist.map((item) => item.toJson()).toList();
      updated = updated.copyWith(checklist: checklist);
    }
    if (patch.isEmpty) return;
    await _patch(current, patch, updated);
  }

  Future<TaskSection> createSection({
    required String listId,
    required String name,
  }) async {
    final list = store.list(listId);
    if (list == null) {
      throw const FormatException('清单不存在');
    }
    final value = name.trim();
    if (value.isEmpty) {
      throw const FormatException('列名称不能为空');
    }
    if (store
        .sectionsSnapshot(listId: listId)
        .any((section) => section.name.toLowerCase() == value.toLowerCase())) {
      throw const FormatException('同名列已存在');
    }
    var order = 0;
    for (final section in store.sectionsSnapshot(listId: listId)) {
      if (section.sortOrder > order) order = section.sortOrder;
    }
    order += 1;
    final now = DateTime.now().toUtc();
    final section = TaskSection(
      id: newSyncId(),
      listId: listId,
      name: value,
      sortOrder: order,
      updatedAt: now,
    );
    await store.batch(() async {
      await store.saveSection(section);
      await store.saveOp(
        opId: newSyncId(),
        entity: 'section',
        entityId: section.id,
        action: 'create',
        patch: {'listId': listId, 'name': value, 'order': order},
      );
    });
    onLocalChange?.call();
    return section;
  }

  Future<void> renameSection(String id, String name) async {
    final section = store.section(id);
    if (section == null) return;
    final value = name.trim();
    if (value.isEmpty || value == section.name) return;
    final existing = store.pendingOp('section', id);
    final baseEtag = existing?.baseEtag ?? section.etag;
    final updated = section.copyWith(
      name: value,
      updatedAt: DateTime.now().toUtc(),
    );
    await store.batch(() async {
      await store.saveSection(updated);
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      await store.saveOp(
        opId: newSyncId(),
        entity: 'section',
        entityId: id,
        action: existing?.action == 'create' ? 'create' : 'update',
        patch: {...?existing?.patch, 'name': value},
        baseEtag: baseEtag,
      );
    });
    onLocalChange?.call();
  }

  Future<void> deleteSection(String id) async {
    final section = store.section(id);
    if (section == null) return;
    final existing = store.pendingOp('section', id);
    if (existing?.action == 'create') {
      await store.batch(() async {
        await store.removeOp(existing!.opId);
        await store.hardDeleteSection(id);
        await _detachSectionFromTasks(id);
      });
      onLocalChange?.call();
      return;
    }
    await store.batch(() async {
      await _detachSectionFromTasks(id);
      await store.hardDeleteSection(id);
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      await store.saveOp(
        opId: newSyncId(),
        entity: 'section',
        entityId: id,
        action: 'delete',
        patch: const {'strategy': 'move'},
        baseEtag: existing?.baseEtag ?? section.etag,
      );
    });
    onLocalChange?.call();
  }

  Future<void> _detachSectionFromTasks(String sectionId) async {
    for (final task in store.allTasks()) {
      if (task.sectionId != sectionId) continue;
      await store.saveTask(task.copyWith(clearSection: true), dirty: false);
      final op = store.pendingOp('task', task.id);
      if (op != null && op.patch.containsKey('sectionId')) {
        final patch = Map<String, dynamic>.of(op.patch)..remove('sectionId');
        await store.removeOp(op.opId);
        await store.saveOp(
          opId: newSyncId(),
          entity: 'task',
          entityId: task.id,
          action: op.action,
          patch: patch,
          baseEtag: op.baseEtag,
          attempts: op.attempts,
          nextTryAt: op.nextTryAt,
          createdAt: op.createdAt,
        );
      }
    }
  }

  Future<void> reorderSections(String listId, List<String> orderedIds) async {
    final sections = store.sectionsSnapshot(listId: listId);
    if (sections.isEmpty) return;
    final byId = {for (final section in sections) section.id: section};
    final ids = orderedIds.where(byId.containsKey).toList();
    if (ids.length != sections.length) return;
    final now = DateTime.now().toUtc();
    await store.batch(() async {
      for (var index = 0; index < ids.length; index++) {
        final section = byId[ids[index]]!;
        if (section.sortOrder == index) continue;
        final updated = section.copyWith(sortOrder: index, updatedAt: now);
        final existing = store.pendingOp('section', section.id);
        await store.saveSection(updated);
        if (existing != null) {
          await store.removeOp(existing.opId);
        }
        await store.saveOp(
          opId: newSyncId(),
          entity: 'section',
          entityId: section.id,
          action: existing?.action == 'create' ? 'create' : 'update',
          patch: {...?existing?.patch, 'order': index},
          baseEtag: existing?.baseEtag ?? section.etag,
        );
      }
    });
    onLocalChange?.call();
  }

  Future<void> reorderTasks(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    final now = DateTime.now().toUtc();
    await store.batch(() async {
      for (var index = 0; index < orderedIds.length; index++) {
        final id = orderedIds[index];
        final task = store.task(id);
        if (task == null || task.deleted || task.completed) continue;
        final existing = store.pendingOp('task', id);
        if (existing == null && task.sortOrder == index) continue;
        final updated = task.copyWith(sortOrder: index, updatedAt: now);
        await store.saveTask(updated, dirty: true);
        if (existing != null) {
          await store.removeOp(existing.opId);
        }
        await store.saveOp(
          opId: newSyncId(),
          entity: 'task',
          entityId: id,
          action: existing?.action == 'create' ? 'create' : 'update',
          patch: {...?existing?.patch, 'order': index},
          baseEtag: existing?.baseEtag ?? task.etag,
        );
      }
    });
    onLocalChange?.call();
  }

  Future<void> updatePriority(String id, int priority) async {
    final task = store.task(id);
    if (task == null || task.priority == priority) return;
    await _patch(task, {
      'priority': priority,
    }, task.copyWith(priority: priority));
  }

  Future<void> setDue(String id, DateTime? due) async {
    final task = store.task(id);
    if (task == null) return;
    final utc = due?.toUtc();
    if (_sameInstant(task.dueAt, utc)) return;
    await _patch(task, {
      'due': utc?.toIso8601String(),
    }, task.copyWith(dueAt: utc, clearDue: utc == null));
  }

  Future<void> addTags(String id, Iterable<String> tags) async {
    final task = store.task(id);
    if (task == null) return;
    final merged = _normalizeTags([...task.tags, ...tags]);
    if (_sameTags(task.tags, merged)) return;
    await _patch(task, {'tags': merged}, task.copyWith(tags: merged));
  }

  /// Renames one tag on every live task; mirrors the web tag manager.
  Future<int> renameTag(String from, String to) async {
    final source = from.trim();
    final target = _normalizeTags([to]).join();
    if (source.isEmpty || target.isEmpty || source == target) return 0;
    var changed = 0;
    for (final task in store.allTasks()) {
      if (task.deleted || !task.tags.contains(source)) continue;
      final tags = _normalizeTags([
        for (final tag in task.tags) tag == source ? target : tag,
      ]);
      if (_sameTags(task.tags, tags)) continue;
      await _patch(task, {'tags': tags}, task.copyWith(tags: tags));
      changed++;
    }
    return changed;
  }

  /// Removes one tag from every live task.
  Future<int> deleteTag(String tag) async {
    final target = tag.trim();
    if (target.isEmpty) return 0;
    var changed = 0;
    for (final task in store.allTasks()) {
      if (task.deleted || !task.tags.contains(target)) continue;
      final tags = _normalizeTags(
        task.tags.where((item) => item != target).toList(growable: false),
      );
      await _patch(task, {'tags': tags}, task.copyWith(tags: tags));
      changed++;
    }
    return changed;
  }

  Future<void> moveTaskToList(String taskId, String listId) async {
    final task = store.task(taskId);
    if (task == null || task.listId == listId) return;
    final target = store.list(listId);
    if (target == null) {
      throw const FormatException('目标清单不存在');
    }
    await _patch(task, {
      'listId': listId,
      'sectionId': null,
    }, task.copyWith(listId: listId, clearSection: true));
  }

  Future<void> moveTaskToSection(String taskId, String? sectionId) async {
    final task = store.task(taskId);
    if (task == null) return;
    if (task.sectionId == sectionId) return;
    if (sectionId != null) {
      final section = store.section(sectionId);
      if (section == null || section.listId != task.listId) {
        throw const FormatException('列不属于当前清单');
      }
    }
    await _patch(task, {
      'sectionId': sectionId,
    }, task.copyWith(sectionId: sectionId, clearSection: sectionId == null));
  }

  Future<void> rescheduleTask(String id, DateTime? due) async {
    final task = store.task(id);
    if (task == null) return;
    final utc = due?.toUtc();
    if (_sameInstant(task.dueAt, utc)) return;
    await _patch(task, {
      'due': utc?.toIso8601String(),
    }, task.copyWith(dueAt: utc, clearDue: utc == null));
  }

  Future<FolderItem> createFolder(String name) async {
    final value = name.trim();
    if (value.isEmpty) {
      throw const FormatException('文件夹名称不能为空');
    }
    if (store.foldersSnapshot().any(
      (folder) => folder.name.toLowerCase() == value.toLowerCase(),
    )) {
      throw const FormatException('同名文件夹已存在');
    }
    var order = 0;
    for (final folder in store.foldersSnapshot()) {
      if (folder.sortOrder > order) order = folder.sortOrder;
    }
    order += 1;
    final now = DateTime.now().toUtc();
    final folder = FolderItem(
      id: newSyncId(),
      name: value,
      sortOrder: order,
      updatedAt: now,
    );
    await store.batch(() async {
      await store.saveFolder(folder);
      await store.saveOp(
        opId: newSyncId(),
        entity: 'folder',
        entityId: folder.id,
        action: 'create',
        patch: {'name': value, 'order': order},
      );
    });
    onLocalChange?.call();
    return folder;
  }

  Future<void> updateFolder(String id, String name) async {
    final folder = store.folder(id);
    if (folder == null) return;
    final value = name.trim();
    if (value.isEmpty) throw const FormatException('文件夹名称不能为空');
    if (value == folder.name) return;
    final existing = store.pendingOp('folder', id);
    await store.batch(() async {
      await store.saveFolder(
        folder.copyWith(name: value, updatedAt: DateTime.now().toUtc()),
      );
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      await store.saveOp(
        opId: newSyncId(),
        entity: 'folder',
        entityId: id,
        action: existing?.action == 'create' ? 'create' : 'update',
        patch: {...?existing?.patch, 'name': value},
        baseEtag: existing?.baseEtag ?? folder.etag,
      );
    });
    onLocalChange?.call();
  }

  Future<void> deleteFolder(String id) async {
    final folder = store.folder(id);
    if (folder == null) return;
    final existing = store.pendingOp('folder', id);
    final hasLists = store.listsSnapshot().any((list) => list.folderId == id);
    if (existing?.action == 'create' && hasLists) {
      throw StateError('文件夹尚未同步，请先同步或移走清单');
    }
    await store.batch(() async {
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      if (existing?.action != 'create') {
        await store.saveOp(
          opId: newSyncId(),
          entity: 'folder',
          entityId: id,
          action: 'delete',
          patch: const {},
          baseEtag: existing?.baseEtag ?? folder.etag,
        );
      }
      await store.hardDeleteFolder(id);
    });
    onLocalChange?.call();
  }

  Future<void> moveListToFolder(String listId, String? folderId) async {
    final list = store.list(listId);
    if (list == null || list.folderId == folderId) return;
    if (folderId != null && store.folder(folderId) == null) {
      throw const FormatException('文件夹不存在');
    }
    await _patchList(list, {
      'folderId': folderId,
    }, list.copyWith(folderId: folderId, clearFolder: folderId == null));
  }

  Future<TaskListItem> createList({
    required String name,
    String color = '#4772fa',
    String? folderId,
  }) async {
    final value = name.trim();
    if (value.isEmpty) {
      throw const FormatException('清单名称不能为空');
    }
    if (store.listsSnapshot().any(
      (list) => list.name.toLowerCase() == value.toLowerCase(),
    )) {
      throw const FormatException('同名清单已存在');
    }
    var order = 0;
    for (final list in store.listsSnapshot()) {
      if (list.sortOrder > order) order = list.sortOrder;
    }
    order += 1;
    if (folderId != null && store.folder(folderId) == null) {
      throw const FormatException('文件夹不存在');
    }
    final now = DateTime.now().toUtc();
    final list = TaskListItem(
      id: newSyncId(),
      folderId: folderId,
      name: value,
      color: color,
      sortOrder: order,
      updatedAt: now,
    );
    final patch = <String, dynamic>{
      'name': value,
      'color': color,
      'kind': 'TASK',
      'order': order,
    };
    if (folderId != null) patch['folderId'] = folderId;
    await store.batch(() async {
      await store.saveList(list, dirty: true);
      await store.saveOp(
        opId: newSyncId(),
        entity: 'list',
        entityId: list.id,
        action: 'create',
        patch: patch,
      );
    });
    onLocalChange?.call();
    return list;
  }

  Future<void> updateList(
    String id, {
    String? name,
    String? color,
    bool? pinned,
  }) async {
    final list = store.list(id);
    if (list == null) return;
    final patch = <String, dynamic>{};
    var updated = list;
    if (name != null) {
      final value = name.trim();
      if (value.isEmpty) throw const FormatException('清单名称不能为空');
      if (list.isInbox) {
        if (value != list.name) {
          throw const FormatException('收集箱不能改名');
        }
      } else if (value != list.name) {
        patch['name'] = value;
        updated = updated.copyWith(name: value);
      }
    }
    if (color != null && color != list.color) {
      patch['color'] = color;
      updated = updated.copyWith(color: color);
    }
    if (pinned != null && pinned != list.pinned) {
      patch['pinned'] = pinned;
      updated = updated.copyWith(pinned: pinned);
    }
    if (patch.isEmpty) return;
    await _patchList(list, patch, updated);
  }

  Future<void> deleteList(String id) async {
    final list = store.list(id);
    if (list == null || list.isInbox) return;
    final existing = store.pendingOp('list', id);
    if (existing?.action == 'create') {
      final hasTasks =
          store.tasksSnapshot(listId: id, completed: false).isNotEmpty ||
          store.tasksSnapshot(listId: id, completed: true).isNotEmpty;
      if (hasTasks) {
        throw StateError('清单尚未同步，请先同步或移走任务');
      }
      await store.batch(() async {
        await store.removeOp(existing!.opId);
        await store.hardDeleteList(id);
      });
    } else {
      await store.batch(() async {
        if (existing != null) {
          await store.removeOp(existing.opId);
        }
        await store.saveOp(
          opId: newSyncId(),
          entity: 'list',
          entityId: id,
          action: 'delete',
          patch: const {},
          baseEtag: existing?.baseEtag ?? list.etag,
        );
        await store.hardDeleteList(id);
      });
    }
    onLocalChange?.call();
  }

  Future<void> _patchList(
    TaskListItem list,
    Map<String, dynamic> patch,
    TaskListItem updated,
  ) async {
    final now = DateTime.now().toUtc();
    final existing = store.pendingOp('list', list.id);
    final mergedPatch = <String, dynamic>{...?existing?.patch, ...patch};
    final action = existing?.action == 'create' ? 'create' : 'update';
    await store.batch(() async {
      await store.saveList(updated.copyWith(updatedAt: now), dirty: true);
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      await store.saveOp(
        opId: newSyncId(),
        entity: 'list',
        entityId: list.id,
        action: action,
        patch: mergedPatch,
        baseEtag: existing?.baseEtag ?? list.etag,
      );
    });
    onLocalChange?.call();
  }

  Future<void> toggleChecklistItem(String id, String itemId) async {
    final task = store.task(id);
    if (task == null) return;
    final items = task.checklist
        .map(
          (item) => item.id == itemId ? item.copyWith(done: !item.done) : item,
        )
        .toList(growable: false);
    await _patch(task, {
      'checklist': items.map((item) => item.toJson()).toList(),
    }, task.copyWith(checklist: items));
  }

  Future<void> toggleCompleted(String id) async {
    final task = store.task(id);
    if (task == null) return;
    final now = DateTime.now().toUtc();
    final completedAt = task.completed ? null : now;
    final patch = <String, dynamic>{
      'completed': completedAt != null,
      'completedAt': completedAt
          ?.toUtc()
          .toIso8601String(), // explicit null clears
    };
    await _patch(
      task,
      patch,
      task.copyWith(
        completedAt: completedAt,
        clearCompleted: completedAt == null,
      ),
    );
  }

  Future<void> deleteTask(String id) async {
    final task = store.task(id);
    if (task == null) return;
    final existing = store.pendingOp('task', id);
    if (existing?.action == 'create') {
      // Never reached the server: drop both sides locally.
      await store.batch(() async {
        await store.removeOp(existing!.opId);
        await store.hardDeleteTask(id);
        await store.clearConflict('task', id);
      });
      onLocalChange?.call();
      return;
    }
    final now = DateTime.now().toUtc();
    final baseEtag = existing?.baseEtag ?? task.etag;
    await store.batch(() async {
      await store.saveTask(
        task.copyWith(deleted: true, deletedAt: now),
        dirty: true,
      );
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      await store.saveOp(
        opId: newSyncId(),
        entity: 'task',
        entityId: id,
        action: 'delete',
        patch: const {},
        baseEtag: baseEtag,
      );
    });
    onLocalChange?.call();
  }

  List<String> _normalizeTags(List<String> tags) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in tags) {
      final value = raw.replaceAll(',', '').trim();
      if (value.isEmpty || !seen.add(value)) continue;
      out.add(value);
      if (out.length >= 20) break;
    }
    return out;
  }

  Future<void> restoreTask(String id) async {
    final task = store.task(id);
    if (task == null || !task.deleted) return;
    final existing = store.pendingOp('task', id);
    final baseEtag = existing?.baseEtag ?? task.etag;
    await store.batch(() async {
      await store.saveTask(
        task.copyWith(
          deleted: false,
          clearDeletedAt: true,
          clearCompleted: true,
        ),
        dirty: true,
      );
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      await store.saveOp(
        opId: newSyncId(),
        entity: 'task',
        entityId: id,
        action: 'restore',
        patch: const {},
        baseEtag: baseEtag,
      );
    });
    onLocalChange?.call();
  }

  Future<void> purgeTask(String id) async {
    final task = store.task(id);
    if (task == null || !task.deleted) return;
    final existing = store.pendingOp('task', id);
    final baseEtag = existing?.baseEtag ?? task.etag;
    await store.batch(() async {
      await store.hardDeleteTask(id);
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      await store.saveOp(
        opId: newSyncId(),
        entity: 'task',
        entityId: id,
        action: 'purge',
        patch: const {},
        baseEtag: baseEtag,
      );
    });
    onLocalChange?.call();
  }

  Future<void> skipOccurrence(String id) async {
    final task = store.task(id);
    if (task == null || task.recurrence.isEmpty) return;
    final existing = store.pendingOp('task', id);
    final baseEtag = existing?.baseEtag ?? task.etag;
    await store.batch(() async {
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      await store.saveOp(
        opId: newSyncId(),
        entity: 'task',
        entityId: id,
        action: 'skip',
        patch: const {},
        baseEtag: baseEtag,
      );
    });
    onLocalChange?.call();
  }

  List<int> _normalizeReminders(List<int> offsets) {
    final out = <int>[];
    for (final raw in offsets) {
      if (raw < 0 || raw > 10080 || out.contains(raw)) continue;
      out.add(raw);
      if (out.length >= 10) break;
    }
    out.sort();
    return out;
  }

  bool _sameInts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameInstant(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.toUtc().isAtSameMomentAs(b.toUtc());
  }

  bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameChecklist(List<ChecklistItem> a, List<ChecklistItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].title != b[i].title ||
          a[i].done != b[i].done) {
        return false;
      }
    }
    return true;
  }

  Future<void> _patch(
    TaskItem task,
    Map<String, dynamic> patch,
    TaskItem updated,
  ) async {
    final now = DateTime.now().toUtc();
    final existing = store.pendingOp('task', task.id);
    final mergedPatch = <String, dynamic>{...?existing?.patch, ...patch};
    final action = existing?.action == 'create' ? 'create' : 'update';
    await store.batch(() async {
      await store.saveTask(updated.copyWith(updatedAt: now), dirty: true);
      if (existing != null) {
        await store.removeOp(existing.opId);
      }
      // A new local intent always gets a fresh idempotency key: reusing one
      // that the server already answered would replay the old result and drop
      // this edit.
      await store.saveOp(
        opId: newSyncId(),
        entity: 'task',
        entityId: task.id,
        action: action,
        patch: mergedPatch,
        baseEtag: existing?.baseEtag ?? task.etag,
      );
    });
    onLocalChange?.call();
  }
}
