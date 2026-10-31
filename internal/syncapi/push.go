package syncapi

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/store"
	taskparse "caldav-free/internal/tasks"
)

const maxPushOps = 200

// Push applies a batch of operations. Results are per-operation so one bad op
// never rejects the whole batch.
func (s *Service) Push(ctx context.Context, userID int64, request *PushRequest) (*PushResponse, error) {
	if request == nil {
		return nil, fmt.Errorf("empty request")
	}
	if len(request.Ops) > maxPushOps {
		return nil, fmt.Errorf("too many operations (max %d)", maxPushOps)
	}
	// Import CalDAV-side changes first so ETag checks see them.
	s.maybeRefresh(ctx, userID)
	s.maybePrune(ctx)
	s.pushMu.Lock()
	defer s.pushMu.Unlock()
	response := &PushResponse{Results: make([]PushResult, 0, len(request.Ops))}
	for _, op := range request.Ops {
		response.Results = append(response.Results, s.pushOne(ctx, userID, op))
	}
	cursor, err := s.store.SyncUserSeq(ctx, userID)
	if err != nil {
		return nil, err
	}
	response.Cursor = strconv.FormatInt(cursor, 10)
	return response, nil
}

func (s *Service) pushOne(ctx context.Context, userID int64, op PushOp) PushResult {
	entity := normalizeEntity(op.Entity)
	result := PushResult{OpID: op.OpID, Entity: entity, EntityID: op.EntityID}
	if op.OpID == "" {
		return failed(result, "invalid_operation", "opId is required")
	}
	if op.EntityID == "" && normalizeAction(op.Action) != "create" {
		return failed(result, "invalid_operation", "entityId is required")
	}
	if entity == "" {
		return failed(result, "invalid_operation", "unknown entity "+op.Entity)
	}

	// Replaying a previously acknowledged operation must not apply it twice.
	if existing, err := s.store.GetSyncOp(ctx, userID, op.OpID); err == nil {
		var stored PushResult
		if json.Unmarshal([]byte(existing.Result), &stored) == nil {
			return stored
		}
	} else if err != store.ErrNotFound {
		return failed(result, "server_error", err.Error())
	}

	action := normalizeAction(op.Action)
	if action == "" {
		return failed(result, "invalid_operation", "unknown action "+op.Action)
	}
	baseSeq, err := parseETag(op.BaseETag)
	if err != nil {
		return failed(result, "invalid_operation", err.Error())
	}
	if action == "create" && op.EntityID == "" {
		op.EntityID = store.NewSyncID()
		result.EntityID = op.EntityID
	}

	outcome := s.apply(ctx, userID, entity, action, op.EntityID, baseSeq, op.Patch)
	result.Status = outcome.status
	result.ETag = formatETag(outcome.seq)
	result.Version = outcome.seq
	result.Snapshot = outcome.snapshot
	result.Error = outcome.err

	if encoded, err := json.Marshal(result); err == nil {
		record := &store.SyncOp{
			UserID:    userID,
			OpID:      op.OpID,
			Entity:    entity,
			EntityID:  op.EntityID,
			Status:    result.Status,
			Result:    string(encoded),
			CreatedAt: time.Now().Unix(),
		}
		if err := s.store.SaveSyncOp(ctx, record); err != nil {
			// A concurrent retry won the race; return its stored result.
			if existing, getErr := s.store.GetSyncOp(ctx, userID, op.OpID); getErr == nil {
				var stored PushResult
				if json.Unmarshal([]byte(existing.Result), &stored) == nil {
					return stored
				}
			}
			slog.Default().Warn("save sync op", "op", op.OpID, "error", err)
		}
	}
	return result
}

func normalizeEntity(entity string) string {
	switch strings.ToLower(strings.TrimSpace(entity)) {
	case store.SyncEntityTask, "tasks":
		return store.SyncEntityTask
	case store.SyncEntityList, "tasklist", "task_list", "lists":
		return store.SyncEntityList
	case store.SyncEntitySection, "sections":
		return store.SyncEntitySection
	case store.SyncEntityFolder, "folders":
		return store.SyncEntityFolder
	case store.SyncEntityFilter, "filters":
		return store.SyncEntityFilter
	default:
		return ""
	}
}

func normalizeAction(action string) string {
	switch strings.ToLower(strings.TrimSpace(action)) {
	case "create":
		return "create"
	case "update", "move", "reorder":
		return "update"
	case "delete":
		return "delete"
	case "restore":
		return "restore"
	case "purge":
		return "purge"
	case "skip", "skip_occurrence", "skip-occurrence":
		return "skip"
	default:
		return ""
	}
}

type outcome struct {
	status   string
	seq      int64
	snapshot any
	err      *PushError
}

func failed(result PushResult, code, message string) PushResult {
	result.Status = "error"
	result.Error = &PushError{Code: code, Message: message}
	return result
}

func errorOutcome(code, message string) outcome {
	return outcome{status: "error", err: &PushError{Code: code, Message: message}}
}

func (s *Service) apply(ctx context.Context, userID int64, entity, action, entityID string, baseSeq int64, patch map[string]json.RawMessage) outcome {
	switch entity {
	case store.SyncEntityTask:
		return s.applyTask(ctx, userID, action, entityID, baseSeq, patch)
	case store.SyncEntityList:
		return s.applyList(ctx, userID, action, entityID, baseSeq, patch)
	case store.SyncEntitySection:
		return s.applySection(ctx, userID, action, entityID, baseSeq, patch)
	case store.SyncEntityFolder:
		return s.applyFolder(ctx, userID, action, entityID, baseSeq, patch)
	case store.SyncEntityFilter:
		return s.applyFilter(ctx, userID, action, entityID, baseSeq, patch)
	default:
		return errorOutcome("invalid_operation", "unknown entity")
	}
}

