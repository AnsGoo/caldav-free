package store

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
)

// Syncable entity kinds exposed by the client sync protocol.
const (
	SyncEntityTask    = "task"
	SyncEntityList    = "list"
	SyncEntitySection = "section"
	SyncEntityFolder  = "folder"
	SyncEntityFilter  = "filter"
)

// SyncLog is one row in the user's monotonic change journal. IDs are assigned
// by SQLite and used as the pull cursor, so they must only ever increase.
type SyncLog struct {
	ID        int64  `gorm:"primaryKey"`
	UserID    int64  `gorm:"not null"`
	Entity    string `gorm:"size:16;not null"`
	EntityID  string `gorm:"size:64;not null"`
	Op        string `gorm:"size:8;not null"` // put | delete
	CreatedAt int64  `gorm:"not null"`        // Unix seconds
}

// SyncOp remembers the result of an idempotent push operation.
type SyncOp struct {
	ID        int64  `gorm:"primaryKey"`
	UserID    int64  `gorm:"not null"`
	OpID      string `gorm:"size:64;not null"`
	Entity    string `gorm:"size:16;not null"`
	EntityID  string `gorm:"size:64;not null"`
	Status    string `gorm:"size:16;not null"`
	Result    string `gorm:"type:text;not null"`
	CreatedAt int64  `gorm:"not null"`
}

// SyncJournalEntry is a collapsed journal row (the latest per entity).
type SyncJournalEntry struct {
	ID        int64
	Entity    string
	EntityID  string
	Op        string
	CreatedAt int64
}

// NewSyncID returns a lexicographically sortable, client-compatible ID.
// It follows the ULID layout (48-bit millisecond timestamp + 80 random bits)
// encoded with Crockford base32, without pulling in a dependency.
func NewSyncID() string {
	const alphabet = "0123456789abcdefghjkmnpqrstvwxyz"
	var random [16]byte
	_, _ = rand.Read(random[:])
	out := make([]byte, 26)
	millis := uint64(time.Now().UnixMilli())
	for i := 9; i >= 0; i-- {
		out[i] = alphabet[millis&31]
		millis >>= 5
	}
	for i := 10; i < 26; i++ {
		out[i] = alphabet[random[i-10]&31]
	}
	return string(out)
}

// BeforeCreate assigns a stable sync ID to every new syncable row.
func (t *Task) BeforeCreate(*gorm.DB) error {
	if t.SyncID == "" {
		t.SyncID = NewSyncID()
	}
	return nil
}

func (l *TaskList) BeforeCreate(*gorm.DB) error {
	if l.SyncID == "" {
		l.SyncID = NewSyncID()
	}
	return nil
}

func (s *TaskSection) BeforeCreate(*gorm.DB) error {
	if s.SyncID == "" {
		s.SyncID = NewSyncID()
	}
	return nil
}

func (f *TaskFolder) BeforeCreate(*gorm.DB) error {
	if f.SyncID == "" {
		f.SyncID = NewSyncID()
	}
	return nil
}

func (f *SavedFilter) BeforeCreate(*gorm.DB) error {
	if f.SyncID == "" {
		f.SyncID = NewSyncID()
	}
	return nil
}

// SyncChangesSince returns one row per changed entity, ordered by the latest
// journal row. hasMore reports whether another page is available.
func (s *Store) SyncChangesSince(ctx context.Context, userID, since int64, limit int) ([]SyncJournalEntry, bool, error) {
	if limit <= 0 || limit > 1000 {
		limit = 500
	}
	var rows []SyncJournalEntry
	err := s.db.WithContext(ctx).Raw(`
		SELECT id, entity, entity_id, op, created_at FROM (
			SELECT id, entity, entity_id, op, created_at,
			       ROW_NUMBER() OVER (PARTITION BY entity, entity_id ORDER BY id DESC) AS rn
			FROM sync_logs
			WHERE user_id = ? AND id > ?
		) WHERE rn = 1
		ORDER BY id ASC
		LIMIT ?`, userID, since, limit+1).Scan(&rows).Error
	if err != nil {
		return nil, false, fmt.Errorf("list sync changes: %w", err)
	}
	hasMore := len(rows) > limit
	if hasMore {
		rows = rows[:limit]
	}
	return rows, hasMore, nil
}

