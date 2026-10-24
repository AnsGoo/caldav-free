package store

import (
	"context"
	"testing"
	"time"
)

func TestFocusPreferencesAndDashboard(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()

	pref, err := s.GetFocusPreferences(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if pref.PomodoroMinutes != 25 || !pref.SoundEnabled || pref.ShortBreakMinutes != 5 {
		t.Fatalf("unexpected defaults: %+v", pref)
	}
	pref.PomodoroMinutes = 45
	pref.ShortBreakMinutes = 8
	pref.LongBreakMinutes = 20
	pref.LongBreakInterval = 3
	pref.AutoStartBreak = true
	pref.SoundEnabled = false
	saved, err := s.SaveFocusPreferences(ctx, pref)
	if err != nil {
		t.Fatal(err)
	}
	if saved.PomodoroMinutes != 45 || saved.SoundEnabled || !saved.AutoStartBreak {
		t.Fatalf("unexpected saved preferences: %+v", saved)
	}

	inbox, err := s.EnsureInbox(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	task, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: inbox.ID, Title: "写方案"})
	if err != nil {
		t.Fatal(err)
	}
	habit, err := s.CreateHabit(ctx, &Habit{UserID: userID, Name: "阅读"})
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	first, err := s.CreateFocusSession(ctx, &FocusSession{
		UserID: userID, TaskID: task.ID, Mode: "pomodoro", PomodoroCount: 1,
		StartedAt: now.Add(-25 * time.Minute), EndedAt: now, DurationSeconds: 1500, Note: "完成任务",
	})
	if err != nil {
		t.Fatal(err)
	}
	if first.Title != "写方案" {
		t.Fatalf("task title = %q", first.Title)
	}
	second, err := s.CreateFocusSession(ctx, &FocusSession{
		UserID: userID, HabitID: habit.ID, Mode: "stopwatch",
		StartedAt: now.AddDate(0, 0, -1), EndedAt: now.AddDate(0, 0, -1).Add(45 * time.Minute), DurationSeconds: 2700,
	})
	if err != nil {
		t.Fatal(err)
	}
	if second.Title != "阅读" || second.PomodoroCount != 0 {
		t.Fatalf("unexpected stopwatch session: %+v", second)
	}

	dashboard, err := s.FocusDashboard(ctx, userID, 20)
	if err != nil {
		t.Fatal(err)
	}
	if dashboard.Stats.TodayPomodoroCount != 1 || dashboard.Stats.TotalPomodoroCount != 1 {
		t.Fatalf("unexpected pomodoro counts: %+v", dashboard.Stats)
	}
	if dashboard.Stats.TodayFocusMinutes != 25 || dashboard.Stats.TotalFocusMinutes != 70 {
		t.Fatalf("unexpected focus minutes: %+v", dashboard.Stats)
	}
	if len(dashboard.Sessions) != 2 || len(dashboard.Daily) != 7 || len(dashboard.Heatmap) == 0 || len(dashboard.Hourly) != 24 {
		t.Fatalf("unexpected dashboard shape: sessions=%d daily=%d heatmap=%d hourly=%d", len(dashboard.Sessions), len(dashboard.Daily), len(dashboard.Heatmap), len(dashboard.Hourly))
	}
	if dashboard.Preferences.PomodoroMinutes != 45 {
		t.Fatalf("dashboard preferences = %+v", dashboard.Preferences)
	}
	rangeStats, err := s.FocusStatsRange(ctx, userID, 30)
	if err != nil {
		t.Fatal(err)
	}
	if rangeStats.Days != 30 || rangeStats.SessionCount != 2 || rangeStats.TotalFocusMinutes != 70 {
		t.Fatalf("unexpected range stats: %+v", rangeStats)
	}
	if len(rangeStats.ByMode) != 2 || len(rangeStats.ByTitle) != 2 || len(rangeStats.Daily) != 30 {
		t.Fatalf("unexpected range breakdown: modes=%d titles=%d daily=%d", len(rangeStats.ByMode), len(rangeStats.ByTitle), len(rangeStats.Daily))
	}

	if err := s.DeleteFocusSession(ctx, userID, first.ID); err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteFocusSession(ctx, userID, first.ID); err != ErrNotFound {
		t.Fatalf("second delete = %v, want ErrNotFound", err)
	}
}

