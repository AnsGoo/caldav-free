package store

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"
)

const habitDayLayout = "20060102"

// Habit is a recurring check-in item shown in the habit workspace.
type Habit struct {
	ID              int64      `gorm:"primaryKey" json:"id"`
	UserID          int64      `gorm:"not null;index:idx_habit_user" json:"-"`
	Name            string     `gorm:"size:200;not null" json:"name"`
	Icon            string     `gorm:"size:100;not null;default:''" json:"icon"`
	Color           string     `gorm:"size:20;not null;default:'#97E38B'" json:"color"`
	SectionID       int64      `gorm:"not null;default:0" json:"sectionId"`
	SortOrder       int64      `gorm:"not null;default:0" json:"sortOrder"`
	Status          int        `gorm:"not null;default:0" json:"status"`
	Goal            float64    `gorm:"not null;default:1" json:"goal"`
	Step            float64    `gorm:"not null;default:1" json:"step"`
	Unit            string     `gorm:"size:32;not null;default:'Count'" json:"unit"`
	Frequency       string     `gorm:"type:text;not null;default:'{}'" json:"frequency"`
	Reminders       string     `gorm:"type:text;not null;default:'[]'" json:"reminders"`
	RecordEnable    bool       `gorm:"not null;default:false" json:"recordEnable"`
	StartDate       int        `gorm:"not null;default:0" json:"startDate"`
	TargetDays      int        `gorm:"not null;default:0" json:"targetDays"`
	CompletedCycles int        `gorm:"not null;default:0" json:"completedCycles"`
	ExDates         string     `gorm:"type:text;not null;default:'[]'" json:"exDates"`
	Style           string     `gorm:"size:20;not null;default:'check'" json:"style"`
	ArchivedAt      *time.Time `json:"archivedAt,omitempty"`
	CreatedAt       time.Time  `gorm:"not null;autoCreateTime" json:"createdAt"`
	ModifiedAt      time.Time  `gorm:"not null;autoUpdateTime" json:"modifiedAt"`

	TotalCheckIns int  `gorm:"-" json:"totalCheckIns"`
	CurrentStreak int  `gorm:"-" json:"currentStreak"`
	MaxStreak     int  `gorm:"-" json:"maxStreak"`
	DueToday      bool `gorm:"-" json:"dueToday"`
	DoneToday     bool `gorm:"-" json:"doneToday"`
}

type HabitSection struct {
	ID         int64     `gorm:"primaryKey" json:"id"`
	UserID     int64     `gorm:"not null;index:idx_habit_section_user" json:"-"`
	Name       string    `gorm:"size:100;not null" json:"name"`
	SortOrder  int64     `gorm:"not null;default:0" json:"sortOrder"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime" json:"createdAt"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime" json:"modifiedAt"`
}

type HabitCheckin struct {
	ID          int64      `gorm:"primaryKey" json:"id"`
	UserID      int64      `gorm:"not null;index:idx_habit_checkin_user" json:"-"`
	HabitID     int64      `gorm:"not null;uniqueIndex:idx_habit_checkin_day" json:"habitId"`
	Stamp       int        `gorm:"column:checkin_stamp;not null;uniqueIndex:idx_habit_checkin_day" json:"checkinStamp"`
	Value       float64    `gorm:"not null;default:0" json:"value"`
	Goal        float64    `gorm:"not null;default:0" json:"goal"`
	Status      int        `gorm:"not null;default:0" json:"status"` // 0 pending, 1 undone, 2 done
	CheckinTime *time.Time `json:"checkinTime,omitempty"`
	OpTime      time.Time  `gorm:"not null;autoCreateTime" json:"opTime"`
	CreatedAt   time.Time  `gorm:"not null;autoCreateTime" json:"createdAt"`
	ModifiedAt  time.Time  `gorm:"not null;autoUpdateTime" json:"modifiedAt"`
}

type HabitRecord struct {
	ID         int64     `gorm:"primaryKey" json:"id"`
	UserID     int64     `gorm:"not null;index:idx_habit_record_user" json:"-"`
	HabitID    int64     `gorm:"not null;index:idx_habit_record_habit" json:"habitId"`
	Stamp      int       `gorm:"not null" json:"stamp"`
	Content    string    `gorm:"type:text;not null" json:"content"`
	Emoji      string    `gorm:"size:20;not null;default:''" json:"emoji"`
	OpTime     time.Time `gorm:"not null;autoCreateTime" json:"opTime"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime" json:"createdAt"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime" json:"modifiedAt"`
}

type HabitFocusSession struct {
	ID          int64     `gorm:"primaryKey" json:"id"`
	UserID      int64     `gorm:"not null;index:idx_habit_focus_user" json:"-"`
	HabitID     int64     `gorm:"not null;index:idx_habit_focus_habit" json:"habitId"`
	Minutes     int       `gorm:"not null;default:0" json:"minutes"`
	StartedAt   time.Time `gorm:"not null" json:"startedAt"`
	CompletedAt time.Time `gorm:"not null" json:"completedAt"`
	CreatedAt   time.Time `gorm:"not null;autoCreateTime" json:"createdAt"`
}

