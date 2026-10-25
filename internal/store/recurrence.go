package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// TaskRecurrenceInstance records what happened to one occurrence of a
// recurring task. The occurrence itself is not materialized as a second row in
// tasks; this table keeps the completion/skip history.
type TaskRecurrenceInstance struct {
	ID           int64      `gorm:"primaryKey"`
	UserID       int64      `gorm:"not null;index:idx_recurrence_instance_user"`
	TaskID       int64      `gorm:"not null;uniqueIndex:idx_recurrence_instance,priority:1;index:idx_recurrence_instance_task"`
	OccurrenceAt time.Time  `gorm:"not null;uniqueIndex:idx_recurrence_instance,priority:2"`
	Status       string     `gorm:"size:16;not null;default:'completed'"`
	PostponedTo  *time.Time `gorm:"index:idx_recurrence_postponed"`
	Title        string     `gorm:"size:500;not null;default:''"`
	CreatedAt    time.Time  `gorm:"not null;autoCreateTime"`
	UpdatedAt    time.Time  `gorm:"autoUpdateTime"`
}

// RecordRecurrenceInstance stores an occurrence result. Repeated requests for
// the same task and occurrence update the existing row so a postponed instance
// can later be completed or skipped.
func (s *Store) RecordRecurrenceInstance(ctx context.Context, instance *TaskRecurrenceInstance) error {
	if instance == nil || instance.TaskID == 0 || instance.OccurrenceAt.IsZero() {
		return nil
	}
	if instance.Status != "completed" && instance.Status != "skipped" && instance.Status != "postponed" {
		instance.Status = "completed"
	}
	if err := s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns: []clause.Column{{Name: "task_id"}, {Name: "occurrence_at"}},
		DoUpdates: clause.AssignmentColumns([]string{
			"status", "postponed_to", "title", "updated_at",
		}),
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

// GetRecurrenceInstance returns one instance row for a task occurrence.
func (s *Store) GetRecurrenceInstance(ctx context.Context, userID, taskID int64, occurrence time.Time) (*TaskRecurrenceInstance, error) {
	var row TaskRecurrenceInstance
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND task_id = ? AND occurrence_at = ?", userID, taskID, occurrence.UTC()).
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get recurrence instance: %w", err)
	}
	return &row, nil
}

// ListRecurrenceInstancesInRange returns instance records whose original or
// postponed time falls into a calendar window. Filtering happens in Go because
// SQLite stores time values in several textual layouts depending on GORM's
// write path.
func (s *Store) ListRecurrenceInstancesInRange(ctx context.Context, userID int64, from, to time.Time) ([]*TaskRecurrenceInstance, error) {
	var rows []*TaskRecurrenceInstance
	err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("occurrence_at DESC").
		Limit(5000).
		Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("list recurrence instances in range: %w", err)
	}
	out := make([]*TaskRecurrenceInstance, 0, len(rows))
	from = from.UTC()
	to = to.UTC()
	for _, row := range rows {
		original := row.OccurrenceAt.UTC()
		postponed := row.PostponedTo != nil && !row.PostponedTo.UTC().Before(from) && row.PostponedTo.UTC().Before(to)
		if (!original.Before(from) && original.Before(to)) || postponed {
			out = append(out, row)
		}
	}
	return out, nil
}
