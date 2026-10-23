package web

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
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
	ID       int64  `json:"id"`
	FolderID int64  `json:"folderId"`
	Name     string `json:"name"`
	Color    string `json:"color"`
	Order    int    `json:"order"`
	IsInbox  bool   `json:"isInbox"`
	Count    int64  `json:"count"`
}

type apiTaskFolder struct {
	ID    int64  `json:"id"`
	Name  string `json:"name"`
	Order int    `json:"order"`
}

type apiSavedFilter struct {
	ID         int64                      `json:"id"`
	Name       string                     `json:"name"`
	Color      string                     `json:"color"`
	Conditions store.TaskFilterConditions `json:"conditions"`
	Order      int                        `json:"order"`
}

type apiTask struct {
	ID              int64              `json:"id"`
	ParentID        int64              `json:"parentId,omitempty"`
	ListID          int64              `json:"listId"`
	ListName        string             `json:"listName"`
	ListColor       string             `json:"listColor"`
	Title           string             `json:"title"`
	Notes           string             `json:"notes"`
	Priority        int                `json:"priority"`
	Due             string             `json:"due,omitempty"`
	AllDay          bool               `json:"allDay"`
	Completed       bool               `json:"completed"`
	CompletedAt     string             `json:"completedAt,omitempty"`
	Recurrence      string             `json:"recurrence"`
	ReminderOffset  int                `json:"reminderOffset"`
	ReminderOffsets []int              `json:"reminderOffsets"`
	DeletedAt       string             `json:"deletedAt,omitempty"`
	Tags            []string           `json:"tags"`
	Checklist       []apiChecklistItem `json:"checklist"`
	Order           int                `json:"order"`
	CreatedAt       string             `json:"createdAt"`
	ModifiedAt      string             `json:"modifiedAt"`
}

type taskPatch struct {
	Text            *string             `json:"text"`
	Title           *string             `json:"title"`
	ListID          *int64              `json:"listId"`
	Notes           *string             `json:"notes"`
	Priority        *int                `json:"priority"`
	Due             *string             `json:"due"`
	AllDay          *bool               `json:"allDay"`
	Completed       *bool               `json:"completed"`
	Tags            *[]string           `json:"tags"`
	Checklist       *[]apiChecklistItem `json:"checklist"`
	Recurrence      *string             `json:"recurrence"`
	ReminderOffset  *int                `json:"reminderOffset"`
	ReminderOffsets *[]int              `json:"reminderOffsets"`
	Timezone        string              `json:"timezone"`
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
		ID:              task.ID,
		ParentID:        task.ParentID,
		ListID:          task.ListID,
		Title:           task.Title,
		Notes:           task.Notes,
		Priority:        task.Priority,
		AllDay:          task.AllDay,
		Completed:       task.Completed,
		Recurrence:      task.Recurrence,
		ReminderOffset:  task.ReminderOffset,
		ReminderOffsets: task.ReminderValues(),
		Tags:            append([]string(nil), task.Tags...),
		Checklist:       decodeChecklist(task.Checklist),
		Order:           task.Order,
		CreatedAt:       task.CreatedAt.Format(time.RFC3339),
		ModifiedAt:      task.ModifiedAt.Format(time.RFC3339),
	}
	if dto.Tags == nil {
		dto.Tags = []string{}
	}
	if dto.ReminderOffsets == nil {
		dto.ReminderOffsets = []int{}
	}
	if task.DueAt != nil {
		dto.Due = task.DueAt.Format(time.RFC3339)
	}
	if task.CompletedAt != nil {
		dto.CompletedAt = task.CompletedAt.Format(time.RFC3339)
	}
	if task.DeletedAt != nil {
		dto.DeletedAt = task.DeletedAt.Format(time.RFC3339)
	}
	if list != nil {
		dto.ListName = list.Name
		dto.ListColor = list.Color
	}
	return dto
}

