package store

import (
	"context"
	"fmt"
	"time"
)

// Notification is an in-app collaboration event such as a task assignment.
type Notification struct {
	ID        int64     `gorm:"primaryKey"`
	UserID    int64     `gorm:"not null;index:idx_notification_user_read,priority:1;index:idx_notification_user_created,priority:1"`
	Type      string    `gorm:"size:32;not null;default:''"`
	Title     string    `gorm:"size:255;not null;default:''"`
	Body      string    `gorm:"type:text;not null;default:''"`
	URL       string    `gorm:"size:1024;not null;default:''"`
	TaskID    int64     `gorm:"not null;default:0"`
	Read      bool      `gorm:"not null;default:false;index:idx_notification_user_read,priority:2"`
	CreatedAt time.Time `gorm:"not null;autoCreateTime;index:idx_notification_user_created,priority:2"`
}

// CreateNotification stores an in-app notification.
func (s *Store) CreateNotification(ctx context.Context, notification *Notification) (*Notification, error) {
	if err := s.db.WithContext(ctx).Create(notification).Error; err != nil {
		return nil, fmt.Errorf("create notification: %w", err)
	}
	s.notifyMu.Lock()
	listener := s.notifyListener
	s.notifyMu.Unlock()
	if listener != nil {
		listener(notification)
	}
	return notification, nil
}

// SetNotificationListener registers a callback for newly created notifications.
func (s *Store) SetNotificationListener(listener func(*Notification)) {
	s.notifyMu.Lock()
	s.notifyListener = listener
	s.notifyMu.Unlock()
}

// ListNotifications returns recent notifications for a user.
func (s *Store) ListNotifications(ctx context.Context, userID int64, limit int) ([]*Notification, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	var notifications []*Notification
	err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("created_at DESC, id DESC").
		Limit(limit).Find(&notifications).Error
	if err != nil {
		return nil, fmt.Errorf("list notifications: %w", err)
	}
	return notifications, nil
}

// CountUnreadNotifications returns the unread badge count.
func (s *Store) CountUnreadNotifications(ctx context.Context, userID int64) (int64, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&Notification{}).
		Where("user_id = ? AND read = ?", userID, false).Count(&count).Error
	if err != nil {
		return 0, fmt.Errorf("count unread notifications: %w", err)
	}
	return count, nil
}

// MarkNotificationRead marks one notification as read.
func (s *Store) MarkNotificationRead(ctx context.Context, userID, id int64) error {
	return s.db.WithContext(ctx).Model(&Notification{}).
		Where("id = ? AND user_id = ?", id, userID).
		Update("read", true).Error
}

// DeleteNotification removes a notification once its task has been handled.
func (s *Store) DeleteNotification(ctx context.Context, userID, id int64) error {
	res := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, userID).
		Delete(&Notification{})
	if res.Error != nil {
		return fmt.Errorf("delete notification: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// MarkAllNotificationsRead clears the unread badge for a user.
func (s *Store) MarkAllNotificationsRead(ctx context.Context, userID int64) error {
	return s.db.WithContext(ctx).Model(&Notification{}).
		Where("user_id = ? AND read = ?", userID, false).
		Update("read", true).Error
}

// GetNotification returns one notification for a user.
func (s *Store) GetNotification(ctx context.Context, userID, id int64) (*Notification, error) {
	var notification Notification
	if err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&notification).Error; err != nil {
		return nil, ErrNotFound
	}
	return &notification, nil
}
