package reminders

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"caldav-free/internal/mailer"
	"caldav-free/internal/store"
)

func (s *Scheduler) tickHabits(ctx context.Context, now time.Time, cfg mailer.Config) int {
	habits, err := s.store.ListHabitsWithReminders(ctx)
	if err != nil {
		s.logger.Warn("list habit reminders", "error", err)
		return 0
	}
	if len(habits) == 0 {
		return 0
	}
	loc, err := time.LoadLocation(store.DefaultTimezone)
	if err != nil {
		loc = time.Local
	}
	sent := 0
	for _, habit := range habits {
		checkins, err := s.store.ListHabitCheckins(ctx, habit.UserID, []int64{habit.ID}, 0)
		if err != nil {
			continue
		}
		rows := checkins[habit.ID]
		today := now.In(loc).Format("20060102")
		done := false
		for _, checkin := range rows {
			if fmt.Sprintf("%08d", checkin.Stamp) == today && store.HabitCheckinDone(checkin) {
				done = true
				break
			}
		}
		if done || !store.HabitDueToday(habit, rows, now.In(loc)) {
			continue
		}
		var times []string
		if err := json.Unmarshal([]byte(habit.Reminders), &times); err != nil {
			continue
		}
		user, _ := s.store.GetUser(ctx, habit.UserID)
		for _, raw := range times {
			raw = strings.TrimSpace(raw)
			parsed, err := time.ParseInLocation("15:04", raw, loc)
			if err != nil {
				continue
			}
			when := time.Date(now.In(loc).Year(), now.In(loc).Month(), now.In(loc).Day(), parsed.Hour(), parsed.Minute(), 0, 0, loc)
			if now.Before(when) || now.Sub(when) > s.grace {
				continue
			}
			key := fmt.Sprintf("habit:%s:%02d%02d", today, parsed.Hour(), parsed.Minute())
			deliveryID := -habit.ID
			delivered := false
			if s.deliverHabitInApp(ctx, habit, deliveryID, key) {
				delivered = true
			}
			if s.deliverHabitPush(ctx, habit, user, deliveryID, key, now) {
				delivered = true
			}
			if cfg.Enabled && user != nil && strings.TrimSpace(user.Email) != "" {
				if s.deliverHabitEmail(ctx, habit, user.Email, deliveryID, key, cfg, now) {
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

func (s *Scheduler) deliverHabitInApp(ctx context.Context, habit *store.Habit, deliveryID int64, key string) bool {
	delivered, err := s.store.HasReminderDelivery(ctx, deliveryID, key, "inapp")
	if err != nil || delivered {
		return false
	}
	if _, err := s.store.CreateNotification(ctx, &store.Notification{
		UserID: habit.UserID,
		Type:   "habit",
		Title:  "习惯提醒",
		Body:   habit.Name + " 今天还没有打卡",
		URL:    fmt.Sprintf("/tasks/habit/%d", habit.ID),
	}); err != nil {
		s.logger.Warn("habit reminder notification", "habit", habit.ID, "error", err)
		return false
	}
	_ = s.store.RecordReminderDelivery(ctx, deliveryID, key, "inapp", "")
	return true
}

func (s *Scheduler) deliverHabitPush(ctx context.Context, habit *store.Habit, user *store.User, deliveryID int64, key string, now time.Time) bool {
	delivered, err := s.store.HasReminderDelivery(ctx, deliveryID, key, "push")
	if err != nil || delivered {
		return false
	}
	attempt, ready := s.retryReady(ctx, deliveryID, key, "push", now)
	if !ready {
		return false
	}
	sent, err := NotifyUser(ctx, s.store, s.logger, habit.UserID, PushMessage{
		Title: "习惯提醒",
		Body:  habit.Name + " 今天还没有打卡",
		Tag:   fmt.Sprintf("habit-%d", habit.ID),
		URL:   fmt.Sprintf("/admin/tasks/habit/%d", habit.ID),
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

func (s *Scheduler) deliverHabitEmail(ctx context.Context, habit *store.Habit, email string, deliveryID int64, key string, cfg mailer.Config, now time.Time) bool {
	delivered, err := s.store.HasReminderDelivery(ctx, deliveryID, key, "email")
	if err != nil || delivered {
		return false
	}
	attempt, ready := s.retryReady(ctx, deliveryID, key, "email", now)
	if !ready {
		return false
	}
	link := fmt.Sprintf("%s/admin/tasks/habit/%d", strings.TrimRight(s.baseURL, "/"), habit.ID)
	body := "习惯提醒\n\n" + habit.Name + " 今天还没有打卡\n\n打开习惯：" + link + "\n"
	if err := cfg.Send(ctx, email, "习惯提醒："+habit.Name, body); err != nil {
		s.recordFailure(ctx, deliveryID, key, "email", attempt, now, err.Error())
		return false
	}
	_ = s.store.RecordReminderDelivery(ctx, deliveryID, key, "email", "")
	_ = s.store.ClearReminderAttempt(ctx, deliveryID, key, "email")
	return true
}
