package web

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/store"
	taskparse "caldav-free/internal/tasks"
)

// ---------------------------------------------------------------- task DTOs

type apiChecklistItem struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Done  bool   `json:"done"`
}

type apiTaskList struct {
	ID      int64  `json:"id"`
	Name    string `json:"name"`
	Color   string `json:"color"`
	Order   int    `json:"order"`
	IsInbox bool   `json:"isInbox"`
	Count   int64  `json:"count"`
}

type apiTask struct {
	ID          int64              `json:"id"`
	ParentID    int64              `json:"parentId,omitempty"`
	ListID      int64              `json:"listId"`
	ListName    string             `json:"listName"`
	ListColor   string             `json:"listColor"`
	Title       string             `json:"title"`
	Notes       string             `json:"notes"`
	Priority    int                `json:"priority"`
	Due         string             `json:"due,omitempty"`
	AllDay      bool               `json:"allDay"`
	Completed   bool               `json:"completed"`
	CompletedAt string             `json:"completedAt,omitempty"`
	Tags        []string           `json:"tags"`
	Checklist   []apiChecklistItem `json:"checklist"`
	Order       int                `json:"order"`
	CreatedAt   string             `json:"createdAt"`
	ModifiedAt  string             `json:"modifiedAt"`
}

type taskPatch struct {
	Text      *string             `json:"text"`
	Title     *string             `json:"title"`
	ListID    *int64              `json:"listId"`
	Notes     *string             `json:"notes"`
	Priority  *int                `json:"priority"`
	Due       *string             `json:"due"`
	AllDay    *bool               `json:"allDay"`
	Completed *bool               `json:"completed"`
	Tags      *[]string           `json:"tags"`
	Checklist *[]apiChecklistItem `json:"checklist"`
	Timezone  string              `json:"timezone"`
}

func decodeChecklist(raw string) []apiChecklistItem {
	if strings.TrimSpace(raw) == "" {
		return []apiChecklistItem{}
	}
	var items []apiChecklistItem
	if err := json.Unmarshal([]byte(raw), &items); err != nil {
		return []apiChecklistItem{}
	}
	if items == nil {
		return []apiChecklistItem{}
	}
	return items
}

// normalizeTaskTags trims prefixes, drops empties/duplicates and caps the
// number of labels stored on a task.
func normalizeTaskTags(tags []string) store.StringList {
	seen := make(map[string]bool, len(tags))
	out := make([]string, 0, len(tags))
	for _, raw := range tags {
		tag := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(raw), "#"))
		tag = strings.ReplaceAll(tag, ",", "")
		if tag == "" || seen[tag] {
			continue
		}
		seen[tag] = true
		out = append(out, tag)
		if len(out) >= 20 {
			break
		}
	}
	return store.StringList(out)
}

func encodeChecklist(items []apiChecklistItem) string {
	if len(items) == 0 {
		return ""
	}
	encoded, err := json.Marshal(items)
	if err != nil {
		return ""
	}
	return string(encoded)
}

func apiTaskDTO(task *store.Task, list *store.TaskList) apiTask {
	dto := apiTask{
		ID:         task.ID,
		ParentID:   task.ParentID,
		ListID:     task.ListID,
		Title:      task.Title,
		Notes:      task.Notes,
		Priority:   task.Priority,
		AllDay:     task.AllDay,
		Completed:  task.Completed,
		Tags:       append([]string(nil), task.Tags...),
		Checklist:  decodeChecklist(task.Checklist),
		Order:      task.Order,
		CreatedAt:  task.CreatedAt.Format(time.RFC3339),
		ModifiedAt: task.ModifiedAt.Format(time.RFC3339),
	}
	if dto.Tags == nil {
		dto.Tags = []string{}
	}
	if task.DueAt != nil {
		dto.Due = task.DueAt.Format(time.RFC3339)
	}
	if task.CompletedAt != nil {
		dto.CompletedAt = task.CompletedAt.Format(time.RFC3339)
	}
	if list != nil {
		dto.ListName = list.Name
		dto.ListColor = list.Color
	}
	return dto
}

func apiTaskListDTO(list *store.TaskList, count int64) apiTaskList {
	return apiTaskList{
		ID:      list.ID,
		Name:    list.Name,
		Color:   list.Color,
		Order:   list.Order,
		IsInbox: list.IsInbox,
		Count:   count,
	}
}

// taskLocation resolves the caller's timezone for quick-add parsing.
func taskLocation(raw string) *time.Location {
	raw = strings.TrimSpace(raw)
	if raw != "" {
		if loc, err := time.LoadLocation(raw); err == nil {
			return loc
		}
	}
	if loc, err := time.LoadLocation(store.DefaultTimezone); err == nil {
		return loc
	}
	return time.Local
}

