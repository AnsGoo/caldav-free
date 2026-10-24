package store

import (
	"context"
	"fmt"
	"time"
)

type TaskAttachment struct {
	ID          int64     `gorm:"primaryKey"`
	TaskID      int64     `gorm:"not null;index:idx_task_attachment_task"`
	UserID      int64     `gorm:"not null;index:idx_task_attachment_user"`
	Filename    string    `gorm:"size:255;not null"`
	ContentType string    `gorm:"size:190;not null;default:'application/octet-stream'"`
	Size        int64     `gorm:"not null;default:0"`
	Data        []byte    `gorm:"type:blob;not null"`
	CreatedAt   time.Time `gorm:"not null;autoCreateTime"`
}

type TaskAttachmentInfo struct {
	ID          int64
	TaskID      int64
	UserID      int64
	Filename    string
	ContentType string
	Size        int64
	CreatedAt   time.Time
}

func (s *Store) ListTaskAttachments(ctx context.Context, taskID int64) ([]TaskAttachmentInfo, error) {
	var rows []TaskAttachmentInfo
	if err := s.db.WithContext(ctx).Model(&TaskAttachment{}).
		Select("id, task_id, user_id, filename, content_type, size, created_at").
		Where("task_id = ?", taskID).Order("id ASC").Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("list task attachments: %w", err)
	}
	return rows, nil
}

func (s *Store) CreateTaskAttachment(ctx context.Context, attachment *TaskAttachment) error {
	if attachment == nil || len(attachment.Data) == 0 {
		return fmt.Errorf("附件为空")
	}
	return s.db.WithContext(ctx).Create(attachment).Error
}

func (s *Store) GetTaskAttachment(ctx context.Context, taskID, id int64) (*TaskAttachment, error) {
	var attachment TaskAttachment
	if err := s.db.WithContext(ctx).Where("task_id = ? AND id = ?", taskID, id).First(&attachment).Error; err != nil {
		return nil, err
	}
	return &attachment, nil
}

func (s *Store) DeleteTaskAttachment(ctx context.Context, taskID, id int64) error {
	result := s.db.WithContext(ctx).Where("task_id = ? AND id = ?", taskID, id).Delete(&TaskAttachment{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}