func TestCreateFocusSessionValidation(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	now := time.Now()
	cases := []FocusSession{
		{UserID: userID, StartedAt: now, EndedAt: now, DurationSeconds: 10},
		{UserID: userID, StartedAt: now, EndedAt: now.Add(time.Minute), DurationSeconds: -1},
		{UserID: userID, StartedAt: now, EndedAt: now.Add(time.Minute), TaskID: 1, HabitID: 1, DurationSeconds: 60},
	}
	for _, tc := range cases {
		if _, err := s.CreateFocusSession(ctx, &tc); err == nil {
			t.Fatalf("expected validation error for %+v", tc)
		}
	}
}

func TestFocusTimerSyncAndAutoFinalize(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	now := time.Now()
	view, err := s.SaveFocusTimer(ctx, userID, &FocusTimerState{
		SessionID: "timer-1", Mode: "pomodoro", Phase: "focus", Status: "running",
		StartedAt: now.Add(-10 * time.Minute), PhaseTotalSeconds: 1500, RemainingSeconds: 60, Note: "同步测试",
	})
	if err != nil {
		t.Fatal(err)
	}
	if view.Revision != 1 || view.RemainingSeconds < 58 || view.RemainingSeconds > 60 {
		t.Fatalf("unexpected timer view: %+v", view)
	}
	paused, err := s.SaveFocusTimer(ctx, userID, &FocusTimerState{
		SessionID: "timer-1", Mode: "pomodoro", Phase: "focus", Status: "paused",
		StartedAt: now.Add(-10 * time.Minute), PhaseTotalSeconds: 1500, RemainingSeconds: 30,
	})
	if err != nil {
		t.Fatal(err)
	}
	if paused.Revision != 2 || paused.RemainingSeconds != 30 || paused.Status != "paused" {
		t.Fatalf("unexpected paused timer: %+v", paused)
	}
	stopwatch, err := s.SaveFocusTimer(ctx, userID, &FocusTimerState{
		SessionID: "timer-2", Mode: "stopwatch", Phase: "focus", Status: "running",
		StartedAt: now.Add(-2 * time.Minute), PhaseTotalSeconds: 0, ElapsedSeconds: 12,
	})
	if err != nil {
		t.Fatal(err)
	}
	if stopwatch.ElapsedSeconds < 12 || stopwatch.Revision != 3 {
		t.Fatalf("unexpected stopwatch timer: %+v", stopwatch)
	}
	if err := s.ClearFocusTimer(ctx, userID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetFocusTimer(ctx, userID); err != ErrNotFound {
		t.Fatalf("cleared timer = %v, want ErrNotFound", err)
	}

	first, err := s.CreateFocusSession(ctx, &FocusSession{
		UserID: userID, ClientID: "same-client", Mode: "pomodoro", PomodoroCount: 1,
		StartedAt: now.Add(-25 * time.Minute), EndedAt: now, DurationSeconds: 1500,
	})
	if err != nil {
		t.Fatal(err)
	}
	second, err := s.CreateFocusSession(ctx, &FocusSession{
		UserID: userID, ClientID: "same-client", Mode: "pomodoro", PomodoroCount: 1,
		StartedAt: now.Add(-25 * time.Minute), EndedAt: now, DurationSeconds: 1500,
	})
	if err != nil || second.ID != first.ID {
		t.Fatalf("duplicate client id = %+v (%v), want existing %d", second, err, first.ID)
	}

	if _, err := s.SaveFocusTimer(ctx, userID, &FocusTimerState{
		SessionID: "expired", Mode: "pomodoro", Phase: "focus", Status: "running",
		StartedAt: now.Add(-25 * time.Minute), PhaseTotalSeconds: 1500, RemainingSeconds: 1,
	}); err != nil {
		t.Fatal(err)
	}
	time.Sleep(1200 * time.Millisecond)
	if _, err := s.GetFocusTimer(ctx, userID); err != ErrNotFound {
		t.Fatalf("expired timer = %v, want ErrNotFound", err)
	}
	dashboard, err := s.FocusDashboard(ctx, userID, 10)
	if err != nil {
		t.Fatal(err)
	}
	if dashboard.Stats.TotalPomodoroCount < 2 {
		t.Fatalf("expired timer was not finalized: %+v", dashboard.Stats)
	}
}