// SyncEntitySeq returns the latest journal sequence for one entity, or 0 when
// it has never been logged.
func (s *Store) SyncEntitySeq(ctx context.Context, userID int64, entity, entityID string) (int64, error) {
	var seq int64
	err := s.db.WithContext(ctx).Model(&SyncLog{}).
		Where("user_id = ? AND entity = ? AND entity_id = ?", userID, entity, entityID).
		Select("COALESCE(MAX(id), 0)").Scan(&seq).Error
	if err != nil {
		return 0, fmt.Errorf("sync entity seq: %w", err)
	}
	return seq, nil
}

// SyncUserSeq returns the current cursor for a user.
func (s *Store) SyncUserSeq(ctx context.Context, userID int64) (int64, error) {
	var seq int64
	err := s.db.WithContext(ctx).Model(&SyncLog{}).
		Where("user_id = ?", userID).
		Select("COALESCE(MAX(id), 0)").Scan(&seq).Error
	if err != nil {
		return 0, fmt.Errorf("sync user seq: %w", err)
	}
	return seq, nil
}

// GetSyncOp returns a previously applied operation, used for idempotent retry.
func (s *Store) GetSyncOp(ctx context.Context, userID int64, opID string) (*SyncOp, error) {
	var op SyncOp
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND op_id = ?", userID, opID).
		First(&op).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get sync op: %w", err)
	}
	return &op, nil
}

// SaveSyncOp records the result of a push operation.
func (s *Store) SaveSyncOp(ctx context.Context, op *SyncOp) error {
	if err := s.db.WithContext(ctx).Create(op).Error; err != nil {
		return fmt.Errorf("save sync op: %w", err)
	}
	return nil
}

// PruneSyncState removes old journal and idempotency rows. A full sync is
// required after the journal retention window.
func (s *Store) PruneSyncState(ctx context.Context, logRetention, opRetention time.Duration) error {
	now := time.Now()
	if logRetention > 0 {
		if err := s.db.WithContext(ctx).
			Where("created_at < ?", now.Add(-logRetention).Unix()).
			Delete(&SyncLog{}).Error; err != nil {
			return fmt.Errorf("prune sync log: %w", err)
		}
	}
	if opRetention > 0 {
		if err := s.db.WithContext(ctx).
			Where("created_at < ?", now.Add(-opRetention).Unix()).
			Delete(&SyncOp{}).Error; err != nil {
			return fmt.Errorf("prune sync ops: %w", err)
		}
	}
	return nil
}

// ---------------------------------------------------------------- lookups

// GetTaskBySyncID returns a task by its client-facing ID, including trashed
// rows so sync clients can observe deletions.
func (s *Store) GetTaskBySyncID(ctx context.Context, userID int64, syncID string) (*Task, error) {
	var task Task
	err := s.db.WithContext(ctx).Where("user_id = ? AND sync_id = ?", userID, syncID).First(&task).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get task by sync id: %w", err)
	}
	return &task, nil
}

// GetTaskListBySyncID returns a list by its client-facing ID.
func (s *Store) GetTaskListBySyncID(ctx context.Context, userID int64, syncID string) (*TaskList, error) {
	var list TaskList
	err := s.db.WithContext(ctx).Where("user_id = ? AND sync_id = ?", userID, syncID).First(&list).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get task list by sync id: %w", err)
	}
	return &list, nil
}

// GetTaskSectionBySyncID returns a section by its client-facing ID.
func (s *Store) GetTaskSectionBySyncID(ctx context.Context, userID int64, syncID string) (*TaskSection, error) {
	var section TaskSection
	err := s.db.WithContext(ctx).Where("user_id = ? AND sync_id = ?", userID, syncID).First(&section).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get task section by sync id: %w", err)
	}
	return &section, nil
}

// GetTaskFolderBySyncID returns a folder by its client-facing ID.
func (s *Store) GetTaskFolderBySyncID(ctx context.Context, userID int64, syncID string) (*TaskFolder, error) {
	var folder TaskFolder
	err := s.db.WithContext(ctx).Where("user_id = ? AND sync_id = ?", userID, syncID).First(&folder).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get task folder by sync id: %w", err)
	}
	return &folder, nil
}

