package web

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"caldav-free/internal/store"
	taskparse "caldav-free/internal/tasks"
)

type apiRecurrenceInstance struct {
	ID           int64  `json:"id"`
	OccurrenceAt string `json:"occurrenceAt"`
	Status       string `json:"status"`
	Title        string `json:"title"`
	CreatedAt    string `json:"createdAt"`
}

func recurrenceInstanceDTO(row *store.TaskRecurrenceInstance) apiRecurrenceInstance {
	return apiRecurrenceInstance{
		ID: row.ID, OccurrenceAt: row.OccurrenceAt.Format(time.RFC3339),
		Status: row.Status, Title: row.Title, CreatedAt: row.CreatedAt.Format(time.RFC3339),
	}
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

func (s *Server) apiSkipTaskOccurrence(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
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
		writeAPIError(w, http.StatusBadRequest, "只有设置了重复和日期的任务才能跳过本次")
		return
	}
	occurrence := *task.DueAt
	next, ok := taskparse.NextOccurrence(task.Recurrence, occurrence)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "无法计算下一次重复日期")
		return
	}
	if err := s.store.RecordRecurrenceInstance(ctx, &store.TaskRecurrenceInstance{
		UserID: task.UserID, TaskID: task.ID, OccurrenceAt: occurrence,
		Status: "skipped", Title: task.Title,
	}); err != nil {
		s.apiServerError(w, err)
		return
	}
	task.DueAt = &next
	task.Completed = false
	task.CompletedAt = nil
	task.SyncPending = true
	if err := s.store.UpdateTask(ctx, task); err != nil {
		s.apiServerError(w, err)
		return
	}
	if err := s.taskSync.PushTask(ctx, task.UserID, task); err != nil {
		s.logger.Warn("push skipped recurrence", "task", task.ID, "error", err)
	}
	_ = s.store.CreateTaskActivity(ctx, task.ID, current.ID, "recurrence-skip", "跳过了本次重复任务")
	list, _ := s.store.GetTaskList(ctx, task.UserID, task.ListID)
	rows, _ := s.store.ListRecurrenceInstances(ctx, task.UserID, task.ID, 20)
	instances := make([]apiRecurrenceInstance, 0, len(rows))
	for _, row := range rows {
		instances = append(instances, recurrenceInstanceDTO(row))
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"task": apiTaskDTO(task, list), "instances": instances})
}