type HabitPreference struct {
	UserID           int64  `gorm:"primaryKey" json:"-"`
	ShowInToday      bool   `gorm:"not null;default:true" json:"showInToday"`
	ShowInCalendar   bool   `gorm:"not null;default:true" json:"showInCalendar"`
	GroupByCompleted bool   `gorm:"not null;default:false" json:"groupByCompleted"`
	DisplayType      string `gorm:"size:16;not null;default:'list'" json:"displayType"`
	SortType         string `gorm:"size:32;not null;default:'custom'" json:"sortType"`
	DefaultSectionID int64  `gorm:"not null;default:0" json:"defaultSectionId"`
	Timezone         string `gorm:"size:64;not null;default:'Asia/Shanghai'" json:"timezone"`
}

type HabitFrequency struct {
	Type        string `json:"type"`
	Weekdays    []int  `json:"weekdays,omitempty"`
	DaysPerWeek int    `json:"daysPerWeek,omitempty"`
	Interval    int    `json:"interval,omitempty"`
}

type HabitDailyStat struct {
	Date  string  `json:"date"`
	Value float64 `json:"value"`
	Goal  float64 `json:"goal"`
}

type HabitStats struct {
	FocusMinutes         int              `json:"focusMinutes"`
	MonthFocusMinutes    int              `json:"monthFocusMinutes"`
	FocusCount           int              `json:"focusCount"`
	TargetDays           int              `json:"targetDays"`
	TargetProgress       int              `json:"targetProgress"`
	CompletedCycles      int              `json:"completedCycles"`
	MonthCheckinDays     int              `json:"monthCheckinDays"`
	TotalCheckinDays     int              `json:"totalCheckinDays"`
	MonthCompletionRate  float64          `json:"monthCompletionRate"`
	CurrentStreak        int              `json:"currentStreak"`
	MonthCompletionCount float64          `json:"monthCompletionCount"`
	TotalCompletionCount float64          `json:"totalCompletionCount"`
	Daily                []HabitDailyStat `json:"daily"`
}

type HabitCalendarEntry struct {
	HabitID int64   `json:"habitId"`
	Name    string  `json:"name"`
	Icon    string  `json:"icon"`
	Color   string  `json:"color"`
	Date    string  `json:"date"`
	Stamp   int     `json:"stamp"`
	Value   float64 `json:"value"`
	Goal    float64 `json:"goal"`
	Done    bool    `json:"done"`
}

type HabitDetail struct {
	Habit         *Habit               `json:"habit"`
	Checkins      []*HabitCheckin      `json:"checkins"`
	Records       []*HabitRecord       `json:"records"`
	FocusSessions []*HabitFocusSession `json:"focusSessions"`
	Stats         HabitStats           `json:"stats"`
}

func (s *Store) ListHabits(ctx context.Context, userID int64, includeArchived bool) ([]*Habit, error) {
	var habits []*Habit
	query := s.db.WithContext(ctx).Where("user_id = ?", userID)
	if !includeArchived {
		query = query.Where("status = ?", 0)
	}
	if err := query.Order("sort_order ASC, id ASC").Find(&habits).Error; err != nil {
		return nil, fmt.Errorf("list habits: %w", err)
	}
	if len(habits) == 0 {
		return habits, nil
	}
	var checkins []*HabitCheckin
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).Find(&checkins).Error; err != nil {
		return nil, fmt.Errorf("list habit checkins: %w", err)
	}
	byHabit := make(map[int64][]*HabitCheckin)
	for _, checkin := range checkins {
		byHabit[checkin.HabitID] = append(byHabit[checkin.HabitID], checkin)
	}
	today := time.Now()
	todayStamp := stampOf(today)
	for _, habit := range habits {
		habit.TotalCheckIns, habit.CurrentStreak, habit.MaxStreak = habitSummary(habit, byHabit[habit.ID])
		var todayCheckin *HabitCheckin
		for _, checkin := range byHabit[habit.ID] {
			if checkin.Stamp == todayStamp {
				todayCheckin = checkin
				break
			}
		}
		habit.DoneToday = habitDone(todayCheckin)
		habit.DueToday = habit.Status == 0 && HabitDueToday(habit, byHabit[habit.ID], today)
	}
	return habits, nil
}

func (s *Store) GetHabit(ctx context.Context, userID, id int64) (*Habit, error) {
	var habit Habit
	if err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&habit).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &habit, nil
}

