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

	"caldav-free/internal/mailer"
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
	baseURL  string
	interval time.Duration
	grace    time.Duration
	client   *http.Client
	mu       sync.Mutex
}

// New creates a scheduler and ensures VAPID keys exist.
func New(st *store.Store, logger *slog.Logger, baseURL string) (*Scheduler, error) {
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
		baseURL:  strings.TrimRight(baseURL, "/"),
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
	mailConfig, mailErr := mailer.Load(ctx, s.store)
	if mailErr != nil {
		s.logger.Warn("load email reminder settings", "error", mailErr)
	}
	now := time.Now()
	sent := 0
	for _, candidate := range candidates {
		task := candidate.Task
		for _, offset := range task.ReminderValues() {
			when, ok := ReminderTimeForOffset(&task, offset)
			if !ok || when.After(now) || now.Sub(when) > s.grace {
				continue
			}
			key := task.DueAt.UTC().Format(time.RFC3339) + ":" + fmt.Sprintf("%d", offset)
			delivered := false
			if s.deliverInAppTask(ctx, &task, key) {
				delivered = true
			}
			if s.deliverPush(ctx, &task, key, now) {
				delivered = true
			}
			if mailErr == nil && s.deliverEmail(ctx, &task, candidate.Email, key, mailConfig, now) {
				delivered = true
			}
			if delivered {
				sent++
			}
		}
	}
	if sent > 0 {
		s.logger.Info("sent task reminders", "count", sent)
	}
	eventSent := s.tickEvents(ctx, now, mailConfig)
	if eventSent > 0 {
		s.logger.Info("sent calendar reminders", "count", eventSent)
	}
	snoozeSent := s.tickSnoozes(ctx, now, mailConfig)
	if snoozeSent > 0 {
		s.logger.Info("sent calendar snoozes", "count", snoozeSent)
	}
	taskSnoozeSent := s.tickTaskSnoozes(ctx, now, mailConfig)
	if taskSnoozeSent > 0 {
		s.logger.Info("sent task snoozes", "count", taskSnoozeSent)
	}
	habitSent := s.tickHabits(ctx, now, mailConfig)
	if habitSent > 0 {
		s.logger.Info("sent habit reminders", "count", habitSent)
	}
	countdownSent := s.tickCountdowns(ctx, now, mailConfig)
	if countdownSent > 0 {
		s.logger.Info("sent countdown reminders", "count", countdownSent)
	}
	_ = s.store.PurgeReminderDeliveries(ctx, now.AddDate(0, 0, -30))
	_ = s.store.PurgeReminderAttempts(ctx, now.AddDate(0, 0, -30))
}

func (s *Scheduler) deliverInAppTask(ctx context.Context, task *store.Task, key string) bool {
	delivered, err := s.store.HasReminderDelivery(ctx, task.ID, key, "inapp")
	if err != nil || delivered {
		return false
	}
	body := task.Title + reminderWhenLabel(task)
	url := fmt.Sprintf("/tasks?view=list&list=%d&task=%d", task.ListID, task.ID)
	if _, err := s.store.CreateNotification(ctx, &store.Notification{
		UserID: task.UserID, Type: "task", Title: "任务提醒", Body: body, URL: url, TaskID: task.ID,
	}); err != nil {
		s.logger.Warn("task reminder notification", "task", task.ID, "error", err)
		return false
	}
	if err := s.store.RecordReminderDelivery(ctx, task.ID, key, "inapp", ""); err != nil {
		s.logger.Warn("record in-app reminder", "task", task.ID, "error", err)
	}
	return true
}

