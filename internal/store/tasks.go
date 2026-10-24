package store

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"

	"caldav-free/internal/richtext"
)

// TaskList is a user-defined list (project) that groups tasks. Every user has
// exactly one inbox list, created lazily on first use.
type TaskList struct {
	ID         int64     `gorm:"primaryKey"`
	UserID     int64     `gorm:"not null;uniqueIndex:idx_tasklist_owner_name,priority:1;index:idx_tasklist_user"`
	FolderID   int64     `gorm:"not null;default:0;index:idx_tasklist_folder"`
	Name       string    `gorm:"size:190;not null;uniqueIndex:idx_tasklist_owner_name,priority:2"`
	Color      string    `gorm:"size:32;not null;default:''"`
	Kind       string    `gorm:"size:16;not null;default:'TASK'"`
	Order      int       `gorm:"column:order_index;not null;default:0"`
	Pinned     bool      `gorm:"not null;default:false;index:idx_tasklist_pinned"`
	IsInbox    bool      `gorm:"not null;default:false"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime"`
}

// TaskSection is a user-defined kanban column inside one task list.
type TaskSection struct {
	ID         int64     `gorm:"primaryKey"`
	UserID     int64     `gorm:"not null;index:idx_tasksection_user"`
	ListID     int64     `gorm:"not null;uniqueIndex:idx_tasksection_list_name,priority:1;index:idx_tasksection_list"`
	Name       string    `gorm:"size:120;not null;uniqueIndex:idx_tasksection_list_name,priority:2"`
	Order      int       `gorm:"column:order_index;not null;default:0"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime"`
}

// Task is a single to-do item. Tasks may be nested one level deep for
// checklists; Deleted is a soft-delete flag so recently removed tasks can be
// inspected before a future purge.
type Task struct {
	ID          int64      `gorm:"primaryKey"`
	UserID      int64      `gorm:"not null;index:idx_task_user_completed,priority:1;index:idx_task_user_due,priority:1"`
	ListID      int64      `gorm:"not null;index:idx_task_list_completed,priority:1"`
	ParentID    int64      `gorm:"not null;default:0;index:idx_task_parent"`
	SectionID   int64      `gorm:"not null;default:0;index:idx_task_section"`
	Title       string     `gorm:"size:500;not null"`
	Notes       string     `gorm:"type:text;not null;default:''"`
	NotesFormat string     `gorm:"size:16;not null;default:'text'"`
	NotesText   string     `gorm:"type:text;not null;default:''"`
	Kind        string     `gorm:"size:16;not null;default:'TASK'"`
	Priority    int        `gorm:"not null;default:0"`
	StartAt     *time.Time `gorm:"index:idx_task_start"`
	DueAt       *time.Time `gorm:"index:idx_task_user_due,priority:2"`
	AllDay      bool       `gorm:"not null;default:false"`
	Recurrence  string     `gorm:"size:255;not null;default:''"`
	// ReminderOffset is the legacy single reminder (minutes before due; -1
	// means none). ReminderOffsets stores all offsets as a comma-separated
	// list; when it is non-empty it is authoritative.
	ReminderOffset  int        `gorm:"not null;default:-1"`
	ReminderOffsets StringList `gorm:"column:reminder_offsets;type:text;not null;default:''"`
	// Assignee is the username of the list owner or a shared member. Empty
	// means unassigned.
	Assignee    string `gorm:"size:190;not null;default:''"`
	Completed   bool   `gorm:"not null;default:false;index:idx_task_user_completed,priority:2;index:idx_task_list_completed,priority:2"`
	CompletedAt *time.Time
	PinnedAt    *time.Time `gorm:"index:idx_task_pinned"`
	Tags        StringList `gorm:"not null"`
	Checklist   string     `gorm:"type:text;not null;default:''"`
	Order       int        `gorm:"column:order_index;not null;default:0"`
	// VTODO fields link a task to its CalDAV object. SyncPending is set on
	// local changes and cleared once the VTODO has been written.
	VTODOUID    string `gorm:"column:vtodo_uid;size:255;not null;default:'';index:idx_task_vtodo_uid"`
	VTODOHref   string `gorm:"column:vtodo_href;size:255;not null;default:''"`
	VTODOETag   string `gorm:"column:vtodo_etag;size:64;not null;default:''"`
	SyncPending bool   `gorm:"column:sync_pending;not null;default:false"`
	Deleted     bool   `gorm:"not null;default:false;index:idx_task_deleted"`
	DeletedAt   *time.Time
	CreatedAt   time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt  time.Time `gorm:"not null;autoUpdateTime"`
}

// MaxReminders is the maximum number of reminders a task may have.
const MaxReminders = 10