func (s *Store) CreateHabit(ctx context.Context, habit *Habit) (*Habit, error) {
	habit.Name = strings.TrimSpace(habit.Name)
	if habit.Name == "" {
		return nil, fmt.Errorf("习惯名称不能为空")
	}
	if habit.Goal <= 0 {
		habit.Goal = 1
	}
	if habit.Step <= 0 {
		habit.Step = 1
	}
	if habit.Unit == "" {
		habit.Unit = "Count"
	}
	if habit.Color == "" {
		habit.Color = "#97E38B"
	}
	if habit.Frequency == "" {
		habit.Frequency = `{"type":"daily","weekdays":[0,1,2,3,4,5,6]}`
	}
	if habit.Reminders == "" {
		habit.Reminders = "[]"
	}
	if habit.ExDates == "" {
		habit.ExDates = "[]"
	}
	if habit.Style == "" {
		habit.Style = "check"
	}
	if habit.StartDate == 0 {
		habit.StartDate = habitTodayStamp()
	}
	var minOrder int64
	_ = s.db.WithContext(ctx).Model(&Habit{}).Where("user_id = ?", habit.UserID).
		Select("COALESCE(MIN(sort_order), 0)").Scan(&minOrder).Error
	habit.SortOrder = minOrder - 1
	if err := s.db.WithContext(ctx).Create(habit).Error; err != nil {
		return nil, fmt.Errorf("create habit: %w", err)
	}
	return habit, nil
}

func (s *Store) UpdateHabit(ctx context.Context, userID, id int64, patch *Habit) (*Habit, error) {
	existing, err := s.GetHabit(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	if patch.Name != "" {
		existing.Name = strings.TrimSpace(patch.Name)
	}
	if existing.Name == "" {
		return nil, fmt.Errorf("习惯名称不能为空")
	}
	if patch.Icon != "" {
		existing.Icon = patch.Icon
	}
	if patch.Color != "" {
		existing.Color = patch.Color
	}
	existing.SectionID = patch.SectionID
	if patch.Goal > 0 {
		existing.Goal = patch.Goal
	}
	if patch.Step > 0 {
		existing.Step = patch.Step
	}
	if patch.Unit != "" {
		existing.Unit = patch.Unit
	}
	if patch.Frequency != "" {
		existing.Frequency = patch.Frequency
	}
	if patch.Reminders != "" {
		existing.Reminders = patch.Reminders
	}
	existing.RecordEnable = patch.RecordEnable
	if patch.StartDate > 0 {
		existing.StartDate = patch.StartDate
	}
	if patch.TargetDays >= 0 {
		existing.TargetDays = patch.TargetDays
	}
	if patch.ExDates != "" {
		existing.ExDates = patch.ExDates
	}
	if patch.Style != "" {
		existing.Style = patch.Style
	}
	if patch.Status == 0 || patch.Status == 1 {
		existing.Status = patch.Status
		if patch.Status == 1 {
			now := time.Now()
			existing.ArchivedAt = &now
		} else {
			existing.ArchivedAt = nil
		}
	}
	if patch.SortOrder != 0 {
		existing.SortOrder = patch.SortOrder
	}
	if err := s.db.WithContext(ctx).Save(existing).Error; err != nil {
		return nil, fmt.Errorf("update habit: %w", err)
	}
	return existing, nil
}

func (s *Store) DeleteHabit(ctx context.Context, userID, id int64) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("user_id = ? AND id = ?", userID, id).Delete(&Habit{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ? AND habit_id = ?", userID, id).Delete(&HabitCheckin{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ? AND habit_id = ?", userID, id).Delete(&HabitRecord{}).Error; err != nil {
			return err
		}
		return nil
	})
}

func (s *Store) ToggleHabitCheckin(ctx context.Context, userID, habitID int64, stamp int, value *float64) (*HabitCheckin, *Habit, error) {
	habit, err := s.GetHabit(ctx, userID, habitID)
	if err != nil {
		return nil, nil, err
	}
	if stamp == 0 {
		stamp = habitTodayStamp()
	}
	var existing HabitCheckin
	found := s.db.WithContext(ctx).Where("user_id = ? AND habit_id = ? AND checkin_stamp = ?", userID, habitID, stamp).
		First(&existing).Error == nil
	if value == nil {
		if found && (existing.Status == 2 || existing.Value >= existing.Goal) {
			if err := s.db.WithContext(ctx).Delete(&existing).Error; err != nil {
				return nil, nil, err
			}
			return nil, habit, nil
		}
		next := habit.Step
		if found {
			next = existing.Value + habit.Step
		}
		if next >= habit.Goal {
			next = habit.Goal
		}
		value = &next
	}
	if *value <= 0 {
		if found {
			if err := s.db.WithContext(ctx).Delete(&existing).Error; err != nil {
				return nil, nil, err
			}
		}
		return nil, habit, nil
	}
	now := time.Now()
	checkin := &HabitCheckin{
		UserID: userID, HabitID: habitID, Stamp: stamp, Value: *value, Goal: habit.Goal,
		Status: 0, CheckinTime: &now, OpTime: now,
	}
	if *value >= habit.Goal {
		checkin.Status = 2
	}
	if found {
		checkin.ID = existing.ID
		checkin.CreatedAt = existing.CreatedAt
		if err := s.db.WithContext(ctx).Save(checkin).Error; err != nil {
			return nil, nil, err
		}
	} else if err := s.db.WithContext(ctx).Create(checkin).Error; err != nil {
		return nil, nil, err
	}
	return checkin, habit, nil
}

