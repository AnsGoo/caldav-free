// Package store provides the GORM-based persistence layer for caldav-free.
package store

import (
	"context"
	"database/sql/driver"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	_ "modernc.org/sqlite"
)

// DefaultTimezone is used for calendars that do not specify a timezone.
const DefaultTimezone = "Asia/Shanghai"

var (
	// ErrNotFound is returned when a requested record does not exist.
	ErrNotFound = errors.New("not found")
	// ErrConflict is returned when a unique constraint would be violated.
	ErrConflict = errors.New("conflict")
)

// StringList is stored as a comma-separated TEXT column.
type StringList []string

// Value implements driver.Valuer.
func (s StringList) Value() (driver.Value, error) { return strings.Join(s, ","), nil }

// Scan implements sql.Scanner.
func (s *StringList) Scan(v any) error {
	switch value := v.(type) {
	case nil:
		*s = nil
	case string:
		*s = SplitComponents(value)
	case []byte:
		*s = SplitComponents(string(value))
	default:
		return fmt.Errorf("cannot scan %T into StringList", v)
	}
	return nil
}

// GormDataType tells GORM which column type to use.
func (StringList) GormDataType() string { return "text" }

// User is a principal that can authenticate and own calendars.
type User struct {
	ID           int64     `gorm:"primaryKey"`
	Username     string    `gorm:"size:190;not null;uniqueIndex"`
	DisplayName  string    `gorm:"size:190;not null;default:''"`
	Email        string    `gorm:"size:190;not null;default:''"`
	PasswordHash string    `gorm:"not null"`
	IsAdmin      bool      `gorm:"not null;default:false"`
	CreatedAt    time.Time `gorm:"not null;autoCreateTime"`
}

// Calendar is a calendar collection owned by a user.
type Calendar struct {
	ID           int64      `gorm:"primaryKey"`
	UserID       int64      `gorm:"not null;uniqueIndex:idx_calendar_owner_slug,priority:1;index:idx_calendar_user"`
	Slug         string     `gorm:"size:190;not null;uniqueIndex:idx_calendar_owner_slug,priority:2"`
	DisplayName  string     `gorm:"not null;default:''"`
	Description  string     `gorm:"not null;default:''"`
	Color        string     `gorm:"size:32;not null;default:''"`
	Order        int        `gorm:"column:order_index;not null;default:0"`
	Timezone     string     `gorm:"size:64;not null;default:'UTC'"`
	TimezoneData string     `gorm:"type:text;not null;default:''"`
	Components   StringList `gorm:"not null"`
	SyncSeq      int64      `gorm:"not null;default:0"`
	CreatedAt    time.Time  `gorm:"not null;autoCreateTime"`
	ModifiedAt   time.Time  `gorm:"not null;autoUpdateTime"`
}

// DisplayNameOrSlug returns a non-empty human-readable calendar name.
func (c *Calendar) DisplayNameOrSlug() string {
	if strings.TrimSpace(c.DisplayName) != "" {
		return c.DisplayName
	}
	return c.Slug
}

// SupportsComponent reports whether the calendar accepts the component type.
func (c *Calendar) SupportsComponent(component string) bool {
	if len(c.Components) == 0 {
		return true
	}
	for _, v := range c.Components {
		if strings.EqualFold(v, component) {
			return true
		}
	}
	return false
}

// Object is a single calendar object resource (an .ics file). FirstStart and
// LastEnd are Unix seconds used for cheap SQL pre-filtering.
type Object struct {
	ID            int64     `gorm:"primaryKey"`
	CalendarID    int64     `gorm:"not null;uniqueIndex:idx_object_calendar_href,priority:1;index:idx_object_calendar_deleted,priority:1"`
	Href          string    `gorm:"size:255;not null;uniqueIndex:idx_object_calendar_href,priority:2"`
	UID           string    `gorm:"size:255;not null;index:idx_object_uid"`
	ETag          string    `gorm:"column:etag;size:64;not null"`
	ContentType   string    `gorm:"not null;default:'text/calendar; charset=utf-8'"`
	Data          []byte    `gorm:"not null"`
	ComponentType string    `gorm:"size:16;not null"`
	FirstStart    int64     `gorm:"not null;default:0;index"`
	LastEnd       int64     `gorm:"not null;default:0"`
	Recurring     bool      `gorm:"not null;default:false"`
	Size          int64     `gorm:"not null;default:0"`
	CreatedAt     time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt    time.Time `gorm:"not null;autoUpdateTime"`
	Deleted       bool      `gorm:"not null;default:false;index:idx_object_calendar_deleted,priority:2"`
}

