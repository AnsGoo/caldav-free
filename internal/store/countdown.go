package store

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"gorm.io/gorm"
)

// CountdownEvent is a countdown, anniversary, birthday or festival card.
// Date uses YYYYMMDD and Repeat describes how the next occurrence is derived.
type CountdownEvent struct {
	ID                int64     `gorm:"primaryKey" json:"id"`
	UserID            int64     `gorm:"not null;index:idx_countdown_user" json:"-"`
	Name              string    `gorm:"size:64;not null" json:"name"`
	Type              string    `gorm:"size:20;not null;default:'countdown'" json:"type"`
	Date              int       `gorm:"not null" json:"date"`
	Icon              string    `gorm:"size:40;not null;default:'⏳'" json:"icon"`
	Color             string    `gorm:"size:20;not null;default:'#92D0FF'" json:"color"`
	Style             string    `gorm:"size:20;not null;default:'normal'" json:"style"`
	Background        string    `gorm:"size:20;not null;default:''" json:"background"`
	Remark            string    `gorm:"type:text;not null;default:''" json:"remark"`
	Reminders         string    `gorm:"type:text;not null;default:'[]'" json:"reminders"`
	ReminderTime      string    `gorm:"size:5;not null;default:'09:00'" json:"reminderTime"`
	Repeat            string    `gorm:"size:20;not null;default:'none'" json:"repeat"`
	IgnoreYear        bool      `gorm:"not null" json:"ignoreYear"`
	ShowAge           bool      `gorm:"not null" json:"showAge"`
	DateDisplayFormat string    `gorm:"size:20;not null;default:'day'" json:"dateDisplayFormat"`
	Status            int       `gorm:"not null;default:0" json:"status"`
	Pinned            bool      `gorm:"not null;default:false;index:idx_countdown_pinned" json:"pinned"`
	SortOrder         int64     `gorm:"not null;default:0" json:"sortOrder"`
	CreatedAt         time.Time `gorm:"not null;autoCreateTime" json:"createdAt"`
	ModifiedAt        time.Time `gorm:"not null;autoUpdateTime" json:"modifiedAt"`
}

type CountdownItem struct {
	CountdownEvent
	Days           int    `json:"days"`
	State          string `json:"state"`
	OccurrenceDate int    `json:"occurrenceDate"`
	Age            int    `json:"age,omitempty"`
}

type CountdownPatch struct {
	Name              *string `json:"name"`
	Type              *string `json:"type"`
	Date              *int    `json:"date"`
	Icon              *string `json:"icon"`
	Color             *string `json:"color"`
	Style             *string `json:"style"`
	Background        *string `json:"background"`
	Remark            *string `json:"remark"`
	Reminders         *string `json:"reminders"`
	ReminderTime      *string `json:"reminderTime"`
	Repeat            *string `json:"repeat"`
	IgnoreYear        *bool   `json:"ignoreYear"`
	ShowAge           *bool   `json:"showAge"`
	DateDisplayFormat *string `json:"dateDisplayFormat"`
	Status            *int    `json:"status"`
	Pinned            *bool   `json:"pinned"`
}

func (s *Store) ListCountdowns(ctx context.Context, userID int64, archivedOnly bool) ([]*CountdownItem, error) {
	status := 0
	if archivedOnly {
		status = 1
	}
	query := s.db.WithContext(ctx).Where("user_id = ? AND status = ?", userID, status)
	var events []*CountdownEvent
	if err := query.Order("pinned DESC, sort_order ASC, date ASC, id ASC").Find(&events).Error; err != nil {
		return nil, fmt.Errorf("list countdowns: %w", err)
	}
	now := time.Now()
	items := make([]*CountdownItem, 0, len(events))
	for _, event := range events {
		items = append(items, countdownItem(event, now))
	}
	return items, nil
}

func (s *Store) CreateCountdown(ctx context.Context, event *CountdownEvent) (*CountdownItem, error) {
	if event == nil {
		return nil, fmt.Errorf("倒数记录不能为空")
	}
	if err := normalizeCountdown(event); err != nil {
		return nil, err
	}
	var minOrder int64
	_ = s.db.WithContext(ctx).Model(&CountdownEvent{}).Where("user_id = ?", event.UserID).
		Select("COALESCE(MIN(sort_order), 0)").Scan(&minOrder).Error
	event.SortOrder = minOrder - 1
	event.Status = 0
	if err := s.db.WithContext(ctx).Create(event).Error; err != nil {
		return nil, fmt.Errorf("create countdown: %w", err)
	}
	return countdownItem(event, time.Now()), nil
}