// ---------------------------------------------------------------- tasks

func (s *Service) applyTask(ctx context.Context, userID int64, action, entityID string, baseSeq int64, patch map[string]json.RawMessage) outcome {
	switch action {
	case "create":
		return s.createTask(ctx, userID, entityID, patch)
	case "delete":
		return s.deleteTask(ctx, userID, entityID, baseSeq)
	case "restore":
		return s.restoreTask(ctx, userID, entityID, baseSeq)
	case "purge":
		return s.purgeTask(ctx, userID, entityID, baseSeq)
	case "skip":
		return s.skipTaskOccurrence(ctx, userID, entityID, baseSeq)
	default:
		return s.updateTask(ctx, userID, entityID, baseSeq, patch)
	}
}

func (s *Service) createTask(ctx context.Context, userID int64, entityID string, patch map[string]json.RawMessage) outcome {
	if existing, err := s.store.GetTaskBySyncID(ctx, userID, entityID); err == nil {
		snapshot, seq, _ := s.taskResult(ctx, userID, existing)
		return outcome{status: "conflict", seq: seq, snapshot: snapshot, err: &PushError{Code: "already_exists", Message: "entity already exists"}}
	} else if err != store.ErrNotFound {
		return errorOutcome("server_error", err.Error())
	}

	title, _, _, err := patchString(patch, "title")
	if err != nil || strings.TrimSpace(title) == "" {
		return errorOutcome("invalid_patch", "title is required")
	}
	kind := "TASK"
	if value, set, _, err := patchString(patch, "kind"); err != nil {
		return errorOutcome("invalid_patch", err.Error())
	} else if set && strings.TrimSpace(value) != "" {
		kind = strings.ToUpper(strings.TrimSpace(value))
		if kind != "TASK" && kind != "NOTE" {
			return errorOutcome("invalid_patch", "kind must be TASK or NOTE")
		}
	}

	list, failure := s.resolveInitialList(ctx, userID, kind, patch)
	if failure != nil {
		return *failure
	}
	if !taskKindMatchesList(kind, list.Kind) {
		return errorOutcome("invalid_patch", "task kind does not match the target list")
	}

	task := &store.Task{
		UserID:      userID,
		SyncID:      entityID,
		ListID:      list.ID,
		Title:       strings.TrimSpace(title),
		Kind:        kind,
		NotesFormat: "text",
		Priority:    0,
		Tags:        store.StringList{},
	}
	if kind == "NOTE" {
		task.NotesFormat = "markdown"
	}
	if failure := s.applyTaskFields(ctx, userID, task, patch, true); failure != nil {
		return *failure
	}
	created, err := s.store.CreateTask(ctx, task)
	if err != nil {
		return storeFailure("create task", err)
	}
	if err := s.syncer.PushTask(ctx, userID, created); err != nil {
		slog.Default().Warn("push new task to caldav", "task", created.SyncID, "error", err)
	}
	return s.taskOutcome(ctx, userID, created.SyncID)
}

func (s *Service) updateTask(ctx context.Context, userID int64, entityID string, baseSeq int64, patch map[string]json.RawMessage) outcome {
	task, err := s.store.GetTaskBySyncID(ctx, userID, entityID)
	if err == store.ErrNotFound {
		return outcome{status: "gone"}
	}
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	if task.Deleted {
		return s.goneTask(ctx, userID, task)
	}
	if failure := s.checkBase(ctx, userID, store.SyncEntityTask, entityID, baseSeq); failure != nil {
		return *failure
	}
	if failure := s.applyTaskFields(ctx, userID, task, patch, false); failure != nil {
		return *failure
	}
	if err := s.store.UpdateTask(ctx, task); err != nil {
		return storeFailure("update task", err)
	}
	if err := s.syncer.PushTask(ctx, userID, task); err != nil {
		slog.Default().Warn("push updated task to caldav", "task", task.SyncID, "error", err)
	}
	return s.taskOutcome(ctx, userID, task.SyncID)
}

func (s *Service) deleteTask(ctx context.Context, userID int64, entityID string, baseSeq int64) outcome {
	task, err := s.store.GetTaskBySyncID(ctx, userID, entityID)
	if err == store.ErrNotFound {
		return outcome{status: "gone"}
	}
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	if task.Deleted {
		return s.taskOutcome(ctx, userID, task.SyncID)
	}
	if failure := s.checkBase(ctx, userID, store.SyncEntityTask, entityID, baseSeq); failure != nil {
		return *failure
	}
	if err := s.syncer.DeleteTask(ctx, userID, task); err != nil {
		slog.Default().Warn("delete task vtodo", "task", task.SyncID, "error", err)
	}
	if err := s.store.DeleteTask(ctx, userID, task.ID); err != nil {
		return storeFailure("delete task", err)
	}
	return s.taskOutcome(ctx, userID, task.SyncID)
}

func (s *Service) restoreTask(ctx context.Context, userID int64, entityID string, baseSeq int64) outcome {
	task, err := s.store.GetTaskBySyncID(ctx, userID, entityID)
	if err == store.ErrNotFound {
		return outcome{status: "gone"}
	}
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	if !task.Deleted {
		// Another client already restored it; restoring is idempotent.
		return s.taskOutcome(ctx, userID, task.SyncID)
	}
	if failure := s.checkBase(ctx, userID, store.SyncEntityTask, entityID, baseSeq); failure != nil {
		return *failure
	}
	restored, err := s.store.RestoreTask(ctx, userID, task.ID)
	if err != nil {
		return storeFailure("restore task", err)
	}
	if err := s.syncer.PushTask(ctx, userID, restored); err != nil {
		slog.Default().Warn("push restored task to caldav", "task", restored.SyncID, "error", err)
	}
	return s.taskOutcome(ctx, userID, restored.SyncID)
}

