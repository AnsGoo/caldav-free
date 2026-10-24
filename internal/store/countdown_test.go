package store

import (
	"context"
	"testing"
	"time"
)

func TestCountdownLifecycleAndOccurrences(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	now := time.Now()

	item, err := s.CreateCountdown(ctx, &CountdownEvent{
		UserID: userID, Name: "发布日", Type: "countdown", Date: stampOf(now.AddDate(0, 0, 10)),
		Repeat: "none", Reminders: "[3,0,3]",
	})
	if err != nil {
		t.Fatal(err)
	}
	if item.State != "future" || item.Days != 10 {
		t.Fatalf("unexpected future countdown: %+v", item)
	}
	if item.Reminders != "[0,3]" {
		t.Fatalf("reminders = %s", item.Reminders)
	}

	pinned := true
	archived := 1
	updated, err := s.UpdateCountdown(ctx, userID, item.ID, &CountdownPatch{Name: stringPtr("发布日（改）"), Pinned: &pinned, Status: &archived})
	if err != nil {
		t.Fatal(err)
	}
	if updated.Name != "发布日（改）" || !updated.Pinned || updated.Status != 1 {
		t.Fatalf("unexpected update: %+v", updated)
	}
	active, err := s.ListCountdowns(ctx, userID, false)
	if err != nil || len(active) != 0 {
		t.Fatalf("active list = %+v (%v)", active, err)
	}
	all, err := s.ListCountdowns(ctx, userID, true)
	if err != nil || len(all) != 1 {
		t.Fatalf("archived list = %+v (%v)", all, err)
	}

	yearly, err := s.CreateCountdown(ctx, &CountdownEvent{
		UserID: userID, Name: "周年", Type: "anniversary", Date: 20200101, Repeat: "yearly",
	})
	if err != nil {
		t.Fatal(err)
	}
	if yearly.State != "future" || yearly.OccurrenceDate <= stampOf(now) {
		t.Fatalf("unexpected yearly occurrence: %+v", yearly)
	}
	monthly, err := s.CreateCountdown(ctx, &CountdownEvent{
		UserID: userID, Name: "月度", Type: "countdown", Date: stampOf(now.AddDate(0, 0, -20)), Repeat: "monthly",
	})
	if err != nil {
		t.Fatal(err)
	}
	if monthly.State != "future" || monthly.Days < 0 {
		t.Fatalf("unexpected monthly occurrence: %+v", monthly)
	}
	weekly, err := s.CreateCountdown(ctx, &CountdownEvent{
		UserID: userID, Name: "周末", Type: "countdown", Date: stampOf(now.AddDate(0, 0, -2)), Repeat: "weekly",
	})
	if err != nil {
		t.Fatal(err)
	}
	if weekly.State != "future" || weekly.Days < 1 || weekly.Days > 7 {
		t.Fatalf("unexpected weekly occurrence: %+v", weekly)
	}
	birthday, err := s.CreateCountdown(ctx, &CountdownEvent{
		UserID: userID, Name: "生日", Type: "birthday", Date: 19900101, Repeat: "yearly", ShowAge: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if birthday.Age < 30 {
		t.Fatalf("birthday age = %d", birthday.Age)
	}

	past, err := s.CreateCountdown(ctx, &CountdownEvent{
		UserID: userID, Name: "已过去", Type: "countdown", Date: stampOf(now.AddDate(0, 0, -2)), Repeat: "none",
	})
	if err != nil {
		t.Fatal(err)
	}
	if past.State != "past" || past.Days != 2 {
		t.Fatalf("unexpected past countdown: %+v", past)
	}

	if err := s.DeleteCountdown(ctx, userID, item.ID); err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteCountdown(ctx, userID, item.ID); err != ErrNotFound {
		t.Fatalf("second delete = %v", err)
	}
}

func stringPtr(value string) *string { return &value }