func apiTaskListDTO(list *store.TaskList, count int64) apiTaskList {
	return apiTaskList{
		ID:       list.ID,
		FolderID: list.FolderID,
		Name:     list.Name,
		Color:    list.Color,
		Order:    list.Order,
		IsInbox:  list.IsInbox,
		Count:    count,
	}
}

func apiTaskFolderDTO(folder *store.TaskFolder) apiTaskFolder {
	return apiTaskFolder{ID: folder.ID, Name: folder.Name, Order: folder.Order}
}

func apiSavedFilterDTO(filter *store.SavedFilter) apiSavedFilter {
	dto := apiSavedFilter{ID: filter.ID, Name: filter.Name, Color: filter.Color, Order: filter.Order}
	if filter.Conditions != "" {
		_ = json.Unmarshal([]byte(filter.Conditions), &dto.Conditions)
	}
	return dto
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
	if err := s.taskSync.Sync(ctx, current.ID); err != nil {
		s.logger.Warn("sync task workspace", "user", current.Username, "error", err)
	}
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
	filterID, _ := strconv.ParseInt(r.URL.Query().Get("filterId"), 10, 64)
	listID, _ := strconv.ParseInt(r.URL.Query().Get("listId"), 10, 64)
	if view == "inbox" {
		listID = inbox.ID
	}
	if view == "today" || view == "next7" || view == "completed" || view == "trash" {
		listID = 0
	}
	var tasks []*store.Task
	if filterID > 0 {
		saved, err := s.store.GetSavedFilter(ctx, current.ID, filterID)
		if err != nil {
			writeAPIError(w, http.StatusNotFound, "过滤器不存在")
			return
		}
		conditions := store.TaskFilterConditions{}
		if saved.Conditions != "" {
			if err := json.Unmarshal([]byte(saved.Conditions), &conditions); err != nil {
				writeAPIError(w, http.StatusInternalServerError, "过滤器条件损坏")
				return
			}
		}
		tasks, err = s.store.ListFilteredTasks(ctx, current.ID, conditions, 300)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
	} else {
		filter := store.TaskFilter{
			View:   view,
			ListID: listID,
			Query:  strings.TrimSpace(r.URL.Query().Get("q")),
		}
		tasks, err = s.store.ListTasks(ctx, current.ID, filter)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
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

	folders, err := s.store.ListTaskFolders(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	folderRows := make([]apiTaskFolder, 0, len(folders))
	for _, folder := range folders {
		folderRows = append(folderRows, apiTaskFolderDTO(folder))
	}
	filters, err := s.store.ListSavedFilters(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	filterRows := make([]apiSavedFilter, 0, len(filters))
	for _, filter := range filters {
		filterRows = append(filterRows, apiSavedFilterDTO(filter))
	}
	tagCounts, err := s.store.TaskTagCounts(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	shared, err := s.store.ListSharedTaskLists(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	sharedRows := make([]apiSharedTaskList, 0, len(shared))
	for _, item := range shared {
		sharedRows = append(sharedRows, sharedTaskListDTO(item))
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"lists":       listRows,
		"sharedLists": sharedRows,
		"folders":     folderRows,
		"filters":     filterRows,
		"tasks":       rows,
		"counts":      counts,
		"tags":        s.taskTags(ctx, current.ID),
		"tagCounts":   tagCounts,
		"inbox":       inbox.ID,
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

func applyTaskReminders(task *store.Task, body taskPatch) error {
	if body.ReminderOffsets != nil {
		offsets, err := store.NormalizeReminderOffsets(*body.ReminderOffsets)
		if err != nil {
			return err
		}
		task.SetReminderValues(offsets)
		return nil
	}
	if body.ReminderOffset != nil {
		if *body.ReminderOffset < -1 || *body.ReminderOffset > 10080 {
			return errors.New("提醒偏移必须在 -1 到 10080 分钟之间")
		}
		if *body.ReminderOffset < 0 {
			task.SetReminderValues(nil)
		} else {
			task.SetReminderValues([]int{*body.ReminderOffset})
		}
	}
	return nil
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
	task := &store.Task{UserID: current.ID, ListID: inbox.ID, ReminderOffset: -1}
	title := ""
	if body.Title != nil {
		title = strings.TrimSpace(*body.Title)
	}
	text := ""
	if body.Text != nil {
		text = strings.TrimSpace(*body.Text)
	}
	if body.ListID != nil && *body.ListID > 0 {
		if own, err := s.store.GetTaskList(ctx, current.ID, *body.ListID); err == nil {
			task.ListID = own.ID
		} else if shared, role, shareErr := s.store.GetSharedTaskList(ctx, current.ID, *body.ListID); shareErr == nil {
			if role != "editor" {
				writeAPIError(w, http.StatusForbidden, "该共享清单为只读")
				return
			}
			task.UserID = shared.UserID
			task.ListID = shared.ID
		} else {
			writeAPIError(w, http.StatusBadRequest, "清单不存在")
			return
		}
	}
	if body.Notes != nil {
		task.Notes = *body.Notes
	}
	if body.Priority != nil {
		task.Priority = *body.Priority
	}
	if body.Recurrence != nil {
		rule := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(*body.Recurrence), "RRULE:"))
		if rule != "" && !taskparse.ValidRule(rule) {
			writeAPIError(w, http.StatusBadRequest, "无效的重复规则")
			return
		}
		task.Recurrence = rule
	}
	if err := applyTaskReminders(task, body); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
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
	if err := s.taskSync.PushTask(ctx, created.UserID, created); err != nil {
		s.logger.Warn("push task to caldav", "user", current.Username, "task", created.ID, "error", err)
	}
	list, _ := s.store.GetTaskList(ctx, created.UserID, created.ListID)
	writeAPIJSON(w, http.StatusCreated, map[string]any{"task": apiTaskDTO(created, list)})
}

func (s *Server) taskForWrite(ctx context.Context, current *store.User, id int64) (*store.Task, *store.TaskList, string, bool, error) {
	task, err := s.store.GetTask(ctx, current.ID, id)
	if err == nil {
		list, listErr := s.store.GetTaskList(ctx, current.ID, task.ListID)
		return task, list, "", false, listErr
	}
	if err != store.ErrNotFound {
		return nil, nil, "", false, err
	}
	task, list, role, err := s.store.GetSharedTask(ctx, current.ID, id)
	if err != nil {
		return nil, nil, "", false, err
	}
	if role != "editor" {
		return nil, nil, role, true, store.ErrForbidden
	}
	return task, list, role, true, nil
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
	task, list, _, shared, err := s.taskForWrite(ctx, current, id)
	if err != nil {
		if err == store.ErrForbidden {
			writeAPIError(w, http.StatusForbidden, "该共享清单为只读")
			return
		}
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	if shared && body.ListID != nil && *body.ListID > 0 && *body.ListID != task.ListID {
		writeAPIError(w, http.StatusBadRequest, "共享任务不能移动到其他清单")
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
	if body.Recurrence != nil {
		rule := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(*body.Recurrence), "RRULE:"))
		if rule != "" && !taskparse.ValidRule(rule) {
			writeAPIError(w, http.StatusBadRequest, "无效的重复规则")
			return
		}
		task.Recurrence = rule
	}
	if err := applyTaskReminders(task, body); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
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
		applyTaskCompletion(task, *body.Completed)
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
	if err := s.taskSync.PushTask(ctx, task.UserID, task); err != nil {
		s.logger.Warn("push task to caldav", "user", current.Username, "task", task.ID, "error", err)
	}
	if list == nil {
		list, _ = s.store.GetTaskList(ctx, task.UserID, task.ListID)
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"task": apiTaskDTO(task, list)})
}

func (s *Server) apiDeleteTask(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	ctx := r.Context()
	task, _, _, _, err := s.taskForWrite(ctx, current, id)
	if err != nil {
		if err == store.ErrForbidden {
			writeAPIError(w, http.StatusForbidden, "该共享清单为只读")
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	// Remove the VTODO first: a stale object without a task would otherwise be
	// imported as a brand new task on the next sync.
	if err := s.taskSync.DeleteTask(ctx, task.UserID, task); err != nil {
		s.apiServerError(w, err)
		return
	}
	if err := s.store.DeleteTask(ctx, task.UserID, id); err != nil {
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) apiCreateTaskList(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		Name     string `json:"name"`
		Color    string `json:"color"`
		FolderID int64  `json:"folderId"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Color) == "" {
		body.Color = "#4772fa"
	}
	if body.FolderID > 0 {
		if _, err := s.store.GetTaskFolder(r.Context(), current.ID, body.FolderID); err != nil {
			writeAPIError(w, http.StatusBadRequest, "文件夹不存在")
			return
		}
	}
	list, err := s.store.CreateTaskList(r.Context(), current.ID, body.Name, body.Color)
	if err == nil && body.FolderID > 0 {
		if folderErr := s.store.SetTaskListFolder(r.Context(), current.ID, list.ID, body.FolderID); folderErr != nil {
			writeAPIError(w, http.StatusBadRequest, "文件夹不存在")
			return
		}
		list.FolderID = body.FolderID
	}
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
		Name     string `json:"name"`
		Color    string `json:"color"`
		Order    *int   `json:"order"`
		FolderID *int64 `json:"folderId"`
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
	if body.FolderID != nil && *body.FolderID > 0 {
		if _, err := s.store.GetTaskFolder(r.Context(), current.ID, *body.FolderID); err != nil {
			writeAPIError(w, http.StatusBadRequest, "文件夹不存在")
			return
		}
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
	if body.FolderID != nil {
		if err := s.store.SetTaskListFolder(r.Context(), current.ID, id, *body.FolderID); err != nil {
			writeAPIError(w, http.StatusBadRequest, "文件夹不存在")
			return
		}
	}
	if err := s.taskSync.Sync(r.Context(), current.ID); err != nil {
		s.logger.Warn("sync task workspace", "user", current.Username, "error", err)
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
	if err := s.pruneFilterLists(r.Context(), current.ID, id); err != nil {
		s.logger.Warn("update filters after list delete", "error", err)
	}
	if err := s.taskSync.Sync(r.Context(), current.ID); err != nil {
		s.logger.Warn("sync task workspace", "user", current.Username, "error", err)
	}
	w.WriteHeader(http.StatusNoContent)
}

// applyTaskCompletion completes a task. Recurring tasks with a due date are
// advanced to the next occurrence instead of being archived; the boolean
// result reports whether the task was advanced.
func applyTaskCompletion(task *store.Task, completed bool) bool {
	if completed && task.Recurrence != "" && task.DueAt != nil {
		if next, ok := taskparse.NextOccurrence(task.Recurrence, *task.DueAt); ok {
			task.DueAt = &next
			task.Completed = false
			task.CompletedAt = nil
			return true
		}
	}
	task.Completed = completed
	if !completed {
		task.CompletedAt = nil
	}
	return false
}

func (s *Server) apiTaskReminders(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	ctx := r.Context()
	tasks, err := s.store.ListReminderTasks(ctx, current.ID, 200)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	lists, err := s.store.ListTaskLists(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	byID := make(map[int64]*store.TaskList, len(lists))
	for _, list := range lists {
		byID[list.ID] = list
	}
	rows := make([]apiTask, 0, len(tasks))
	for _, task := range tasks {
		rows = append(rows, apiTaskDTO(task, byID[task.ListID]))
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"tasks": rows})
}

func (s *Server) apiBatchTasks(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		IDs    []int64 `json:"ids"`
		Action string  `json:"action"`
		ListID int64   `json:"listId"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if len(body.IDs) == 0 || len(body.IDs) > 200 {
		writeAPIError(w, http.StatusBadRequest, "请选择 1-200 个任务")
		return
	}
	if body.Action != "complete" && body.Action != "uncomplete" && body.Action != "move" && body.Action != "delete" {
		writeAPIError(w, http.StatusBadRequest, "无效的批量操作")
		return
	}
	if body.Action == "move" {
		if _, err := s.store.GetTaskList(r.Context(), current.ID, body.ListID); err != nil {
			writeAPIError(w, http.StatusBadRequest, "目标清单不存在")
			return
		}
	}
	ctx := r.Context()
	seen := make(map[int64]bool, len(body.IDs))
	updated := 0
	for _, id := range body.IDs {
		if seen[id] {
			continue
		}
		seen[id] = true
		task, err := s.store.GetTask(ctx, current.ID, id)
		if err != nil {
			continue
		}
		switch body.Action {
		case "delete":
			if err := s.taskSync.DeleteTask(ctx, current.ID, task); err != nil {
				s.logger.Warn("delete task caldav object", "task", id, "error", err)
				continue
			}
			if err := s.store.DeleteTask(ctx, current.ID, id); err != nil {
				continue
			}
			updated++
			continue
		case "complete", "uncomplete":
			applyTaskCompletion(task, body.Action == "complete")
		case "move":
			task.ListID = body.ListID
		}
		if err := s.store.UpdateTask(ctx, task); err != nil {
			continue
		}
		if err := s.taskSync.PushTask(ctx, current.ID, task); err != nil {
			s.logger.Warn("push task to caldav", "task", id, "error", err)
		}
		updated++
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"updated": updated})
}

func (s *Server) apiReorderTasks(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		IDs []int64 `json:"ids"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if len(body.IDs) > 500 {
		writeAPIError(w, http.StatusBadRequest, "一次最多排序 500 个任务")
		return
	}
	if err := s.store.SetTaskOrder(r.Context(), current.ID, body.IDs); err != nil {
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) apiRestoreTask(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	ctx := r.Context()
	task, err := s.store.RestoreTask(ctx, current.ID, id)
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "任务不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	if err := s.taskSync.PushTask(ctx, current.ID, task); err != nil {
		s.logger.Warn("push restored task", "task", id, "error", err)
	}
	list, _ := s.store.GetTaskList(ctx, current.ID, task.ListID)
	writeAPIJSON(w, http.StatusOK, map[string]any{"task": apiTaskDTO(task, list)})
}

func (s *Server) apiPurgeTask(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	if err := s.store.PurgeTask(r.Context(), current.ID, id); err != nil {
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) apiEmptyTrash(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	if _, err := s.store.PurgeDeletedTasks(r.Context(), current.ID); err != nil {
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------- folders

func (s *Server) apiCreateTaskFolder(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		Name string `json:"name"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	folder, err := s.store.CreateTaskFolder(r.Context(), current.ID, body.Name)
	if err != nil {
		if err == store.ErrConflict {
			writeAPIError(w, http.StatusConflict, "同名文件夹已存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"folder": apiTaskFolderDTO(folder)})
}

func (s *Server) apiUpdateTaskFolder(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "文件夹不存在")
		return
	}
	existing, err := s.store.GetTaskFolder(r.Context(), current.ID, id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "文件夹不存在")
		return
	}
	var body struct {
		Name  string `json:"name"`
		Order *int   `json:"order"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Name) == "" {
		body.Name = existing.Name
	}
	order := existing.Order
	if body.Order != nil {
		order = *body.Order
	}
	if err := s.store.UpdateTaskFolder(r.Context(), current.ID, id, body.Name, order); err != nil {
		if err == store.ErrConflict {
			writeAPIError(w, http.StatusConflict, "同名文件夹已存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	updated, _ := s.store.GetTaskFolder(r.Context(), current.ID, id)
	writeAPIJSON(w, http.StatusOK, map[string]any{"folder": apiTaskFolderDTO(updated)})
}

func (s *Server) apiDeleteTaskFolder(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "文件夹不存在")
		return
	}
	if err := s.store.DeleteTaskFolder(r.Context(), current.ID, id); err != nil {
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------- tags

func (s *Server) apiTaskTags(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	tags, err := s.store.TaskTagCounts(r.Context(), current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"tags": tags})
}

// pruneFilterLists removes a deleted list from saved filter conditions.
func (s *Server) pruneFilterLists(ctx context.Context, userID, listID int64) error {
	filters, err := s.store.ListSavedFilters(ctx, userID)
	if err != nil {
		return err
	}
	for _, filter := range filters {
		conditions := store.TaskFilterConditions{}
		if filter.Conditions != "" {
			if err := json.Unmarshal([]byte(filter.Conditions), &conditions); err != nil {
				continue
			}
		}
		changed := false
		ids := make([]int64, 0, len(conditions.ListIDs))
		for _, id := range conditions.ListIDs {
			if id == listID {
				changed = true
				continue
			}
			ids = append(ids, id)
		}
		if !changed {
			continue
		}
		conditions.ListIDs = ids
		encoded, err := json.Marshal(conditions)
		if err != nil {
			return err
		}
		if err := s.store.UpdateSavedFilter(ctx, userID, filter.ID, filter.Name, filter.Color, string(encoded), filter.Order); err != nil {
			return err
		}
	}
	return nil
}

// retagSavedFilters keeps saved filter conditions consistent after a tag is
// renamed or removed.
func (s *Server) retagSavedFilters(ctx context.Context, userID int64, from, to string) error {
	filters, err := s.store.ListSavedFilters(ctx, userID)
	if err != nil {
		return err
	}
	for _, filter := range filters {
		conditions := store.TaskFilterConditions{}
		if filter.Conditions != "" {
			if err := json.Unmarshal([]byte(filter.Conditions), &conditions); err != nil {
				continue
			}
		}
		changed := false
		tags := make([]string, 0, len(conditions.Tags))
		for _, tag := range conditions.Tags {
			if tag == from {
				changed = true
				if to == "" {
					continue
				}
				tag = to
			}
			if !containsString(tags, tag) {
				tags = append(tags, tag)
			}
		}
		if !changed {
			continue
		}
		conditions.Tags = tags
		encoded, err := json.Marshal(conditions)
		if err != nil {
			return err
		}
		if err := s.store.UpdateSavedFilter(ctx, userID, filter.ID, filter.Name, filter.Color, string(encoded), filter.Order); err != nil {
			return err
		}
	}
	return nil
}

func containsString(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}

func (s *Server) apiRenameTaskTag(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		From string `json:"from"`
		To   string `json:"to"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if err := s.store.RenameTaskTag(r.Context(), current.ID, body.From, body.To); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := s.retagSavedFilters(r.Context(), current.ID, body.From, body.To); err != nil {
		s.logger.Warn("update filters after tag rename", "error", err)
	}
	if err := s.taskSync.Sync(r.Context(), current.ID); err != nil {
		s.logger.Warn("sync after tag rename", "user", current.Username, "error", err)
	}
	s.apiTaskTags(w, r, current, nil)
}

func (s *Server) apiDeleteTaskTag(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		Tag string `json:"tag"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if err := s.store.DeleteTaskTag(r.Context(), current.ID, body.Tag); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := s.retagSavedFilters(r.Context(), current.ID, body.Tag, ""); err != nil {
		s.logger.Warn("update filters after tag delete", "error", err)
	}
	if err := s.taskSync.Sync(r.Context(), current.ID); err != nil {
		s.logger.Warn("sync after tag delete", "user", current.Username, "error", err)
	}
	s.apiTaskTags(w, r, current, nil)
}

// ---------------------------------------------------------------- saved filters

func normalizeFilterConditions(cond store.TaskFilterConditions) (store.TaskFilterConditions, error) {
	if len(cond.ListIDs) > 50 || len(cond.Tags) > 20 || len(cond.Priorities) > 3 {
		return cond, fmt.Errorf("过滤器条件过多")
	}
	switch cond.Status {
	case "", "open", "completed", "all":
	default:
		return cond, fmt.Errorf("无效的状态条件")
	}
	if cond.Status == "" {
		cond.Status = "open"
	}
	switch cond.Date {
	case "", "any", "today", "next7", "overdue", "none":
	default:
		return cond, fmt.Errorf("无效的日期条件")
	}
	if cond.Date == "" {
		cond.Date = "any"
	}
	if cond.TagMode != "all" {
		cond.TagMode = "any"
	}
	tags := make([]string, 0, len(cond.Tags))
	seen := map[string]bool{}
	for _, raw := range cond.Tags {
		tag := strings.TrimSpace(strings.TrimPrefix(raw, "#"))
		if tag == "" || seen[tag] {
			continue
		}
		seen[tag] = true
		tags = append(tags, tag)
	}
	cond.Tags = tags
	priorities := make([]int, 0, len(cond.Priorities))
	seenPriority := map[int]bool{}
	for _, priority := range cond.Priorities {
		if priority < 1 || priority > 3 || seenPriority[priority] {
			continue
		}
		seenPriority[priority] = true
		priorities = append(priorities, priority)
	}
	cond.Priorities = priorities
	lists := make([]int64, 0, len(cond.ListIDs))
	seenList := map[int64]bool{}
	for _, id := range cond.ListIDs {
		if id <= 0 || seenList[id] {
			continue
		}
		seenList[id] = true
		lists = append(lists, id)
	}
	cond.ListIDs = lists
	cond.Keyword = strings.TrimSpace(cond.Keyword)
	if len([]rune(cond.Keyword)) > 100 {
		return cond, fmt.Errorf("关键词过长")
	}
	return cond, nil
}

func filterConditionsJSON(cond store.TaskFilterConditions) (string, error) {
	normalized, err := normalizeFilterConditions(cond)
	if err != nil {
		return "", err
	}
	encoded, err := json.Marshal(normalized)
	if err != nil {
		return "", err
	}
	return string(encoded), nil
}

func (s *Server) apiSavedFilters(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	filters, err := s.store.ListSavedFilters(r.Context(), current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	rows := make([]apiSavedFilter, 0, len(filters))
	for _, filter := range filters {
		rows = append(rows, apiSavedFilterDTO(filter))
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"filters": rows})
}

func (s *Server) apiCreateSavedFilter(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		Name       string                     `json:"name"`
		Color      string                     `json:"color"`
		Conditions store.TaskFilterConditions `json:"conditions"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	conditions, err := filterConditionsJSON(body.Conditions)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	filter, err := s.store.CreateSavedFilter(r.Context(), current.ID, body.Name, body.Color, conditions)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"filter": apiSavedFilterDTO(filter)})
}

func (s *Server) apiUpdateSavedFilter(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "过滤器不存在")
		return
	}
	existing, err := s.store.GetSavedFilter(r.Context(), current.ID, id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "过滤器不存在")
		return
	}
	var body struct {
		Name       string                     `json:"name"`
		Color      string                     `json:"color"`
		Conditions store.TaskFilterConditions `json:"conditions"`
		Order      *int                       `json:"order"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Name) == "" {
		body.Name = existing.Name
	}
	if body.Color == "" {
		body.Color = existing.Color
	}
	conditions, err := filterConditionsJSON(body.Conditions)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	order := existing.Order
	if body.Order != nil {
		order = *body.Order
	}
	if err := s.store.UpdateSavedFilter(r.Context(), current.ID, id, body.Name, body.Color, conditions, order); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	updated, _ := s.store.GetSavedFilter(r.Context(), current.ID, id)
	writeAPIJSON(w, http.StatusOK, map[string]any{"filter": apiSavedFilterDTO(updated)})
}

func (s *Server) apiDeleteSavedFilter(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "过滤器不存在")
		return
	}
	if err := s.store.DeleteSavedFilter(r.Context(), current.ID, id); err != nil {
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) apiTaskStats(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	days, _ := strconv.Atoi(r.URL.Query().Get("days"))
	if days <= 0 || days > 365 {
		days = 30
	}
	stats, err := s.store.ComputeTaskStats(r.Context(), current.ID, days)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"stats": stats})
}