// NormalizeReminderOffsets validates, deduplicates and sorts reminder offsets.
// Offsets are minutes before the due time; 0 means exactly at due time.
func NormalizeReminderOffsets(values []int) ([]int, error) {
	if len(values) > MaxReminders {
		return nil, fmt.Errorf("最多设置 %d 个提醒", MaxReminders)
	}
	seen := make(map[int]struct{}, len(values))
	out := make([]int, 0, len(values))
	for _, value := range values {
		if value < 0 || value > 10080 {
			return nil, errors.New("提醒偏移必须在 0-10080 分钟之间")
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		out = append(out, value)
	}
	sort.Ints(out)
	return out, nil
}

// ReminderValues returns the effective reminders, falling back to the legacy
// single ReminderOffset for tasks created before multi-reminder support.
func (t *Task) ReminderValues() []int {
	values := make([]int, 0, len(t.ReminderOffsets))
	for _, raw := range t.ReminderOffsets {
		value, err := strconv.Atoi(strings.TrimSpace(raw))
		if err != nil || value < 0 || value > 10080 {
			continue
		}
		values = append(values, value)
	}
	if len(values) > 0 {
		normalized, _ := NormalizeReminderOffsets(values)
		return normalized
	}
	if t.ReminderOffset >= 0 && t.ReminderOffset <= 10080 {
		return []int{t.ReminderOffset}
	}
	return nil
}

// SetReminderValues stores a normalized reminder list and mirrors the earliest
// reminder into ReminderOffset for legacy clients.
func (t *Task) SetReminderValues(values []int) {
	normalized, err := NormalizeReminderOffsets(values)
	if err != nil {
		normalized = nil
	}
	t.ReminderOffsets = make(StringList, 0, len(normalized))
	for _, value := range normalized {
		t.ReminderOffsets = append(t.ReminderOffsets, strconv.Itoa(value))
	}
	if len(normalized) == 0 {
		t.ReminderOffset = -1
		return
	}
	// The largest offset fires earliest and preserves the old single-reminder
	// meaning for integrations that only read ReminderOffset.
	t.ReminderOffset = normalized[len(normalized)-1]
}

// TaskFilter selects tasks for the smart lists in the task workspace.
type TaskFilter struct {
	View   string
	ListID int64
	Query  string
	Limit  int
}

// TaskCounts holds the badge numbers shown in the task sidebar.
type TaskCounts struct {
	All       int64 `json:"all"`
	Today     int64 `json:"today"`
	Next7     int64 `json:"next7"`
	Inbox     int64 `json:"inbox"`
	Completed int64 `json:"completed"`
	Trash     int64 `json:"trash"`
}

// EnsureInbox returns the user's inbox list, creating it when missing.
func (s *Store) EnsureInbox(ctx context.Context, userID int64) (*TaskList, error) {
	var list TaskList
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND is_inbox = ?", userID, true).
		First(&list).Error
	if err == nil {
		return &list, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("load inbox: %w", err)
	}
	list = TaskList{UserID: userID, Name: "收集箱", Color: "#4772fa", Kind: "TASK", IsInbox: true, Order: 0}
	if err := s.db.WithContext(ctx).Create(&list).Error; err != nil {
		// Another request may have created the inbox concurrently.
		var existing TaskList
		if findErr := s.db.WithContext(ctx).
			Where("user_id = ? AND is_inbox = ?", userID, true).
			First(&existing).Error; findErr == nil {
			return &existing, nil
		}
		return nil, fmt.Errorf("create inbox: %w", err)
	}
	return &list, nil
}

// ListTaskLists returns a user's lists ordered for display.
func (s *Store) ListTaskLists(ctx context.Context, userID int64) ([]*TaskList, error) {
	var lists []*TaskList
	err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("pinned DESC, is_inbox DESC, order_index ASC, id ASC").
		Find(&lists).Error
	if err != nil {
		return nil, fmt.Errorf("list task lists: %w", err)
	}
	return lists, nil
}

// GetTaskList returns one list scoped to its owner.
func (s *Store) GetTaskList(ctx context.Context, userID, id int64) (*TaskList, error) {
	var list TaskList
	err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&list).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get task list: %w", err)
	}
	return &list, nil
}

// CreateTaskList adds a task list for the user.
func (s *Store) CreateTaskList(ctx context.Context, userID int64, name, color string) (*TaskList, error) {
	return s.CreateTaskListKind(ctx, userID, name, color, "TASK")
}

// CreateTaskListKind adds a task or note list for the user.
func (s *Store) CreateTaskListKind(ctx context.Context, userID int64, name, color, kind string) (*TaskList, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, errors.New("list name is required")
	}
	if kind != "NOTE" {
		kind = "TASK"
	}
	var maxOrder int
	_ = s.db.WithContext(ctx).Model(&TaskList{}).Where("user_id = ?", userID).
		Select("COALESCE(MAX(order_index), 0)").Scan(&maxOrder).Error
	list := TaskList{UserID: userID, Name: name, Color: color, Kind: kind, Order: maxOrder + 1}
	if err := s.db.WithContext(ctx).Create(&list).Error; err != nil {
		if errors.Is(translate(err), ErrConflict) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("create task list: %w", err)
	}
	return &list, nil
}