func (s *Service) purgeTask(ctx context.Context, userID int64, entityID string, baseSeq int64) outcome {
	task, err := s.store.GetTaskBySyncID(ctx, userID, entityID)
	if err == store.ErrNotFound {
		return outcome{status: "gone"}
	}
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	if failure := s.checkBase(ctx, userID, store.SyncEntityTask, entityID, baseSeq); failure != nil {
		return *failure
	}
	if err := s.syncer.DeleteTask(ctx, userID, task); err != nil {
		slog.Default().Warn("delete purged task vtodo", "task", task.SyncID, "error", err)
	}
	if err := s.store.PurgeTask(ctx, userID, task.ID); err != nil {
		return storeFailure("purge task", err)
	}
	return outcome{status: "ok"}
}

func (s *Service) completeTaskOccurrence(ctx context.Context, userID int64, task *store.Task) bool {
	if task == nil || task.Recurrence == "" || task.DueAt == nil {
		return false
	}
	occurrence := task.DueAt.UTC()
	if err := s.store.RecordRecurrenceInstance(ctx, &store.TaskRecurrenceInstance{
		UserID: task.UserID, TaskID: task.ID, OccurrenceAt: occurrence,
		Status: "completed", Title: task.Title,
	}); err != nil {
		slog.Default().Warn("record completed recurrence", "task", task.SyncID, "error", err)
	}
	if err := s.syncer.UpsertRecurrenceException(ctx, userID, task, occurrence, "completed"); err != nil {
		slog.Default().Warn("write completed recurrence exception", "task", task.SyncID, "error", err)
	}
	anchor := *task.DueAt
	if task.RecurrenceAnchor != nil {
		anchor = *task.RecurrenceAnchor
	}
	next, ok := taskparse.NextOccurrenceAfter(task.Recurrence, anchor, occurrence)
	if !ok {
		return false
	}
	task.DueAt = &next
	task.Completed = false
	task.CompletedAt = nil
	return true
}

func (s *Service) skipTaskOccurrence(ctx context.Context, userID int64, entityID string, baseSeq int64) outcome {
	task, err := s.store.GetTaskBySyncID(ctx, userID, entityID)
	if err == store.ErrNotFound {
		return outcome{status: "gone"}
	}
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	if task.Deleted {
		return s.goneTask(ctx, userID, task)
	}
	if task.Recurrence == "" || task.DueAt == nil {
		return errorOutcome("invalid_operation", "task is not recurring")
	}
	if failure := s.checkBase(ctx, userID, store.SyncEntityTask, entityID, baseSeq); failure != nil {
		return *failure
	}
	occurrence := task.DueAt.UTC()
	anchor := *task.DueAt
	if task.RecurrenceAnchor != nil {
		anchor = *task.RecurrenceAnchor
	}
	if err := s.store.RecordRecurrenceInstance(ctx, &store.TaskRecurrenceInstance{
		UserID: task.UserID, TaskID: task.ID, OccurrenceAt: occurrence,
		Status: "skipped", Title: task.Title,
	}); err != nil {
		return storeFailure("record skipped occurrence", err)
	}
	if next, ok := taskparse.NextOccurrenceAfter(task.Recurrence, anchor, occurrence); ok {
		task.DueAt = &next
		task.Completed = false
		task.CompletedAt = nil
	} else {
		now := time.Now().UTC()
		task.Completed = true
		task.CompletedAt = &now
	}
	task.SyncPending = true
	if err := s.store.UpdateTask(ctx, task); err != nil {
		return storeFailure("skip occurrence", err)
	}
	if err := s.syncer.PushTask(ctx, userID, task); err != nil {
		slog.Default().Warn("push skipped recurring task to caldav", "task", task.SyncID, "error", err)
	}
	if err := s.syncer.UpsertRecurrenceException(ctx, userID, task, occurrence, "skipped"); err != nil {
		slog.Default().Warn("write skipped recurrence exception", "task", task.SyncID, "error", err)
	}
	return s.taskOutcome(ctx, userID, task.SyncID)
}

