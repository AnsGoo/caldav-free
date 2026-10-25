package store

import (
	"context"
	"fmt"
	"time"

	"gorm.io/gorm/clause"
)

// TaskRecurrenceInstance records what happened to one occurrence of a
// recurring task. The occurrence itself is not materialized as a second row in
// tasks; this table keeps the completion/skip history.
type TaskRecurrenceInstance struct {
	ID           int64     `gorm:"primaryKey"`
	UserID       int64     `gorm:"not null;index:idx_recurrence_instance_user"`
	TaskID       int64     `gorm:"not null;uniqueIndex:idx_recurrence_instance,priority:1;index:idx_recurrence_instance_task"`
	OccurrenceAt time.Time `gorm:"not null;uniqueIndex:idx_recurrence_instance,priority:2"`
	Status       string    `gorm:"size:16;not null;default:'completed'"`
	Title        string    `gorm:"size:500;not null;default:''"`
	CreatedAt    time.Time `gorm:"not null;autoCreateTime"`
}

// RecordRecurrenceInstance stores an idempotent occurrence result. Repeated
// requests for the same task and occurrence keep the first record.
func (s *Store) RecordRecurrenceInstance(ctx context.Context, instance *TaskRecurrenceInstance) error {
	if instance == nil || instance.TaskID == 0 || instance.OccurrenceAt.IsZero() {
		return nil
	}
	if instance.Status != "completed" && instance.Status != "skipped" {
		instance.Status = "completed"
	}
	if err := s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "task_id"}, {Name: "occurrence_at"}},
		DoNothing: true,
	}).Create(instance).Error; err != nil {
		return fmt.Errorf("record recurrence instance: %w", err)
	}
	return nil
}

// ListRecurrenceInstances returns recent occurrence history for a task.
func (s *Store) ListRecurrenceInstances(ctx context.Context, userID, taskID int64, limit int) ([]*TaskRecurrenceInstance, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	var rows []*TaskRecurrenceInstance
	if err := s.db.WithContext(ctx).
		Where("user_id = ? AND task_id = ?", userID, taskID).
		Order("occurrence_at DESC, id DESC").
		Limit(limit).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("list recurrence instances: %w", err)
	}
	return rows, nil
}