// UpdateTaskList updates a list's name, color and order.
func (s *Store) UpdateTaskList(ctx context.Context, userID, id int64, name, color string, order int) error {
	list, err := s.GetTaskList(ctx, userID, id)
	if err != nil {
		return err
	}
	if list.IsInbox {
		name = list.Name
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return errors.New("list name is required")
	}
	err = s.db.WithContext(ctx).Model(&TaskList{}).Where("id = ? AND user_id = ?", id, userID).
		Updates(map[string]any{"name": name, "color": color, "order_index": order}).Error
	if err != nil {
		if errors.Is(translate(err), ErrConflict) {
			return ErrConflict
		}
		return fmt.Errorf("update task list: %w", err)
	}
	if name != list.Name {
		// The list name is mirrored into each VTODO.
		if err := s.db.WithContext(ctx).Model(&Task{}).
			Where("user_id = ? AND list_id = ? AND deleted = ?", userID, id, false).
			Update("sync_pending", true).Error; err != nil {
			return fmt.Errorf("mark tasks for sync: %w", err)
		}
	}
	return nil
}

// DeleteTaskList removes a list and moves its tasks to the inbox in one
// transaction. Inbox lists cannot be deleted.
func (s *Store) DeleteTaskList(ctx context.Context, userID, id int64) error {
	list, err := s.GetTaskList(ctx, userID, id)
	if err != nil {
		return err
	}
	if list.IsInbox {
		return errors.New("inbox cannot be deleted")
	}
	inbox, err := s.EnsureInbox(ctx, userID)
	if err != nil {
		return err
	}
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&Task{}).Where("user_id = ? AND list_id = ? AND deleted = ?", userID, id, false).
			Updates(map[string]any{"list_id": inbox.ID, "section_id": 0, "sync_pending": true}).Error; err != nil {
			return fmt.Errorf("move tasks to inbox: %w", err)
		}
		if err := tx.Where("user_id = ? AND list_id = ?", userID, id).Delete(&TaskSection{}).Error; err != nil {
			return fmt.Errorf("delete task sections: %w", err)
		}
		if err := s.deleteTaskListSharesTx(tx, id); err != nil {
			return fmt.Errorf("delete task list shares: %w", err)
		}
		if err := tx.Where("id = ? AND user_id = ?", id, userID).Delete(&TaskList{}).Error; err != nil {
			return fmt.Errorf("delete task list: %w", err)
		}
		return nil
	})
}

// CountTasksInList reports how many open tasks a list holds.
func (s *Store) CountTasksInList(ctx context.Context, userID, listID int64) (int64, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&Task{}).
		Where("user_id = ? AND list_id = ? AND completed = ? AND deleted = ?", userID, listID, false, false).
		Count(&count).Error
	if err != nil {
		return 0, fmt.Errorf("count tasks: %w", err)
	}
	return count, nil
}

// taskTodayStart returns midnight of the current day in the deployment's
// default timezone, expressed in UTC for comparisons against due_at.
func taskTodayStart(now time.Time) time.Time {
	loc, err := time.LoadLocation(DefaultTimezone)
	if err != nil {
		loc = time.UTC
	}
	local := now.In(loc)
	return time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, loc).UTC()
}

func (s *Store) taskQuery(ctx context.Context, userID int64, filter TaskFilter, completed bool) *gorm.DB {
	if filter.View == "trash" {
		return s.db.WithContext(ctx).Model(&Task{}).
			Where("user_id = ? AND deleted = ?", userID, true).
			Order("deleted_at DESC, id DESC")
	}
	query := s.db.WithContext(ctx).Model(&Task{}).
		Where("user_id = ? AND deleted = ? AND completed = ?", userID, false, completed)
	todayStart := taskTodayStart(time.Now())
	switch filter.View {
	case "today":
		query = query.Where("(due_at IS NOT NULL AND due_at < ?)", todayStart.Add(24*time.Hour))
	case "next7":
		query = query.Where("(due_at IS NOT NULL AND due_at >= ? AND due_at < ?)", todayStart, todayStart.AddDate(0, 0, 7))
	case "inbox", "list":
		query = query.Where("list_id = ?", filter.ListID)
	}
	if filter.Query != "" {
		like := "%" + strings.ReplaceAll(strings.ReplaceAll(filter.Query, "%", `\%`), "_", `\_`) + "%"
		query = query.Where(`(title LIKE ? ESCAPE '\' OR notes_text LIKE ? ESCAPE '\')`, like, like)
	}
	return query
}