func (s *Store) ListHabitCheckins(ctx context.Context, userID int64, habitIDs []int64, afterStamp int) (map[int64][]*HabitCheckin, error) {
	out := make(map[int64][]*HabitCheckin, len(habitIDs))
	query := s.db.WithContext(ctx).Where("user_id = ?", userID)
	if len(habitIDs) > 0 {
		query = query.Where("habit_id IN ?", habitIDs)
	}
	if afterStamp > 0 {
		query = query.Where("checkin_stamp >= ?", afterStamp)
	}
	var rows []*HabitCheckin
	if err := query.Order("checkin_stamp ASC").Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("list habit checkins: %w", err)
	}
	for _, row := range rows {
		out[row.HabitID] = append(out[row.HabitID], row)
	}
	return out, nil
}

func (s *Store) ListHabitSections(ctx context.Context, userID int64) ([]*HabitSection, error) {
	var sections []*HabitSection
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).Order("sort_order ASC, id ASC").Find(&sections).Error; err != nil {
		return nil, fmt.Errorf("list habit sections: %w", err)
	}
	return sections, nil
}

func (s *Store) SetHabitOrder(ctx context.Context, userID int64, ids []int64) error {
	if len(ids) > 500 {
		return fmt.Errorf("一次最多排序 500 个习惯")
	}
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for index, id := range ids {
			if err := tx.Model(&Habit{}).Where("id = ? AND user_id = ?", id, userID).
				Update("sort_order", index+1).Error; err != nil {
				return fmt.Errorf("set habit order: %w", err)
			}
		}
		return nil
	})
}

func (s *Store) CreateHabitSection(ctx context.Context, userID int64, name string) (*HabitSection, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("分组名称不能为空")
	}
	var maxOrder int64
	_ = s.db.WithContext(ctx).Model(&HabitSection{}).Where("user_id = ?", userID).
		Select("COALESCE(MAX(sort_order), 0)").Scan(&maxOrder).Error
	section := &HabitSection{UserID: userID, Name: name, SortOrder: maxOrder + 1}
	if err := s.db.WithContext(ctx).Create(section).Error; err != nil {
		return nil, fmt.Errorf("create habit section: %w", err)
	}
	return section, nil
}

func (s *Store) UpdateHabitSection(ctx context.Context, userID, id int64, name string, sortOrder int64) (*HabitSection, error) {
	updates := map[string]any{}
	if strings.TrimSpace(name) != "" {
		updates["name"] = strings.TrimSpace(name)
	}
	if sortOrder != 0 {
		updates["sort_order"] = sortOrder
	}
	if len(updates) > 0 {
		if err := s.db.WithContext(ctx).Model(&HabitSection{}).Where("id = ? AND user_id = ?", id, userID).Updates(updates).Error; err != nil {
			return nil, err
		}
	}
	var section HabitSection
	if err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&section).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &section, nil
}

func (s *Store) DeleteHabitSection(ctx context.Context, userID, id int64) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&Habit{}).Where("user_id = ? AND section_id = ?", userID, id).Update("section_id", 0).Error; err != nil {
			return err
		}
		return tx.Where("id = ? AND user_id = ?", id, userID).Delete(&HabitSection{}).Error
	})
}

func (s *Store) GetHabitPreference(ctx context.Context, userID int64) (*HabitPreference, error) {
	var pref HabitPreference
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).First(&pref).Error
	if err == gorm.ErrRecordNotFound {
		return &HabitPreference{UserID: userID, ShowInToday: true, ShowInCalendar: true, DisplayType: "list", SortType: "custom", Timezone: DefaultTimezone}, nil
	}
	if err != nil {
		return nil, err
	}
	return &pref, nil
}

func (s *Store) SaveHabitPreference(ctx context.Context, pref *HabitPreference) (*HabitPreference, error) {
	if pref.DisplayType == "" {
		pref.DisplayType = "list"
	}
	if pref.SortType == "" {
		pref.SortType = "custom"
	}
	if pref.Timezone == "" {
		pref.Timezone = DefaultTimezone
	}
	if err := s.db.WithContext(ctx).Save(pref).Error; err != nil {
		return nil, fmt.Errorf("save habit preference: %w", err)
	}
	return pref, nil
}

