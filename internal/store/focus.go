package store

import (
	"context"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

// FocusSession is a completed pomodoro or stopwatch session. TaskID and
// HabitID are optional associations; Title keeps a readable snapshot even if
// the associated item is later renamed or deleted.
type FocusSession struct {
	ID              int64     `gorm:"primaryKey" json:"id"`
	UserID          int64     `gorm:"not null;index:idx_focus_session_user" json:"-"`
	TaskID          int64     `gorm:"not null;default:0;index:idx_focus_session_task" json:"taskId"`
	HabitID         int64     `gorm:"not null;default:0;index:idx_focus_session_habit" json:"habitId"`
	Title           string    `gorm:"size:200;not null;default:''" json:"title"`
	Mode            string    `gorm:"size:20;not null;default:'pomodoro'" json:"mode"`
	Status          int       `gorm:"not null;default:1" json:"status"`
	StartedAt       time.Time `gorm:"not null;index:idx_focus_session_started" json:"startedAt"`
	EndedAt         time.Time `gorm:"not null" json:"endedAt"`
	PauseSeconds    int       `gorm:"not null;default:0" json:"pauseSeconds"`
	DurationSeconds int       `gorm:"not null;default:0" json:"durationSeconds"`
	PomodoroCount   int       `gorm:"not null;default:0" json:"pomodoroCount"`
	Note            string    `gorm:"type:text;not null;default:''" json:"note"`
	CreatedAt       time.Time `gorm:"not null;autoCreateTime" json:"createdAt"`
}

type FocusPreference struct {
	UserID            int64 `gorm:"primaryKey" json:"-"`
	PomodoroMinutes   int   `gorm:"not null;default:25" json:"pomodoroMinutes"`
	ShortBreakMinutes int   `gorm:"not null;default:5" json:"shortBreakMinutes"`
	LongBreakMinutes  int   `gorm:"not null;default:15" json:"longBreakMinutes"`
	LongBreakInterval int   `gorm:"not null;default:4" json:"longBreakInterval"`
	DailyGoal         int   `gorm:"not null;default:4" json:"dailyGoal"`
	AutoStartPomodoro bool  `gorm:"not null" json:"autoStartPomodoro"`
	AutoStartBreak    bool  `gorm:"not null" json:"autoStartBreak"`
	SoundEnabled      bool  `gorm:"not null" json:"soundEnabled"`
	TabTitleEnabled   bool  `gorm:"not null" json:"tabTitleEnabled"`
}

type FocusStats struct {
	TodayPomodoroCount int `json:"todayPomodoroCount"`
	TodayFocusMinutes  int `json:"todayFocusMinutes"`
	TotalPomodoroCount int `json:"totalPomodoroCount"`
	TotalFocusMinutes  int `json:"totalFocusMinutes"`
	TodayFocusSeconds  int `json:"todayFocusSeconds"`
	TotalFocusSeconds  int `json:"totalFocusSeconds"`
	DailyGoal          int `json:"dailyGoal"`
}

type FocusDailyStat struct {
	Date    string `json:"date"`
	Minutes int    `json:"minutes"`
	Seconds int    `json:"seconds"`
}

type FocusHeatmapDay struct {
	Date    string `json:"date"`
	Minutes int    `json:"minutes"`
	Seconds int    `json:"seconds"`
}

type FocusHourlyStat struct {
	Hour    int `json:"hour"`
	Minutes int `json:"minutes"`
	Seconds int `json:"seconds"`
}

type FocusDashboard struct {
	Preferences *FocusPreference  `json:"preferences"`
	Stats       FocusStats        `json:"stats"`
	Sessions    []*FocusSession   `json:"sessions"`
	Daily       []FocusDailyStat  `json:"daily"`
	Heatmap     []FocusHeatmapDay `json:"heatmap"`
	Hourly      []FocusHourlyStat `json:"hourly"`
}

func (s *Store) GetFocusPreferences(ctx context.Context, userID int64) (*FocusPreference, error) {
	var pref FocusPreference
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).First(&pref).Error
	if err == gorm.ErrRecordNotFound {
		return defaultFocusPreference(userID), nil
	}
	if err != nil {
		return nil, err
	}
	applyFocusPreferenceDefaults(&pref)
	return &pref, nil
}

