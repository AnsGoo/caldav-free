// Package reminders delivers task reminders through Web Push while the
// scheduler keeps running independently of any open browser page.
package reminders

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	webpush "github.com/SherClockHolmes/webpush-go"

	"caldav-free/internal/store"
)

const (
	settingVAPIDPublic  = "push.vapid_public"
	settingVAPIDPrivate = "push.vapid_private"
)

var vapidMu sync.Mutex

// Keys are the VAPID key pair used to sign push messages.
type Keys struct {
	Public  string
	Private string
}

// EnsureVAPID returns the configured VAPID keys, generating them once if
// missing. The keys are stored in the settings table.
func EnsureVAPID(ctx context.Context, st *store.Store) (Keys, error) {
	vapidMu.Lock()
	defer vapidMu.Unlock()
	public, _ := st.GetSetting(ctx, settingVAPIDPublic)
	private, _ := st.GetSetting(ctx, settingVAPIDPrivate)
	if public != "" && private != "" {
		return Keys{Public: public, Private: private}, nil
	}
	newPrivate, newPublic, err := webpush.GenerateVAPIDKeys()
	if err != nil {
		return Keys{}, fmt.Errorf("generate vapid keys: %w", err)
	}
	if err := st.SetSetting(ctx, settingVAPIDPublic, newPublic); err != nil {
		return Keys{}, err
	}
	if err := st.SetSetting(ctx, settingVAPIDPrivate, newPrivate); err != nil {
		return Keys{}, err
	}
	return Keys{Public: newPublic, Private: newPrivate}, nil
}

// Scheduler delivers due task reminders through Web Push.
type Scheduler struct {
	store    *store.Store
	logger   *slog.Logger
	keys     Keys
	subject  string
	interval time.Duration
	grace    time.Duration
	client   *http.Client
	mu       sync.Mutex
}

// New creates a scheduler and ensures VAPID keys exist.
func New(st *store.Store, logger *slog.Logger) (*Scheduler, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	keys, err := EnsureVAPID(ctx, st)
	if err != nil {
		return nil, err
	}
	if logger == nil {
		logger = slog.Default()
	}
	subject := strings.TrimSpace(os.Getenv("CALDAV_PUSH_SUBJECT"))
	if subject == "" {
		subject = "mailto:admin@example.com"
	}
	interval := 30 * time.Second
	if raw := strings.TrimSpace(os.Getenv("CALDAV_REMINDER_INTERVAL")); raw != "" {
		if parsed, err := time.ParseDuration(raw); err == nil && parsed >= 10*time.Second {
			interval = parsed
		}
	}
	return &Scheduler{
		store: st, logger: logger, keys: keys, subject: subject,
		interval: interval, grace: 6 * time.Hour,
		client: &http.Client{Timeout: 10 * time.Second},
	}, nil
}

// Run ticks until ctx is cancelled.
func (s *Scheduler) Run(ctx context.Context) {
	s.logger.Info("reminder scheduler started", "interval", s.interval.String())
	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()
	s.tick(ctx)
	for {
		select {
		case <-ctx.Done():
			s.logger.Info("reminder scheduler stopped")
			return
		case <-ticker.C:
			s.tick(ctx)
		}
	}
}

func (s *Scheduler) tick(ctx context.Context) {
	s.mu.Lock()
	defer s.mu.Unlock()
	candidates, err := s.store.ListReminderCandidates(ctx)
	if err != nil {
		s.logger.Warn("list reminder candidates", "error", err)
		return
	}
	now := time.Now()
	sent := 0
	for _, candidate := range candidates {
		task := candidate.Task
		when, ok := ReminderTime(&task)
		if !ok || when.After(now) || now.Sub(when) > s.grace {
			continue
		}
		key := task.DueAt.UTC().Format(time.RFC3339) + ":" + fmt.Sprintf("%d", task.ReminderOffset)
		delivered, err := s.store.HasReminderDelivery(ctx, task.ID, key, "push")
		if err != nil || delivered {
			continue
		}
		subscriptions, err := s.store.ListPushSubscriptions(ctx, task.UserID)
		if err != nil || len(subscriptions) == 0 {
			continue
		}
		payload, _ := json.Marshal(map[string]any{
			"title":  "任务提醒",
			"body":   task.Title + reminderWhenLabel(&task),
			"tag":    fmt.Sprintf("task-%d", task.ID),
			"taskId": task.ID,
			"url":    fmt.Sprintf("/admin/tasks?task=%d", task.ID),
		})
		deliveredAny := false
		var lastErr string
		for _, subscription := range subscriptions {
			response, err := webpush.SendNotificationWithContext(ctx, payload, &webpush.Subscription{
				Endpoint: subscription.Endpoint,
				Keys:     webpush.Keys{Auth: subscription.Auth, P256dh: subscription.P256dh},
			}, &webpush.Options{
				Subscriber:      s.subject,
				TTL:             86400,
				Urgency:         webpush.UrgencyNormal,
				VAPIDPublicKey:  s.keys.Public,
				VAPIDPrivateKey: s.keys.Private,
				HTTPClient:      s.client,
			})
			if err != nil {
				lastErr = err.Error()
				s.logger.Warn("push reminder", "task", task.ID, "error", err)
				continue
			}
			if response != nil {
				status := response.StatusCode
				_ = response.Body.Close()
				if status == http.StatusNotFound || status == http.StatusGone {
					_ = s.store.DeletePushSubscriptionEndpoint(ctx, subscription.Endpoint)
				}
				if status < 200 || status >= 300 {
					lastErr = fmt.Sprintf("push service returned %d", status)
					s.logger.Warn("push reminder", "task", task.ID, "status", status)
					continue
				}
			}
			deliveredAny = true
		}
		if deliveredAny {
			if err := s.store.RecordReminderDelivery(ctx, task.ID, key, "push", lastErr); err != nil {
				s.logger.Warn("record reminder delivery", "task", task.ID, "error", err)
			}
			sent++
		}
	}
	if sent > 0 {
		s.logger.Info("sent task reminders", "count", sent)
	}
	_ = s.store.PurgeReminderDeliveries(ctx, now.AddDate(0, 0, -30))
}

// ReminderTime computes the absolute reminder instant for a task.
func ReminderTime(task *store.Task) (time.Time, bool) {
	if task == nil || task.DueAt == nil || task.ReminderOffset < 0 {
		return time.Time{}, false
	}
	loc, err := time.LoadLocation(store.DefaultTimezone)
	if err != nil {
		loc = time.UTC
	}
	due := task.DueAt.In(loc)
	if task.AllDay {
		due = time.Date(due.Year(), due.Month(), due.Day(), 9, 0, 0, 0, loc)
	}
	return due.Add(-time.Duration(task.ReminderOffset) * time.Minute), true
}

func reminderWhenLabel(task *store.Task) string {
	loc, err := time.LoadLocation(store.DefaultTimezone)
	if err != nil {
		loc = time.UTC
	}
	due := task.DueAt.In(loc)
	if task.AllDay {
		return " · " + due.Format("1月2日") + " 全天"
	}
	return " · " + due.Format("1月2日 15:04")
}