// SyncChange is one entry in a calendar's sync journal.
type SyncChange struct {
	ID         int64  `gorm:"primaryKey"`
	CalendarID int64  `gorm:"not null;index:idx_sync_calendar_seq,priority:1;index:idx_sync_calendar_href,priority:1"`
	Seq        int64  `gorm:"not null;index:idx_sync_calendar_seq,priority:2;index:idx_sync_calendar_href,priority:3"`
	Href       string `gorm:"size:255;not null;index:idx_sync_calendar_href,priority:2"`
	UID        string `gorm:"size:255;not null;default:''"`
	Op         string `gorm:"size:16;not null"` // "put" or "delete"
}

// Setting is a simple key/value store for server settings.
type Setting struct {
	Key   string `gorm:"primaryKey;size:190"`
	Value string `gorm:"not null"`
}

// Store owns the GORM database handle.
type Store struct {
	db *gorm.DB
}

// Open opens (and if necessary creates) the SQLite database.
func Open(path string) (*Store, error) {
	if path == "" {
		return nil, errors.New("database path is required")
	}
	if path != ":memory:" && !strings.HasPrefix(path, "file:") {
		if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
			return nil, fmt.Errorf("create data directory: %w", err)
		}
	}

	dsn := path
	if path == ":memory:" {
		dsn = "file:caldav-free?mode=memory&cache=shared"
	} else if !strings.HasPrefix(path, "file:") {
		dsn = "file:" + path
	}
	sep := "?"
	if strings.Contains(dsn, "?") {
		sep = "&"
	}
	// modernc.org/sqlite registers the "sqlite" driver.
	dsn += sep + "_pragma=busy_timeout(10000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)&_pragma=synchronous(NORMAL)"

	db, err := gorm.Open(sqlite.Dialector{DriverName: "sqlite", DSN: dsn}, &gorm.Config{
		Logger:  logger.Default.LogMode(logger.Silent),
		NowFunc: func() time.Time { return time.Now().UTC() },
	})
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("get database handle: %w", err)
	}
	sqlDB.SetMaxOpenConns(8)
	sqlDB.SetMaxIdleConns(4)
	sqlDB.SetConnMaxLifetime(0)

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := db.WithContext(ctx).AutoMigrate(&User{}, &Calendar{}, &Object{}, &SyncChange{}, &Setting{}, &TaskFolder{}, &TaskList{}, &Task{}, &SavedFilter{}, &SummaryDocument{}); err != nil {
		sqlDB.Close()
		return nil, fmt.Errorf("migrate schema: %w", err)
	}
	if path != ":memory:" && !strings.HasPrefix(path, "file:") {
		// The database contains credentials and calendar data.
		_ = os.Chmod(path, 0o600)
	}
	return &Store{db: db}, nil
}

// Close closes the underlying database.
func (s *Store) Close() error {
	sqlDB, err := s.db.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}

// DB exposes the GORM handle (used by tests and maintenance commands).
func (s *Store) DB() *gorm.DB { return s.db }

func translate(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrNotFound
	}
	msg := strings.ToLower(err.Error())
	if strings.Contains(msg, "unique constraint") || (strings.Contains(msg, "constraint failed") && strings.Contains(msg, "unique")) {
		return ErrConflict
	}
	return err
}

// ---------------------------------------------------------------- users