func (s *Store) HabitCalendar(ctx context.Context, userID int64, from, to time.Time) ([]HabitCalendarEntry, error) {
	preference, err := s.GetHabitPreference(ctx, userID)
	if err != nil {
		return nil, err
	}
	if !preference.ShowInCalendar {
		return []HabitCalendarEntry{}, nil
	}
	habits, err := s.ListHabits(ctx, userID, false)
	if err != nil {
		return nil, err
	}
	if len(habits) == 0 {
		return []HabitCalendarEntry{}, nil
	}
	fromStamp, toStamp := stampOf(from), stampOf(to)
	ids := make([]int64, 0, len(habits))
	for _, habit := range habits {
		ids = append(ids, habit.ID)
	}
	checkins, err := s.ListHabitCheckins(ctx, userID, ids, fromStamp)
	if err != nil {
		return nil, err
	}
	habitByID := make(map[int64]*Habit, len(habits))
	for _, habit := range habits {
		habitByID[habit.ID] = habit
	}
	entries := make([]HabitCalendarEntry, 0)
	for _, habit := range habits {
		rows := checkins[habit.ID]
		for _, checkin := range rows {
			if checkin.Stamp < fromStamp || checkin.Stamp > toStamp {
				continue
			}
			entries = append(entries, HabitCalendarEntry{
				HabitID: habit.ID,
				Name:    habit.Name,
				Icon:    habit.Icon,
				Color:   habit.Color,
				Date:    habitDateString(checkin.Stamp),
				Stamp:   checkin.Stamp,
				Value:   checkin.Value,
				Goal:    checkin.Goal,
				Done:    habitDone(checkin),
			})
		}
		today := time.Now()
		todayStamp := stampOf(today)
		if todayStamp >= fromStamp && todayStamp <= toStamp {
			found := false
			for _, checkin := range rows {
				if checkin.Stamp == todayStamp {
					found = true
					break
				}
			}
			if !found && HabitDueToday(habit, rows, today) {
				entries = append(entries, HabitCalendarEntry{
					HabitID: habit.ID, Name: habit.Name, Icon: habit.Icon, Color: habit.Color,
					Date: habitDateString(todayStamp), Stamp: todayStamp, Goal: habit.Goal,
				})
			}
		}
	}
	sort.SliceStable(entries, func(i, j int) bool {
		if entries[i].Stamp != entries[j].Stamp {
			return entries[i].Stamp < entries[j].Stamp
		}
		return habitByID[entries[i].HabitID].SortOrder < habitByID[entries[j].HabitID].SortOrder
	})
	return entries, nil
}

func habitDateString(stamp int) string {
	return fmt.Sprintf("%04d-%02d-%02d", stamp/10000, stamp/100%100, stamp%100)
}

func (s *Store) HabitDetail(ctx context.Context, userID, habitID int64, month string) (*HabitDetail, error) {
	habit, err := s.GetHabit(ctx, userID, habitID)
	if err != nil {
		return nil, err
	}
	var checkins []*HabitCheckin
	if err := s.db.WithContext(ctx).Where("user_id = ? AND habit_id = ?", userID, habitID).
		Order("checkin_stamp ASC").Find(&checkins).Error; err != nil {
		return nil, err
	}
	monthStart, monthEnd := habitMonthRange(month)
	var records []*HabitRecord
	if err := s.db.WithContext(ctx).Where("user_id = ? AND habit_id = ? AND stamp >= ? AND stamp <= ?", userID, habitID, stampOf(monthStart), stampOf(monthEnd)).
		Order("stamp ASC, id ASC").Find(&records).Error; err != nil {
		return nil, err
	}
	var focusSessions []*HabitFocusSession
	if err := s.db.WithContext(ctx).Where("user_id = ? AND habit_id = ?", userID, habitID).
		Order("completed_at DESC, id DESC").Find(&focusSessions).Error; err != nil {
		return nil, err
	}
	stats := computeHabitStats(habit, checkins, monthStart, monthEnd)
	for _, session := range focusSessions {
		stats.FocusMinutes += session.Minutes
		stats.FocusCount++
		if session.CompletedAt.In(monthStart.Location()).Month() == monthStart.Month() && session.CompletedAt.In(monthStart.Location()).Year() == monthStart.Year() {
			stats.MonthFocusMinutes += session.Minutes
		}
	}
	if len(focusSessions) > 30 {
		focusSessions = focusSessions[:30]
	}
	return &HabitDetail{Habit: habit, Checkins: checkins, Records: records, FocusSessions: focusSessions, Stats: stats}, nil
}

func (s *Store) CreateHabitFocusSession(ctx context.Context, session *HabitFocusSession) (*HabitFocusSession, error) {
	if session.Minutes <= 0 || session.Minutes > 600 {
		return nil, fmt.Errorf("专注时长无效")
	}
	if session.StartedAt.IsZero() {
		session.StartedAt = time.Now()
	}
	if session.CompletedAt.IsZero() {
		session.CompletedAt = time.Now()
	}
	if err := s.db.WithContext(ctx).Create(session).Error; err != nil {
		return nil, fmt.Errorf("create habit focus session: %w", err)
	}
	return session, nil
}

func (s *Store) ListHabitRecords(ctx context.Context, userID, habitID int64, month string) ([]*HabitRecord, error) {
	monthStart, monthEnd := habitMonthRange(month)
	var records []*HabitRecord
	if err := s.db.WithContext(ctx).Where("user_id = ? AND habit_id = ? AND stamp >= ? AND stamp <= ?", userID, habitID, stampOf(monthStart), stampOf(monthEnd)).
		Order("stamp ASC, id ASC").Find(&records).Error; err != nil {
		return nil, err
	}
	return records, nil
}

