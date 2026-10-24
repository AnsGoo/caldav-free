package reminders

import (
	"context"
	"log/slog"
	"strconv"
	"testing"
	"time"

	"caldav-free/internal/auth"
	"caldav-free/internal/mailer"
	"caldav-free/internal/store"
)

func TestCountdownInAppReminder(t *testing.T) {
	st, err := store.Open(t.TempDir() + "/reminders.db")
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	hash, _ := auth.HashPassword("password123")
	user, err := st.CreateUser(context.Background(), "alice", "Alice", "alice@example.com", hash, true)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	date, _ := strconv.Atoi(now.Format("20060102"))
	_, err = st.CreateCountdown(context.Background(), &store.CountdownEvent{
		UserID: user.ID, Name: "今天发布", Type: "countdown", Date: date,
		Reminders: "[0]", ReminderTime: now.Add(-time.Minute).Format("15:04"), Repeat: "none",
	})
	if err != nil {
		t.Fatal(err)
	}
	scheduler := &Scheduler{store: st, logger: slog.Default(), grace: 6 * time.Hour}
	if sent := scheduler.tickCountdowns(context.Background(), now, mailer.Config{}); sent == 0 {
		t.Fatal("countdown reminder was not delivered")
	}
	notifications, err := st.ListNotifications(context.Background(), user.ID, 10)
	if err != nil || len(notifications) == 0 {
		t.Fatalf("notifications = %+v (%v)", notifications, err)
	}
	if notifications[0].Type != "countdown" || notifications[0].URL != "/tasks/countdown" {
		t.Fatalf("unexpected countdown notification: %+v", notifications[0])
	}
}