// ListTasks returns open tasks plus recently completed tasks for the filter.
// Open tasks are sorted by due date (undated last), then manual order and age.
func (s *Store) ListTasks(ctx context.Context, userID int64, filter TaskFilter) ([]*Task, error) {
	limit := filter.Limit
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	if filter.View == "trash" {
		var deleted []*Task
		err := s.taskQuery(ctx, userID, filter, false).Limit(limit).Find(&deleted).Error
		if err != nil {
			return nil, fmt.Errorf("list deleted tasks: %w", err)
		}
		return deleted, nil
	}
	var open []*Task
	if filter.View != "completed" {
		err := s.taskQuery(ctx, userID, filter, false).
			Order("CASE WHEN pinned_at IS NULL THEN 1 ELSE 0 END, pinned_at DESC, CASE WHEN due_at IS NULL THEN 1 ELSE 0 END, due_at ASC, order_index ASC, id DESC").
			Limit(limit).Find(&open).Error
		if err != nil {
			return nil, fmt.Errorf("list tasks: %w", err)
		}
	}
	doneLimit := 50
	if filter.View == "completed" {
		doneLimit = limit
	}
	var done []*Task
	err := s.taskQuery(ctx, userID, filter, true).
		Order("completed_at DESC, id DESC").
		Limit(doneLimit).Find(&done).Error
	if err != nil {
		return nil, fmt.Errorf("list completed tasks: %w", err)
	}
	return append(open, done...), nil
}

// TaskCounts returns the smart list badge numbers for a user.
func (s *Store) TaskCounts(ctx context.Context, userID int64) (TaskCounts, error) {
	var counts TaskCounts
	todayStart := taskTodayStart(time.Now())
	inbox, err := s.EnsureInbox(ctx, userID)
	if err != nil {
		return counts, err
	}
	base := s.db.WithContext(ctx).Model(&Task{}).Where("user_id = ? AND deleted = ?", userID, false)
	if err := base.Where("completed = ?", false).Count(&counts.All).Error; err != nil {
		return counts, err
	}
	if err := s.db.WithContext(ctx).Model(&Task{}).
		Where("user_id = ? AND deleted = ? AND completed = ?", userID, false, false).
		Where("due_at IS NOT NULL AND due_at < ?", todayStart.Add(24*time.Hour)).
		Count(&counts.Today).Error; err != nil {
		return counts, err
	}
	if err := s.db.WithContext(ctx).Model(&Task{}).
		Where("user_id = ? AND deleted = ? AND completed = ?", userID, false, false).
		Where("due_at IS NOT NULL AND due_at >= ? AND due_at < ?", todayStart, todayStart.AddDate(0, 0, 7)).
		Count(&counts.Next7).Error; err != nil {
		return counts, err
	}
	if err := s.db.WithContext(ctx).Model(&Task{}).
		Where("user_id = ? AND deleted = ? AND completed = ? AND list_id = ?", userID, false, false, inbox.ID).
		Count(&counts.Inbox).Error; err != nil {
		return counts, err
	}
	if err := s.db.WithContext(ctx).Model(&Task{}).
		Where("user_id = ? AND deleted = ? AND completed = ?", userID, false, true).
		Count(&counts.Completed).Error; err != nil {
		return counts, err
	}
	if err := s.db.WithContext(ctx).Model(&Task{}).
		Where("user_id = ? AND deleted = ?", userID, true).
		Count(&counts.Trash).Error; err != nil {
		return counts, err
	}
	return counts, nil
}

// GetTask returns a task scoped to its owner.
func (s *Store) GetTask(ctx context.Context, userID, id int64) (*Task, error) {
	var task Task
	err := s.db.WithContext(ctx).Where("id = ? AND user_id = ? AND deleted = ?", id, userID, false).First(&task).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get task: %w", err)
	}
	return &task, nil
}

func backfillTaskNotesText(ctx context.Context, db *gorm.DB) error {
	for {
		var tasks []*Task
		if err := db.WithContext(ctx).
			Where("notes <> '' AND (notes_text IS NULL OR notes_text = '')").
			Limit(500).Find(&tasks).Error; err != nil {
			return fmt.Errorf("load notes for backfill: %w", err)
		}
		if len(tasks) == 0 {
			return nil
		}
		for _, task := range tasks {
			if err := db.WithContext(ctx).Model(&Task{}).
				Where("id = ?", task.ID).
				UpdateColumn("notes_text", richtext.Plain(task.Notes)).Error; err != nil {
				return fmt.Errorf("backfill notes text: %w", err)
			}
		}
	}
}

func normalizeTaskNotes(task *Task) error {
	if task.NotesFormat == "" {
		if task.Kind == "NOTE" {
			task.NotesFormat = "html"
		} else {
			task.NotesFormat = "text"
		}
	}
	if task.NotesFormat != "html" {
		task.NotesFormat = "text"
	}
	if task.NotesFormat == "html" {
		if len(task.Notes) > richtext.MaxNoteHTML {
			return errors.New("笔记内容过长")
		}
		task.Notes = richtext.Sanitize(task.Notes)
	}
	task.NotesText = richtext.Plain(task.Notes)
	return nil
}

func normalizeTaskTimes(task *Task) {
	if task.DueAt != nil {
		value := task.DueAt.UTC()
		task.DueAt = &value
	}
	if task.CompletedAt != nil {
		value := task.CompletedAt.UTC()
		task.CompletedAt = &value
	}
}

