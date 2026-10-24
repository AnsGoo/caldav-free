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
