package store

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	lunarcalendar "github.com/6tail/lunar-go/calendar"
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
	Calendar          string    `gorm:"size:10;not null;default:'solar'" json:"calendar"`
	LunarMonth        int       `gorm:"not null;default:0" json:"lunarMonth"`
	LunarDay          int       `gorm:"not null;default:0" json:"lunarDay"`
	LunarLeap         bool      `gorm:"not null;default:false" json:"lunarLeap"`
	LunarYear         int       `gorm:"not null;default:0" json:"lunarYear"`
	HasBackground     bool      `gorm:"not null;default:false" json:"hasBackground"`
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
	DaysOption        string    `gorm:"size:10;not null;default:'day'" json:"daysOption"`
	Status            int       `gorm:"not null;default:0" json:"status"`
	Pinned            bool      `gorm:"not null;default:false;index:idx_countdown_pinned" json:"pinned"`
	SortOrder         int64     `gorm:"not null;default:0" json:"sortOrder"`
	CreatedAt         time.Time `gorm:"not null;autoCreateTime" json:"createdAt"`
	ModifiedAt        time.Time `gorm:"not null;autoUpdateTime" json:"modifiedAt"`
}

type CountdownItem struct {
	CountdownEvent
	Days           int    `json:"days"`
	Hours          int    `json:"hours"`
	State          string `json:"state"`
	OccurrenceDate int    `json:"occurrenceDate"`
	Age            int    `json:"age,omitempty"`
	BackgroundURL  string `json:"backgroundUrl,omitempty"`
}

type CountdownBackground struct {
	EventID   int64     `gorm:"primaryKey" json:"-"`
	UserID    int64     `gorm:"not null;index:idx_countdown_background_user" json:"-"`
	Mime      string    `gorm:"size:80;not null" json:"mime"`
	Data      []byte    `gorm:"type:blob;not null" json:"-"`
	UpdatedAt time.Time `gorm:"not null" json:"updatedAt"`
}