func (s *Scheduler) deliverPush(ctx context.Context, task *store.Task, key string, now time.Time) bool {
	delivered, err := s.store.HasReminderDelivery(ctx, task.ID, key, "push")
	if err != nil {
		s.logger.Warn("check push delivery", "task", task.ID, "error", err)
		return false
	}
	if delivered {
		return false
	}
	attempt, ready := s.retryReady(ctx, task.ID, key, "push", now)
	if !ready {
		return false
	}
	subscriptions, err := s.store.ListPushSubscriptions(ctx, task.UserID)
	if err != nil {
		s.logger.Warn("list push subscriptions", "task", task.ID, "error", err)
		return false
	}
	if len(subscriptions) == 0 {
		return false
	}
	payload, _ := json.Marshal(map[string]any{
		"title":  "任务提醒",
		"body":   task.Title + reminderWhenLabel(task),
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
		_ = s.store.ClearReminderAttempt(ctx, task.ID, key, "push")
		return true
	}
	if lastErr != "" {
		s.recordFailure(ctx, task.ID, key, "push", attempt, now, lastErr)
	}
	return false
}

func (s *Scheduler) deliverEmail(ctx context.Context, task *store.Task, email, key string, cfg mailer.Config, now time.Time) bool {
	if !cfg.Enabled {
		return false
	}
	email = strings.TrimSpace(email)
	if email == "" {
		return false
	}
	delivered, err := s.store.HasReminderDelivery(ctx, task.ID, key, "email")
	if err != nil {
		s.logger.Warn("check email delivery", "task", task.ID, "error", err)
		return false
	}
	if delivered {
		return false
	}
	attempt, ready := s.retryReady(ctx, task.ID, key, "email", now)
	if !ready {
		return false
	}
	subject := "任务提醒：" + task.Title
	if err := cfg.Send(ctx, email, subject, s.emailBody(task)); err != nil {
		s.logger.Warn("email reminder", "task", task.ID, "error", err)
		s.recordFailure(ctx, task.ID, key, "email", attempt, now, err.Error())
		return false
	}
	if err := s.store.RecordReminderDelivery(ctx, task.ID, key, "email", ""); err != nil {
		s.logger.Warn("record email delivery", "task", task.ID, "error", err)
	}
	_ = s.store.ClearReminderAttempt(ctx, task.ID, key, "email")
	return true
}

func (s *Scheduler) retryReady(ctx context.Context, taskID int64, key, channel string, now time.Time) (*store.ReminderAttempt, bool) {
	attempt, err := s.store.ReminderAttemptState(ctx, taskID, key, channel)
	if err != nil {
		s.logger.Warn("read reminder retry state", "task", taskID, "channel", channel, "error", err)
		return nil, false
	}
	if attempt != nil && now.Before(attempt.NextAttemptAt) {
		return attempt, false
	}
	return attempt, true
}

func (s *Scheduler) recordFailure(ctx context.Context, taskID int64, key, channel string, attempt *store.ReminderAttempt, now time.Time, failure string) {
	attempts := 1
	if attempt != nil {
		attempts = attempt.Attempts + 1
	}
	next := now.Add(retryBackoff(attempts)).UTC()
	if err := s.store.RecordReminderFailure(ctx, taskID, key, channel, attempts, next, failure); err != nil {
		s.logger.Warn("record reminder failure", "task", taskID, "channel", channel, "error", err)
	}
	s.logger.Info("reminder retry scheduled", "task", taskID, "channel", channel, "attempt", attempts, "next", next.Format(time.RFC3339))
}

func retryBackoff(attempts int) time.Duration {
	delay := time.Minute
	for index := 1; index < attempts; index++ {
		delay *= 2
		if delay >= 2*time.Hour {
			return 2 * time.Hour
		}
	}
	return delay
}

func (s *Scheduler) emailBody(task *store.Task) string {
	notes := strings.TrimSpace(task.Notes)
	if len([]rune(notes)) > 1000 {
		notes = string([]rune(notes)[:1000]) + "…"
	}
	link := s.baseURL + fmt.Sprintf("/admin/tasks?task=%d", task.ID)
	parts := []string{"任务提醒", "", task.Title, "时间：" + strings.TrimPrefix(reminderWhenLabel(task), " · ")}
	if notes != "" {
		parts = append(parts, "", notes)
	}
	parts = append(parts, "", "打开任务："+link)
	return strings.Join(parts, "\n") + "\n"
}

// ReminderTime computes the reminder instant for the task's legacy single
// reminder. Multi-reminder callers should use ReminderTimeForOffset.
func ReminderTime(task *store.Task) (time.Time, bool) {
	if task == nil {
		return time.Time{}, false
	}
	return ReminderTimeForOffset(task, task.ReminderOffset)
}

// ReminderTimeForOffset computes one absolute reminder instant.
func ReminderTimeForOffset(task *store.Task, offset int) (time.Time, bool) {
	if task == nil || task.DueAt == nil || offset < 0 {
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
	return due.Add(-time.Duration(offset) * time.Minute), true
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