// CreateUser inserts a new user and returns it.
func (s *Store) CreateUser(ctx context.Context, username, displayName, email, passwordHash string, isAdmin bool) (*User, error) {
	username = strings.ToLower(strings.TrimSpace(username))
	if username == "" {
		return nil, errors.New("username is required")
	}
	u := &User{
		Username:     username,
		DisplayName:  displayName,
		Email:        email,
		PasswordHash: passwordHash,
		IsAdmin:      isAdmin,
		CreatedAt:    time.Now().UTC(),
	}
	if err := s.db.WithContext(ctx).Create(u).Error; err != nil {
		return nil, translate(err)
	}
	return u, nil
}

// GetUser loads a user by ID.
func (s *Store) GetUser(ctx context.Context, id int64) (*User, error) {
	var u User
	if err := s.db.WithContext(ctx).First(&u, id).Error; err != nil {
		return nil, translate(err)
	}
	return &u, nil
}

// GetUserByUsername loads a user by username (usernames are stored lowercase).
func (s *Store) GetUserByUsername(ctx context.Context, username string) (*User, error) {
	var u User
	err := s.db.WithContext(ctx).Where("username = ?", strings.ToLower(strings.TrimSpace(username))).First(&u).Error
	if err != nil {
		return nil, translate(err)
	}
	return &u, nil
}

// ListUsers returns all users ordered by username.
func (s *Store) ListUsers(ctx context.Context) ([]*User, error) {
	var users []*User
	if err := s.db.WithContext(ctx).Order("username ASC").Find(&users).Error; err != nil {
		return nil, translate(err)
	}
	return users, nil
}

// UpdateUser updates profile fields and, when passwordHash is non-empty, the password.
func (s *Store) UpdateUser(ctx context.Context, id int64, displayName, email string, isAdmin bool, passwordHash string) error {
	updates := map[string]any{
		"display_name": displayName,
		"email":        email,
		"is_admin":     isAdmin,
	}
	if passwordHash != "" {
		updates["password_hash"] = passwordHash
	}
	res := s.db.WithContext(ctx).Model(&User{}).Where("id = ?", id).Updates(updates)
	if res.Error != nil {
		return translate(res.Error)
	}
	if res.RowsAffected == 0 {
		var count int64
		if err := s.db.WithContext(ctx).Model(&User{}).Where("id = ?", id).Count(&count).Error; err != nil {
			return translate(err)
		}
		if count == 0 {
			return ErrNotFound
		}
	}
	return nil
}

// DeleteUser removes a user and everything they own.
func (s *Store) DeleteUser(ctx context.Context, id int64) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var calendars []Calendar
		if err := tx.Where("user_id = ?", id).Find(&calendars).Error; err != nil {
			return err
		}
		for _, cal := range calendars {
			if err := deleteCalendarTx(tx, cal.ID); err != nil {
				return err
			}
		}
		if err := tx.Where("user_id = ?", id).Delete(&Task{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ?", id).Delete(&TaskList{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ?", id).Delete(&TaskFolder{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ?", id).Delete(&SavedFilter{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ?", id).Delete(&SummaryDocument{}).Error; err != nil {
			return err
		}
		res := tx.Delete(&User{}, id)
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return ErrNotFound
		}
		return nil
	})
}

// CountUsers returns the total number of users.
func (s *Store) CountUsers(ctx context.Context) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&User{}).Count(&n).Error
	return n, translate(err)
}

// ---------------------------------------------------------------- calendars

