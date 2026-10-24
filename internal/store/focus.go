package store

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	"caldav-free/internal/auth"

	"gorm.io/gorm"
)

// FocusSession is a completed pomodoro or stopwatch session. TaskID and
// HabitID are optional associations; Title keeps a readable snapshot even if
// the associated item is later renamed or deleted.
type FocusSession struct {
	ID              int64     `gorm:"primaryKey" json:"id"`
	UserID          int64     `gorm:"not null;index:idx_focus_session_user" json:"-"`
	ClientID        string    `gorm:"size:64;not null;default:''" json:"clientId"`
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

type FocusTimerState struct {
	UserID            int64      `gorm:"primaryKey" json:"-"`
	SessionID         string     `gorm:"size:64;not null;default:''" json:"sessionId"`
	Mode              string     `gorm:"size:20;not null;default:'pomodoro'" json:"mode"`
	Phase             string     `gorm:"size:20;not null;default:'focus'" json:"phase"`
	Status            string     `gorm:"size:20;not null;default:'idle'" json:"status"`
	StartedAt         time.Time  `json:"startedAt"`
	PhaseTotalSeconds int        `gorm:"not null;default:0" json:"phaseTotalSeconds"`
	RemainingSeconds  int        `gorm:"not null;default:0" json:"remainingSeconds"`
	DeadlineAt        *time.Time `json:"deadlineAt,omitempty"`
	SegmentStartedAt  *time.Time `json:"segmentStartedAt,omitempty"`
	ElapsedSeconds    int        `gorm:"not null;default:0" json:"elapsedSeconds"`
	PauseSeconds      int        `gorm:"not null;default:0" json:"pauseSeconds"`
	Note              string     `gorm:"type:text;not null;default:''" json:"note"`
	TaskID            int64      `gorm:"not null;default:0" json:"taskId"`
	HabitID           int64      `gorm:"not null;default:0" json:"habitId"`
	Title             string     `gorm:"size:200;not null;default:''" json:"title"`
	CyclePomodoros    int        `gorm:"not null;default:0" json:"cyclePomodoros"`
	Revision          int64      `gorm:"not null;default:0" json:"revision"`
	UpdatedAt         time.Time  `gorm:"not null" json:"updatedAt"`
}

type FocusTimerView struct {
	SessionID         string    `json:"sessionId"`
	Mode              string    `json:"mode"`
	Phase             string    `json:"phase"`
	Status            string    `json:"status"`
	StartedAt         time.Time `json:"startedAt"`
	PhaseTotalSeconds int       `json:"phaseTotalSeconds"`
	RemainingSeconds  int       `json:"remainingSeconds"`
	ElapsedSeconds    int       `json:"elapsedSeconds"`
	PauseSeconds      int       `json:"pauseSeconds"`
	Note              string    `json:"note"`
	TaskID            int64     `json:"taskId"`
	HabitID           int64     `json:"habitId"`
	Title             string    `json:"title"`
	CyclePomodoros    int       `json:"cyclePomodoros"`
	Revision          int64     `json:"revision"`
	UpdatedAt         time.Time `json:"updatedAt"`
	ServerNow         time.Time `json:"serverNow"`
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

type FocusModeStat struct {
	Mode    string `json:"mode"`
	Seconds int    `json:"seconds"`
	Minutes int    `json:"minutes"`
	Count   int    `json:"count"`
}

type FocusTitleStat struct {
	Title   string `json:"title"`
	Seconds int    `json:"seconds"`
	Minutes int    `json:"minutes"`
	Count   int    `json:"count"`
}

type FocusRangeStats struct {
	Days               int               `json:"days"`
	From               string            `json:"from"`
	To                 string            `json:"to"`
	TotalPomodoroCount int               `json:"totalPomodoroCount"`
	TotalFocusSeconds  int               `json:"totalFocusSeconds"`
	TotalFocusMinutes  int               `json:"totalFocusMinutes"`
	SessionCount       int               `json:"sessionCount"`
	ActiveDays         int               `json:"activeDays"`
	AverageMinutes     int               `json:"averageMinutes"`
	BestDay            FocusDailyStat    `json:"bestDay"`
	Daily              []FocusDailyStat  `json:"daily"`
	Hourly             []FocusHourlyStat `json:"hourly"`
	ByMode             []FocusModeStat   `json:"byMode"`
	ByTitle            []FocusTitleStat  `json:"byTitle"`
	Sessions           []*FocusSession   `json:"sessions"`
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
	if session.ClientID == "" {
		session.ClientID = auth.RandomToken(12)
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
		var existing FocusSession
		if s.db.WithContext(ctx).Where("user_id = ? AND client_id = ?", session.UserID, session.ClientID).First(&existing).Error == nil {
			return &existing, nil
		}
		return nil, fmt.Errorf("create focus session: %w", err)
	}
	return session, nil
}

func (s *Store) GetFocusTimer(ctx context.Context, userID int64) (*FocusTimerView, error) {
	now := time.Now()
	var state FocusTimerState
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).First(&state).Error
	if err == gorm.ErrRecordNotFound {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if state.Status == "running" && state.DeadlineAt != nil && !now.Before(*state.DeadlineAt) {
		if state.Phase == "focus" && state.Mode != "stopwatch" {
			endedAt := *state.DeadlineAt
			_, _ = s.CreateFocusSession(ctx, &FocusSession{
				UserID: userID, TaskID: state.TaskID, HabitID: state.HabitID, Title: state.Title,
				Mode: "pomodoro", StartedAt: state.StartedAt, EndedAt: endedAt,
				PauseSeconds: state.PauseSeconds, DurationSeconds: state.PhaseTotalSeconds,
				PomodoroCount: 1, Note: state.Note, ClientID: state.SessionID,
			})
		}
		_ = s.db.WithContext(ctx).Where("user_id = ?", userID).Delete(&FocusTimerState{}).Error
		return nil, ErrNotFound
	}
	if state.Status == "idle" && state.Phase == "focus" && state.RemainingSeconds <= 0 && state.ElapsedSeconds <= 0 {
		return nil, ErrNotFound
	}
	view := focusTimerView(&state, now)
	return &view, nil
}

func (s *Store) SaveFocusTimer(ctx context.Context, userID int64, input *FocusTimerState) (*FocusTimerView, error) {
	if input == nil {
		return nil, fmt.Errorf("专注计时状态不能为空")
	}
	now := time.Now()
	input.Status = strings.ToLower(strings.TrimSpace(input.Status))
	if input.Status != "running" && input.Status != "paused" && input.Status != "idle" {
		input.Status = "idle"
	}
	input.Mode = strings.ToLower(strings.TrimSpace(input.Mode))
	if input.Mode != "stopwatch" {
		input.Mode = "pomodoro"
	}
	input.Phase = strings.TrimSpace(input.Phase)
	if input.Phase != "shortBreak" && input.Phase != "longBreak" {
		input.Phase = "focus"
	}
	if input.Note = strings.TrimSpace(input.Note); len([]rune(input.Note)) > 2000 {
		input.Note = string([]rune(input.Note)[:2000])
	}
	if input.TaskID != 0 && input.HabitID != 0 {
		return nil, fmt.Errorf("专注计时只能关联一个任务或习惯")
	}
	if input.SessionID == "" {
		input.SessionID = auth.RandomToken(12)
	}
	input.UserID = userID
	input.UpdatedAt = now
	var existing FocusTimerState
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).First(&existing).Error; err == nil {
		input.Revision = existing.Revision + 1
		if input.StartedAt.IsZero() {
			input.StartedAt = existing.StartedAt
		}
	} else if err == gorm.ErrRecordNotFound {
		input.Revision = 1
	} else {
		return nil, err
	}
	input.DeadlineAt = nil
	input.SegmentStartedAt = nil
	switch input.Status {
	case "running":
		if input.Mode == "stopwatch" && input.Phase == "focus" {
			if input.ElapsedSeconds < 0 {
				input.ElapsedSeconds = 0
			}
			input.SegmentStartedAt = &now
		} else {
			if input.RemainingSeconds < 0 {
				input.RemainingSeconds = 0
			}
			deadline := now.Add(time.Duration(input.RemainingSeconds) * time.Second)
			input.DeadlineAt = &deadline
		}
	case "paused":
		input.DeadlineAt = nil
	}
	if input.StartedAt.IsZero() {
		input.StartedAt = now
	}
	if err := s.db.WithContext(ctx).Save(input).Error; err != nil {
		return nil, fmt.Errorf("save focus timer: %w", err)
	}
	view := focusTimerView(input, now)
	return &view, nil
}

func (s *Store) ClearFocusTimer(ctx context.Context, userID int64) error {
	return s.db.WithContext(ctx).Where("user_id = ?", userID).Delete(&FocusTimerState{}).Error
}

func focusTimerView(state *FocusTimerState, now time.Time) FocusTimerView {
	remaining := state.RemainingSeconds
	elapsed := state.ElapsedSeconds
	if state.Status == "running" {
		if state.Mode == "stopwatch" && state.Phase == "focus" {
			if state.SegmentStartedAt != nil {
				elapsed += int(now.Sub(*state.SegmentStartedAt).Seconds())
			}
		} else if state.DeadlineAt != nil {
			remaining = int(state.DeadlineAt.Sub(now).Seconds())
			if remaining < 0 {
				remaining = 0
			}
		}
	}
	return FocusTimerView{
		SessionID: state.SessionID, Mode: state.Mode, Phase: state.Phase, Status: state.Status,
		StartedAt: state.StartedAt, PhaseTotalSeconds: state.PhaseTotalSeconds,
		RemainingSeconds: remaining, ElapsedSeconds: elapsed, PauseSeconds: state.PauseSeconds,
		Note: state.Note, TaskID: state.TaskID, HabitID: state.HabitID, Title: state.Title,
		CyclePomodoros: state.CyclePomodoros, Revision: state.Revision, UpdatedAt: state.UpdatedAt, ServerNow: now,
	}
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

func (s *Store) FocusStatsRange(ctx context.Context, userID int64, days int) (*FocusRangeStats, error) {
	if days != 7 && days != 30 && days != 90 && days != 365 {
		days = 30
	}
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	from := today.AddDate(0, 0, -(days - 1))
	to := today.AddDate(0, 0, 1)
	var sessions []*FocusSession
	if err := s.db.WithContext(ctx).Where("user_id = ? AND started_at >= ? AND started_at < ?", userID, from, to).
		Order("started_at DESC, id DESC").Find(&sessions).Error; err != nil {
		return nil, err
	}
	byDay := make(map[string]*FocusDailyStat)
	hourly := make([]FocusHourlyStat, 24)
	for hour := range hourly {
		hourly[hour].Hour = hour
	}
	byMode := make(map[string]*FocusModeStat)
	byTitle := make(map[string]*FocusTitleStat)
	result := &FocusRangeStats{
		Days: days, From: from.Format("2006-01-02"), To: today.Format("2006-01-02"),
		Sessions: sessions,
	}
	for _, session := range sessions {
		local := session.StartedAt.In(now.Location())
		key := local.Format("2006-01-02")
		day := byDay[key]
		if day == nil {
			day = &FocusDailyStat{Date: key}
			byDay[key] = day
		}
		day.Seconds += session.DurationSeconds
		day.Minutes += session.DurationSeconds / 60
		result.TotalFocusSeconds += session.DurationSeconds
		result.TotalPomodoroCount += session.PomodoroCount
		result.SessionCount++
		hourly[local.Hour()].Seconds += session.DurationSeconds
		hourly[local.Hour()].Minutes += session.DurationSeconds / 60
		mode := byMode[session.Mode]
		if mode == nil {
			mode = &FocusModeStat{Mode: session.Mode}
			byMode[session.Mode] = mode
		}
		mode.Seconds += session.DurationSeconds
		mode.Minutes += session.DurationSeconds / 60
		mode.Count++
		title := strings.TrimSpace(session.Title)
		if title == "" || title == "专注" {
			title = "自由专注"
		}
		target := byTitle[title]
		if target == nil {
			target = &FocusTitleStat{Title: title}
			byTitle[title] = target
		}
		target.Seconds += session.DurationSeconds
		target.Minutes += session.DurationSeconds / 60
		target.Count++
	}
	result.TotalFocusMinutes = result.TotalFocusSeconds / 60
	result.Daily = make([]FocusDailyStat, 0, days)
	for day := from; !day.After(today); day = day.AddDate(0, 0, 1) {
		key := day.Format("2006-01-02")
		if row := byDay[key]; row != nil {
			result.ActiveDays++
			result.Daily = append(result.Daily, *row)
			if row.Minutes >= result.BestDay.Minutes {
				result.BestDay = *row
			}
		} else {
			result.Daily = append(result.Daily, FocusDailyStat{Date: key})
		}
	}
	if result.ActiveDays > 0 {
		result.AverageMinutes = result.TotalFocusMinutes / result.ActiveDays
	}
	result.Hourly = hourly
	for _, mode := range byMode {
		result.ByMode = append(result.ByMode, *mode)
	}
	sort.Slice(result.ByMode, func(i, j int) bool { return result.ByMode[i].Seconds > result.ByMode[j].Seconds })
	for _, target := range byTitle {
		result.ByTitle = append(result.ByTitle, *target)
	}
	sort.Slice(result.ByTitle, func(i, j int) bool { return result.ByTitle[i].Seconds > result.ByTitle[j].Seconds })
	if len(result.ByTitle) > 8 {
		result.ByTitle = result.ByTitle[:8]
	}
	return result, nil
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