// CreateTask stores a new task after validating its list ownership.
func (s *Store) CreateTask(ctx context.Context, task *Task) (*Task, error) {
	if strings.TrimSpace(task.Title) == "" {
		return nil, errors.New("task title is required")
	}
	if _, err := s.GetTaskList(ctx, task.UserID, task.ListID); err != nil {
		return nil, err
	}
	if task.Priority < 0 || task.Priority > 3 {
		return nil, errors.New("invalid priority")
	}
	if task.Completed && task.CompletedAt == nil {
		now := time.Now().UTC()
		task.CompletedAt = &now
	}
	if err := normalizeTaskNotes(task); err != nil {
		return nil, err
	}
	task.SyncPending = true
	task.SetReminderValues(task.ReminderValues())
	if task.ReminderOffset < -1 || task.ReminderOffset > 10080 {
		return nil, errors.New("invalid reminder offset")
	}
	if task.Order == 0 {
		var maxOrder int
		_ = s.db.WithContext(ctx).Model(&Task{}).
			Where("user_id = ? AND list_id = ? AND deleted = ?", task.UserID, task.ListID, false).
			Select("COALESCE(MAX(order_index), 0)").Scan(&maxOrder).Error
		task.Order = maxOrder + 1
	}
	normalizeTaskTimes(task)
	// GORM replaces zero values with the column default (-1) on create, so a
	// reminder exactly at the due time needs an explicit follow-up update.
	reminderOffset := task.ReminderOffset
	if err := s.db.WithContext(ctx).Create(task).Error; err != nil {
		return nil, fmt.Errorf("create task: %w", err)
	}
	if reminderOffset == 0 {
		if err := s.db.WithContext(ctx).Model(&Task{}).
			Where("id = ?", task.ID).UpdateColumn("reminder_offset", 0).Error; err != nil {
			return nil, fmt.Errorf("set task reminder: %w", err)
		}
		task.ReminderOffset = 0
	}
	return task, nil
}

// UpdateTask persists mutable task fields.
func (s *Store) UpdateTask(ctx context.Context, task *Task) error {
	if strings.TrimSpace(task.Title) == "" {
		return errors.New("task title is required")
	}
	if task.Priority < 0 || task.Priority > 3 {
		return errors.New("invalid priority")
	}
	task.SetReminderValues(task.ReminderValues())
	if task.ReminderOffset < -1 || task.ReminderOffset > 10080 {
		return errors.New("invalid reminder offset")
	}
	if err := normalizeTaskNotes(task); err != nil {
		return err
	}
	if _, err := s.GetTaskList(ctx, task.UserID, task.ListID); err != nil {
		return err
	}
	now := time.Now().UTC()
	if task.Completed && task.CompletedAt == nil {
		task.CompletedAt = &now
	}
	if !task.Completed {
		task.CompletedAt = nil
	}
	task.SyncPending = true
	normalizeTaskTimes(task)
	updates := map[string]any{
		"list_id":          task.ListID,
		"section_id":       task.SectionID,
		"title":            task.Title,
		"notes":            task.Notes,
		"notes_format":     task.NotesFormat,
		"notes_text":       task.NotesText,
		"kind":             task.Kind,
		"priority":         task.Priority,
		"due_at":           task.DueAt,
		"recurrence":       task.Recurrence,
		"reminder_offset":  task.ReminderOffset,
		"reminder_offsets": task.ReminderOffsets,
		"assignee":         task.Assignee,
		"all_day":          task.AllDay,
		"completed":        task.Completed,
		"completed_at":     task.CompletedAt,
		"pinned_at":        task.PinnedAt,
		"tags":             task.Tags,
		"checklist":        task.Checklist,
		"order_index":      task.Order,
	}
	err := s.db.WithContext(ctx).Model(&Task{}).
		Where("id = ? AND user_id = ? AND deleted = ?", task.ID, task.UserID, false).
		Updates(updates).Error
	if err != nil {
		return fmt.Errorf("update task: %w", err)
	}
	updated, err := s.GetTask(ctx, task.UserID, task.ID)
	if err != nil {
		return err
	}
	*task = *updated
	return nil
}