func (s *Store) SaveFocusPreferences(ctx context.Context, pref *FocusPreference) (*FocusPreference, error) {
	if pref == nil {
		return nil, fmt.Errorf("专注设置不能为空")
	}
	applyFocusPreferenceDefaults(pref)
	if pref.PomodoroMinutes < 5 || pref.PomodoroMinutes > 180 {
		return nil, fmt.Errorf("番茄时长需在 5 到 180 分钟之间")
	}
	if pref.ShortBreakMinutes < 1 || pref.ShortBreakMinutes > 60 {
		return nil, fmt.Errorf("短休息时长需在 1 到 60 分钟之间")
	}
	if pref.LongBreakMinutes < 1 || pref.LongBreakMinutes > 60 {
		return nil, fmt.Errorf("长休息时长需在 1 到 60 分钟之间")
	}
	if pref.LongBreakInterval < 1 || pref.LongBreakInterval > 60 {
		return nil, fmt.Errorf("长休息间隔需在 1 到 60 个番茄之间")
	}
	if pref.DailyGoal < 0 || pref.DailyGoal > 100 {
		return nil, fmt.Errorf("每日目标需在 0 到 100 个番茄之间")
	}
	if err := s.db.WithContext(ctx).Save(pref).Error; err != nil {
		return nil, fmt.Errorf("save focus preferences: %w", err)
	}
	return pref, nil
}

func defaultFocusPreference(userID int64) *FocusPreference {
	return &FocusPreference{
		UserID: userID, PomodoroMinutes: 25, ShortBreakMinutes: 5, LongBreakMinutes: 15,
		LongBreakInterval: 4, DailyGoal: 4, SoundEnabled: true,
	}
}

func applyFocusPreferenceDefaults(pref *FocusPreference) {
	if pref.PomodoroMinutes <= 0 {
		pref.PomodoroMinutes = 25
	}
	if pref.ShortBreakMinutes <= 0 {
		pref.ShortBreakMinutes = 5
	}
	if pref.LongBreakMinutes <= 0 {
		pref.LongBreakMinutes = 15
	}
	if pref.LongBreakInterval <= 0 {
		pref.LongBreakInterval = 4
	}
	if pref.DailyGoal <= 0 {
		pref.DailyGoal = 4
	}
}

func (s *Store) CreateFocusSession(ctx context.Context, session *FocusSession) (*FocusSession, error) {
	if session == nil {
		return nil, fmt.Errorf("专注记录不能为空")
	}
	if session.StartedAt.IsZero() || session.EndedAt.IsZero() {
		return nil, fmt.Errorf("开始和结束时间不能为空")
	}
	if !session.EndedAt.After(session.StartedAt) {
		return nil, fmt.Errorf("结束时间必须晚于开始时间")
	}
	rawDuration := int(session.EndedAt.Sub(session.StartedAt).Seconds())
	if session.DurationSeconds < 0 {
		return nil, fmt.Errorf("专注时长无效")
	}
	if session.DurationSeconds == 0 {
		session.DurationSeconds = rawDuration - session.PauseSeconds
	}
	if session.PauseSeconds < 0 || session.PauseSeconds > rawDuration {
		return nil, fmt.Errorf("暂停时长无效")
	}
	if session.DurationSeconds <= 0 || session.DurationSeconds > 24*60*60 {
		return nil, fmt.Errorf("专注时长需在 1 秒到 24 小时之间")
	}
	if session.Mode != "stopwatch" {
		session.Mode = "pomodoro"
	}
	if session.Mode == "stopwatch" {
		session.PomodoroCount = 0
	}
	if session.PomodoroCount < 0 || session.PomodoroCount > 100 {
		return nil, fmt.Errorf("番茄数量无效")
	}
	if session.TaskID != 0 && session.HabitID != 0 {
		return nil, fmt.Errorf("专注记录只能关联一个任务或习惯")
	}
	session.Status = 1
	session.Note = strings.TrimSpace(session.Note)
	if len([]rune(session.Note)) > 2000 {
		session.Note = string([]rune(session.Note)[:2000])
	}
	if session.TaskID != 0 {
		task, err := s.GetTask(ctx, session.UserID, session.TaskID)
		if err != nil {
			return nil, fmt.Errorf("关联任务不存在")
		}
		session.Title = strings.TrimSpace(task.Title)
	} else if session.HabitID != 0 {
		habit, err := s.GetHabit(ctx, session.UserID, session.HabitID)
		if err != nil {
			return nil, fmt.Errorf("关联习惯不存在")
		}
		session.Title = strings.TrimSpace(habit.Name)
	}
	if session.Title == "" {
		session.Title = "专注"
	}
	if err := s.db.WithContext(ctx).Create(session).Error; err != nil {
		return nil, fmt.Errorf("create focus session: %w", err)
	}
	return session, nil
}