// GetSavedFilterBySyncID returns a saved filter by its client-facing ID.
func (s *Store) GetSavedFilterBySyncID(ctx context.Context, userID int64, syncID string) (*SavedFilter, error) {
	var filter SavedFilter
	err := s.db.WithContext(ctx).Where("user_id = ? AND sync_id = ?", userID, syncID).First(&filter).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get saved filter by sync id: %w", err)
	}
	return &filter, nil
}

// SetTaskListFolder moves a list into a folder (folderID 0 = no folder).
// The public wrapper lives in filters.go; this file only needs the sync IDs.
// ListTasksBySyncIDs loads tasks (including trashed) for a pull batch.
func (s *Store) ListTasksBySyncIDs(ctx context.Context, userID int64, ids []string) ([]*Task, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var tasks []*Task
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND sync_id IN ?", userID, ids).
		Find(&tasks).Error
	if err != nil {
		return nil, fmt.Errorf("list tasks by sync ids: %w", err)
	}
	return tasks, nil
}

// ListTaskListsBySyncIDs loads lists for a pull batch.
func (s *Store) ListTaskListsBySyncIDs(ctx context.Context, userID int64, ids []string) ([]*TaskList, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var lists []*TaskList
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND sync_id IN ?", userID, ids).
		Find(&lists).Error
	if err != nil {
		return nil, fmt.Errorf("list task lists by sync ids: %w", err)
	}
	return lists, nil
}

// ListTaskSectionsBySyncIDs loads kanban sections for a pull batch.
func (s *Store) ListTaskSectionsBySyncIDs(ctx context.Context, userID int64, ids []string) ([]*TaskSection, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var sections []*TaskSection
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND sync_id IN ?", userID, ids).
		Find(&sections).Error
	if err != nil {
		return nil, fmt.Errorf("list task sections by sync ids: %w", err)
	}
	return sections, nil
}

// ListTaskFoldersBySyncIDs loads folders for a pull batch.
func (s *Store) ListTaskFoldersBySyncIDs(ctx context.Context, userID int64, ids []string) ([]*TaskFolder, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var folders []*TaskFolder
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND sync_id IN ?", userID, ids).
		Find(&folders).Error
	if err != nil {
		return nil, fmt.Errorf("list task folders by sync ids: %w", err)
	}
	return folders, nil
}

// ListSavedFiltersBySyncIDs loads saved filters for a pull batch.
func (s *Store) ListSavedFiltersBySyncIDs(ctx context.Context, userID int64, ids []string) ([]*SavedFilter, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var filters []*SavedFilter
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND sync_id IN ?", userID, ids).
		Find(&filters).Error
	if err != nil {
		return nil, fmt.Errorf("list saved filters by sync ids: %w", err)
	}
	return filters, nil
}

// TaskSyncIDMap maps internal task IDs to their client-facing IDs.
func (s *Store) TaskSyncIDMap(ctx context.Context, userID int64, ids []int64) (map[int64]string, error) {
	out := make(map[int64]string, len(ids))
	if len(ids) == 0 {
		return out, nil
	}
	var rows []struct {
		ID     int64
		SyncID string
	}
	if err := s.db.WithContext(ctx).Model(&Task{}).
		Where("user_id = ? AND id IN ?", userID, ids).
		Select("id, sync_id").Scan(&rows).Error; err != nil {
		return nil, fmt.Errorf("task sync id map: %w", err)
	}
	for _, row := range rows {
		out[row.ID] = row.SyncID
	}
	return out, nil
}

// ---------------------------------------------------------------- journal install

