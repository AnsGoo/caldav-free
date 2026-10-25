package store

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	"gorm.io/gorm"
)

// TaskFolder groups lists in the workspace sidebar.
type TaskFolder struct {
	ID         int64     `gorm:"primaryKey"`
	SyncID     string    `gorm:"column:sync_id;size:64;not null;default:''"`
	UserID     int64     `gorm:"not null;uniqueIndex:idx_taskfolder_owner_name,priority:1;index:idx_taskfolder_user"`
	Name       string    `gorm:"size:190;not null;uniqueIndex:idx_taskfolder_owner_name,priority:2"`
	Order      int       `gorm:"column:order_index;not null;default:0"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime"`
}

// TaskFilterConditions is the JSON payload stored on a saved filter.
type TaskFilterConditions struct {
	ListIDs    []int64  `json:"listIds"`
	Tags       []string `json:"tags"`
	TagMode    string   `json:"tagMode"` // any | all
	Priorities []int    `json:"priorities"`
	Status     string   `json:"status"` // open | completed | all
	// Date supports any | today | tomorrow | next7 | overdue | none |
	// yesterday | thisWeek | lastWeek | thisMonth | lastMonth | range.
	Date     string `json:"date"`
	DateFrom string `json:"dateFrom,omitempty"`
	DateTo   string `json:"dateTo,omitempty"`
	Keyword  string `json:"keyword"`
}

// SavedFilter is a named set of task filter conditions.
type SavedFilter struct {
	ID         int64     `gorm:"primaryKey"`
	SyncID     string    `gorm:"column:sync_id;size:64;not null;default:''"`
	UserID     int64     `gorm:"not null;index:idx_savedfilter_user"`
	Name       string    `gorm:"size:120;not null"`
	Color      string    `gorm:"size:32;not null;default:''"`
	Conditions string    `gorm:"type:text;not null;default:''"`
	Order      int       `gorm:"column:order_index;not null;default:0"`
	Pinned     bool      `gorm:"not null;default:false;index:idx_savedfilter_pinned"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime"`
}

// TaskTagCount is a tag with the number of live tasks using it.
type TaskTagCount struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
	Color string `json:"color"`
}

// ---------------------------------------------------------------- folders

// ListTaskFolders returns a user's folders in display order.
func (s *Store) ListTaskFolders(ctx context.Context, userID int64) ([]*TaskFolder, error) {
	var folders []*TaskFolder
	err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("order_index ASC, id ASC").
		Find(&folders).Error
	if err != nil {
		return nil, fmt.Errorf("list task folders: %w", err)
	}
	return folders, nil
}

// GetTaskFolder returns a folder scoped to its owner.
func (s *Store) GetTaskFolder(ctx context.Context, userID, id int64) (*TaskFolder, error) {
	var folder TaskFolder
	err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&folder).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get task folder: %w", err)
	}
	return &folder, nil
}

// CreateTaskFolder adds a folder for the user.
func (s *Store) CreateTaskFolder(ctx context.Context, userID int64, name string) (*TaskFolder, error) {
	return s.CreateTaskFolderWithSyncID(ctx, userID, name, "")
}

// CreateTaskFolderWithSyncID adds a folder using a caller-supplied sync ID.
func (s *Store) CreateTaskFolderWithSyncID(ctx context.Context, userID int64, name, syncID string) (*TaskFolder, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, errors.New("folder name is required")
	}
	var maxOrder int
	_ = s.db.WithContext(ctx).Model(&TaskFolder{}).Where("user_id = ?", userID).
		Select("COALESCE(MAX(order_index), 0)").Scan(&maxOrder).Error
	folder := TaskFolder{UserID: userID, SyncID: syncID, Name: name, Order: maxOrder + 1}
	if err := s.db.WithContext(ctx).Create(&folder).Error; err != nil {
		if errors.Is(translate(err), ErrConflict) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("create task folder: %w", err)
	}
	return &folder, nil
}

// UpdateTaskFolder renames or reorders a folder.
func (s *Store) UpdateTaskFolder(ctx context.Context, userID, id int64, name string, order int) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return errors.New("folder name is required")
	}
	res := s.db.WithContext(ctx).Model(&TaskFolder{}).
		Where("id = ? AND user_id = ?", id, userID).
		Updates(map[string]any{"name": name, "order_index": order})
	if res.Error != nil {
		if errors.Is(translate(res.Error), ErrConflict) {
			return ErrConflict
		}
		return fmt.Errorf("update task folder: %w", res.Error)
	}
	return nil
}