func (s *Store) DeleteFocusSession(ctx context.Context, userID, id int64) error {
	result := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).Delete(&FocusSession{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) FocusDashboard(ctx context.Context, userID int64, limit int) (*FocusDashboard, error) {
	if limit <= 0 {
		limit = 100
	}
	pref, err := s.GetFocusPreferences(ctx, userID)
	if err != nil {
		return nil, err
	}
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	yearStart := time.Date(now.Year(), time.January, 1, 0, 0, 0, 0, now.Location())
	var total FocusStats
	if err := s.db.WithContext(ctx).Model(&FocusSession{}).Where("user_id = ?", userID).
		Select("COALESCE(SUM(pomodoro_count), 0) AS total_pomodoro_count, COALESCE(SUM(duration_seconds), 0) AS total_focus_seconds").
		Scan(&total).Error; err != nil {
		return nil, err
	}
	var today FocusStats
	if err := s.db.WithContext(ctx).Model(&FocusSession{}).
		Where("user_id = ? AND started_at >= ?", userID, todayStart).
		Select("COALESCE(SUM(pomodoro_count), 0) AS today_pomodoro_count, COALESCE(SUM(duration_seconds), 0) AS today_focus_seconds").
		Scan(&today).Error; err != nil {
		return nil, err
	}
	stats := FocusStats{
		TodayPomodoroCount: today.TodayPomodoroCount, TodayFocusSeconds: today.TodayFocusSeconds,
		TotalPomodoroCount: total.TotalPomodoroCount, TotalFocusSeconds: total.TotalFocusSeconds,
		TodayFocusMinutes: today.TodayFocusSeconds / 60, TotalFocusMinutes: total.TotalFocusSeconds / 60,
		DailyGoal: pref.DailyGoal,
	}
	var sessions []*FocusSession
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("started_at DESC, id DESC").Limit(limit).Find(&sessions).Error; err != nil {
		return nil, err
	}
	var yearSessions []*FocusSession
	if err := s.db.WithContext(ctx).Where("user_id = ? AND started_at >= ?", userID, yearStart).
		Select("started_at, duration_seconds").Find(&yearSessions).Error; err != nil {
		return nil, err
	}
	byDay := make(map[string]*FocusDailyStat)
	hourly := make([]FocusHourlyStat, 24)
	for hour := range hourly {
		hourly[hour].Hour = hour
	}
	for _, session := range yearSessions {
		local := session.StartedAt.In(now.Location())
		key := local.Format("2006-01-02")
		row := byDay[key]
		if row == nil {
			row = &FocusDailyStat{Date: key}
			byDay[key] = row
		}
		row.Seconds += session.DurationSeconds
		row.Minutes += session.DurationSeconds / 60
		hourly[local.Hour()].Seconds += session.DurationSeconds
		hourly[local.Hour()].Minutes += session.DurationSeconds / 60
	}
	daily := make([]FocusDailyStat, 0, 7)
	for offset := 6; offset >= 0; offset-- {
		day := now.AddDate(0, 0, -offset)
		key := day.Format("2006-01-02")
		if row := byDay[key]; row != nil {
			daily = append(daily, *row)
		} else {
			daily = append(daily, FocusDailyStat{Date: key})
		}
	}
	heatmap := make([]FocusHeatmapDay, 0, 366)
	for day := yearStart; !day.After(now); day = day.AddDate(0, 0, 1) {
		key := day.Format("2006-01-02")
		row := FocusHeatmapDay{Date: key}
		if value := byDay[key]; value != nil {
			row.Minutes = value.Minutes
			row.Seconds = value.Seconds
		}
		heatmap = append(heatmap, row)
	}
	return &FocusDashboard{
		Preferences: pref, Stats: stats, Sessions: sessions, Daily: daily, Heatmap: heatmap, Hourly: hourly,
	}, nil
}
