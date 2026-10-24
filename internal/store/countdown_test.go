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
		Repeat: "none", Reminders: "[3,0,3]", ReminderTime: "08:30",
	})
	if err != nil {
		t.Fatal(err)
	}
	if item.State != "future" || item.Days != 10 {
		t.Fatalf("unexpected future countdown: %+v", item)
	}
	if item.Reminders != "[0,3]" || item.ReminderTime != "08:30" {
		t.Fatalf("reminders = %s at %s", item.Reminders, item.ReminderTime)
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
	lunar, err := s.CreateCountdown(ctx, &CountdownEvent{
		UserID: userID, Name: "中秋", Type: "festival", Date: stampOf(now), Calendar: "lunar",
		LunarMonth: 8, LunarDay: 15, Repeat: "yearly",
	})
	if err != nil {
		t.Fatal(err)
	}
	if lunar.Calendar != "lunar" || lunar.LunarMonth != 8 || lunar.LunarDay != 15 || lunar.State == "past" {
		t.Fatalf("unexpected lunar countdown: %+v", lunar)
	}
	weekend, err := s.CreateCountdown(ctx, &CountdownEvent{
		UserID: userID, Name: "周末", Type: "festival", Date: stampOf(now), Repeat: "weekend",
	})
	if err != nil {
		t.Fatal(err)
	}
	if weekend.State == "past" || weekend.Days > 6 {
		t.Fatalf("unexpected weekend occurrence: %+v", weekend)
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
	lunarBirthday, err := s.CreateCountdown(ctx, &CountdownEvent{
		UserID: userID, Name: "农历生日", Type: "birthday", Date: stampOf(now), Calendar: "lunar",
		LunarMonth: 8, LunarDay: 15, LunarYear: 1990, Repeat: "yearly", ShowAge: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if lunarBirthday.Age < 30 {
		t.Fatalf("lunar birthday age = %d", lunarBirthday.Age)
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

	activeItems, err := s.ListCountdowns(ctx, userID, false)
	if err != nil || len(activeItems) < 2 {
		t.Fatalf("active items = %d (%v)", len(activeItems), err)
	}
	ids := make([]int64, 0, len(activeItems))
	for index := len(activeItems) - 1; index >= 0; index-- {
		ids = append(ids, activeItems[index].ID)
	}
	if err := s.SetCountdownOrder(ctx, userID, ids); err != nil {
		t.Fatal(err)
	}
	reordered, err := s.ListCountdowns(ctx, userID, false)
	if err != nil || len(reordered) < 2 || reordered[0].ID != ids[0] {
		t.Fatalf("reordered countdowns = %+v (%v)", reordered, err)
	}

	backgroundData := []byte{0x89, 0x50, 0x4e, 0x47}
	if err := s.SaveCountdownBackground(ctx, userID, lunar.ID, "image/png", backgroundData); err != nil {
		t.Fatal(err)
	}
	background, err := s.GetCountdownBackground(ctx, userID, lunar.ID)
	if err != nil || string(background.Data) != string(backgroundData) {
		t.Fatalf("background = %+v (%v)", background, err)
	}
	withBackground, err := s.ListCountdowns(ctx, userID, false)
	if err != nil {
		t.Fatal(err)
	}
	foundBackgroundURL := false
	for _, row := range withBackground {
		if row.ID == lunar.ID && row.BackgroundURL != "" {
			foundBackgroundURL = true
		}
	}
	if !foundBackgroundURL {
		t.Fatal("background url was not exposed")
	}
	if err := s.DeleteCountdownBackground(ctx, userID, lunar.ID); err != nil {
		t.Fatal(err)
	}

	if err := s.DeleteCountdown(ctx, userID, item.ID); err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteCountdown(ctx, userID, item.ID); err != ErrNotFound {
		t.Fatalf("second delete = %v", err)
	}
}

func stringPtr(value string) *string { return &value }