func (s *Service) applyTaskFields(ctx context.Context, userID int64, task *store.Task, patch map[string]json.RawMessage, creating bool) *outcome {
	recurrenceAdvanced := false
	if value, set, _, err := patchString(patch, "kind"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set && !creating {
		kind := strings.ToUpper(strings.TrimSpace(value))
		if kind != task.Kind {
			return failure("unsupported", "changing a task between TASK and NOTE is not supported")
		}
	}
	if value, set, _, err := patchString(patch, "title"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		if strings.TrimSpace(value) == "" {
			return failure("invalid_patch", "title cannot be empty")
		}
		task.Title = strings.TrimSpace(value)
	}

	if listID, set, null, err := patchString(patch, "listId"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		if null || strings.TrimSpace(listID) == "" {
			if !creating {
				return failure("invalid_patch", "listId cannot be cleared")
			}
		} else {
			list, err := s.store.GetTaskListBySyncID(ctx, userID, listID)
			if err != nil {
				return failure("invalid_patch", "list not found")
			}
			if !taskKindMatchesList(task.Kind, list.Kind) {
				return failure("invalid_patch", "task kind does not match the target list")
			}
			task.ListID = list.ID
			if !creating && task.SectionID != 0 {
				section, secErr := s.store.GetTaskSection(ctx, userID, task.SectionID)
				if secErr != nil || section.ListID != list.ID {
					task.SectionID = 0
				}
			}
		}
	}

	if parentID, set, null, err := patchString(patch, "parentId"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		if null || strings.TrimSpace(parentID) == "" {
			task.ParentID = 0
		} else {
			parent, err := s.store.GetTaskBySyncID(ctx, userID, parentID)
			if err != nil || parent.Deleted {
				return failure("invalid_patch", "parent task not found")
			}
			if !creating && parent.ID == task.ID {
				return failure("invalid_patch", "task cannot be its own parent")
			}
			task.ParentID = parent.ID
		}
	}

	if sectionID, set, null, err := patchString(patch, "sectionId"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		if null || strings.TrimSpace(sectionID) == "" {
			task.SectionID = 0
		} else {
			section, err := s.store.GetTaskSectionBySyncID(ctx, userID, sectionID)
			if err != nil {
				return failure("invalid_patch", "section not found")
			}
			if section.ListID != task.ListID {
				return failure("invalid_patch", "section belongs to another list")
			}
			task.SectionID = section.ID
		}
	}

	if value, set, _, err := patchString(patch, "notes"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		task.Notes = value
	}
	if value, set, _, err := patchString(patch, "notesFormat"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		format := strings.ToLower(strings.TrimSpace(value))
		if format != "text" && format != "html" && format != "markdown" {
			return failure("invalid_patch", "invalid notesFormat")
		}
		task.NotesFormat = format
	}
	if value, set, _, err := patchInt(patch, "priority"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		if value < 0 || value > 3 {
			return failure("invalid_patch", "priority must be 0..3")
		}
		task.Priority = value
	}
	datesTouched := false
	if value, set, err := patchTime(patch, "start"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		datesTouched = true
		task.StartAt = value
	}
	if value, set, err := patchTime(patch, "due"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		datesTouched = true
		task.DueAt = value
		if task.DueAt != nil && task.Recurrence != "" {
			anchor := task.DueAt.UTC()
			task.RecurrenceAnchor = &anchor
		}
		if task.DueAt == nil {
			task.RecurrenceAnchor = nil
		}
	}
	if datesTouched && task.StartAt != nil && task.DueAt != nil && task.StartAt.After(*task.DueAt) {
		return failure("invalid_patch", "start must not be after due")
	}
	if value, set, err := patchBool(patch, "allDay"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		task.AllDay = value
	}
	if value, set, _, err := patchString(patch, "recurrence"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		task.Recurrence = strings.TrimSpace(value)
		if task.Recurrence == "" {
			task.RecurrenceAnchor = nil
		} else if task.DueAt != nil && task.RecurrenceAnchor == nil {
			anchor := task.DueAt.UTC()
			task.RecurrenceAnchor = &anchor
		}
	}
	if value, set, _, err := patchString(patch, "assignee"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		task.Assignee = strings.TrimSpace(value)
	}
	if value, set, err := patchBool(patch, "completed"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		recurrenceAdvanced = false
		if value && task.Recurrence != "" && task.DueAt != nil {
			recurrenceAdvanced = s.completeTaskOccurrence(ctx, userID, task)
		}
		if !recurrenceAdvanced {
			applyTaskCompletion(task, value)
		}
	}
	if value, set, err := patchTime(patch, "completedAt"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		if recurrenceAdvanced && value != nil {
			// Completing a recurring task moved the master to its next
			// occurrence; keep the stale completion timestamp from undoing it.
		} else {
			task.CompletedAt = value
			if value != nil {
				task.Completed = true
			}
		}
	}
	if value, set, err := patchBool(patch, "pinned"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		if value {
			if task.PinnedAt == nil {
				now := time.Now().UTC()
				task.PinnedAt = &now
			}
		} else {
			task.PinnedAt = nil
		}
	}
	if value, set, err := patchStrings(patch, "tags"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		task.Tags = normalizeTags(value)
	}
	if value, set, err := patchChecklist(patch, "checklist"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		task.Checklist = value
	}
	if value, set, _, err := patchInt(patch, "order"); err != nil {
		return failure("invalid_patch", err.Error())
	} else if set {
		task.Order = value
	}
	if raw, ok := patchRaw(patch, "reminderOffsets"); ok {
		var offsets []int
		if patchIsNull(raw) {
			offsets = nil
		} else if err := json.Unmarshal(raw, &offsets); err != nil {
			return failure("invalid_patch", "reminderOffsets: "+err.Error())
		}
		if _, err := store.NormalizeReminderOffsets(offsets); err != nil {
			return failure("invalid_patch", err.Error())
		}
		task.SetReminderValues(offsets)
	}
	return nil
}

func (s *Service) resolveInitialList(ctx context.Context, userID int64, kind string, patch map[string]json.RawMessage) (*store.TaskList, *outcome) {
	listID, set, null, err := patchString(patch, "listId")
	if err != nil {
		return nil, failure("invalid_patch", err.Error())
	}
	if set && !null && strings.TrimSpace(listID) != "" {
		list, err := s.store.GetTaskListBySyncID(ctx, userID, listID)
		if err != nil {
			return nil, failure("invalid_patch", "list not found")
		}
		return list, nil
	}
	if kind == "NOTE" {
		list, err := s.store.EnsureNoteFallbackList(ctx, userID)
		if err != nil {
			return nil, failure("server_error", err.Error())
		}
		return list, nil
	}
	list, err := s.store.EnsureInbox(ctx, userID)
	if err != nil {
		return nil, failure("server_error", err.Error())
	}
	return list, nil
}

func (s *Service) taskOutcome(ctx context.Context, userID int64, syncID string) outcome {
	task, err := s.store.GetTaskBySyncID(ctx, userID, syncID)
	if err == store.ErrNotFound {
		return outcome{status: "ok"}
	}
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	snapshot, seq, err := s.taskResult(ctx, userID, task)
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	return outcome{status: "ok", seq: seq, snapshot: snapshot}
}

func (s *Service) taskResult(ctx context.Context, userID int64, task *store.Task) (*TaskDTO, int64, error) {
	seq, err := s.store.SyncEntitySeq(ctx, userID, store.SyncEntityTask, task.SyncID)
	if err != nil {
		return nil, 0, err
	}
	snapshot, err := s.taskSnapshot(ctx, userID, task, seq)
	if err != nil {
		return nil, 0, err
	}
	return snapshot, seq, nil
}

func (s *Service) goneTask(ctx context.Context, userID int64, task *store.Task) outcome {
	snapshot, seq, err := s.taskResult(ctx, userID, task)
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	return outcome{status: "gone", seq: seq, snapshot: snapshot}
}

// ---------------------------------------------------------------- lists

func (s *Service) applyList(ctx context.Context, userID int64, action, entityID string, baseSeq int64, patch map[string]json.RawMessage) outcome {
	switch action {
	case "create":
		if existing, err := s.store.GetTaskListBySyncID(ctx, userID, entityID); err == nil {
			snapshot, seq, _ := s.listResult(ctx, userID, existing)
			return outcome{status: "conflict", seq: seq, snapshot: snapshot, err: &PushError{Code: "already_exists", Message: "entity already exists"}}
		} else if err != store.ErrNotFound {
			return errorOutcome("server_error", err.Error())
		}
		name, _, _, err := patchString(patch, "name")
		if err != nil || strings.TrimSpace(name) == "" {
			return errorOutcome("invalid_patch", "name is required")
		}
		color := "#4772fa"
		if value, set, _, err := patchString(patch, "color"); err == nil && set && strings.TrimSpace(value) != "" {
			color = strings.TrimSpace(value)
		} else if err != nil {
			return errorOutcome("invalid_patch", err.Error())
		}
		kind := "TASK"
		if value, set, _, err := patchString(patch, "kind"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set && strings.TrimSpace(value) != "" {
			kind = strings.ToUpper(strings.TrimSpace(value))
			if kind != "TASK" && kind != "NOTE" {
				return errorOutcome("invalid_patch", "kind must be TASK or NOTE")
			}
		}
		list, err := s.store.CreateTaskListKindWithSyncID(ctx, userID, name, color, kind, entityID)
		if err != nil {
			return storeFailure("create list", err)
		}
		if folderID, set, null, err := patchString(patch, "folderId"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set && !null && strings.TrimSpace(folderID) != "" {
			folder, err := s.store.GetTaskFolderBySyncID(ctx, userID, folderID)
			if err != nil {
				return errorOutcome("invalid_patch", "folder not found")
			}
			if err := s.store.SetTaskListFolder(ctx, userID, list.ID, folder.ID); err != nil {
				return storeFailure("move list", err)
			}
		}
		if order, set, _, err := patchInt(patch, "order"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			if err := s.store.UpdateTaskList(ctx, userID, list.ID, list.Name, list.Color, order); err != nil {
				return storeFailure("order list", err)
			}
		}
		if pinned, set, err := patchBool(patch, "pinned"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			if _, err := s.store.SetTaskListPinned(ctx, userID, list.ID, pinned); err != nil {
				return storeFailure("pin list", err)
			}
		}
		return s.listOutcome(ctx, userID, list.SyncID)

	case "delete":
		list, err := s.store.GetTaskListBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return outcome{status: "gone"}
		}
		if err != nil {
			return errorOutcome("server_error", err.Error())
		}
		if list.IsInbox {
			return errorOutcome("inbox_immutable", "the inbox list cannot be deleted")
		}
		if failure := s.checkBase(ctx, userID, store.SyncEntityList, entityID, baseSeq); failure != nil {
			return *failure
		}
		if err := s.store.DeleteTaskList(ctx, userID, list.ID); err != nil {
			return storeFailure("delete list", err)
		}
		return outcome{status: "ok"}

	default:
		list, err := s.store.GetTaskListBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return outcome{status: "gone"}
		}
		if err != nil {
			return errorOutcome("server_error", err.Error())
		}
		if failure := s.checkBase(ctx, userID, store.SyncEntityList, entityID, baseSeq); failure != nil {
			return *failure
		}
		name := list.Name
		if value, set, _, err := patchString(patch, "name"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set && strings.TrimSpace(value) != "" {
			name = strings.TrimSpace(value)
		}
		color := list.Color
		if value, set, _, err := patchString(patch, "color"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			color = value
		}
		order := list.Order
		if value, set, _, err := patchInt(patch, "order"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			order = value
		}
		if err := s.store.UpdateTaskList(ctx, userID, list.ID, name, color, order); err != nil {
			return storeFailure("update list", err)
		}
		if pinned, set, err := patchBool(patch, "pinned"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			if _, err := s.store.SetTaskListPinned(ctx, userID, list.ID, pinned); err != nil {
				return storeFailure("pin list", err)
			}
		}
		if folderID, set, null, err := patchString(patch, "folderId"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			target := int64(0)
			if !null && strings.TrimSpace(folderID) != "" {
				folder, err := s.store.GetTaskFolderBySyncID(ctx, userID, folderID)
				if err != nil {
					return errorOutcome("invalid_patch", "folder not found")
				}
				target = folder.ID
			}
			if err := s.store.SetTaskListFolder(ctx, userID, list.ID, target); err != nil {
				return storeFailure("move list", err)
			}
		}
		return s.listOutcome(ctx, userID, list.SyncID)
	}
}

func (s *Service) listOutcome(ctx context.Context, userID int64, syncID string) outcome {
	list, err := s.store.GetTaskListBySyncID(ctx, userID, syncID)
	if err == store.ErrNotFound {
		return outcome{status: "ok"}
	}
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	snapshot, seq, err := s.listResult(ctx, userID, list)
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	return outcome{status: "ok", seq: seq, snapshot: snapshot}
}

func (s *Service) listResult(ctx context.Context, userID int64, list *store.TaskList) (*ListDTO, int64, error) {
	seq, err := s.store.SyncEntitySeq(ctx, userID, store.SyncEntityList, list.SyncID)
	if err != nil {
		return nil, 0, err
	}
	snapshot, err := s.listSnapshot(ctx, userID, list, seq)
	if err != nil {
		return nil, 0, err
	}
	return snapshot, seq, nil
}

// ---------------------------------------------------------------- sections

func (s *Service) applySection(ctx context.Context, userID int64, action, entityID string, baseSeq int64, patch map[string]json.RawMessage) outcome {
	switch action {
	case "create":
		if existing, err := s.store.GetTaskSectionBySyncID(ctx, userID, entityID); err == nil {
			snapshot, seq, _ := s.sectionResult(ctx, userID, existing)
			return outcome{status: "conflict", seq: seq, snapshot: snapshot, err: &PushError{Code: "already_exists", Message: "entity already exists"}}
		} else if err != store.ErrNotFound {
			return errorOutcome("server_error", err.Error())
		}
		listID, set, _, err := patchString(patch, "listId")
		if err != nil || !set || strings.TrimSpace(listID) == "" {
			return errorOutcome("invalid_patch", "listId is required")
		}
		list, err := s.store.GetTaskListBySyncID(ctx, userID, listID)
		if err != nil {
			return errorOutcome("invalid_patch", "list not found")
		}
		name, _, _, err := patchString(patch, "name")
		if err != nil || strings.TrimSpace(name) == "" {
			return errorOutcome("invalid_patch", "name is required")
		}
		section, err := s.store.CreateTaskSectionWithSyncID(ctx, userID, list.ID, name, entityID)
		if err != nil {
			return storeFailure("create section", err)
		}
		if order, set, _, err := patchInt(patch, "order"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			if err := s.store.UpdateTaskSection(ctx, userID, section.ID, section.Name, order); err != nil {
				return storeFailure("order section", err)
			}
		}
		return s.sectionOutcome(ctx, userID, section.SyncID)

	case "delete":
		section, err := s.store.GetTaskSectionBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return outcome{status: "gone"}
		}
		if err != nil {
			return errorOutcome("server_error", err.Error())
		}
		if failure := s.checkBase(ctx, userID, store.SyncEntitySection, entityID, baseSeq); failure != nil {
			return *failure
		}
		strategy := "move"
		if value, set, _, err := patchString(patch, "strategy"); err == nil && set && strings.EqualFold(value, "delete") {
			strategy = "delete"
		}
		target := int64(0)
		if targetID, set, null, err := patchString(patch, "targetSectionId"); err == nil && set && !null && strings.TrimSpace(targetID) != "" {
			targetSection, err := s.store.GetTaskSectionBySyncID(ctx, userID, targetID)
			if err != nil {
				return errorOutcome("invalid_patch", "target section not found")
			}
			target = targetSection.ID
		}
		if err := s.store.DeleteTaskSection(ctx, userID, section.ID, strategy, target); err != nil {
			return storeFailure("delete section", err)
		}
		return outcome{status: "ok"}

	default:
		section, err := s.store.GetTaskSectionBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return outcome{status: "gone"}
		}
		if err != nil {
			return errorOutcome("server_error", err.Error())
		}
		if failure := s.checkBase(ctx, userID, store.SyncEntitySection, entityID, baseSeq); failure != nil {
			return *failure
		}
		if listID, set, null, err := patchString(patch, "listId"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set && !null && strings.TrimSpace(listID) != "" {
			list, err := s.store.GetTaskListBySyncID(ctx, userID, listID)
			if err != nil || list.ID != section.ListID {
				return errorOutcome("unsupported", "moving a section between lists is not supported")
			}
		}
		name := section.Name
		if value, set, _, err := patchString(patch, "name"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set && strings.TrimSpace(value) != "" {
			name = strings.TrimSpace(value)
		}
		order := section.Order
		if value, set, _, err := patchInt(patch, "order"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			order = value
		}
		if err := s.store.UpdateTaskSection(ctx, userID, section.ID, name, order); err != nil {
			return storeFailure("update section", err)
		}
		return s.sectionOutcome(ctx, userID, section.SyncID)
	}
}

func (s *Service) sectionOutcome(ctx context.Context, userID int64, syncID string) outcome {
	section, err := s.store.GetTaskSectionBySyncID(ctx, userID, syncID)
	if err == store.ErrNotFound {
		return outcome{status: "ok"}
	}
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	snapshot, seq, err := s.sectionResult(ctx, userID, section)
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	return outcome{status: "ok", seq: seq, snapshot: snapshot}
}

func (s *Service) sectionResult(ctx context.Context, userID int64, section *store.TaskSection) (*SectionDTO, int64, error) {
	seq, err := s.store.SyncEntitySeq(ctx, userID, store.SyncEntitySection, section.SyncID)
	if err != nil {
		return nil, 0, err
	}
	snapshot, err := s.sectionSnapshot(ctx, userID, section, seq)
	if err != nil {
		return nil, 0, err
	}
	return snapshot, seq, nil
}

// ---------------------------------------------------------------- folders

func (s *Service) applyFolder(ctx context.Context, userID int64, action, entityID string, baseSeq int64, patch map[string]json.RawMessage) outcome {
	switch action {
	case "create":
		if existing, err := s.store.GetTaskFolderBySyncID(ctx, userID, entityID); err == nil {
			seq, _ := s.store.SyncEntitySeq(ctx, userID, store.SyncEntityFolder, existing.SyncID)
			snapshot := folderSnapshot(existing, seq)
			return outcome{status: "conflict", seq: seq, snapshot: snapshot, err: &PushError{Code: "already_exists", Message: "entity already exists"}}
		} else if err != store.ErrNotFound {
			return errorOutcome("server_error", err.Error())
		}
		name, _, _, err := patchString(patch, "name")
		if err != nil || strings.TrimSpace(name) == "" {
			return errorOutcome("invalid_patch", "name is required")
		}
		kind := "TASK"
		if value, set, _, err := patchString(patch, "kind"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set && strings.TrimSpace(value) != "" {
			kind = value
		}
		folder, err := s.store.CreateTaskFolderWithSyncID(ctx, userID, name, kind, entityID)
		if err != nil {
			return storeFailure("create folder", err)
		}
		if order, set, _, err := patchInt(patch, "order"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			if err := s.store.UpdateTaskFolder(ctx, userID, folder.ID, folder.Name, order); err != nil {
				return storeFailure("order folder", err)
			}
		}
		return s.folderOutcome(ctx, userID, folder.SyncID)

	case "delete":
		folder, err := s.store.GetTaskFolderBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return outcome{status: "gone"}
		}
		if err != nil {
			return errorOutcome("server_error", err.Error())
		}
		if failure := s.checkBase(ctx, userID, store.SyncEntityFolder, entityID, baseSeq); failure != nil {
			return *failure
		}
		if err := s.store.DeleteTaskFolder(ctx, userID, folder.ID); err != nil {
			return storeFailure("delete folder", err)
		}
		return outcome{status: "ok"}

	default:
		folder, err := s.store.GetTaskFolderBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return outcome{status: "gone"}
		}
		if err != nil {
			return errorOutcome("server_error", err.Error())
		}
		if failure := s.checkBase(ctx, userID, store.SyncEntityFolder, entityID, baseSeq); failure != nil {
			return *failure
		}
		name := folder.Name
		if value, set, _, err := patchString(patch, "name"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set && strings.TrimSpace(value) != "" {
			name = strings.TrimSpace(value)
		}
		order := folder.Order
		if value, set, _, err := patchInt(patch, "order"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			order = value
		}
		if err := s.store.UpdateTaskFolder(ctx, userID, folder.ID, name, order); err != nil {
			return storeFailure("update folder", err)
		}
		return s.folderOutcome(ctx, userID, folder.SyncID)
	}
}

func (s *Service) folderOutcome(ctx context.Context, userID int64, syncID string) outcome {
	folder, err := s.store.GetTaskFolderBySyncID(ctx, userID, syncID)
	if err == store.ErrNotFound {
		return outcome{status: "ok"}
	}
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	seq, err := s.store.SyncEntitySeq(ctx, userID, store.SyncEntityFolder, folder.SyncID)
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	return outcome{status: "ok", seq: seq, snapshot: folderSnapshot(folder, seq)}
}

// ---------------------------------------------------------------- filters

func (s *Service) applyFilter(ctx context.Context, userID int64, action, entityID string, baseSeq int64, patch map[string]json.RawMessage) outcome {
	switch action {
	case "create":
		if existing, err := s.store.GetSavedFilterBySyncID(ctx, userID, entityID); err == nil {
			seq, _ := s.store.SyncEntitySeq(ctx, userID, store.SyncEntityFilter, existing.SyncID)
			snapshot := filterSnapshot(existing, seq)
			return outcome{status: "conflict", seq: seq, snapshot: snapshot, err: &PushError{Code: "already_exists", Message: "entity already exists"}}
		} else if err != store.ErrNotFound {
			return errorOutcome("server_error", err.Error())
		}
		name, _, _, err := patchString(patch, "name")
		if err != nil || strings.TrimSpace(name) == "" {
			return errorOutcome("invalid_patch", "name is required")
		}
		color := ""
		if value, set, _, err := patchString(patch, "color"); err == nil && set {
			color = value
		}
		conditions, err := patchConditions(patch)
		if err != nil {
			return errorOutcome("invalid_patch", err.Error())
		}
		filter, err := s.store.CreateSavedFilterWithSyncID(ctx, userID, name, color, conditions, entityID)
		if err != nil {
			return storeFailure("create filter", err)
		}
		if order, set, _, err := patchInt(patch, "order"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			if err := s.store.UpdateSavedFilter(ctx, userID, filter.ID, filter.Name, filter.Color, filter.Conditions, order); err != nil {
				return storeFailure("order filter", err)
			}
		}
		if pinned, set, err := patchBool(patch, "pinned"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			if _, err := s.store.SetSavedFilterPinned(ctx, userID, filter.ID, pinned); err != nil {
				return storeFailure("pin filter", err)
			}
		}
		return s.filterOutcome(ctx, userID, filter.SyncID)

	case "delete":
		filter, err := s.store.GetSavedFilterBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return outcome{status: "gone"}
		}
		if err != nil {
			return errorOutcome("server_error", err.Error())
		}
		if failure := s.checkBase(ctx, userID, store.SyncEntityFilter, entityID, baseSeq); failure != nil {
			return *failure
		}
		if err := s.store.DeleteSavedFilter(ctx, userID, filter.ID); err != nil {
			return storeFailure("delete filter", err)
		}
		return outcome{status: "ok"}

	default:
		filter, err := s.store.GetSavedFilterBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return outcome{status: "gone"}
		}
		if err != nil {
			return errorOutcome("server_error", err.Error())
		}
		if failure := s.checkBase(ctx, userID, store.SyncEntityFilter, entityID, baseSeq); failure != nil {
			return *failure
		}
		name := filter.Name
		if value, set, _, err := patchString(patch, "name"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set && strings.TrimSpace(value) != "" {
			name = strings.TrimSpace(value)
		}
		color := filter.Color
		if value, set, _, err := patchString(patch, "color"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			color = value
		}
		conditions := filter.Conditions
		if _, ok := patchRaw(patch, "conditions"); ok {
			value, err := patchConditions(patch)
			if err != nil {
				return errorOutcome("invalid_patch", err.Error())
			}
			conditions = value
		}
		order := filter.Order
		if value, set, _, err := patchInt(patch, "order"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			order = value
		}
		if err := s.store.UpdateSavedFilter(ctx, userID, filter.ID, name, color, conditions, order); err != nil {
			return storeFailure("update filter", err)
		}
		if pinned, set, err := patchBool(patch, "pinned"); err != nil {
			return errorOutcome("invalid_patch", err.Error())
		} else if set {
			if _, err := s.store.SetSavedFilterPinned(ctx, userID, filter.ID, pinned); err != nil {
				return storeFailure("pin filter", err)
			}
		}
		return s.filterOutcome(ctx, userID, filter.SyncID)
	}
}

func (s *Service) filterOutcome(ctx context.Context, userID int64, syncID string) outcome {
	filter, err := s.store.GetSavedFilterBySyncID(ctx, userID, syncID)
	if err == store.ErrNotFound {
		return outcome{status: "ok"}
	}
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	seq, err := s.store.SyncEntitySeq(ctx, userID, store.SyncEntityFilter, filter.SyncID)
	if err != nil {
		return errorOutcome("server_error", err.Error())
	}
	return outcome{status: "ok", seq: seq, snapshot: filterSnapshot(filter, seq)}
}

func patchConditions(patch map[string]json.RawMessage) (string, error) {
	raw, ok := patchRaw(patch, "conditions")
	if !ok || patchIsNull(raw) {
		return "", nil
	}
	trimmed := json.RawMessage(strings.TrimSpace(string(raw)))
	if len(trimmed) == 0 {
		return "", nil
	}
	if trimmed[0] != '{' && trimmed[0] != '[' {
		var text string
		if err := json.Unmarshal(raw, &text); err != nil {
			return "", fmt.Errorf("conditions must be a JSON object")
		}
		if !json.Valid([]byte(text)) {
			return "", fmt.Errorf("conditions must be valid JSON")
		}
		return text, nil
	}
	if !json.Valid(trimmed) {
		return "", fmt.Errorf("conditions must be valid JSON")
	}
	return string(trimmed), nil
}

// ---------------------------------------------------------------- shared helpers

func (s *Service) checkBase(ctx context.Context, userID int64, entity, entityID string, baseSeq int64) *outcome {
	if baseSeq == 0 {
		return nil
	}
	current, err := s.store.SyncEntitySeq(ctx, userID, entity, entityID)
	if err != nil {
		failure := errorOutcome("server_error", err.Error())
		return &failure
	}
	if current == baseSeq {
		return nil
	}
	snapshot, err := s.loadSnapshot(ctx, userID, entity, entityID)
	if err != nil {
		failure := errorOutcome("server_error", err.Error())
		return &failure
	}
	failure := outcome{
		status:   "conflict",
		seq:      current,
		snapshot: snapshot,
		err:      &PushError{Code: "etag_mismatch", Message: "entity changed on the server"},
	}
	return &failure
}

func (s *Service) loadSnapshot(ctx context.Context, userID int64, entity, entityID string) (any, error) {
	switch entity {
	case store.SyncEntityTask:
		task, err := s.store.GetTaskBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return nil, nil
		}
		if err != nil {
			return nil, err
		}
		snapshot, _, err := s.taskResult(ctx, userID, task)
		return snapshot, err
	case store.SyncEntityList:
		list, err := s.store.GetTaskListBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return nil, nil
		}
		if err != nil {
			return nil, err
		}
		snapshot, _, err := s.listResult(ctx, userID, list)
		return snapshot, err
	case store.SyncEntitySection:
		section, err := s.store.GetTaskSectionBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return nil, nil
		}
		if err != nil {
			return nil, err
		}
		snapshot, _, err := s.sectionResult(ctx, userID, section)
		return snapshot, err
	case store.SyncEntityFolder:
		folder, err := s.store.GetTaskFolderBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return nil, nil
		}
		if err != nil {
			return nil, err
		}
		seq, err := s.store.SyncEntitySeq(ctx, userID, store.SyncEntityFolder, folder.SyncID)
		if err != nil {
			return nil, err
		}
		return folderSnapshot(folder, seq), nil
	case store.SyncEntityFilter:
		filter, err := s.store.GetSavedFilterBySyncID(ctx, userID, entityID)
		if err == store.ErrNotFound {
			return nil, nil
		}
		if err != nil {
			return nil, err
		}
		seq, err := s.store.SyncEntitySeq(ctx, userID, store.SyncEntityFilter, filter.SyncID)
		if err != nil {
			return nil, err
		}
		return filterSnapshot(filter, seq), nil
	default:
		return nil, nil
	}
}

func storeFailure(action string, err error) outcome {
	switch err {
	case store.ErrNotFound:
		return outcome{status: "gone"}
	case store.ErrConflict:
		return errorOutcome("conflict", "unique constraint violated")
	case store.ErrForbidden:
		return errorOutcome("forbidden", "write access denied")
	default:
		return errorOutcome("server_error", action+": "+err.Error())
	}
}

func failure(code, message string) *outcome {
	result := errorOutcome(code, message)
	return &result
}

func taskKindMatchesList(taskKind, listKind string) bool {
	if taskKind == "" {
		taskKind = "TASK"
	}
	if listKind == "" {
		listKind = "TASK"
	}
	return (taskKind == "NOTE") == (listKind == "NOTE")
}

func applyTaskCompletion(task *store.Task, completed bool) {
	task.Completed = completed
	if completed {
		if task.CompletedAt == nil {
			now := time.Now().UTC()
			task.CompletedAt = &now
		}
		return
	}
	task.CompletedAt = nil
}
