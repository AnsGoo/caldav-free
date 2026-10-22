package store

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

// TaskList is a user-defined list (project) that groups tasks. Every user has
// exactly one inbox list, created lazily on first use.
type TaskList struct {
	ID         int64     `gorm:"primaryKey"`
	UserID     int64     `gorm:"not null;uniqueIndex:idx_tasklist_owner_name,priority:1;index:idx_tasklist_user"`
	Name       string    `gorm:"size:190;not null;uniqueIndex:idx_tasklist_owner_name,priority:2"`
	Color      string    `gorm:"size:32;not null;default:''"`
	Order      int       `gorm:"column:order_index;not null;default:0"`
	IsInbox    bool      `gorm:"not null;default:false"`
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
	Title       string     `gorm:"size:500;not null"`
	Notes       string     `gorm:"type:text;not null;default:''"`
	Priority    int        `gorm:"not null;default:0"`
	DueAt       *time.Time `gorm:"index:idx_task_user_due,priority:2"`
	AllDay      bool       `gorm:"not null;default:false"`
	Completed   bool       `gorm:"not null;default:false;index:idx_task_user_completed,priority:2;index:idx_task_list_completed,priority:2"`
	CompletedAt *time.Time
	Tags        StringList `gorm:"not null"`
	Checklist   string     `gorm:"type:text;not null;default:''"`
	Order       int        `gorm:"column:order_index;not null;default:0"`
	Deleted     bool       `gorm:"not null;default:false;index:idx_task_deleted"`
	DeletedAt   *time.Time
	CreatedAt   time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt  time.Time `gorm:"not null;autoUpdateTime"`
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
	list = TaskList{UserID: userID, Name: "收集箱", Color: "#4772fa", IsInbox: true, Order: 0}
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
		Order("is_inbox DESC, order_index ASC, id ASC").
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

// CreateTaskList adds a list for the user.
func (s *Store) CreateTaskList(ctx context.Context, userID int64, name, color string) (*TaskList, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, errors.New("list name is required")
	}
	var maxOrder int
	_ = s.db.WithContext(ctx).Model(&TaskList{}).Where("user_id = ?", userID).
		Select("COALESCE(MAX(order_index), 0)").Scan(&maxOrder).Error
	list := TaskList{UserID: userID, Name: name, Color: color, Order: maxOrder + 1}
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
			Update("list_id", inbox.ID).Error; err != nil {
			return fmt.Errorf("move tasks to inbox: %w", err)
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
		query = query.Where(`(title LIKE ? ESCAPE '\' OR notes LIKE ? ESCAPE '\')`, like, like)
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
	var open []*Task
	if filter.View != "completed" {
		err := s.taskQuery(ctx, userID, filter, false).
			Order("CASE WHEN due_at IS NULL THEN 1 ELSE 0 END, due_at ASC, order_index ASC, id DESC").
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
	if task.Completed {
		now := time.Now().UTC()
		task.CompletedAt = &now
	}
	normalizeTaskTimes(task)
	if err := s.db.WithContext(ctx).Create(task).Error; err != nil {
		return nil, fmt.Errorf("create task: %w", err)
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
	normalizeTaskTimes(task)
	updates := map[string]any{
		"list_id":      task.ListID,
		"title":        task.Title,
		"notes":        task.Notes,
		"priority":     task.Priority,
		"due_at":       task.DueAt,
		"all_day":      task.AllDay,
		"completed":    task.Completed,
		"completed_at": task.CompletedAt,
		"tags":         task.Tags,
		"checklist":    task.Checklist,
		"order_index":  task.Order,
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