func (s *Store) CreateHabitRecord(ctx context.Context, record *HabitRecord) (*HabitRecord, error) {
	if strings.TrimSpace(record.Content) == "" {
		return nil, fmt.Errorf("日志内容不能为空")
	}
	if record.Stamp == 0 {
		record.Stamp = habitTodayStamp()
	}
	record.OpTime = time.Now()
	if err := s.db.WithContext(ctx).Create(record).Error; err != nil {
		return nil, fmt.Errorf("create habit record: %w", err)
	}
	return record, nil
}

func (s *Store) UpdateHabitRecord(ctx context.Context, userID, habitID, id int64, content, emoji string) (*HabitRecord, error) {
	updates := map[string]any{"op_time": time.Now()}
	if strings.TrimSpace(content) != "" {
		updates["content"] = strings.TrimSpace(content)
	}
	if emoji != "" {
		updates["emoji"] = emoji
	}
	if err := s.db.WithContext(ctx).Model(&HabitRecord{}).Where("id = ? AND habit_id = ? AND user_id = ?", id, habitID, userID).
		Updates(updates).Error; err != nil {
		return nil, err
	}
	var record HabitRecord
	if err := s.db.WithContext(ctx).Where("id = ? AND habit_id = ? AND user_id = ?", id, habitID, userID).First(&record).Error; err != nil {
		return nil, ErrNotFound
	}
	return &record, nil
}

func (s *Store) DeleteHabitRecord(ctx context.Context, userID, habitID, id int64) error {
	res := s.db.WithContext(ctx).Where("id = ? AND habit_id = ? AND user_id = ?", id, habitID, userID).Delete(&HabitRecord{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

func habitMonthRange(month string) (time.Time, time.Time) {
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	if parsed, err := time.ParseInLocation("2006-01", month, now.Location()); err == nil {
		start = parsed
	}
	return start, start.AddDate(0, 1, -1)
}

func stampOf(t time.Time) int {
	value, _ := strconv.Atoi(t.Format(habitDayLayout))
	return value
}

func habitTodayStamp() int {
	return stampOf(time.Now())
}

func parseHabitFrequency(raw string) HabitFrequency {
	freq := HabitFrequency{Type: "daily"}
	_ = json.Unmarshal([]byte(raw), &freq)
	if freq.Type == "" {
		freq.Type = "daily"
	}
	if freq.Type == "daily" && len(freq.Weekdays) == 0 {
		freq.Weekdays = []int{0, 1, 2, 3, 4, 5, 6}
	}
	if freq.Interval <= 0 {
		freq.Interval = 1
	}
	if freq.DaysPerWeek <= 0 {
		freq.DaysPerWeek = 1
	}
	return freq
}

func parseHabitExDates(raw string) map[int]bool {
	var values []int
	_ = json.Unmarshal([]byte(raw), &values)
	out := make(map[int]bool, len(values))
	for _, value := range values {
		out[value] = true
	}
	return out
}

func habitStartDate(habit *Habit) time.Time {
	if habit.StartDate > 0 {
		if parsed, err := time.ParseInLocation(habitDayLayout, fmt.Sprintf("%08d", habit.StartDate), time.Local); err == nil {
			return parsed
		}
	}
	return time.Now()
}

func habitScheduledOn(habit *Habit, date time.Time) bool {
	freq := parseHabitFrequency(habit.Frequency)
	start := habitStartDate(habit)
	day := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	if day.Before(time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, date.Location())) {
		return false
	}
	if parseHabitExDates(habit.ExDates)[stampOf(day)] {
		return false
	}
	switch freq.Type {
	case "interval":
		days := int(day.Sub(time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, date.Location())).Hours() / 24)
		return days%freq.Interval == 0
	case "weekly":
		return true
	default:
		for _, weekday := range freq.Weekdays {
			if int(day.Weekday()) == weekday {
				return true
			}
		}
		return false
	}
}

func habitDone(checkin *HabitCheckin) bool {
	return checkin != nil && (checkin.Status == 2 || checkin.Value >= checkin.Goal && checkin.Goal > 0)
}

func HabitCheckinDone(checkin *HabitCheckin) bool {
	return habitDone(checkin)
}

func (s *Store) ListHabitsWithReminders(ctx context.Context) ([]*Habit, error) {
	var habits []*Habit
	if err := s.db.WithContext(ctx).Where("status = 0 AND reminders NOT IN ('', '[]')").
		Order("id ASC").Find(&habits).Error; err != nil {
		return nil, fmt.Errorf("list habits with reminders: %w", err)
	}
	return habits, nil
}

func habitSummary(habit *Habit, checkins []*HabitCheckin) (total, current, max int) {
	byStamp := make(map[int]*HabitCheckin, len(checkins))
	for _, checkin := range checkins {
		byStamp[checkin.Stamp] = checkin
		if habitDone(checkin) {
			total++
		}
	}
	current = habitCurrentStreak(habit, byStamp)
	return total, current, current
}

func HabitDueToday(habit *Habit, checkins []*HabitCheckin, today time.Time) bool {
	freq := parseHabitFrequency(habit.Frequency)
	start := habitStartDate(habit)
	day := time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, today.Location())
	if day.Before(time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, today.Location())) {
		return false
	}
	if parseHabitExDates(habit.ExDates)[stampOf(day)] {
		return false
	}
	if freq.Type != "weekly" {
		return habitScheduledOn(habit, day)
	}
	weekStart := startOfHabitWeek(day)
	done := 0
	for offset := 0; offset < 7; offset++ {
		stamp := stampOf(weekStart.AddDate(0, 0, offset))
		for _, checkin := range checkins {
			if checkin.Stamp == stamp && habitDone(checkin) {
				done++
				break
			}
		}
	}
	return done < freq.DaysPerWeek
}

