package store

import (
	"context"
	"fmt"
	"time"
)

type CalendarSubscription struct {
	ID         int64      `gorm:"primaryKey" json:"id"`
	UserID     int64      `gorm:"not null;index:idx_calendar_subscription_user" json:"-"`
	Name       string     `gorm:"size:120;not null" json:"name"`
	URL        string     `gorm:"size:1000;not null" json:"url"`
	Color      string     `gorm:"size:20;not null;default:'#f0a020'" json:"color"`
	Data       []byte     `gorm:"type:blob" json:"-"`
	LastSynced *time.Time `json:"lastSynced,omitempty"`
	LastError  string     `gorm:"size:500;not null;default:''" json:"lastError,omitempty"`
	CreatedAt  time.Time  `gorm:"not null;autoCreateTime" json:"createdAt"`
}

func (s *Store) ListCalendarSubscriptions(ctx context.Context, userID int64) ([]*CalendarSubscription, error) {
	var subscriptions []*CalendarSubscription
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).Order("id ASC").Find(&subscriptions).Error; err != nil {
		return nil, fmt.Errorf("list calendar subscriptions: %w", err)
	}
	return subscriptions, nil
}

func (s *Store) CreateCalendarSubscription(ctx context.Context, subscription *CalendarSubscription) (*CalendarSubscription, error) {
	if subscription == nil {
		return nil, fmt.Errorf("订阅不能为空")
	}
	if err := s.db.WithContext(ctx).Create(subscription).Error; err != nil {
		return nil, fmt.Errorf("create calendar subscription: %w", err)
	}
	return subscription, nil
}

func (s *Store) DeleteCalendarSubscription(ctx context.Context, userID, id int64) error {
	result := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).Delete(&CalendarSubscription{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) UpdateCalendarSubscriptionCache(ctx context.Context, id int64, data []byte, syncErr string) error {
	now := time.Now()
	return s.db.WithContext(ctx).Model(&CalendarSubscription{}).Where("id = ?", id).Updates(map[string]any{
		"data": data, "last_synced": now, "last_error": syncErr,
	}).Error
}
