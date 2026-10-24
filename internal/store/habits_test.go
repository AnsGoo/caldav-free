package store

import (
	"context"
	"encoding/json"
	"math"
	"sync"
	"testing"
	"time"
)

func TestComputeHabitStatsWeeklyCapsCompletedUnits(t *testing.T) {
	loc := time.Local
	monthStart := time.Date(2026, time.February, 1, 0, 0, 0, 0, loc)
	monthEnd := time.Date(2026, time.February, 28, 0, 0, 0, 0, loc)
	habit := &Habit{
		Goal:      1,
		StartDate: 20260201,
		Frequency: `{"type":"weekly","daysPerWeek":3}`,
	}
	checkins := []*HabitCheckin{
		{Stamp: stampOf(monthStart), Value: 1, Goal: 1, Status: 2},
		{Stamp: stampOf(monthStart.AddDate(0, 0, 1)), Value: 1, Goal: 1, Status: 2},
		{Stamp: stampOf(monthStart.AddDate(0, 0, 2)), Value: 1, Goal: 1, Status: 2},
		{Stamp: stampOf(monthStart.AddDate(0, 0, 3)), Value: 1, Goal: 1, Status: 2},
		{Stamp: stampOf(monthStart.AddDate(0, 0, 7)), Value: 1, Goal: 1, Status: 2},
		{Stamp: stampOf(monthStart.AddDate(0, 0, 8)), Value: 1, Goal: 1, Status: 2},
	}
	stats := computeHabitStats(habit, checkins, monthStart, monthEnd)
	if stats.MonthCheckinDays != 6 {
		t.Fatalf("month checkin days = %d, want 6", stats.MonthCheckinDays)
	}
	assertClose(t, stats.MonthCompletionRate, 5.0/12.0*100)
}

func TestHabitScheduledOnIntervalAcrossDST(t *testing.T) {
	loc, err := time.LoadLocation("America/New_York")
	if err != nil {
		t.Skipf("timezone unavailable: %v", err)
	}
	habit := &Habit{
		StartDate: 20260307,
		Frequency: `{"type":"interval","interval":2}`,
	}
	dates := []struct {
		day  time.Time
		want bool
	}{
		{time.Date(2026, time.March, 7, 0, 0, 0, 0, loc), true},
		{time.Date(2026, time.March, 8, 0, 0, 0, 0, loc), false},
		{time.Date(2026, time.March, 9, 0, 0, 0, 0, loc), true},
	}
	for _, tc := range dates {
		if got := habitScheduledOn(habit, tc.day); got != tc.want {
			t.Fatalf("scheduled on %s = %v, want %v", tc.day.Format("2006-01-02"), got, tc.want)
		}
	}
}

func TestParseHabitFrequencyCapsValues(t *testing.T) {
	raw, _ := json.Marshal(HabitFrequency{Type: "weekly", DaysPerWeek: 12, Interval: 9999})
	freq := parseHabitFrequency(string(raw))
	if freq.DaysPerWeek != 7 {
		t.Fatalf("days per week = %d, want 7", freq.DaysPerWeek)
	}
	if freq.Interval != 3650 {
		t.Fatalf("interval = %d, want 3650", freq.Interval)
	}
}

func assertClose(t *testing.T, got, want float64) {
	t.Helper()
	if math.Abs(got-want) > 0.001 {
		t.Fatalf("got %.4f, want %.4f", got, want)
	}
}

func TestToggleHabitCheckinConcurrentSet(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	habit, err := s.CreateHabit(ctx, &Habit{
		UserID: userID, Name: "并发打卡", Goal: 3, Step: 1,
		Frequency: `{"type":"daily","weekdays":[0,1,2,3,4,5,6]}`,
	})
	if err != nil {
		t.Fatal(err)
	}
	value := 2.0
	var wg sync.WaitGroup
	errs := make(chan error, 24)
	for i := 0; i < 24; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if _, _, err := s.ToggleHabitCheckin(ctx, userID, habit.ID, 20261024, &value); err != nil {
				errs <- err
			}
		}()
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		t.Fatalf("concurrent checkin: %v", err)
	}
	var rows []HabitCheckin
	if err := s.db.WithContext(ctx).Where("user_id = ? AND habit_id = ? AND checkin_stamp = ?", userID, habit.ID, 20261024).Find(&rows).Error; err != nil {
		t.Fatal(err)
	}
	if len(rows) != 1 {
		t.Fatalf("checkin rows = %d, want 1", len(rows))
	}
	if rows[0].Value != 2 || rows[0].Status != 0 {
		t.Fatalf("unexpected checkin: %+v", rows[0])
	}
}

func TestToggleHabitCheckinConcurrentToggleStable(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	habit, err := s.CreateHabit(ctx, &Habit{
		UserID: userID, Name: "并发开关", Goal: 1, Step: 1,
		Frequency: `{"type":"daily","weekdays":[0,1,2,3,4,5,6]}`,
	})
	if err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if _, _, err := s.ToggleHabitCheckin(ctx, userID, habit.ID, 20261024, nil); err != nil {
				t.Errorf("toggle: %v", err)
			}
		}()
	}
	wg.Wait()
	var count int64
	if err := s.db.WithContext(ctx).Model(&HabitCheckin{}).
		Where("user_id = ? AND habit_id = ? AND checkin_stamp = ?", userID, habit.ID, 20261024).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatalf("toggle twice left %d rows, want 0", count)
	}
}