func installSyncJournal(db *gorm.DB) error {
	// Give legacy rows a stable client-facing ID. Numeric IDs are unique per
	// table and remain valid opaque strings.
	for _, table := range []string{"tasks", "task_lists", "task_sections", "task_folders", "saved_filters"} {
		if err := db.Exec("UPDATE " + table + " SET sync_id = CAST(id AS TEXT) WHERE sync_id IS NULL OR sync_id = ''").Error; err != nil {
			return fmt.Errorf("backfill %s sync ids: %w", table, err)
		}
	}
	for _, stmt := range []string{
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_user_syncid ON tasks(user_id, sync_id)",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_task_lists_user_syncid ON task_lists(user_id, sync_id)",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_task_sections_user_syncid ON task_sections(user_id, sync_id)",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_task_folders_user_syncid ON task_folders(user_id, sync_id)",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_saved_filters_user_syncid ON saved_filters(user_id, sync_id)",
		"CREATE INDEX IF NOT EXISTS idx_synclog_lookup ON sync_logs(user_id, entity, entity_id, id)",
		"CREATE INDEX IF NOT EXISTS idx_synclog_user_id ON sync_logs(user_id, id)",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_syncop_user_op ON sync_ops(user_id, op_id)",
		"DROP INDEX IF EXISTS idx_synclog_entity",
		"DROP INDEX IF EXISTS idx_synclog_user_seq",
	} {
		if err := db.Exec(stmt).Error; err != nil {
			return fmt.Errorf("index sync ids: %w", err)
		}
	}
	for _, item := range syncTriggers() {
		if err := db.Exec(item.SQL).Error; err != nil {
			return fmt.Errorf("install sync trigger %s: %w", item.Name, err)
		}
	}
	// Backfill one journal row per entity that predates the journal. This also
	// covers rows imported while the process was starting.
	type backfill struct {
		entity string
		table  string
		op     string
	}
	for _, item := range []backfill{
		{"task", "tasks", "CASE WHEN deleted = 1 THEN 'delete' ELSE 'put' END"},
		{"list", "task_lists", "'put'"},
		{"section", "task_sections", "'put'"},
		{"folder", "task_folders", "'put'"},
		{"filter", "saved_filters", "'put'"},
	} {
		query := fmt.Sprintf(`
			INSERT INTO sync_logs (user_id, entity, entity_id, op, created_at)
			SELECT user_id, '%s', sync_id, %s, CAST(strftime('%%s','now') AS INTEGER)
			FROM %s row
			WHERE row.sync_id <> '' AND NOT EXISTS (
				SELECT 1 FROM sync_logs l
				WHERE l.user_id = row.user_id AND l.entity = '%s' AND l.entity_id = row.sync_id
			)`, item.entity, item.op, item.table, item.entity)
		if err := db.Exec(query).Error; err != nil {
			return fmt.Errorf("backfill %s sync log: %w", item.entity, err)
		}
	}
	return nil
}