type CountdownPatch struct {
	Name              *string `json:"name"`
	Type              *string `json:"type"`
	Date              *int    `json:"date"`
	Calendar          *string `json:"calendar"`
	LunarMonth        *int    `json:"lunarMonth"`
	LunarDay          *int    `json:"lunarDay"`
	LunarLeap         *bool   `json:"lunarLeap"`
	LunarYear         *int    `json:"lunarYear"`
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
	DaysOption        *string `json:"daysOption"`
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
		if patch.Calendar != nil {
			event.Calendar = *patch.Calendar
		}
		if patch.LunarMonth != nil {
			event.LunarMonth = *patch.LunarMonth
		}
		if patch.LunarDay != nil {
			event.LunarDay = *patch.LunarDay
		}
		if patch.LunarLeap != nil {
			event.LunarLeap = *patch.LunarLeap
		}
		if patch.LunarYear != nil {
			event.LunarYear = *patch.LunarYear
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
		if patch.DaysOption != nil {
			event.DaysOption = *patch.DaysOption
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
	if event.Calendar != "lunar" {
		event.Calendar = "solar"
		event.LunarMonth = 0
		event.LunarDay = 0
		event.LunarLeap = false
		event.LunarYear = 0
	} else {
		if event.LunarMonth == 0 || event.LunarDay == 0 {
			parsed, _ := parseCountdownDate(event.Date)
			fromSolar := lunarcalendar.NewLunarFromSolar(lunarcalendar.NewSolarFromDate(parsed))
			month := fromSolar.GetMonth()
			event.LunarLeap = month < 0
			if month < 0 {
				month = -month
			}
			event.LunarMonth = month
			event.LunarDay = fromSolar.GetDay()
		}
		if event.LunarMonth < 1 || event.LunarMonth > 12 || event.LunarDay < 1 || event.LunarDay > 30 {
			return fmt.Errorf("农历日期无效")
		}
		if event.LunarYear < 0 || event.LunarYear > 9999 {
			return fmt.Errorf("农历年份无效")
		}
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
	if event.DaysOption != "hour" {
		event.DaysOption = "day"
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
	if event.Calendar == "lunar" && event.Repeat == "yearly" {
		if next, ok := nextLunarCountdown(event, today); ok {
			occurrence = next
		}
	} else if event.Repeat != "none" {
		occurrence = nextCountdownDate(original, event.Repeat, today)
	}

	item := &CountdownItem{
		CountdownEvent: *event,
		OccurrenceDate: stampOf(occurrence),
		Days:           countdownDays(today, occurrence),
	}
	if event.DaysOption == "hour" {
		duration := occurrence.Sub(now)
		if duration < 0 {
			duration = -duration
		}
		item.Hours = int(math.Ceil(duration.Hours()))
	}
	if event.HasBackground {
		item.BackgroundURL = fmt.Sprintf("/api/admin/countdowns/%d/background?v=%d", event.ID, event.ModifiedAt.Unix())
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
		if event.Calendar == "lunar" && event.LunarYear > 0 {
			occurrenceLunar := lunarcalendar.NewLunarFromSolar(lunarcalendar.NewSolarFromDate(occurrence))
			item.Age = occurrenceLunar.GetYear() - event.LunarYear
		} else {
			item.Age = occurrence.Year() - original.Year()
		}
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

func nextLunarCountdown(event *CountdownEvent, today time.Time) (time.Time, bool) {
	month := event.LunarMonth
	if month < 1 || month > 12 || event.LunarDay < 1 || event.LunarDay > 30 {
		return time.Time{}, false
	}
	for year := today.Year() - 1; year <= today.Year()+2; year++ {
		lunarYear := lunarcalendar.NewLunarYear(year)
		monthKey := month
		// A leap-month event falls back to the normal month in years without
		// that leap month, matching the usual birthday/anniversary convention.
		if event.LunarLeap && lunarYear.GetLeapMonth() == month {
			monthKey = -month
		}
		lunarMonth := lunarYear.GetMonth(monthKey)
		if lunarMonth == nil {
			continue
		}
		day := event.LunarDay
		if day > lunarMonth.GetDayCount() {
			day = lunarMonth.GetDayCount()
		}
		lunar := lunarcalendar.NewLunarFromYmd(year, monthKey, day)
		solar := lunar.GetSolar()
		candidate := time.Date(solar.GetYear(), time.Month(solar.GetMonth()), solar.GetDay(), 0, 0, 0, 0, today.Location())
		if !candidate.Before(today) {
			return candidate, true
		}
	}
	return time.Time{}, false
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

func (s *Store) SetCountdownOrder(ctx context.Context, userID int64, ids []int64) error {
	if len(ids) > 500 {
		return fmt.Errorf("一次最多排序 500 个倒数日")
	}
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for index, id := range ids {
			if err := tx.Model(&CountdownEvent{}).Where("id = ? AND user_id = ?", id, userID).
				Update("sort_order", index+1).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

func (s *Store) SaveCountdownBackground(ctx context.Context, userID, eventID int64, mime string, data []byte) error {
	var event CountdownEvent
	if err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", eventID, userID).First(&event).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return ErrNotFound
		}
		return err
	}
	if len(data) == 0 {
		return fmt.Errorf("背景图片为空")
	}
	now := time.Now()
	background := CountdownBackground{EventID: eventID, UserID: userID, Mime: mime, Data: data, UpdatedAt: now}
	if err := s.db.WithContext(ctx).Save(&background).Error; err != nil {
		return err
	}
	return s.db.WithContext(ctx).Model(&CountdownEvent{}).Where("id = ? AND user_id = ?", eventID, userID).
		Updates(map[string]any{"has_background": true, "modified_at": now}).Error
}

func (s *Store) GetCountdownBackground(ctx context.Context, userID, eventID int64) (*CountdownBackground, error) {
	var background CountdownBackground
	if err := s.db.WithContext(ctx).Where("event_id = ? AND user_id = ?", eventID, userID).First(&background).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &background, nil
}

func (s *Store) DeleteCountdownBackground(ctx context.Context, userID, eventID int64) error {
	if err := s.db.WithContext(ctx).Where("event_id = ? AND user_id = ?", eventID, userID).Delete(&CountdownBackground{}).Error; err != nil {
		return err
	}
	return s.db.WithContext(ctx).Model(&CountdownEvent{}).Where("id = ? AND user_id = ?", eventID, userID).
		Updates(map[string]any{"has_background": false, "modified_at": time.Now()}).Error
}
