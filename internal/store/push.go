package store

import (
	"context"
	"fmt"
	"time"

	"gorm.io/gorm/clause"
)

// PushSubscription is one browser/device Web Push registration.
type PushSubscription struct {
	ID         int64     `gorm:"primaryKey"`
	UserID     int64     `gorm:"not null;index:idx_push_user"`
	Endpoint   string    `gorm:"size:1024;not null;uniqueIndex:idx_push_endpoint"`
	P256dh     string    `gorm:"size:255;not null"`
	Auth       string    `gorm:"size:255;not null"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime"`
}

// ReminderDelivery deduplicates server-side reminder pushes.
type ReminderDelivery struct {
	ID      int64     `gorm:"primaryKey"`
	TaskID  int64     `gorm:"not null;uniqueIndex:idx_reminder_delivery_key,priority:1"`
	Key     string    `gorm:"size:100;not null;uniqueIndex:idx_reminder_delivery_key,priority:2"`
	Channel string    `gorm:"size:16;not null;uniqueIndex:idx_reminder_delivery_key,priority:3"`
	SentAt  time.Time `gorm:"not null;autoCreateTime"`
	Error   string    `gorm:"size:500;not null;default:''"`
}

// ReminderAttempt tracks failed deliveries so the scheduler can back off
// instead of retrying a broken SMTP or push endpoint every tick.
type ReminderAttempt struct {
	ID            int64     `gorm:"primaryKey"`
	TaskID        int64     `gorm:"not null;uniqueIndex:idx_reminder_attempt_key,priority:1"`
	Key           string    `gorm:"size:100;not null;uniqueIndex:idx_reminder_attempt_key,priority:2"`
	Channel       string    `gorm:"size:16;not null;uniqueIndex:idx_reminder_attempt_key,priority:3"`
	Attempts      int       `gorm:"not null;default:1"`
	NextAttemptAt time.Time `gorm:"not null;index:idx_reminder_attempt_next"`
	LastError     string    `gorm:"size:500;not null;default:''"`
	UpdatedAt     time.Time `gorm:"not null;autoUpdateTime"`
}

// ReminderCandidate joins a task with its owner for delivery.
type ReminderCandidate struct {
	Task  Task
	Email string
}

// SavePushSubscription upserts a push subscription by endpoint.
func (s *Store) SavePushSubscription(ctx context.Context, userID int64, endpoint, p256dh, auth string) error {
	subscription := PushSubscription{
		UserID: userID, Endpoint: endpoint, P256dh: p256dh, Auth: auth,
	}
	err := s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "endpoint"}},
		DoUpdates: clause.AssignmentColumns([]string{"user_id", "p256dh", "auth", "modified_at"}),
	}).Create(&subscription).Error
	if err != nil {
		return fmt.Errorf("save push subscription: %w", err)
	}
	return nil
}

// DeletePushSubscription removes a registration.
func (s *Store) DeletePushSubscription(ctx context.Context, userID int64, endpoint string) error {
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND endpoint = ?", userID, endpoint).
		Delete(&PushSubscription{}).Error
	if err != nil {
		return fmt.Errorf("delete push subscription: %w", err)
	}
	return nil
}

// DeletePushSubscriptionEndpoint removes a registration without a user scope.
// It is used when the push service reports the endpoint is gone.
func (s *Store) DeletePushSubscriptionEndpoint(ctx context.Context, endpoint string) error {
	return s.db.WithContext(ctx).Where("endpoint = ?", endpoint).Delete(&PushSubscription{}).Error
}

// ListPushSubscriptions returns a user's registrations.
func (s *Store) ListPushSubscriptions(ctx context.Context, userID int64) ([]*PushSubscription, error) {
	var subscriptions []*PushSubscription
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).Find(&subscriptions).Error
	if err != nil {
		return nil, fmt.Errorf("list push subscriptions: %w", err)
	}
	return subscriptions, nil
}