// DeleteTaskFolder removes a folder and moves its lists back to the root.
func (s *Store) DeleteTaskFolder(ctx context.Context, userID, id int64) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&TaskList{}).
			Where("user_id = ? AND folder_id = ?", userID, id).
			Update("folder_id", 0).Error; err != nil {
			return fmt.Errorf("detach lists: %w", err)
		}
		res := tx.Where("id = ? AND user_id = ?", id, userID).Delete(&TaskFolder{})
		if res.Error != nil {
			return fmt.Errorf("delete folder: %w", res.Error)
		}
		return nil
	})
}

// SetTaskListFolder moves a list into a folder (0 = root).
func (s *Store) SetTaskListFolder(ctx context.Context, userID, listID, folderID int64) error {
	if _, err := s.GetTaskList(ctx, userID, listID); err != nil {
		return err
	}
	if folderID != 0 {
		if _, err := s.GetTaskFolder(ctx, userID, folderID); err != nil {
			return err
		}
	}
	err := s.db.WithContext(ctx).Model(&TaskList{}).
		Where("id = ? AND user_id = ?", listID, userID).
		Update("folder_id", folderID).Error
	if err != nil {
		return fmt.Errorf("move task list: %w", err)
	}
	return nil
}

// ---------------------------------------------------------------- tags

// TaskTagCounts aggregates tags across live tasks.
func (s *Store) TaskTagCounts(ctx context.Context, userID int64) ([]TaskTagCount, error) {
	tasks, err := s.ListAllTasks(ctx, userID, 5000)
	if err != nil {
		return nil, err
	}
	counts := map[string]int{}
	for _, task := range tasks {
		for _, tag := range task.Tags {
			if tag != "" {
				counts[tag]++
			}
		}
	}
	colors, _ := s.ListTaskTagColors(ctx, userID)
	out := make([]TaskTagCount, 0, len(counts))
	for name, count := range counts {
		out = append(out, TaskTagCount{Name: name, Count: count, Color: colors[name]})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Count != out[j].Count {
			return out[i].Count > out[j].Count
		}
		return out[i].Name < out[j].Name
	})
	return out, nil
}

// RenameTaskTag rewrites every live task carrying the old tag.
func (s *Store) RenameTaskTag(ctx context.Context, userID int64, from, to string) error {
	from = strings.TrimSpace(from)
	to = strings.TrimSpace(strings.ReplaceAll(to, ",", ""))
	if from == "" || to == "" {
		return errors.New("tag names are required")
	}
	if from == to {
		return nil
	}
	tasks, err := s.listTasksIncludingDeleted(ctx, userID)
	if err != nil {
		return err
	}
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for _, task := range tasks {
			if !containsTag(task.Tags, from) {
				continue
			}
			tags := make(StringList, 0, len(task.Tags))
			for _, tag := range task.Tags {
				if tag == from {
					tag = to
				}
				if !containsTag(tags, tag) {
					tags = append(tags, tag)
				}
			}
			if err := tx.Model(&Task{}).Where("id = ? AND user_id = ?", task.ID, userID).
				Updates(map[string]any{"tags": tags, "sync_pending": true}).Error; err != nil {
				return fmt.Errorf("rename tag: %w", err)
			}
		}
		var source TaskTagColor
		if err := tx.Where("user_id = ? AND name = ?", userID, from).First(&source).Error; err == nil {
			var targetCount int64
			_ = tx.Model(&TaskTagColor{}).Where("user_id = ? AND name = ?", userID, to).Count(&targetCount).Error
			if targetCount > 0 {
				_ = tx.Where("id = ?", source.ID).Delete(&TaskTagColor{}).Error
			} else {
				_ = tx.Model(&TaskTagColor{}).Where("id = ?", source.ID).Update("name", to).Error
			}
		}
		return nil
	})
}

// DeleteTaskTag removes a tag from every live task.
func (s *Store) DeleteTaskTag(ctx context.Context, userID int64, tag string) error {
	tag = strings.TrimSpace(tag)
	if tag == "" {
		return nil
	}
	tasks, err := s.listTasksIncludingDeleted(ctx, userID)
	if err != nil {
		return err
	}
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for _, task := range tasks {
			if !containsTag(task.Tags, tag) {
				continue
			}
			tags := make(StringList, 0, len(task.Tags))
			for _, item := range task.Tags {
				if item != tag {
					tags = append(tags, item)
				}
			}
			if err := tx.Model(&Task{}).Where("id = ? AND user_id = ?", task.ID, userID).
				Updates(map[string]any{"tags": tags, "sync_pending": true}).Error; err != nil {
				return fmt.Errorf("delete tag: %w", err)
			}
		}
		if err := tx.Where("user_id = ? AND name = ?", userID, tag).Delete(&TaskTagColor{}).Error; err != nil {
			return fmt.Errorf("delete tag color: %w", err)
		}
		return nil
	})
}

