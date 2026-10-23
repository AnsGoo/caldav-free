package reminders

import (
	"strings"
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

func TestRetryBackoff(t *testing.T) {
	cases := map[int]time.Duration{
		1: time.Minute,
		2: 2 * time.Minute,
		3: 4 * time.Minute,
		7: 64 * time.Minute,
		8: 2 * time.Hour,
	}
	for attempts, want := range cases {
		if got := retryBackoff(attempts); got != want {
			t.Fatalf("retryBackoff(%d) = %v, want %v", attempts, got, want)
		}
	}
}

func TestEmailBody(t *testing.T) {
	due := time.Date(2026, 10, 24, 15, 0, 0, 0, time.UTC)
	task := &store.Task{ID: 7, Title: "写周报", DueAt: &due, Notes: "带上数据"}
	scheduler := &Scheduler{baseURL: "https://dav.example.test"}
	body := scheduler.emailBody(task)
	for _, want := range []string{"写周报", "https://dav.example.test/admin/tasks?task=7", "带上数据"} {
		if !strings.Contains(body, want) {
			t.Fatalf("email body missing %q: %s", want, body)
		}
	}
}