// ListReminderCandidates returns open tasks with reminders, joined with owner email.
func (s *Store) ListReminderCandidates(ctx context.Context) ([]ReminderCandidate, error) {
	var tasks []Task
	if err := s.db.WithContext(ctx).
		Where("deleted = ? AND completed = ? AND due_at IS NOT NULL AND (reminder_offset >= 0 OR reminder_offsets <> '')", false, false).
		Find(&tasks).Error; err != nil {
		return nil, fmt.Errorf("list reminder candidates: %w", err)
	}
	if len(tasks) == 0 {
		return nil, nil
	}
	users, err := s.ListUsers(ctx)
	if err != nil {
		return nil, err
	}
	emails := make(map[int64]string, len(users))
	for _, user := range users {
		emails[user.ID] = user.Email
	}
	out := make([]ReminderCandidate, 0, len(tasks))
	for index := range tasks {
		out = append(out, ReminderCandidate{Task: tasks[index], Email: emails[tasks[index].UserID]})
	}
	return out, nil
}

// HasReminderDelivery reports whether a channel already delivered a reminder key.
func (s *Store) HasReminderDelivery(ctx context.Context, taskID int64, key, channel string) (bool, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&ReminderDelivery{}).
		Where("task_id = ? AND key = ? AND channel = ?", taskID, key, channel).
		Count(&count).Error
	if err != nil {
		return false, fmt.Errorf("check reminder delivery: %w", err)
	}
	return count > 0, nil
}

// RecordReminderDelivery records one delivery attempt.
func (s *Store) RecordReminderDelivery(ctx context.Context, taskID int64, key, channel, failure string) error {
	delivery := ReminderDelivery{TaskID: taskID, Key: key, Channel: channel, Error: failure}
	err := s.db.WithContext(ctx).Clauses(clause.OnConflict{DoNothing: true}).Create(&delivery).Error
	if err != nil {
		return fmt.Errorf("record reminder delivery: %w", err)
	}
	return nil
}

// PurgeReminderDeliveries removes old delivery records.
func (s *Store) PurgeReminderDeliveries(ctx context.Context, before time.Time) error {
	return s.db.WithContext(ctx).Where("sent_at < ?", before).Delete(&ReminderDelivery{}).Error
}

// ReminderAttemptState returns the retry state for a channel, or nil.
func (s *Store) ReminderAttemptState(ctx context.Context, taskID int64, key, channel string) (*ReminderAttempt, error) {
	var attempt ReminderAttempt
	result := s.db.WithContext(ctx).
		Where("task_id = ? AND key = ? AND channel = ?", taskID, key, channel).
		Limit(1).Find(&attempt)
	if result.Error != nil {
		return nil, fmt.Errorf("read reminder attempt: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return nil, nil
	}
	return &attempt, nil
}

// RecordReminderFailure upserts the retry state after a failed delivery.
func (s *Store) RecordReminderFailure(ctx context.Context, taskID int64, key, channel string, attempts int, next time.Time, failure string) error {
	if attempts < 1 {
		attempts = 1
	}
	next = next.UTC()
	attempt := ReminderAttempt{
		TaskID: taskID, Key: key, Channel: channel,
		Attempts: attempts, NextAttemptAt: next, LastError: truncateString(failure, 500),
	}
	err := s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns: []clause.Column{
			{Name: "task_id"}, {Name: "key"}, {Name: "channel"},
		},
		DoUpdates: clause.AssignmentColumns([]string{"attempts", "next_attempt_at", "last_error", "updated_at"}),
	}).Create(&attempt).Error
	if err != nil {
		return fmt.Errorf("record reminder failure: %w", err)
	}
	return nil
}

// ClearReminderAttempt removes retry state after a successful delivery.
func (s *Store) ClearReminderAttempt(ctx context.Context, taskID int64, key, channel string) error {
	return s.db.WithContext(ctx).
		Where("task_id = ? AND key = ? AND channel = ?", taskID, key, channel).
		Delete(&ReminderAttempt{}).Error
}

// PurgeReminderAttempts removes stale retry state.
func (s *Store) PurgeReminderAttempts(ctx context.Context, before time.Time) error {
	return s.db.WithContext(ctx).Where("updated_at < ?", before).Delete(&ReminderAttempt{}).Error
}

func truncateString(value string, limit int) string {
	if len(value) <= limit {
		return value
	}
	return value[:limit]
}
