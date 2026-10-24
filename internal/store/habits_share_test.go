package store

import (
	"context"
	"errors"
	"testing"
	"time"

	"caldav-free/internal/auth"
)

func TestHabitSharePublicViewAndRevoke(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	hash, err := auth.HashPassword("password123")
	if err != nil {
		t.Fatal(err)
	}
	user, err := s.CreateUser(ctx, "alice", "Alice", "", hash, true)
	if err != nil {
		t.Fatal(err)
	}
	section, err := s.CreateHabitSection(ctx, user.ID, "阅读")
	if err != nil {
		t.Fatal(err)
	}
	habit, err := s.CreateHabit(ctx, &Habit{
		UserID: user.ID, Name: "晨间阅读", Icon: "📚", SectionID: section.ID,
		StartDate: stampOf(time.Now()), Goal: 1, Step: 1,
	})
	if err != nil {
		t.Fatal(err)
	}
	value := 1.0
	if _, _, err := s.ToggleHabitCheckin(ctx, user.ID, habit.ID, stampOf(time.Now()), &value); err != nil {
		t.Fatal(err)
	}
	if _, err := s.CreateHabitFocusSession(ctx, &HabitFocusSession{UserID: user.ID, HabitID: habit.ID, Minutes: 25, CompletedAt: time.Now()}); err != nil {
		t.Fatal(err)
	}

	share, err := s.GetOrCreateHabitShare(ctx, user.ID, habit.ID)
	if err != nil {
		t.Fatal(err)
	}
	if share.Token == "" {
		t.Fatal("share token is empty")
	}
	again, err := s.GetOrCreateHabitShare(ctx, user.ID, habit.ID)
	if err != nil || again.Token != share.Token {
		t.Fatalf("share token is not stable: %v %+v", err, again)
	}

	public, err := s.HabitPublicShare(ctx, share.Token)
	if err != nil {
		t.Fatal(err)
	}
	if public.Name != "晨间阅读" || public.Stats.TotalCheckinDays != 1 || len(public.Days) != 30 {
		t.Fatalf("unexpected public share: %+v", public)
	}
	if !public.Days[29].Done {
		t.Fatalf("today should be done: %+v", public.Days[29])
	}

	backup, err := s.ExportHabitBackup(ctx, user.ID, habit.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(backup.Habits) != 1 || len(backup.Sections) != 1 || len(backup.Habits[0].Checkins) != 1 || len(backup.Habits[0].FocusSessions) != 1 {
		t.Fatalf("unexpected single habit backup: %+v", backup)
	}

	if err := s.RevokeHabitShare(ctx, user.ID, habit.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.HabitPublicShare(ctx, share.Token); !errors.Is(err, ErrNotFound) {
		t.Fatalf("revoked share = %v, want ErrNotFound", err)
	}
	renewed, err := s.GetOrCreateHabitShare(ctx, user.ID, habit.ID)
	if err != nil || renewed.Token == share.Token {
		t.Fatalf("renewed share token = %+v (%v)", renewed, err)
	}
	if err := s.DeleteHabit(ctx, user.ID, habit.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.HabitPublicShare(ctx, renewed.Token); !errors.Is(err, ErrNotFound) {
		t.Fatalf("deleted habit share = %v, want ErrNotFound", err)
	}
}