// SplitComponents normalizes a comma-separated component list.
func SplitComponents(s string) []string {
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.ToUpper(strings.TrimSpace(p))
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

// CreateCalendar inserts a calendar.
func (s *Store) CreateCalendar(ctx context.Context, userID int64, slug, displayName, description, color, timezone string, order int, components []string) (*Calendar, error) {
	slug = strings.TrimSpace(slug)
	if slug == "" {
		return nil, errors.New("calendar slug is required")
	}
	if timezone == "" {
		timezone = DefaultTimezone
	}
	if len(components) == 0 {
		components = []string{"VEVENT", "VTODO", "VJOURNAL"}
	}
	now := time.Now().UTC()
	c := &Calendar{
		UserID:      userID,
		Slug:        slug,
		DisplayName: displayName,
		Description: description,
		Color:       color,
		Order:       order,
		Timezone:    timezone,
		Components:  StringList(components),
		CreatedAt:   now,
		ModifiedAt:  now,
	}
	if err := s.db.WithContext(ctx).Create(c).Error; err != nil {
		return nil, translate(err)
	}
	return c, nil
}

// GetCalendar loads a calendar by ID.
func (s *Store) GetCalendar(ctx context.Context, id int64) (*Calendar, error) {
	var c Calendar
	if err := s.db.WithContext(ctx).First(&c, id).Error; err != nil {
		return nil, translate(err)
	}
	return &c, nil
}

// GetCalendarBySlug loads a calendar by owner and slug.
func (s *Store) GetCalendarBySlug(ctx context.Context, userID int64, slug string) (*Calendar, error) {
	var c Calendar
	err := s.db.WithContext(ctx).Where("user_id = ? AND slug = ?", userID, slug).First(&c).Error
	if err != nil {
		return nil, translate(err)
	}
	return &c, nil
}

// ListCalendars returns a user's calendars ordered by display order and name.
func (s *Store) ListCalendars(ctx context.Context, userID int64) ([]*Calendar, error) {
	var cals []*Calendar
	err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("order_index ASC, display_name COLLATE NOCASE ASC, id ASC").
		Find(&cals).Error
	if err != nil {
		return nil, translate(err)
	}
	return cals, nil
}

// UpdateCalendar updates editable calendar properties.
func (s *Store) UpdateCalendar(ctx context.Context, id int64, displayName, description, color, timezone string, order int, components []string) error {
	if timezone == "" {
		timezone = DefaultTimezone
	}
	if len(components) == 0 {
		components = []string{"VEVENT", "VTODO", "VJOURNAL"}
	}
	res := s.db.WithContext(ctx).Model(&Calendar{}).Where("id = ?", id).Updates(map[string]any{
		"display_name": displayName,
		"description":  description,
		"color":        color,
		"timezone":     timezone,
		"order_index":  order,
		"components":   StringList(components),
		"modified_at":  time.Now().UTC(),
	})
	if res.Error != nil {
		return translate(res.Error)
	}
	if res.RowsAffected == 0 {
		var count int64
		if err := s.db.WithContext(ctx).Model(&Calendar{}).Where("id = ?", id).Count(&count).Error; err != nil {
			return translate(err)
		}
		if count == 0 {
			return ErrNotFound
		}
	}
	return nil
}

// SetCalendarTimezoneData stores the original VTIMEZONE payload for a calendar.
func (s *Store) SetCalendarTimezoneData(ctx context.Context, id int64, data string) error {
	res := s.db.WithContext(ctx).Model(&Calendar{}).Where("id = ?", id).Updates(map[string]any{
		"timezone_data": data,
		"modified_at":   time.Now().UTC(),
	})
	if res.Error != nil {
		return translate(res.Error)
	}
	if res.RowsAffected == 0 {
		var count int64
		if err := s.db.WithContext(ctx).Model(&Calendar{}).Where("id = ?", id).Count(&count).Error; err != nil {
			return translate(err)
		}
		if count == 0 {
			return ErrNotFound
		}
	}
	return nil
}

// DeleteCalendar removes a calendar and all of its objects.
func (s *Store) DeleteCalendar(ctx context.Context, id int64) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return deleteCalendarTx(tx, id)
	})
}

func deleteCalendarTx(tx *gorm.DB, id int64) error {
	if err := tx.Where("calendar_id = ?", id).Delete(&Object{}).Error; err != nil {
		return err
	}
	if err := tx.Where("calendar_id = ?", id).Delete(&SyncChange{}).Error; err != nil {
		return err
	}
	res := tx.Delete(&Calendar{}, id)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// CountCalendars returns the number of calendars owned by a user.
func (s *Store) CountCalendars(ctx context.Context, userID int64) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&Calendar{}).Where("user_id = ?", userID).Count(&n).Error
	return n, translate(err)
}

