package web

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/store"
	taskparse "caldav-free/internal/tasks"
)

type apiRecurrenceInstance struct {
	ID           int64  `json:"id"`
	OccurrenceAt string `json:"occurrenceAt"`
	Status       string `json:"status"`
	PostponedTo  string `json:"postponedTo,omitempty"`
	Title        string `json:"title"`
	CreatedAt    string `json:"createdAt"`
}

func recurrenceInstanceDTO(row *store.TaskRecurrenceInstance) apiRecurrenceInstance {
	dto := apiRecurrenceInstance{
		ID: row.ID, OccurrenceAt: row.OccurrenceAt.Format(time.RFC3339),
		Status: row.Status, Title: row.Title, CreatedAt: row.CreatedAt.Format(time.RFC3339),
	}
	if row.PostponedTo != nil {
		dto.PostponedTo = row.PostponedTo.Format(time.RFC3339)
	}
	return dto
}

func (s *Server) recordCompletedOccurrence(ctx context.Context, task *store.Task, occurrence *time.Time) {
	if task == nil || occurrence == nil || occurrence.IsZero() || task.Recurrence == "" {
		return
	}
	if err := s.store.RecordRecurrenceInstance(ctx, &store.TaskRecurrenceInstance{
		UserID: task.UserID, TaskID: task.ID, OccurrenceAt: *occurrence,
		Status: "completed", Title: task.Title,
	}); err != nil {
		s.logger.Warn("record completed recurrence", "task", task.ID, "error", err)
	}
	if err := s.taskSync.UpsertRecurrenceException(ctx, task.UserID, task, *occurrence, "completed"); err != nil {
		s.logger.Warn("write completed recurrence exception", "task", task.ID, "error", err)
	}
}

func (s *Server) apiTaskRecurrence(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	taskID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	access, err := s.store.GetTaskAccess(r.Context(), current.ID, taskID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	rows, err := s.store.ListRecurrenceInstances(r.Context(), access.Task.UserID, taskID, 20)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	out := make([]apiRecurrenceInstance, 0, len(rows))
	for _, row := range rows {
		out = append(out, recurrenceInstanceDTO(row))
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"instances": out})
}

type recurrenceActionBody struct {
	Occurrence string `json:"occurrence"`
	Days       int    `json:"days"`
	Due        string `json:"due"`
}

func decodeRecurrenceActionBody(r *http.Request) recurrenceActionBody {
	var body recurrenceActionBody
	if r.Body != nil {
		_ = json.NewDecoder(r.Body).Decode(&body)
	}
	return body
}

func parseOccurrenceValue(raw string) (time.Time, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, false
	}
	if parsed, err := time.Parse(time.RFC3339, raw); err == nil {
		return parsed, true
	}
	loc := taskLocation("")
	for _, layout := range []string{"2006-01-02T15:04", "2006-01-02 15:04", "2006-01-02"} {
		if parsed, err := time.ParseInLocation(layout, raw, loc); err == nil {
			return parsed, true
		}
	}
	return time.Time{}, false
}

func sameOccurrence(left, right time.Time) bool {
	return left.UTC().Unix() == right.UTC().Unix()
}

func (s *Server) recordOccurrence(ctx context.Context, task *store.Task, occurrence time.Time, status string, postponedTo *time.Time) {
	if task == nil || occurrence.IsZero() {
		return
	}
	if err := s.store.RecordRecurrenceInstance(ctx, &store.TaskRecurrenceInstance{
		UserID: task.UserID, TaskID: task.ID, OccurrenceAt: occurrence.UTC(),
		Status: status, PostponedTo: postponedTo, Title: task.Title,
	}); err != nil {
		s.logger.Warn("record recurrence instance", "task", task.ID, "status", status, "error", err)
	}
}

// advancePastHandledInstances moves the master due date past occurrences that
// were already completed, skipped, or postponed out of order. It returns true
// when the task changed.
func (s *Server) advancePastHandledInstances(ctx context.Context, task *store.Task) bool {
	if task == nil || task.Recurrence == "" || task.DueAt == nil {
		return false
	}
	anchor := *task.DueAt
	if task.RecurrenceAnchor != nil {
		anchor = *task.RecurrenceAnchor
	}
	changed := false
	for index := 0; index < 1000; index++ {
		instance, err := s.store.GetRecurrenceInstance(ctx, task.UserID, task.ID, *task.DueAt)
		if err != nil || instance == nil {
			return changed
		}
		next, ok := taskparse.NextOccurrenceAfter(task.Recurrence, anchor, *task.DueAt)
		if !ok {
			now := time.Now().UTC()
			task.Completed = true
			task.CompletedAt = &now
			return true
		}
		task.DueAt = &next
		changed = true
	}
	return changed
}

func (s *Server) apiCompleteTaskOccurrence(w http.ResponseWriter, r *http.Request, current *store.User, session *session) {
	s.handleTaskOccurrenceAction(w, r, current, "complete")
}

func (s *Server) apiSkipTaskOccurrence(w http.ResponseWriter, r *http.Request, current *store.User, session *session) {
	s.handleTaskOccurrenceAction(w, r, current, "skip")
}