func (s *Store) listTasksIncludingDeleted(ctx context.Context, userID int64) ([]*Task, error) {
	var tasks []*Task
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).Limit(5000).Find(&tasks).Error
	if err != nil {
		return nil, fmt.Errorf("list tasks for tags: %w", err)
	}
	return tasks, nil
}

func containsTag(tags []string, want string) bool {
	for _, tag := range tags {
		if tag == want {
			return true
		}
	}
	return false
}

// ---------------------------------------------------------------- saved filters

// ListSavedFilters returns filters in display order.
func (s *Store) ListSavedFilters(ctx context.Context, userID int64) ([]*SavedFilter, error) {
	var filters []*SavedFilter
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("pinned DESC, order_index ASC, id ASC").Find(&filters).Error
	if err != nil {
		return nil, fmt.Errorf("list saved filters: %w", err)
	}
	return filters, nil
}

// GetSavedFilter returns one filter scoped to its owner.
func (s *Store) GetSavedFilter(ctx context.Context, userID, id int64) (*SavedFilter, error) {
	var filter SavedFilter
	err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&filter).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get saved filter: %w", err)
	}
	return &filter, nil
}

// CreateSavedFilter stores a new filter.
func (s *Store) CreateSavedFilter(ctx context.Context, userID int64, name, color, conditions string) (*SavedFilter, error) {
	return s.CreateSavedFilterWithSyncID(ctx, userID, name, color, conditions, "")
}

// CreateSavedFilterWithSyncID stores a filter using a caller-supplied sync ID.
func (s *Store) CreateSavedFilterWithSyncID(ctx context.Context, userID int64, name, color, conditions, syncID string) (*SavedFilter, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, errors.New("filter name is required")
	}
	var maxOrder int
	_ = s.db.WithContext(ctx).Model(&SavedFilter{}).Where("user_id = ?", userID).
		Select("COALESCE(MAX(order_index), 0)").Scan(&maxOrder).Error
	filter := SavedFilter{UserID: userID, SyncID: syncID, Name: name, Color: color, Conditions: conditions, Order: maxOrder + 1}
	if err := s.db.WithContext(ctx).Create(&filter).Error; err != nil {
		return nil, fmt.Errorf("create saved filter: %w", err)
	}
	return &filter, nil
}

// UpdateSavedFilter replaces a filter's fields.
func (s *Store) UpdateSavedFilter(ctx context.Context, userID, id int64, name, color, conditions string, order int) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return errors.New("filter name is required")
	}
	res := s.db.WithContext(ctx).Model(&SavedFilter{}).
		Where("id = ? AND user_id = ?", id, userID).
		Updates(map[string]any{
			"name": name, "color": color, "conditions": conditions, "order_index": order,
		})
	if res.Error != nil {
		return fmt.Errorf("update saved filter: %w", res.Error)
	}
	return nil
}

// SetSavedFilterPinned pins or unpins a saved filter in the sidebar.
func (s *Store) SetSavedFilterPinned(ctx context.Context, userID, id int64, pinned bool) (*SavedFilter, error) {
	res := s.db.WithContext(ctx).Model(&SavedFilter{}).
		Where("id = ? AND user_id = ?", id, userID).
		Update("pinned", pinned)
	if res.Error != nil {
		return nil, fmt.Errorf("pin saved filter: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return nil, ErrNotFound
	}
	return s.GetSavedFilter(ctx, userID, id)
}

// DeleteSavedFilter removes a filter.
func (s *Store) DeleteSavedFilter(ctx context.Context, userID, id int64) error {
	res := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).Delete(&SavedFilter{})
	if res.Error != nil {
		return fmt.Errorf("delete saved filter: %w", res.Error)
	}
	return nil
}

// ListFilteredTasks applies saved-filter conditions.
func filterLocation() *time.Location {
	if loc, err := time.LoadLocation(DefaultTimezone); err == nil {
		return loc
	}
	return time.UTC
}

// parseFilterDate reads a YYYY-MM-DD boundary in the deployment timezone.
func parseFilterDate(raw string) (time.Time, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, false
	}
	parsed, err := time.ParseInLocation("2006-01-02", raw, filterLocation())
	if err != nil {
		return time.Time{}, false
	}
	return parsed.UTC(), true
}