func habitCurrentStreak(habit *Habit, byStamp map[int]*HabitCheckin) int {
	freq := parseHabitFrequency(habit.Frequency)
	today := time.Now()
	streak := 0
	if freq.Type == "weekly" {
		weekStart := startOfHabitWeek(today)
		for offset := 0; offset < 260; offset++ {
			start := weekStart.AddDate(0, 0, -offset*7)
			done := 0
			for day := 0; day < 7; day++ {
				if habitDone(byStamp[stampOf(start.AddDate(0, 0, day))]) {
					done++
				}
			}
			if done >= freq.DaysPerWeek {
				streak++
			} else if offset == 0 {
				continue
			} else {
				break
			}
		}
		return streak
	}
	for offset := 0; offset < 3650; offset++ {
		day := today.AddDate(0, 0, -offset)
		if !habitScheduledOn(habit, day) {
			continue
		}
		if habitDone(byStamp[stampOf(day)]) {
			streak++
		} else if offset == 0 {
			continue
		} else {
			break
		}
	}
	return streak
}

func startOfHabitWeek(day time.Time) time.Time {
	weekday := int(day.Weekday())
	return time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, day.Location()).AddDate(0, 0, -weekday)
}

func computeHabitStats(habit *Habit, checkins []*HabitCheckin, monthStart, monthEnd time.Time) HabitStats {
	byStamp := make(map[int]*HabitCheckin, len(checkins))
	stats := HabitStats{Daily: make([]HabitDailyStat, 0, 31), TargetDays: habit.TargetDays}
	for _, checkin := range checkins {
		byStamp[checkin.Stamp] = checkin
		if habitDone(checkin) {
			stats.TotalCheckinDays++
			value := checkin.Value
			if value <= 0 {
				value = 1
			}
			stats.TotalCompletionCount += value
		}
	}
	stats.CurrentStreak = habitCurrentStreak(habit, byStamp)
	stats.MonthCompletionCount = 0
	stats.MonthCheckinDays = 0

	freq := parseHabitFrequency(habit.Frequency)
	var scheduled int
	for day := monthStart; !day.After(monthEnd); day = day.AddDate(0, 0, 1) {
		stamp := stampOf(day)
		checkin := byStamp[stamp]
		value := 0.0
		if checkin != nil {
			value = checkin.Value
			if habitDone(checkin) {
				stats.MonthCheckinDays++
				stats.MonthCompletionCount += checkin.Value
			}
		}
		stats.Daily = append(stats.Daily, HabitDailyStat{Date: day.Format("2006-01-02"), Value: value, Goal: habit.Goal})
		if freq.Type == "weekly" {
			if day.Weekday() == time.Monday {
				scheduled += freq.DaysPerWeek
			}
		} else if habitScheduledOn(habit, day) {
			scheduled++
		}
	}
	if freq.Type == "weekly" {
		scheduled = 0
		for day := monthStart; !day.After(monthEnd); day = day.AddDate(0, 0, 1) {
			if day.Weekday() == time.Monday {
				scheduled += freq.DaysPerWeek
			}
		}
	}
	if stats.TargetDays > 0 {
		stats.CompletedCycles = stats.TotalCheckinDays / stats.TargetDays
		stats.TargetProgress = stats.TotalCheckinDays % stats.TargetDays
	}
	if scheduled > 0 {
		stats.MonthCompletionRate = float64(stats.MonthCheckinDays) / float64(scheduled) * 100
		if stats.MonthCompletionRate > 100 {
			stats.MonthCompletionRate = 100
		}
	}
	return stats
}

func (s *Store) ExportHabitsCSV(ctx context.Context, userID int64) (string, error) {
	habits, err := s.ListHabits(ctx, userID, true)
	if err != nil {
		return "", err
	}
	var checkins []*HabitCheckin
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).Order("habit_id ASC, checkin_stamp ASC").Find(&checkins).Error; err != nil {
		return "", err
	}
	byHabit := make(map[int64][]*HabitCheckin)
	for _, checkin := range checkins {
		byHabit[checkin.HabitID] = append(byHabit[checkin.HabitID], checkin)
	}
	var b strings.Builder
	b.WriteString("habit,date,value,goal,status\n")
	for _, habit := range habits {
		for _, checkin := range byHabit[habit.ID] {
			b.WriteString(fmt.Sprintf("%q,%08d,%.2f,%.2f,%d\n", habit.Name, checkin.Stamp, checkin.Value, checkin.Goal, checkin.Status))
		}
	}
	return b.String(), nil
}