func syncTriggers() []triggerDef {
	taskChanged := `(
		OLD.title IS NOT NEW.title OR OLD.notes IS NOT NEW.notes OR
		OLD.notes_format IS NOT NEW.notes_format OR OLD.kind IS NOT NEW.kind OR
		OLD.priority IS NOT NEW.priority OR OLD.start_at IS NOT NEW.start_at OR
		OLD.due_at IS NOT NEW.due_at OR OLD.all_day IS NOT NEW.all_day OR
		OLD.recurrence IS NOT NEW.recurrence OR
		OLD.reminder_offset IS NOT NEW.reminder_offset OR
		OLD.reminder_offsets IS NOT NEW.reminder_offsets OR
		OLD.assignee IS NOT NEW.assignee OR OLD.completed IS NOT NEW.completed OR
		OLD.completed_at IS NOT NEW.completed_at OR OLD.pinned_at IS NOT NEW.pinned_at OR
		OLD.tags IS NOT NEW.tags OR OLD.checklist IS NOT NEW.checklist OR
		OLD.order_index IS NOT NEW.order_index OR OLD.list_id IS NOT NEW.list_id OR
		OLD.parent_id IS NOT NEW.parent_id OR OLD.section_id IS NOT NEW.section_id OR
		OLD.deleted IS NOT NEW.deleted
	)`
	listChanged := `(
		OLD.name IS NOT NEW.name OR OLD.color IS NOT NEW.color OR OLD.kind IS NOT NEW.kind OR
		OLD.order_index IS NOT NEW.order_index OR OLD.pinned IS NOT NEW.pinned OR
		OLD.folder_id IS NOT NEW.folder_id
	)`
	sectionChanged := `(OLD.name IS NOT NEW.name OR OLD.order_index IS NOT NEW.order_index OR OLD.list_id IS NOT NEW.list_id)`
	folderChanged := `(OLD.name IS NOT NEW.name OR OLD.order_index IS NOT NEW.order_index)`
	filterChanged := `(
		OLD.name IS NOT NEW.name OR OLD.color IS NOT NEW.color OR
		OLD.conditions IS NOT NEW.conditions OR OLD.order_index IS NOT NEW.order_index OR
		OLD.pinned IS NOT NEW.pinned
	)`

	insert := func(name, table, entity, opExpr string) triggerDef {
		return triggerDef{Name: name, SQL: fmt.Sprintf(`CREATE TRIGGER IF NOT EXISTS %s AFTER INSERT ON %s BEGIN
			INSERT INTO sync_logs (user_id, entity, entity_id, op, created_at)
			VALUES (NEW.user_id, '%s', NEW.sync_id, %s, CAST(strftime('%%s','now') AS INTEGER));
		END`, name, table, entity, opExpr)}
	}
	update := func(name, table, entity, when, opExpr string) triggerDef {
		return triggerDef{Name: name, SQL: fmt.Sprintf(`CREATE TRIGGER IF NOT EXISTS %s AFTER UPDATE ON %s WHEN %s BEGIN
			INSERT INTO sync_logs (user_id, entity, entity_id, op, created_at)
			VALUES (NEW.user_id, '%s', NEW.sync_id, %s, CAST(strftime('%%s','now') AS INTEGER));
		END`, name, table, when, entity, opExpr)}
	}
	remove := func(name, table, entity string) triggerDef {
		return triggerDef{Name: name, SQL: fmt.Sprintf(`CREATE TRIGGER IF NOT EXISTS %s AFTER DELETE ON %s BEGIN
			INSERT INTO sync_logs (user_id, entity, entity_id, op, created_at)
			VALUES (OLD.user_id, '%s', OLD.sync_id, 'delete', CAST(strftime('%%s','now') AS INTEGER));
		END`, name, table, entity)}
	}

	return []triggerDef{
		insert("sync_v1_tasks_insert", "tasks", "task", "'put'"),
		update("sync_v1_tasks_update_live", "tasks", "task", taskChanged+" AND NEW.deleted = 0", "'put'"),
		update("sync_v1_tasks_update_delete", "tasks", "task", "OLD.deleted = 0 AND NEW.deleted = 1", "'delete'"),
		update("sync_v1_tasks_update_restore", "tasks", "task", "OLD.deleted = 1 AND NEW.deleted = 0", "'put'"),
		remove("sync_v1_tasks_delete", "tasks", "task"),

		insert("sync_v1_lists_insert", "task_lists", "list", "'put'"),
		update("sync_v1_lists_update", "task_lists", "list", listChanged, "'put'"),
		remove("sync_v1_lists_delete", "task_lists", "list"),

		insert("sync_v1_sections_insert", "task_sections", "section", "'put'"),
		update("sync_v1_sections_update", "task_sections", "section", sectionChanged, "'put'"),
		remove("sync_v1_sections_delete", "task_sections", "section"),

		insert("sync_v1_folders_insert", "task_folders", "folder", "'put'"),
		update("sync_v1_folders_update", "task_folders", "folder", folderChanged, "'put'"),
		remove("sync_v1_folders_delete", "task_folders", "folder"),

		insert("sync_v1_filters_insert", "saved_filters", "filter", "'put'"),
		update("sync_v1_filters_update", "saved_filters", "filter", filterChanged, "'put'"),
		remove("sync_v1_filters_delete", "saved_filters", "filter"),
	}
}

// dropSyncTriggers removes the journal triggers before AutoMigrate. GORM's
// SQLite migrator recreates tables by renaming and dropping them; a trigger
// that references a table in the middle of that dance makes SQLite abort the
// migration. Triggers are reinstalled once the schema is stable.
func dropSyncTriggers(db *gorm.DB) error {
	for _, trigger := range syncTriggers() {
		if err := db.Exec("DROP TRIGGER IF EXISTS " + trigger.Name).Error; err != nil {
			return fmt.Errorf("drop sync trigger %s: %w", trigger.Name, err)
		}
	}
	return nil
}

type triggerDef struct {
	Name string
	SQL  string
}