// SetTaskPinned moves a task into the pinned group. Pinning is workspace-only,
// so it does not mark the VTODO as pending.
func (s *Store) SetTaskPinned(ctx context.Context, userID, id int64, pinned bool) (*Task, error) {
	var pinnedAt *time.Time
	if pinned {
		now := time.Now().UTC()
		pinnedAt = &now
	}
	res := s.db.WithContext(ctx).Model(&Task{}).
		Where("id = ? AND user_id = ? AND deleted = ?", id, userID, false).
		Update("pinned_at", pinnedAt)
	if res.Error != nil {
		return nil, fmt.Errorf("pin task: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return nil, ErrNotFound
	}
	return s.GetTask(ctx, userID, id)
}

// SetTaskListPinned pins or unpins a list in the sidebar.
func (s *Store) SetTaskListPinned(ctx context.Context, userID, id int64, pinned bool) (*TaskList, error) {
	res := s.db.WithContext(ctx).Model(&TaskList{}).
		Where("id = ? AND user_id = ?", id, userID).
		Update("pinned", pinned)
	if res.Error != nil {
		return nil, fmt.Errorf("pin task list: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return nil, ErrNotFound
	}
	return s.GetTaskList(ctx, userID, id)
}

// SetTaskCompleted toggles completion for one task and its children.
func (s *Store) SetTaskCompleted(ctx context.Context, userID, id int64, completed bool) (*Task, error) {
	task, err := s.GetTask(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	task.Completed = completed
	if err := s.UpdateTask(ctx, task); err != nil {
		return nil, err
	}
	var children []*Task
	if err := s.db.WithContext(ctx).Where("user_id = ? AND parent_id = ? AND deleted = ?", userID, id, false).Find(&children).Error; err == nil {
		for _, child := range children {
			child.Completed = completed
			_ = s.UpdateTask(ctx, child)
		}
	}
	return task, nil
}

// DeleteTask soft-deletes a task and its children.
func (s *Store) DeleteTask(ctx context.Context, userID, id int64) error {
	now := time.Now().UTC()
	err := s.db.WithContext(ctx).Model(&Task{}).
		Where("user_id = ? AND (id = ? OR parent_id = ?) AND deleted = ?", userID, id, id, false).
		Updates(map[string]any{"deleted": true, "deleted_at": &now}).Error
	if err != nil {
		return fmt.Errorf("delete task: %w", err)
	}
	return nil
}

// PurgeCompletedTasks permanently removes all completed tasks for a user.
func (s *Store) PurgeCompletedTasks(ctx context.Context, userID int64) (int64, error) {
	result := s.db.WithContext(ctx).Where("user_id = ? AND completed = ?", userID, true).Delete(&Task{})
	if result.Error != nil {
		return 0, fmt.Errorf("purge completed tasks: %w", result.Error)
	}
	return result.RowsAffected, nil
}

// ListAllTasks returns every live task for a user, used by CalDAV sync.
func (s *Store) ListAllTasks(ctx context.Context, userID int64, limit int) ([]*Task, error) {
	if limit <= 0 || limit > 5000 {
		limit = 2000
	}
	var tasks []*Task
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND deleted = ?", userID, false).
		Order("id ASC").
		Limit(limit).Find(&tasks).Error
	if err != nil {
		return nil, fmt.Errorf("list all tasks: %w", err)
	}
	return tasks, nil
}

// GetTaskByVTODOUID finds a live task by its CalDAV UID.
func (s *Store) GetTaskByVTODOUID(ctx context.Context, userID int64, uid string) (*Task, error) {
	var task Task
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND vtodo_uid = ? AND deleted = ?", userID, uid, false).
		First(&task).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get task by vtodo uid: %w", err)
	}
	return &task, nil
}

// SetTaskSyncIdentity persists a newly generated CalDAV identity without
// clearing the pending flag, so a retry reuses the same UID and href.
func (s *Store) SetTaskSyncIdentity(ctx context.Context, userID, id int64, uid, href string) error {
	res := s.db.WithContext(ctx).Model(&Task{}).
		Where("id = ? AND user_id = ?", id, userID).
		Updates(map[string]any{"vtodo_uid": uid, "vtodo_href": href})
	if res.Error != nil {
		return fmt.Errorf("set task sync identity: %w", res.Error)
	}
	return nil
}

// SetTaskSync records the CalDAV identity of a task and clears the pending
// flag. It intentionally does not touch calendar-facing task fields.
func (s *Store) SetTaskSync(ctx context.Context, userID, id int64, uid, href, etag string) error {
	res := s.db.WithContext(ctx).Model(&Task{}).
		Where("id = ? AND user_id = ?", id, userID).
		Updates(map[string]any{
			"vtodo_uid":    uid,
			"vtodo_href":   href,
			"vtodo_etag":   etag,
			"sync_pending": false,
		})
	if res.Error != nil {
		return fmt.Errorf("set task sync: %w", res.Error)
	}
	return nil
}

// ListDeletedObjects returns tombstoned objects so the sync layer can detect
// deletions made by CalDAV clients.
func (s *Store) ListDeletedObjects(ctx context.Context, calendarID int64) ([]*Object, error) {
	var objects []*Object
	err := s.db.WithContext(ctx).
		Where("calendar_id = ? AND deleted = ?", calendarID, true).
		Order("modified_at DESC").
		Limit(2000).Find(&objects).Error
	if err != nil {
		return nil, fmt.Errorf("list deleted objects: %w", err)
	}
	return objects, nil
}

// ListDeletedTasks returns the user's trash, newest deletion first.
func (s *Store) ListDeletedTasks(ctx context.Context, userID int64, limit int) ([]*Task, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	var tasks []*Task
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND deleted = ?", userID, true).
		Order("deleted_at DESC, id DESC").
		Limit(limit).Find(&tasks).Error
	if err != nil {
		return nil, fmt.Errorf("list deleted tasks: %w", err)
	}
	return tasks, nil
}

// RestoreTask moves a trashed task back into a live list. The CalDAV identity
// is cleared so the reconciler creates a fresh VTODO instead of resurrecting
// the tombstoned one.
func (s *Store) RestoreTask(ctx context.Context, userID, id int64) (*Task, error) {
	var task Task
	err := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ? AND deleted = ?", id, userID, true).
		First(&task).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get trashed task: %w", err)
	}
	listID := task.ListID
	if _, err := s.GetTaskList(ctx, userID, listID); err != nil {
		inbox, inboxErr := s.EnsureInbox(ctx, userID)
		if inboxErr != nil {
			return nil, inboxErr
		}
		listID = inbox.ID
	}
	err = s.db.WithContext(ctx).Model(&Task{}).
		Where("id = ? AND user_id = ?", id, userID).
		Updates(map[string]any{
			"deleted":      false,
			"deleted_at":   nil,
			"list_id":      listID,
			"vtodo_uid":    "",
			"vtodo_href":   "",
			"vtodo_etag":   "",
			"sync_pending": true,
			"completed":    false,
			"completed_at": nil,
			"modified_at":  time.Now().UTC(),
		}).Error
	if err != nil {
		return nil, fmt.Errorf("restore task: %w", err)
	}
	return s.GetTask(ctx, userID, id)
}

// PurgeTask permanently removes a single trashed task.
func (s *Store) PurgeTask(ctx context.Context, userID, id int64) error {
	res := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ? AND deleted = ?", id, userID, true).
		Delete(&Task{})
	if res.Error != nil {
		return fmt.Errorf("purge task: %w", res.Error)
	}
	return nil
}

// PurgeDeletedTasks permanently removes every trashed task.
func (s *Store) PurgeDeletedTasks(ctx context.Context, userID int64) (int64, error) {
	res := s.db.WithContext(ctx).
		Where("user_id = ? AND deleted = ?", userID, true).
		Delete(&Task{})
	if res.Error != nil {
		return 0, fmt.Errorf("empty trash: %w", res.Error)
	}
	return res.RowsAffected, nil
}

// ListReminderTasks returns open tasks that carry a reminder and a due date.
func (s *Store) ListReminderTasks(ctx context.Context, userID int64, limit int) ([]*Task, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	var tasks []*Task
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND deleted = ? AND completed = ? AND reminder_offset >= 0 AND due_at IS NOT NULL", userID, false, false).
		Order("due_at ASC").
		Limit(limit).Find(&tasks).Error
	if err != nil {
		return nil, fmt.Errorf("list reminder tasks: %w", err)
	}
	return tasks, nil
}

// SetTaskOrder stores manual ordering for the supplied tasks.
func (s *Store) SetTaskOrder(ctx context.Context, userID int64, ids []int64) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for index, id := range ids {
			if err := tx.Model(&Task{}).
				Where("id = ? AND user_id = ? AND deleted = ?", id, userID, false).
				Update("order_index", index+1).Error; err != nil {
				return fmt.Errorf("set task order: %w", err)
			}
		}
		return nil
	})
}