// CountAllCalendars returns the total number of calendars.
func (s *Store) CountAllCalendars(ctx context.Context) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&Calendar{}).Count(&n).Error
	return n, translate(err)
}

// ---------------------------------------------------------------- objects

// PutObject creates or replaces an object and records a sync change. It returns
// the new sync sequence, whether the object was newly created, and the previous
// object (nil when created).
func (s *Store) PutObject(ctx context.Context, obj *Object) (seq int64, created bool, existing *Object, err error) {
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var prev Object
		findErr := tx.Where("calendar_id = ? AND href = ?", obj.CalendarID, obj.Href).First(&prev).Error
		switch {
		case findErr == nil:
			existing = &prev
			obj.ID = prev.ID
			obj.CreatedAt = prev.CreatedAt
			obj.Deleted = false
			if err := tx.Model(&Object{}).Where("id = ?", prev.ID).Updates(map[string]any{
				"uid":            obj.UID,
				"etag":           obj.ETag,
				"content_type":   obj.ContentType,
				"data":           obj.Data,
				"component_type": obj.ComponentType,
				"first_start":    obj.FirstStart,
				"last_end":       obj.LastEnd,
				"recurring":      obj.Recurring,
				"size":           obj.Size,
				"deleted":        false,
				"modified_at":    time.Now().UTC(),
			}).Error; err != nil {
				return err
			}
		case errors.Is(findErr, gorm.ErrRecordNotFound):
			created = true
			obj.Deleted = false
			now := time.Now().UTC()
			obj.CreatedAt = now
			obj.ModifiedAt = now
			if err := tx.Create(obj).Error; err != nil {
				return err
			}
		default:
			return findErr
		}

		now := time.Now().UTC()
		if err := tx.Model(&Calendar{}).Where("id = ?", obj.CalendarID).Updates(map[string]any{
			"sync_seq":    gorm.Expr("sync_seq + 1"),
			"modified_at": now,
		}).Error; err != nil {
			return err
		}
		obj.ModifiedAt = now
		if err := tx.Model(&Calendar{}).Where("id = ?", obj.CalendarID).Pluck("sync_seq", &seq).Error; err != nil {
			return err
		}
		change := &SyncChange{CalendarID: obj.CalendarID, Seq: seq, Href: obj.Href, UID: obj.UID, Op: "put"}
		return tx.Create(change).Error
	})
	if err != nil {
		return 0, false, nil, translate(err)
	}
	return seq, created, existing, nil
}

// GetObject loads a live object by href.
func (s *Store) GetObject(ctx context.Context, calendarID int64, href string) (*Object, error) {
	var obj Object
	err := s.db.WithContext(ctx).
		Where("calendar_id = ? AND href = ? AND deleted = ?", calendarID, href, false).
		First(&obj).Error
	if err != nil {
		return nil, translate(err)
	}
	return &obj, nil
}

// GetObjectByUID loads a live object by its iCalendar UID.
func (s *Store) GetObjectByUID(ctx context.Context, calendarID int64, uid string) (*Object, error) {
	var obj Object
	err := s.db.WithContext(ctx).
		Where("calendar_id = ? AND uid = ? AND deleted = ?", calendarID, uid, false).
		First(&obj).Error
	if err != nil {
		return nil, translate(err)
	}
	return &obj, nil
}

// ListObjects returns all live objects in a calendar ordered by href.
func (s *Store) ListObjects(ctx context.Context, calendarID int64) ([]*Object, error) {
	var objs []*Object
	err := s.db.WithContext(ctx).
		Where("calendar_id = ? AND deleted = ?", calendarID, false).
		Order("href ASC").
		Find(&objs).Error
	if err != nil {
		return nil, translate(err)
	}
	return objs, nil
}