func (s *Server) apiPostponeTaskOccurrence(w http.ResponseWriter, r *http.Request, current *store.User, session *session) {
	s.handleTaskOccurrenceAction(w, r, current, "postpone")
}

func (s *Server) handleTaskOccurrenceAction(w http.ResponseWriter, r *http.Request, current *store.User, action string) {
	taskID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	ctx := r.Context()
	task, _, _, _, err := s.taskForWrite(ctx, current, taskID)
	if err != nil {
		if err == store.ErrForbidden {
			writeAPIError(w, http.StatusForbidden, "该共享清单为只读")
			return
		}
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	if task.Recurrence == "" || task.DueAt == nil {
		writeAPIError(w, http.StatusBadRequest, "只有设置了重复和日期的任务才能处理单次实例")
		return
	}
	body := decodeRecurrenceActionBody(r)
	occurrence := *task.DueAt
	if strings.TrimSpace(body.Occurrence) != "" {
		parsed, ok := parseOccurrenceValue(body.Occurrence)
		if !ok {
			writeAPIError(w, http.StatusBadRequest, "实例时间格式无效")
			return
		}
		occurrence = parsed
	}
	occurrence = occurrence.UTC()
	existing, _ := s.store.GetRecurrenceInstance(ctx, task.UserID, task.ID, occurrence)
	var existingPostponedTo *time.Time
	if existing != nil && existing.PostponedTo != nil {
		value := existing.PostponedTo.UTC()
		existingPostponedTo = &value
	}
	isCurrent := sameOccurrence(occurrence, *task.DueAt)
	anchor := *task.DueAt
	if task.RecurrenceAnchor != nil {
		anchor = *task.RecurrenceAnchor
	}
	changed := false
	var postponedTo *time.Time
	status := "completed"
	label := "完成了本次重复任务"
	switch action {
	case "complete":
		status = "completed"
		s.recordOccurrence(ctx, task, occurrence, "completed", existingPostponedTo)
		if isCurrent {
			applyTaskCompletion(task, true)
			changed = true
		}
	case "skip":
		status = "skipped"
		label = "跳过了本次重复任务"
		s.recordOccurrence(ctx, task, occurrence, "skipped", nil)
		if isCurrent {
			if next, ok := taskparse.NextOccurrenceAfter(task.Recurrence, anchor, occurrence); ok {
				task.DueAt = &next
				task.Completed = false
				task.CompletedAt = nil
			} else {
				now := time.Now().UTC()
				task.Completed = true
				task.CompletedAt = &now
			}
			changed = true
		}
	case "postpone":
		status = "postponed"
		days := body.Days
		if days == 0 {
			days = 1
		}
		if days < 1 || days > 365 {
			writeAPIError(w, http.StatusBadRequest, "顺延天数必须在 1-365 天之间")
			return
		}
		base := occurrence
		if existingPostponedTo != nil {
			base = *existingPostponedTo
		}
		nextDue := base.AddDate(0, 0, days)
		if strings.TrimSpace(body.Due) != "" {
			parsed, ok := parseOccurrenceValue(body.Due)
			if !ok {
				writeAPIError(w, http.StatusBadRequest, "顺延时间格式无效")
				return
			}
			nextDue = parsed
		}
		nextDue = nextDue.UTC()
		if !nextDue.After(occurrence) {
			writeAPIError(w, http.StatusBadRequest, "顺延时间必须晚于原实例")
			return
		}
		postponedTo = &nextDue
		label = fmt.Sprintf("将本次重复任务顺延到 %s", nextDue.In(taskLocation("")).Format("1月2日 15:04"))
		s.recordOccurrence(ctx, task, occurrence, "postponed", postponedTo)
		if isCurrent {
			if next, ok := taskparse.NextOccurrenceAfter(task.Recurrence, anchor, occurrence); ok {
				task.DueAt = &next
			} else {
				task.DueAt = &nextDue
			}
			task.Completed = false
			task.CompletedAt = nil
			changed = true
		}
	default:
		writeAPIError(w, http.StatusBadRequest, "未知的重复实例操作")
		return
	}

	if changed {
		s.advancePastHandledInstances(ctx, task)
		task.SyncPending = true
		if err := s.store.UpdateTask(ctx, task); err != nil {
			s.apiServerError(w, err)
			return
		}
		if err := s.taskSync.PushTask(ctx, task.UserID, task); err != nil {
			s.logger.Warn("push recurrence action", "task", task.ID, "error", err)
		}
	}
	if err := s.taskSync.UpsertRecurrenceExceptionAt(ctx, task.UserID, task, occurrence, status, postponedTo); err != nil {
		s.logger.Warn("write recurrence exception", "task", task.ID, "status", status, "error", err)
	}
	_ = s.store.CreateTaskActivity(ctx, task.ID, current.ID, "recurrence-"+action, label)

	list, _ := s.store.GetTaskList(ctx, task.UserID, task.ListID)
	rows, _ := s.store.ListRecurrenceInstances(ctx, task.UserID, task.ID, 20)
	instances := make([]apiRecurrenceInstance, 0, len(rows))
	for _, row := range rows {
		instances = append(instances, recurrenceInstanceDTO(row))
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"task": apiTaskDTO(task, list), "instances": instances})
}