func (s *Store) UpdateCountdown(ctx context.Context, userID, id int64, patch *CountdownPatch) (*CountdownItem, error) {
	var event CountdownEvent
	if err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&event).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if patch != nil {
		if patch.Name != nil {
			event.Name = *patch.Name
		}
		if patch.Type != nil {
			event.Type = *patch.Type
		}
		if patch.Date != nil {
			event.Date = *patch.Date
		}
		if patch.Icon != nil {
			event.Icon = *patch.Icon
		}
		if patch.Color != nil {
			event.Color = *patch.Color
		}
		if patch.Style != nil {
			event.Style = *patch.Style
		}
		if patch.Background != nil {
			event.Background = *patch.Background
		}
		if patch.Remark != nil {
			event.Remark = *patch.Remark
		}
		if patch.Reminders != nil {
			event.Reminders = *patch.Reminders
		}
		if patch.ReminderTime != nil {
			event.ReminderTime = *patch.ReminderTime
		}
		if patch.Repeat != nil {
			event.Repeat = *patch.Repeat
		}
		if patch.IgnoreYear != nil {
			event.IgnoreYear = *patch.IgnoreYear
		}
		if patch.ShowAge != nil {
			event.ShowAge = *patch.ShowAge
		}
		if patch.DateDisplayFormat != nil {
			event.DateDisplayFormat = *patch.DateDisplayFormat
		}
		if patch.Status != nil {
			event.Status = *patch.Status
		}
		if patch.Pinned != nil {
			event.Pinned = *patch.Pinned
		}
	}
	if err := normalizeCountdown(&event); err != nil {
		return nil, err
	}
	if event.Status != 0 {
		event.Status = 1
	}
	if err := s.db.WithContext(ctx).Save(&event).Error; err != nil {
		return nil, fmt.Errorf("update countdown: %w", err)
	}
	return countdownItem(&event, time.Now()), nil
}

