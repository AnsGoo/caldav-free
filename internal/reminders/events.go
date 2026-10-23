package reminders

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/url"
	"strings"
	"time"

	"caldav-free/internal/ical"
	"caldav-free/internal/mailer"
	"caldav-free/internal/store"
)

func (s *Scheduler) tickEvents(ctx context.Context, now time.Time, mailConfig mailer.Config) int {
	calendars, err := s.store.ListAllCalendars(ctx)
	if err != nil {
		s.logger.Warn("list calendars for reminders", "error", err)
		return 0
	}
	users, err := s.store.ListUsers(ctx)
	if err != nil {
		s.logger.Warn("list users for event reminders", "error", err)
		return 0
	}
	byID := make(map[int64]*store.User, len(users))
	for _, user := range users {
		byID[user.ID] = user
	}
	rangeStart := now.Add(-24 * time.Hour)
	rangeEnd := now.Add(8 * 24 * time.Hour)
	sent := 0
	for _, calendar := range calendars {
		if calendar.Slug == "caldav-tasks" || !calendar.SupportsComponent("VEVENT") {
			continue
		}
		objects, err := s.store.ObjectRange(ctx, calendar.ID, rangeStart, rangeEnd)
		if err != nil {
			continue
		}
		for _, object := range objects {
			if len(object.Data) == 0 {
				continue
			}
			parsed, err := ical.Load(object.Data, calendar.Timezone)
			if err != nil {
				continue
			}
			instances, err := parsed.ExpandObject(rangeStart, rangeEnd, 500)
			if err != nil {
				continue
			}
			for _, instance := range instances {
				offsets := eventReminderOffsets(instance.Component)
				if len(offsets) == 0 {
					continue
				}
				for _, offset := range offsets {
					start := instance.Start
					if instance.AllDay {
						start = time.Date(start.Year(), start.Month(), start.Day(), 9, 0, 0, 0, start.Location())
					}
					when := start.Add(-time.Duration(offset) * time.Minute)
					if when.After(now) || now.Sub(when) > s.grace {
						continue
					}
					uid := instance.Component.Value("UID")
					if uid == "" {
						uid = object.UID
					}
					key := eventReminderKey(calendar.ID, uid, instance.Start, offset)
					if s.deliverEventReminder(ctx, calendar, byID[calendar.UserID], object.Href, instance, start, key, offset, now, mailConfig) {
						sent++
					}
				}
			}
		}
	}
	_ = s.store.PurgeEventReminderDeliveries(ctx, now.AddDate(0, 0, -30))
	return sent
}

func (s *Scheduler) deliverEventReminder(ctx context.Context, calendar *store.Calendar, owner *store.User, href string, instance ical.Instance, start time.Time, key string, offset int, now time.Time, cfg mailer.Config) bool {
	if owner == nil {
		return false
	}
	title := instance.Component.Value("SUMMARY")
	if title == "" {
		title = "日程提醒"
	}
	whenLabel := start.Format("1月2日 15:04")
	if instance.AllDay {
		whenLabel = start.Format("1月2日") + " 全天"
	}
	body := fmt.Sprintf("%s · %s", title, whenLabel)
	eventURL := fmt.Sprintf("%s/admin/tasks?view=all&mode=calendar&calendar=%d&event=%s&occurrence=%s",
		s.baseURL, calendar.ID, url.QueryEscape(href), url.QueryEscape(instance.Start.Format(time.RFC3339)))
	sentAny := false
	// Web Push
	delivered, _ := s.store.HasEventReminderDelivery(ctx, calendar.ID, key, "push")
	if !delivered {
		attempt, ready := s.retryReady(ctx, 0, key, "push", now)
		if ready {
			count, err := NotifyUser(ctx, s.store, s.logger, owner.ID, PushMessage{
				Title: "日程提醒", Body: body, Tag: "event-" + key, URL: eventURL,
			})
			if count > 0 {
				_ = s.store.RecordEventReminderDelivery(ctx, calendar.ID, key, "push", "")
				_ = s.store.ClearReminderAttempt(ctx, 0, key, "push")
				sentAny = true
			} else if err != nil {
				s.recordFailure(ctx, 0, key, "push", attempt, now, err.Error())
			}
		}
	}
	// Email
	if cfg.Enabled && owner.Email != "" {
		delivered, _ := s.store.HasEventReminderDelivery(ctx, calendar.ID, key, "email")
		if !delivered {
			attempt, ready := s.retryReady(ctx, 0, key, "email", now)
			if ready {
				content := "日程提醒\n\n" + title + "\n时间：" + whenLabel + "\n打开日程：" + eventURL + "\n"
				if err := cfg.Send(ctx, owner.Email, "日程提醒："+title, content); err != nil {
					s.logger.Warn("event reminder email", "calendar", calendar.ID, "error", err)
					s.recordFailure(ctx, 0, key, "email", attempt, now, err.Error())
				} else {
					_ = s.store.RecordEventReminderDelivery(ctx, calendar.ID, key, "email", "")
					_ = s.store.ClearReminderAttempt(ctx, 0, key, "email")
					sentAny = true
				}
			}
		}
	}
	return sentAny
}

func eventReminderKey(calendarID int64, uid string, start time.Time, offset int) string {
	sum := sha256.Sum256([]byte(uid))
	return fmt.Sprintf("%d:%s:%d:%d", calendarID, hex.EncodeToString(sum[:8]), start.UTC().Unix(), offset)
}

func eventReminderOffsets(comp *ical.Component) []int {
	if comp == nil {
		return nil
	}
	seen := map[int]bool{}
	out := make([]int, 0, 2)
	for _, alarm := range comp.ChildrenNamed("VALARM") {
		raw := comp.Value("TRIGGER")
		if alarm != nil {
			raw = alarm.Value("TRIGGER")
		}
		raw = strings.TrimSpace(raw)
		negative := len(raw) > 0 && raw[0] == '-'
		raw = strings.TrimPrefix(raw, "-")
		if raw == "" || (raw[0] >= '0' && raw[0] <= '9') {
			continue
		}
		duration, err := ical.ParseDuration(raw)
		if err != nil {
			continue
		}
		if duration < 0 {
			duration = -duration
		}
		minutes := int(duration.Minutes())
		if minutes < 0 || (!negative && minutes > 0) || minutes > 10080 {
			continue
		}
		if !seen[minutes] {
			seen[minutes] = true
			out = append(out, minutes)
		}
	}
	return out
}