// ObjectRange pre-filters objects that could overlap a time range. Recurring
// objects are always returned; callers must expand them.
func (s *Store) ObjectRange(ctx context.Context, calendarID int64, start, end time.Time) ([]*Object, error) {
	var objs []*Object
	err := s.db.WithContext(ctx).
		Where("calendar_id = ? AND deleted = ?", calendarID, false).
		Where("(recurring = ? OR (last_end >= ? AND first_start < ?))", true, start.Unix(), end.Unix()).
		Order("href ASC").
		Find(&objs).Error
	if err != nil {
		return nil, translate(err)
	}
	return objs, nil
}

// DeleteObject tombstones an object and records a delete change. The returned
// bool reports whether a live object was actually removed.
func (s *Store) DeleteObject(ctx context.Context, calendarID int64, href string) (int64, bool, error) {
	var seq int64
	var removed bool
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var obj Object
		if err := tx.Where("calendar_id = ? AND href = ? AND deleted = ?", calendarID, href, false).First(&obj).Error; err != nil {
			return err
		}
		if err := tx.Model(&Object{}).Where("id = ?", obj.ID).Updates(map[string]any{
			"deleted":     true,
			"data":        []byte{},
			"modified_at": time.Now().UTC(),
		}).Error; err != nil {
			return err
		}
		if err := tx.Model(&Calendar{}).Where("id = ?", calendarID).Updates(map[string]any{
			"sync_seq":    gorm.Expr("sync_seq + 1"),
			"modified_at": time.Now().UTC(),
		}).Error; err != nil {
			return err
		}
		if err := tx.Model(&Calendar{}).Where("id = ?", calendarID).Pluck("sync_seq", &seq).Error; err != nil {
			return err
		}
		change := &SyncChange{CalendarID: calendarID, Seq: seq, Href: href, UID: obj.UID, Op: "delete"}
		if err := tx.Create(change).Error; err != nil {
			return err
		}
		removed = true
		return nil
	})
	if err != nil {
		return 0, false, translate(err)
	}
	return seq, removed, nil
}

// Change is one deduplicated entry in a calendar's sync journal.
type Change struct {
	Seq  int64
	Href string
	UID  string
	Op   string
}

// ChangesSince returns the latest change for each href after seq, ordered by seq.
func (s *Store) ChangesSince(ctx context.Context, calendarID, seq int64) ([]Change, error) {
	var changes []Change
	err := s.db.WithContext(ctx).Raw(`SELECT c.seq, c.href, c.uid, c.op FROM sync_changes c
		WHERE c.calendar_id = ? AND c.seq > ?
		  AND c.seq = (SELECT MAX(c2.seq) FROM sync_changes c2 WHERE c2.calendar_id = c.calendar_id AND c2.href = c.href)
		ORDER BY c.seq`, calendarID, seq).Scan(&changes).Error
	if err != nil {
		return nil, translate(err)
	}
	return changes, nil
}

// CountObjects returns the number of live objects in a calendar.
func (s *Store) CountObjects(ctx context.Context, calendarID int64) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&Object{}).
		Where("calendar_id = ? AND deleted = ?", calendarID, false).Count(&n).Error
	return n, translate(err)
}

// CountAllObjects returns the total number of live objects.
func (s *Store) CountAllObjects(ctx context.Context) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&Object{}).Where("deleted = ?", false).Count(&n).Error
	return n, translate(err)
}

// ---------------------------------------------------------------- settings

// GetSetting returns a setting value, or an empty string if absent.
func (s *Store) GetSetting(ctx context.Context, key string) (string, error) {
	var v Setting
	err := s.db.WithContext(ctx).Where("key = ?", key).First(&v).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return "", nil
	}
	if err != nil {
		return "", translate(err)
	}
	return v.Value, nil
}

// SetSetting upserts a setting.
func (s *Store) SetSetting(ctx context.Context, key, value string) error {
	setting := &Setting{Key: key, Value: value}
	err := s.db.WithContext(ctx).Save(setting).Error
	return translate(err)
}
