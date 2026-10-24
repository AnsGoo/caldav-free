package reminders

import (
	"context"
	"fmt"
	"strings"
	"time"

	"caldav-free/internal/mailer"
	"caldav-free/internal/store"
)

// Countdowns deliver their reminders at 09:00 in the application timezone.
// The delivery key is tied to the next occurrence and the selected offset so
// a yearly anniversary reminds once per year and a one-off countdown reminds
// once per occurrence.
func (s *Scheduler) tickCountdowns(ctx context.Context, now time.Time, cfg mailer.Config) int {
	items, err := s.store.ListCountdownReminderCandidates(ctx)
	if err != nil {
		s.logger.Warn("list countdown reminders", "error", err)
		return 0
	}
	loc, err := time.LoadLocation(store.DefaultTimezone)
	if err != nil {
		loc = time.Local
	}
	localNow := now.In(loc)
	sent := 0
	for _, item := range items {
		if item.State == "past" {
			continue
		}
		raw := strings.TrimSpace(item.Reminders)
		offsets := store.CountdownReminders(raw)
		if len(offsets) == 0 {
			continue
		}
		occurrenceTime, ok := store.CountdownOccurrenceTime(item.OccurrenceDate)
		if !ok {
			continue
		}
		occurrence := time.Date(occurrenceTime.Year(), occurrenceTime.Month(), occurrenceTime.Day(), 0, 0, 0, 0, loc)
		clock, err := time.ParseInLocation("15:04", item.ReminderTime, loc)
		if err != nil {
			clock, _ = time.ParseInLocation("15:04", "09:00", loc)
		}
		user, _ := s.store.GetUser(ctx, item.UserID)
		for _, offset := range offsets {
			reminderDay := occurrence.AddDate(0, 0, -offset)
			when := time.Date(reminderDay.Year(), reminderDay.Month(), reminderDay.Day(), clock.Hour(), clock.Minute(), 0, 0, loc)
			if localNow.Before(when) || localNow.Sub(when) > s.grace {
				continue
			}
			key := fmt.Sprintf("countdown:%08d:%d", item.OccurrenceDate, offset)
			deliveryID := int64(-1_000_000_000 - item.ID)
			delivered := false
			if s.deliverCountdownInApp(ctx, item, offset, deliveryID, key) {
				delivered = true
			}
			if s.deliverCountdownPush(ctx, item, offset, user, deliveryID, key, now) {
				delivered = true
			}
			if cfg.Enabled && user != nil && strings.TrimSpace(user.Email) != "" {
				if s.deliverCountdownEmail(ctx, item, offset, user.Email, deliveryID, key, cfg, now) {
					delivered = true
				}
			}
			if delivered {
				sent++
			}
		}
	}
	return sent
}

func countdownReminderBody(item *store.CountdownItem, offset int) string {
	if offset == 0 {
		return fmt.Sprintf("今天是「%s」", item.Name)
	}
	return fmt.Sprintf("距离「%s」还有 %d 天", item.Name, offset)
}

func (s *Scheduler) deliverCountdownInApp(ctx context.Context, item *store.CountdownItem, offset int, deliveryID int64, key string) bool {
	delivered, err := s.store.HasReminderDelivery(ctx, deliveryID, key, "inapp")
	if err != nil || delivered {
		return false
	}
	if _, err := s.store.CreateNotification(ctx, &store.Notification{
		UserID: item.UserID, Type: "countdown", Title: "倒数日提醒",
		Body: countdownReminderBody(item, offset), URL: "/tasks/countdown",
	}); err != nil {
		s.logger.Warn("countdown reminder notification", "countdown", item.ID, "error", err)
		return false
	}
	_ = s.store.RecordReminderDelivery(ctx, deliveryID, key, "inapp", "")
	return true
}

func (s *Scheduler) deliverCountdownPush(ctx context.Context, item *store.CountdownItem, offset int, user *store.User, deliveryID int64, key string, now time.Time) bool {
	delivered, err := s.store.HasReminderDelivery(ctx, deliveryID, key, "push")
	if err != nil || delivered {
		return false
	}
	attempt, ready := s.retryReady(ctx, deliveryID, key, "push", now)
	if !ready {
		return false
	}
	sent, err := NotifyUser(ctx, s.store, s.logger, item.UserID, PushMessage{
		Title: "倒数日提醒", Body: countdownReminderBody(item, offset),
		Tag: fmt.Sprintf("countdown-%d", item.ID), URL: "/admin/tasks/countdown",
	})
	if sent > 0 {
		_ = s.store.RecordReminderDelivery(ctx, deliveryID, key, "push", "")
		_ = s.store.ClearReminderAttempt(ctx, deliveryID, key, "push")
		return true
	}
	if err != nil {
		s.recordFailure(ctx, deliveryID, key, "push", attempt, now, err.Error())
	}
	return false
}

func (s *Scheduler) deliverCountdownEmail(ctx context.Context, item *store.CountdownItem, offset int, email string, deliveryID int64, key string, cfg mailer.Config, now time.Time) bool {
	delivered, err := s.store.HasReminderDelivery(ctx, deliveryID, key, "email")
	if err != nil || delivered {
		return false
	}
	attempt, ready := s.retryReady(ctx, deliveryID, key, "email", now)
	if !ready {
		return false
	}
	link := strings.TrimRight(s.baseURL, "/") + "/admin/tasks/countdown"
	body := "倒数日提醒\n\n" + countdownReminderBody(item, offset) + "\n\n打开倒数纪念日：" + link + "\n"
	if err := cfg.Send(ctx, email, "倒数日提醒："+item.Name, body); err != nil {
		s.recordFailure(ctx, deliveryID, key, "email", attempt, now, err.Error())
		return false
	}
	_ = s.store.RecordReminderDelivery(ctx, deliveryID, key, "email", "")
	_ = s.store.ClearReminderAttempt(ctx, deliveryID, key, "email")
	return true
}