func (s *Store) DeleteCountdown(ctx context.Context, userID, id int64) error {
	result := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).Delete(&CountdownEvent{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

func normalizeCountdown(event *CountdownEvent) error {
	event.Name = strings.TrimSpace(event.Name)
	if event.Name == "" {
		return fmt.Errorf("名称不能为空")
	}
	if len([]rune(event.Name)) > 64 {
		event.Name = string([]rune(event.Name)[:64])
	}
	switch event.Type {
	case "anniversary", "countdown", "birthday", "festival":
	default:
		event.Type = "countdown"
	}
	if event.Date < 19000101 || event.Date > 99991231 {
		return fmt.Errorf("日期无效")
	}
	if _, ok := parseCountdownDate(event.Date); !ok {
		return fmt.Errorf("日期无效")
	}
	if event.Icon == "" {
		event.Icon = "⏳"
	}
	if event.Color == "" {
		event.Color = "#92D0FF"
	}
	switch event.Style {
	case "normal", "color", "soft", "outline":
	default:
		event.Style = "normal"
	}
	switch event.Repeat {
	case "none", "yearly", "monthly", "weekly", "weekend":
	default:
		event.Repeat = "none"
	}
	if strings.TrimSpace(event.ReminderTime) == "" {
		event.ReminderTime = "09:00"
	}
	if _, err := time.Parse("15:04", event.ReminderTime); err != nil {
		return fmt.Errorf("提醒时间无效")
	}
	if event.DateDisplayFormat != "full" {
		event.DateDisplayFormat = "day"
	}
	if strings.TrimSpace(event.Reminders) == "" {
		event.Reminders = "[]"
	}
	var offsets []int
	if err := json.Unmarshal([]byte(event.Reminders), &offsets); err != nil {
		return fmt.Errorf("提醒设置无效")
	}
	filtered := make([]int, 0, len(offsets))
	for _, offset := range offsets {
		if offset >= 0 && offset <= 3650 {
			filtered = append(filtered, offset)
		}
	}
	sort.Ints(filtered)
	unique := filtered[:0]
	for _, offset := range filtered {
		if len(unique) == 0 || unique[len(unique)-1] != offset {
			unique = append(unique, offset)
		}
	}
	encoded, _ := json.Marshal(unique)
	event.Reminders = string(encoded)
	event.Remark = strings.TrimSpace(event.Remark)
	if len([]rune(event.Remark)) > 2000 {
		event.Remark = string([]rune(event.Remark)[:2000])
	}
	return nil
}

func countdownItem(event *CountdownEvent, now time.Time) *CountdownItem {
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	original, _ := parseCountdownDate(event.Date)
	occurrence := original
	if event.Repeat != "none" {
		occurrence = nextCountdownDate(original, event.Repeat, today)
	}
	item := &CountdownItem{
		CountdownEvent: *event,
		OccurrenceDate: stampOf(occurrence),
		Days:           countdownDays(today, occurrence),
	}
	switch {
	case item.Days == 0:
		item.State = "today"
	case item.Days > 0:
		item.State = "future"
	default:
		item.State = "past"
		item.Days = -item.Days
	}
	if event.Type == "birthday" && event.ShowAge {
		item.Age = occurrence.Year() - original.Year()
		if item.Age < 0 {
			item.Age = 0
		}
	}
	return item
}

func parseCountdownDate(value int) (time.Time, bool) {
	raw := fmt.Sprintf("%08d", value)
	parsed, err := time.ParseInLocation("20060102", raw, time.Local)
	if err != nil {
		return time.Time{}, false
	}
	return parsed, true
}

func nextCountdownDate(original time.Time, repeat string, today time.Time) time.Time {
	switch repeat {
	case "yearly":
		for year := today.Year(); year <= today.Year()+2; year++ {
			candidate := annualCountdownDate(original, year)
			if !candidate.Before(today) {
				return candidate
			}
		}
	case "monthly":
		for offset := 0; offset <= 24; offset++ {
			month := time.Date(today.Year(), today.Month()+time.Month(offset), 1, 0, 0, 0, 0, today.Location())
			candidate := monthlyCountdownDate(original, month.Year(), month.Month())
			if !candidate.Before(today) {
				return candidate
			}
		}
	case "weekly":
		candidate := original
		if candidate.Before(today) {
			days := countdownDays(candidate, today)
			weeks := (days + 6) / 7
			candidate = candidate.AddDate(0, 0, weeks*7)
		}
		for candidate.Before(today) {
			candidate = candidate.AddDate(0, 0, 7)
		}
		return candidate
	case "weekend":
		weekday := int(today.Weekday())
		if weekday == 0 || weekday == 6 {
			return today
		}
		days := 6 - weekday
		return today.AddDate(0, 0, days)
	}
	return original
}

func annualCountdownDate(original time.Time, year int) time.Time {
	day := original.Day()
	last := time.Date(year, original.Month()+1, 0, 0, 0, 0, 0, original.Location()).Day()
	if day > last {
		day = last
	}
	return time.Date(year, original.Month(), day, 0, 0, 0, 0, original.Location())
}

func monthlyCountdownDate(original time.Time, year int, month time.Month) time.Time {
	day := original.Day()
	last := time.Date(year, month+1, 0, 0, 0, 0, 0, original.Location()).Day()
	if day > last {
		day = last
	}
	return time.Date(year, month, day, 0, 0, 0, 0, original.Location())
}

func countdownDays(from, to time.Time) int {
	fromDay := time.Date(from.Year(), from.Month(), from.Day(), 0, 0, 0, 0, time.UTC)
	toDay := time.Date(to.Year(), to.Month(), to.Day(), 0, 0, 0, 0, time.UTC)
	return int(toDay.Sub(fromDay).Hours() / 24)
}

func CountdownReminders(raw string) []int {
	var offsets []int
	_ = json.Unmarshal([]byte(raw), &offsets)
	return offsets
}

func (s *Store) ListCountdownReminderCandidates(ctx context.Context) ([]*CountdownItem, error) {
	var events []*CountdownEvent
	if err := s.db.WithContext(ctx).Where("status = 0 AND reminders NOT IN ('', '[]')").
		Order("id ASC").Find(&events).Error; err != nil {
		return nil, fmt.Errorf("list countdown reminders: %w", err)
	}
	now := time.Now()
	items := make([]*CountdownItem, 0, len(events))
	for _, event := range events {
		items = append(items, countdownItem(event, now))
	}
	return items, nil
}

func CountdownOccurrenceTime(stamp int) (time.Time, bool) {
	return parseCountdownDate(stamp)
}