func (s *Store) ListFilteredTasks(ctx context.Context, userID int64, cond TaskFilterConditions, limit int) ([]*Task, error) {
	if limit <= 0 || limit > 500 {
		limit = 300
	}
	query := s.db.WithContext(ctx).Model(&Task{}).Where("user_id = ? AND deleted = ?", userID, false)
	switch cond.Status {
	case "completed":
		query = query.Where("completed = ?", true)
	case "all":
	default:
		query = query.Where("completed = ?", false)
	}
	if len(cond.ListIDs) > 0 {
		query = query.Where("list_id IN ?", cond.ListIDs)
	}
	if len(cond.Priorities) > 0 {
		query = query.Where("priority IN ?", cond.Priorities)
	}
	now := time.Now().UTC()
	loc := filterLocation()
	localNow := now.In(loc)
	dayStart := time.Date(localNow.Year(), localNow.Month(), localNow.Day(), 0, 0, 0, 0, loc)
	today := dayStart.UTC()
	weekday := int(dayStart.Weekday())
	if weekday == 0 {
		weekday = 7 // Monday-based week
	}
	weekStart := dayStart.AddDate(0, 0, -(weekday - 1))
	monthStart := time.Date(dayStart.Year(), dayStart.Month(), 1, 0, 0, 0, 0, loc)
	switch cond.Date {
	case "today":
		query = query.Where("due_at IS NOT NULL AND due_at < ?", dayStart.AddDate(0, 0, 1).UTC())
	case "tomorrow":
		query = query.Where("due_at IS NOT NULL AND due_at >= ? AND due_at < ?", dayStart.AddDate(0, 0, 1).UTC(), dayStart.AddDate(0, 0, 2).UTC())
	case "next7":
		query = query.Where("due_at IS NOT NULL AND due_at >= ? AND due_at < ?", today, dayStart.AddDate(0, 0, 7).UTC())
	case "overdue":
		query = query.Where("((all_day = ? AND due_at < ?) OR (all_day = ? AND due_at < ?))", false, now, true, today)
	case "none":
		query = query.Where("due_at IS NULL")
	case "yesterday":
		query = query.Where("due_at IS NOT NULL AND due_at >= ? AND due_at < ?", dayStart.AddDate(0, 0, -1).UTC(), today)
	case "thisWeek":
		query = query.Where("due_at IS NOT NULL AND due_at >= ? AND due_at < ?", weekStart.UTC(), weekStart.AddDate(0, 0, 7).UTC())
	case "lastWeek":
		query = query.Where("due_at IS NOT NULL AND due_at >= ? AND due_at < ?", weekStart.AddDate(0, 0, -7).UTC(), weekStart.UTC())
	case "thisMonth":
		query = query.Where("due_at IS NOT NULL AND due_at >= ? AND due_at < ?", monthStart.UTC(), monthStart.AddDate(0, 1, 0).UTC())
	case "lastMonth":
		query = query.Where("due_at IS NOT NULL AND due_at >= ? AND due_at < ?", monthStart.AddDate(0, -1, 0).UTC(), monthStart.UTC())
	case "range":
		if from, ok := parseFilterDate(cond.DateFrom); ok {
			query = query.Where("due_at IS NOT NULL AND due_at >= ?", from)
		}
		if to, ok := parseFilterDate(cond.DateTo); ok {
			query = query.Where("due_at IS NOT NULL AND due_at < ?", to.AddDate(0, 0, 1))
		}
	}
	if len(cond.Tags) > 0 {
		clauses := make([]string, 0, len(cond.Tags))
		args := make([]any, 0, len(cond.Tags))
		for _, tag := range cond.Tags {
			clauses = append(clauses, "instr(',' || tags || ',', ',' || ? || ',') > 0")
			args = append(args, tag)
		}
		join := " OR "
		if cond.TagMode == "all" {
			join = " AND "
		}
		query = query.Where("("+strings.Join(clauses, join)+")", args...)
	}
	if keyword := strings.TrimSpace(cond.Keyword); keyword != "" {
		like := "%" + strings.ReplaceAll(strings.ReplaceAll(keyword, "%", `\%`), "_", `\_`) + "%"
		query = query.Where(`(title LIKE ? ESCAPE '\' OR notes_text LIKE ? ESCAPE '\')`, like, like)
	}
	var tasks []*Task
	if err := query.Order("CASE WHEN pinned_at IS NULL THEN 1 ELSE 0 END, pinned_at DESC, CASE WHEN due_at IS NULL THEN 1 ELSE 0 END, due_at ASC, order_index ASC, id DESC").
		Limit(limit).Find(&tasks).Error; err != nil {
		return nil, fmt.Errorf("list filtered tasks: %w", err)
	}
	return tasks, nil
}
