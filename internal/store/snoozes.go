package store

import (
	"context"
	"fmt"
	"time"
)

// EventSnooze is a one-off delayed calendar reminder initiated from an
// existing reminder notification.
type EventSnooze struct {
	ID         int64     `gorm:"primaryKey"`
	UserID     int64     `gorm:"not null;index:idx_event_snooze_due,priority:1"`
	CalendarID int64     `gorm:"not null"`
	Href       string    `gorm:"size:255;not null"`
	Occurrence string    `gorm:"size:64;not null;default:''"`
	Title      string    `gorm:"size:255;not null;default:''"`
	Body       string    `gorm:"type:text;not null;default:''"`
	URL        string    `gorm:"size:1024;not null;default:''"`
	RemindAt   time.Time `gorm:"not null;index:idx_event_snooze_due,priority:2"`
	Sent       bool      `gorm:"not null;default:false"`
	SentAt     *time.Time
	CreatedAt  time.Time `gorm:"not null;autoCreateTime"`
}

func (s *Store) CreateEventSnooze(ctx context.Context, item *EventSnooze) (*EventSnooze, error) {
	if err := s.db.WithContext(ctx).Create(item).Error; err != nil {
		return nil, fmt.Errorf("create event snooze: %w", err)
	}
	return item, nil
}

func (s *Store) ListDueEventSnoozes(ctx context.Context, now time.Time, limit int) ([]*EventSnooze, error) {
	if limit <= 0 || limit > 100 {
		limit = 100
	}
	var items []*EventSnooze
	err := s.db.WithContext(ctx).Where("sent = ? AND remind_at <= ?", false, now).
		Order("remind_at ASC").Limit(limit).Find(&items).Error
	if err != nil {
		return nil, fmt.Errorf("list due event snoozes: %w", err)
	}
	return items, nil
}

func (s *Store) MarkEventSnoozeSent(ctx context.Context, id int64) error {
	now := time.Now().UTC()
	return s.db.WithContext(ctx).Model(&EventSnooze{}).Where("id = ?", id).
		Updates(map[string]any{"sent": true, "sent_at": now}).Error
}
