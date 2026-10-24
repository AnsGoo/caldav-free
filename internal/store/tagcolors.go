package store

import (
	"context"
	"fmt"
	"time"

	"gorm.io/gorm/clause"
)

// TaskTagColor stores a user-defined color for a tag name.
type TaskTagColor struct {
	ID         int64     `gorm:"primaryKey"`
	UserID     int64     `gorm:"not null;uniqueIndex:idx_task_tag_color,priority:1"`
	Name       string    `gorm:"size:190;not null;uniqueIndex:idx_task_tag_color,priority:2"`
	Color      string    `gorm:"size:16;not null;default:''"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime"`
}

func (s *Store) ListTaskTagColors(ctx context.Context, userID int64) (map[string]string, error) {
	var rows []TaskTagColor
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("list task tag colors: %w", err)
	}
	out := make(map[string]string, len(rows))
	for _, row := range rows {
		out[row.Name] = row.Color
	}
	return out, nil
}

func (s *Store) SetTaskTagColor(ctx context.Context, userID int64, name, color string) error {
	if color == "" {
		return s.db.WithContext(ctx).Where("user_id = ? AND name = ?", userID, name).Delete(&TaskTagColor{}).Error
	}
	row := TaskTagColor{UserID: userID, Name: name, Color: color}
	err := s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "user_id"}, {Name: "name"}},
		DoUpdates: clause.AssignmentColumns([]string{"color", "modified_at"}),
	}).Create(&row).Error
	if err != nil {
		return fmt.Errorf("set task tag color: %w", err)
	}
	return nil
}