// ---------------------------------------------------------------- sections

// ListTaskSections returns all kanban sections for a user's lists.
func (s *Store) ListTaskSections(ctx context.Context, userID int64) ([]*TaskSection, error) {
	var sections []*TaskSection
	err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("list_id ASC, order_index ASC, id ASC").
		Find(&sections).Error
	if err != nil {
		return nil, fmt.Errorf("list task sections: %w", err)
	}
	return sections, nil
}

func (s *Store) GetTaskSection(ctx context.Context, userID, id int64) (*TaskSection, error) {
	var section TaskSection
	err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&section).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get task section: %w", err)
	}
	return &section, nil
}

// CreateTaskSection appends a column to a list.
func (s *Store) CreateTaskSection(ctx context.Context, userID, listID int64, name string) (*TaskSection, error) {
	if _, err := s.GetTaskList(ctx, userID, listID); err != nil {
		return nil, err
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, errors.New("section name is required")
	}
	var maxOrder int
	_ = s.db.WithContext(ctx).Model(&TaskSection{}).
		Where("user_id = ? AND list_id = ?", userID, listID).
		Select("COALESCE(MAX(order_index), 0)").Scan(&maxOrder).Error
	section := &TaskSection{UserID: userID, ListID: listID, Name: name, Order: maxOrder + 1}
	if err := s.db.WithContext(ctx).Create(section).Error; err != nil {
		if errors.Is(translate(err), ErrConflict) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("create task section: %w", err)
	}
	return section, nil
}