// parseTaskDue accepts RFC3339, "2006-01-02T15:04" or a bare date.
func parseTaskDue(raw, tz string, allDay bool) (*time.Time, bool, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, false, true
	}
	loc := taskLocation(tz)
	if parsed, err := time.Parse(time.RFC3339, raw); err == nil {
		utc := parsed.UTC()
		return &utc, allDay, true
	}
	for _, layout := range []string{"2006-01-02T15:04", "2006-01-02T15:04:05", "2006-01-02 15:04"} {
		if parsed, err := time.ParseInLocation(layout, raw, loc); err == nil {
			utc := parsed.UTC()
			return &utc, allDay, true
		}
	}
	if parsed, err := time.ParseInLocation("2006-01-02", raw, loc); err == nil {
		utc := parsed.UTC()
		return &utc, true, true
	}
	return nil, false, false
}

// ---------------------------------------------------------------- handlers

func (s *Server) apiTaskWorkspace(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	ctx := r.Context()
	inbox, err := s.store.EnsureInbox(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	lists, err := s.store.ListTaskLists(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}

	view := strings.TrimSpace(r.URL.Query().Get("view"))
	if view == "" {
		view = "all"
	}
	listID, _ := strconv.ParseInt(r.URL.Query().Get("listId"), 10, 64)
	if view == "inbox" {
		listID = inbox.ID
	}
	if view == "today" || view == "next7" || view == "completed" {
		listID = 0
	}
	filter := store.TaskFilter{
		View:   view,
		ListID: listID,
		Query:  strings.TrimSpace(r.URL.Query().Get("q")),
	}
	tasks, err := s.store.ListTasks(ctx, current.ID, filter)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	counts, err := s.store.TaskCounts(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}

	byID := make(map[int64]*store.TaskList, len(lists))
	listRows := make([]apiTaskList, 0, len(lists))
	for _, list := range lists {
		byID[list.ID] = list
		count, err := s.store.CountTasksInList(ctx, current.ID, list.ID)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		listRows = append(listRows, apiTaskListDTO(list, count))
	}

	rows := make([]apiTask, 0, len(tasks))
	for _, task := range tasks {
		rows = append(rows, apiTaskDTO(task, byID[task.ListID]))
	}

	writeAPIJSON(w, http.StatusOK, map[string]any{
		"lists":  listRows,
		"tasks":  rows,
		"counts": counts,
		"tags":   s.taskTags(ctx, current.ID),
		"inbox":  inbox.ID,
	})
}

// taskTags collects the distinct tags used by a user's open tasks.
func (s *Server) taskTags(ctx context.Context, userID int64) []string {
	tasks, err := s.store.ListTasks(ctx, userID, store.TaskFilter{View: "all", Limit: 500})
	if err != nil {
		return []string{}
	}
	seen := map[string]bool{}
	out := make([]string, 0, 8)
	for _, task := range tasks {
		for _, tag := range task.Tags {
			if tag == "" || seen[tag] {
				continue
			}
			seen[tag] = true
			out = append(out, tag)
		}
	}
	return out
}

func (s *Server) apiCreateTask(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body taskPatch
	if !readAPIJSON(w, r, &body) {
		return
	}
	ctx := r.Context()
	inbox, err := s.store.EnsureInbox(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	task := &store.Task{UserID: current.ID, ListID: inbox.ID}
	title := ""
	if body.Title != nil {
		title = strings.TrimSpace(*body.Title)
	}
	text := ""
	if body.Text != nil {
		text = strings.TrimSpace(*body.Text)
	}
	if body.ListID != nil && *body.ListID > 0 {
		task.ListID = *body.ListID
	}
	if body.Notes != nil {
		task.Notes = *body.Notes
	}
	if body.Priority != nil {
		task.Priority = *body.Priority
	}
	if body.Tags != nil {
		task.Tags = normalizeTaskTags(*body.Tags)
	}
	if body.Checklist != nil {
		task.Checklist = encodeChecklist(*body.Checklist)
	}
	if body.AllDay != nil {
		task.AllDay = *body.AllDay
	}
	if body.Completed != nil {
		task.Completed = *body.Completed
	}
	if body.Due != nil && strings.TrimSpace(*body.Due) != "" {
		due, allDay, ok := parseTaskDue(*body.Due, body.Timezone, task.AllDay)
		if !ok {
			writeAPIError(w, http.StatusBadRequest, "无效的日期")
			return
		}
		task.DueAt = due
		task.AllDay = allDay
	}
	if text != "" && title == "" {
		parsed := taskparse.Parse(text, time.Now(), taskLocation(body.Timezone))
		title = parsed.Title
		if task.DueAt == nil && parsed.Due != nil {
			utc := parsed.Due.UTC()
			task.DueAt = &utc
			task.AllDay = parsed.AllDay
		}
		if task.Priority == 0 {
			task.Priority = parsed.Priority
		}
		if len(task.Tags) == 0 && len(parsed.Tags) > 0 {
			task.Tags = normalizeTaskTags(parsed.Tags)
		}
	}
	if title == "" {
		writeAPIError(w, http.StatusBadRequest, "任务标题不能为空")
		return
	}
	task.Title = title
	created, err := s.store.CreateTask(ctx, task)
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusBadRequest, "清单不存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	list, _ := s.store.GetTaskList(ctx, current.ID, created.ListID)
	writeAPIJSON(w, http.StatusCreated, map[string]any{"task": apiTaskDTO(created, list)})
}

func (s *Server) apiUpdateTask(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	var body taskPatch
	if !readAPIJSON(w, r, &body) {
		return
	}
	ctx := r.Context()
	task, err := s.store.GetTask(ctx, current.ID, id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	if body.Title != nil {
		task.Title = strings.TrimSpace(*body.Title)
	}
	if body.ListID != nil && *body.ListID > 0 {
		task.ListID = *body.ListID
	}
	if body.Notes != nil {
		task.Notes = *body.Notes
	}
	if body.Priority != nil {
		task.Priority = *body.Priority
	}
	if body.Tags != nil {
		task.Tags = normalizeTaskTags(*body.Tags)
	}
	if body.Checklist != nil {
		task.Checklist = encodeChecklist(*body.Checklist)
	}
	if body.AllDay != nil {
		task.AllDay = *body.AllDay
	}
	if body.Due != nil {
		due, allDay, ok := parseTaskDue(*body.Due, body.Timezone, task.AllDay)
		if !ok {
			writeAPIError(w, http.StatusBadRequest, "无效的日期")
			return
		}
		task.DueAt = due
		if strings.TrimSpace(*body.Due) != "" {
			task.AllDay = allDay
		} else {
			task.AllDay = false
		}
	}
	if body.Completed != nil {
		completed := *body.Completed
		updated, err := s.store.SetTaskCompleted(ctx, current.ID, id, completed)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		task.Completed = updated.Completed
		task.CompletedAt = updated.CompletedAt
	}
	if body.Text != nil && strings.TrimSpace(*body.Text) != "" {
		parsed := taskparse.Parse(*body.Text, time.Now(), taskLocation(body.Timezone))
		if task.Title == "" {
			task.Title = parsed.Title
		}
		if task.DueAt == nil && parsed.Due != nil {
			utc := parsed.Due.UTC()
			task.DueAt = &utc
			task.AllDay = parsed.AllDay
		}
		if task.Priority == 0 {
			task.Priority = parsed.Priority
		}
		if len(task.Tags) == 0 && len(parsed.Tags) > 0 {
			task.Tags = normalizeTaskTags(parsed.Tags)
		}
	}
	if err := s.store.UpdateTask(ctx, task); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "任务不存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	list, _ := s.store.GetTaskList(ctx, current.ID, task.ListID)
	writeAPIJSON(w, http.StatusOK, map[string]any{"task": apiTaskDTO(task, list)})
}

func (s *Server) apiDeleteTask(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	if err := s.store.DeleteTask(r.Context(), current.ID, id); err != nil {
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) apiCreateTaskList(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		Name  string `json:"name"`
		Color string `json:"color"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Color) == "" {
		body.Color = "#4772fa"
	}
	list, err := s.store.CreateTaskList(r.Context(), current.ID, body.Name, body.Color)
	if err != nil {
		if err == store.ErrConflict {
			writeAPIError(w, http.StatusConflict, "同名清单已存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"list": apiTaskListDTO(list, 0)})
}

func (s *Server) apiUpdateTaskList(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "清单不存在")
		return
	}
	existing, err := s.store.GetTaskList(r.Context(), current.ID, id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "清单不存在")
		return
	}
	var body struct {
		Name  string `json:"name"`
		Color string `json:"color"`
		Order *int   `json:"order"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Name) == "" {
		body.Name = existing.Name
	}
	if strings.TrimSpace(body.Color) == "" {
		body.Color = existing.Color
	}
	order := existing.Order
	if body.Order != nil {
		order = *body.Order
	}
	if err := s.store.UpdateTaskList(r.Context(), current.ID, id, body.Name, body.Color, order); err != nil {
		if err == store.ErrConflict {
			writeAPIError(w, http.StatusConflict, "同名清单已存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	updated, _ := s.store.GetTaskList(r.Context(), current.ID, id)
	count, _ := s.store.CountTasksInList(r.Context(), current.ID, id)
	writeAPIJSON(w, http.StatusOK, map[string]any{"list": apiTaskListDTO(updated, count)})
}

func (s *Server) apiDeleteTaskList(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "清单不存在")
		return
	}
	if err := s.store.DeleteTaskList(r.Context(), current.ID, id); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "清单不存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
