package reminders

import (
	"testing"
	"time"

	"caldav-free/internal/store"
)

func TestReminderTime(t *testing.T) {
	loc, _ := time.LoadLocation(store.DefaultTimezone)
	due := time.Date(2026, 10, 24, 15, 0, 0, 0, loc)
	task := &store.Task{DueAt: &due, ReminderOffset: 15}
	when, ok := ReminderTime(task)
	if !ok || !when.Equal(due.Add(-15*time.Minute)) {
		t.Fatalf("timed reminder = %v (%v)", when, ok)
	}
	allDay := time.Date(2026, 10, 24, 0, 0, 0, 0, loc)
	task = &store.Task{DueAt: &allDay, AllDay: true, ReminderOffset: 60}
	when, ok = ReminderTime(task)
	want := time.Date(2026, 10, 24, 8, 0, 0, 0, loc)
	if !ok || !when.Equal(want) {
		t.Fatalf("all-day reminder = %v, want %v", when, want)
	}
	if _, ok := ReminderTime(&store.Task{}); ok {
		t.Fatal("missing due/offset should not produce a reminder")
	}
}
