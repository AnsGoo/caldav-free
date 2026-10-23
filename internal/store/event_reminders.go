package store

import (
	"context"
	"fmt"
	"time"
)

// EventReminderDelivery deduplicates server-side calendar reminders.
type EventReminderDelivery struct {
	ID         int64     `gorm:"primaryKey"`
	CalendarID int64     `gorm:"not null;uniqueIndex:idx_event_reminder_delivery,priority:1"`
	Key        string    `gorm:"size:160;not null;uniqueIndex:idx_event_reminder_delivery,priority:2"`
	Channel    string    `gorm:"size:16;not null;uniqueIndex:idx_event_reminder_delivery,priority:3"`
	SentAt     time.Time `gorm:"not null;autoCreateTime"`
	Error      string    `gorm:"size:500;not null;default:''"`
}

// ListAllCalendars returns every calendar for the reminder scheduler.
func (s *Store) ListAllCalendars(ctx context.Context) ([]*Calendar, error) {
	var calendars []*Calendar
	if err := s.db.WithContext(ctx).Order("id ASC").Find(&calendars).Error; err != nil {
		return nil, fmt.Errorf("list all calendars: %w", err)
	}
	return calendars, nil
}

func (s *Store) HasEventReminderDelivery(ctx context.Context, calendarID int64, key, channel string) (bool, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&EventReminderDelivery{}).
		Where("calendar_id = ? AND key = ? AND channel = ?", calendarID, key, channel).
		Count(&count).Error
	return count > 0, err
}

func (s *Store) RecordEventReminderDelivery(ctx context.Context, calendarID int64, key, channel, failure string) error {
	delivery := EventReminderDelivery{CalendarID: calendarID, Key: key, Channel: channel, Error: failure}
	return s.db.WithContext(ctx).Create(&delivery).Error
}

func (s *Store) PurgeEventReminderDeliveries(ctx context.Context, before time.Time) error {
	return s.db.WithContext(ctx).Where("sent_at < ?", before).Delete(&EventReminderDelivery{}).Error
}
