package store

import (
	"context"
	"fmt"
	"time"
)

// TaskActivity is a lightweight collaboration timeline entry.
type TaskActivity struct {
	ID        int64     `gorm:"primaryKey"`
	TaskID    int64     `gorm:"not null;index:idx_task_activity_task,priority:1"`
	UserID    int64     `gorm:"not null;index:idx_task_activity_user"`
	Type      string    `gorm:"size:32;not null"`
	Detail    string    `gorm:"size:500;not null;default:''"`
	CreatedAt time.Time `gorm:"not null;autoCreateTime;index:idx_task_activity_task,priority:2"`
}

type TaskActivityView struct {
	ID          int64
	TaskID      int64
	UserID      int64
	Username    string
	DisplayName string
	Type        string
	Detail      string
	CreatedAt   time.Time
}

func (s *Store) CreateTaskActivity(ctx context.Context, taskID, userID int64, kind, detail string) error {
	activity := &TaskActivity{TaskID: taskID, UserID: userID, Type: kind, Detail: detail}
	if err := s.db.WithContext(ctx).Create(activity).Error; err != nil {
		return fmt.Errorf("create task activity: %w", err)
	}
	return nil
}

func (s *Store) ListTaskActivities(ctx context.Context, taskID int64, limit int) ([]TaskActivityView, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	var activities []TaskActivity
	if err := s.db.WithContext(ctx).Where("task_id = ?", taskID).
		Order("created_at DESC, id DESC").Limit(limit).Find(&activities).Error; err != nil {
		return nil, fmt.Errorf("list task activities: %w", err)
	}
	if len(activities) == 0 {
		return []TaskActivityView{}, nil
	}
	users, err := s.ListUsers(ctx)
	if err != nil {
		return nil, err
	}
	byID := make(map[int64]*User, len(users))
	for _, user := range users {
		byID[user.ID] = user
	}
	out := make([]TaskActivityView, 0, len(activities))
	for _, activity := range activities {
		view := TaskActivityView{
			ID: activity.ID, TaskID: activity.TaskID, UserID: activity.UserID,
			Type: activity.Type, Detail: activity.Detail, CreatedAt: activity.CreatedAt,
		}
		if user := byID[activity.UserID]; user != nil {
			view.Username = user.Username
			view.DisplayName = user.DisplayName
		}
		out = append(out, view)
	}
	return out, nil
}

func (s *Store) LatestTaskActivity(ctx context.Context, taskID, userID int64, kind string) (*TaskActivity, error) {
	var activity TaskActivity
	err := s.db.WithContext(ctx).
		Where("task_id = ? AND user_id = ? AND type = ?", taskID, userID, kind).
		Order("created_at DESC, id DESC").First(&activity).Error
	if err != nil {
		return nil, err
	}
	return &activity, nil
}

func (s *Store) UpdateTaskActivityDetail(ctx context.Context, id int64, detail string) error {
	return s.db.WithContext(ctx).Model(&TaskActivity{}).Where("id = ?", id).
		Update("detail", detail).Error
}