func (s *Store) UpdateTaskSection(ctx context.Context, userID, id int64, name string, order int) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return errors.New("section name is required")
	}
	res := s.db.WithContext(ctx).Model(&TaskSection{}).
		Where("id = ? AND user_id = ?", id, userID).
		Updates(map[string]any{"name": name, "order_index": order})
	if res.Error != nil {
		if errors.Is(translate(res.Error), ErrConflict) {
			return ErrConflict
		}
		return fmt.Errorf("update task section: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// ListTasksInSection returns live tasks assigned to a section.
func (s *Store) ListTasksInSection(ctx context.Context, userID, sectionID int64) ([]*Task, error) {
	var tasks []*Task
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND section_id = ? AND deleted = ?", userID, sectionID, false).
		Find(&tasks).Error
	if err != nil {
		return nil, fmt.Errorf("list section tasks: %w", err)
	}
	return tasks, nil
}

// DeleteTaskSection deletes a column. strategy=move reassigns its tasks to
// targetID (0 = ungrouped); strategy=delete soft-deletes its tasks.
func (s *Store) DeleteTaskSection(ctx context.Context, userID, id int64, strategy string, targetID int64) error {
	section, err := s.GetTaskSection(ctx, userID, id)
	if err != nil {
		return err
	}
	if strategy == "move" && targetID != 0 {
		target, err := s.GetTaskSection(ctx, userID, targetID)
		if err != nil {
			return errors.New("目标分组不存在")
		}
		if target.ListID != section.ListID {
			return errors.New("目标分组不属于同一清单")
		}
	}
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if strategy == "move" {
			if err := tx.Model(&Task{}).
				Where("user_id = ? AND section_id = ? AND deleted = ?", userID, id, false).
				Update("section_id", targetID).Error; err != nil {
				return fmt.Errorf("move section tasks: %w", err)
			}
		} else {
			now := time.Now().UTC()
			if err := tx.Model(&Task{}).
				Where("user_id = ? AND section_id = ? AND deleted = ?", userID, id, false).
				Updates(map[string]any{"deleted": true, "deleted_at": &now}).Error; err != nil {
				return fmt.Errorf("delete section tasks: %w", err)
			}
		}
		if err := tx.Where("id = ? AND user_id = ?", id, userID).Delete(&TaskSection{}).Error; err != nil {
			return fmt.Errorf("delete task section: %w", err)
		}
		return nil
	})
}

// CopyTaskList duplicates a list, its sections and tasks. mode is open
// (unfinished only), all (all tasks, completed tasks copied as open) or
// keep (all tasks with their completion state).
func (s *Store) CopyTaskList(ctx context.Context, userID, sourceID int64, newName, mode string) (*TaskList, error) {
	source, err := s.GetTaskList(ctx, userID, sourceID)
	if err != nil {
		return nil, err
	}
	newName = strings.TrimSpace(newName)
	if newName == "" {
		newName = source.Name + " 副本"
	}
	list, err := s.CreateTaskListKind(ctx, userID, newName, source.Color, source.Kind)
	if err != nil {
		return nil, err
	}
	if source.FolderID > 0 {
		_ = s.SetTaskListFolder(ctx, userID, list.ID, source.FolderID)
		list.FolderID = source.FolderID
	}

	var sourceSections []*TaskSection
	if source.Kind != "NOTE" {
		sourceSections, _ = s.ListTaskSections(ctx, userID)
	}
	sectionMap := map[int64]int64{}
	for _, section := range sourceSections {
		if section.ListID != sourceID {
			continue
		}
		copied, err := s.CreateTaskSection(ctx, userID, list.ID, section.Name)
		if err != nil {
			continue
		}
		sectionMap[section.ID] = copied.ID
	}

	var tasks []*Task
	if err := s.db.WithContext(ctx).
		Where("user_id = ? AND list_id = ? AND deleted = ?", userID, sourceID, false).
		Order("order_index ASC, id ASC").
		Find(&tasks).Error; err != nil {
		return nil, fmt.Errorf("copy list tasks: %w", err)
	}
	keepCompleted := mode == "keep"
	createdBySource := map[int64]int64{}
	for _, task := range tasks {
		if mode == "open" && task.Completed {
			continue
		}
		copied := &Task{
			UserID:         userID,
			ListID:         list.ID,
			SectionID:      sectionMap[task.SectionID],
			Title:          task.Title,
			Notes:          task.Notes,
			NotesFormat:    task.NotesFormat,
			NotesText:      task.NotesText,
			Kind:           task.Kind,
			Priority:       task.Priority,
			StartAt:        task.StartAt,
			DueAt:          task.DueAt,
			AllDay:         task.AllDay,
			Recurrence:     task.Recurrence,
			ReminderOffset: -1,
			Assignee:       task.Assignee,
			Tags:           append(StringList(nil), task.Tags...),
			Checklist:      task.Checklist,
			Order:          task.Order,
			SyncPending:    task.Kind != "NOTE",
		}
		if keepCompleted && task.Completed {
			copied.Completed = true
			copied.CompletedAt = task.CompletedAt
		}
		if offsets := task.ReminderValues(); len(offsets) > 0 {
			copied.SetReminderValues(offsets)
		}
		created, err := s.CreateTask(ctx, copied)
		if err != nil {
			return nil, err
		}
		createdBySource[task.ID] = created.ID
	}
	for _, task := range tasks {
		parentID := createdBySource[task.ParentID]
		if parentID == 0 {
			continue
		}
		childID := createdBySource[task.ID]
		if childID == 0 {
			continue
		}
		if err := s.db.WithContext(ctx).Model(&Task{}).
			Where("id = ? AND user_id = ?", childID, userID).
			Update("parent_id", parentID).Error; err != nil {
			return nil, fmt.Errorf("copy task parent: %w", err)
		}
	}
	return list, nil
}