func SortHabitsBySection(habits []*Habit, sections []*HabitSection) []*Habit {
	order := make(map[int64]int64, len(sections))
	for index, section := range sections {
		order[section.ID] = int64(index)
	}
	out := append([]*Habit(nil), habits...)
	sort.SliceStable(out, func(i, j int) bool {
		left := out[i]
		right := out[j]
		leftOrder := order[left.SectionID]
		rightOrder := order[right.SectionID]
		if leftOrder != rightOrder {
			return leftOrder < rightOrder
		}
		return left.SortOrder < right.SortOrder
	})
	return out
}

type HabitBackupHabit struct {
	Habit         *Habit               `json:"habit"`
	Checkins      []*HabitCheckin      `json:"checkins"`
	Records       []*HabitRecord       `json:"records"`
	FocusSessions []*HabitFocusSession `json:"focusSessions"`
}

type HabitBackup struct {
	Version    int                `json:"version"`
	ExportedAt time.Time          `json:"exportedAt"`
	Sections   []*HabitSection    `json:"sections"`
	Habits     []HabitBackupHabit `json:"habits"`
}

func (s *Store) ExportHabitsBackup(ctx context.Context, userID int64) (*HabitBackup, error) {
	habits, err := s.ListHabits(ctx, userID, true)
	if err != nil {
		return nil, err
	}
	sections, err := s.ListHabitSections(ctx, userID)
	if err != nil {
		return nil, err
	}
	backup := &HabitBackup{Version: 1, ExportedAt: time.Now(), Sections: sections, Habits: make([]HabitBackupHabit, 0, len(habits))}
	for _, habit := range habits {
		var checkins []*HabitCheckin
		if err := s.db.WithContext(ctx).Where("user_id = ? AND habit_id = ?", userID, habit.ID).Order("checkin_stamp ASC").Find(&checkins).Error; err != nil {
			return nil, err
		}
		var records []*HabitRecord
		if err := s.db.WithContext(ctx).Where("user_id = ? AND habit_id = ?", userID, habit.ID).Order("stamp ASC, id ASC").Find(&records).Error; err != nil {
			return nil, err
		}
		var focusSessions []*HabitFocusSession
		if err := s.db.WithContext(ctx).Where("user_id = ? AND habit_id = ?", userID, habit.ID).Order("completed_at ASC").Find(&focusSessions).Error; err != nil {
			return nil, err
		}
		backup.Habits = append(backup.Habits, HabitBackupHabit{Habit: habit, Checkins: checkins, Records: records, FocusSessions: focusSessions})
	}
	return backup, nil
}

func (s *Store) ImportHabitsBackup(ctx context.Context, userID int64, backup *HabitBackup) (int, int, int, error) {
	if len(backup.Habits) > 200 {
		return 0, 0, 0, fmt.Errorf("一次最多导入 200 个习惯")
	}
	sectionMap := make(map[int64]int64)
	for _, section := range backup.Sections {
		if strings.TrimSpace(section.Name) == "" {
			continue
		}
		created, err := s.CreateHabitSection(ctx, userID, section.Name)
		if err != nil {
			continue
		}
		sectionMap[section.ID] = created.ID
	}
	importedHabits, importedCheckins, importedRecords := 0, 0, 0
	for _, entry := range backup.Habits {
		if entry.Habit == nil || strings.TrimSpace(entry.Habit.Name) == "" {
			continue
		}
		habit := *entry.Habit
		habit.ID = 0
		habit.UserID = userID
		habit.SectionID = sectionMap[habit.SectionID]
		habit.TotalCheckIns = 0
		habit.CurrentStreak = 0
		habit.MaxStreak = 0
		created, err := s.CreateHabit(ctx, &habit)
		if err != nil {
			continue
		}
		importedHabits++
		for _, checkin := range entry.Checkins {
			if checkin == nil || checkin.Stamp == 0 {
				continue
			}
			row := *checkin
			row.ID = 0
			row.UserID = userID
			row.HabitID = created.ID
			if err := s.db.WithContext(ctx).Create(&row).Error; err == nil {
				importedCheckins++
			}
		}
		for _, record := range entry.Records {
			if record == nil || strings.TrimSpace(record.Content) == "" {
				continue
			}
			row := *record
			row.ID = 0
			row.UserID = userID
			row.HabitID = created.ID
			if err := s.db.WithContext(ctx).Create(&row).Error; err == nil {
				importedRecords++
			}
		}
		for _, session := range entry.FocusSessions {
			if session == nil || session.Minutes <= 0 {
				continue
			}
			row := *session
			row.ID = 0
			row.UserID = userID
			row.HabitID = created.ID
			_ = s.db.WithContext(ctx).Create(&row).Error
		}
	}
	return importedHabits, importedCheckins, importedRecords, nil
}
