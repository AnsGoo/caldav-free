package store

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type TaskTemplate struct {
	ID         int64     `gorm:"primaryKey" json:"id"`
	UserID     int64     `gorm:"not null;index:idx_task_template_user" json:"-"`
	Name       string    `gorm:"size:120;not null" json:"name"`
	Payload    string    `gorm:"type:text;not null" json:"payload"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime" json:"createdAt"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime" json:"modifiedAt"`
}

func (s *Store) ListTaskTemplates(ctx context.Context, userID int64) ([]*TaskTemplate, error) {
	var templates []*TaskTemplate
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("modified_at DESC, id DESC").Limit(200).Find(&templates).Error; err != nil {
		return nil, fmt.Errorf("list task templates: %w", err)
	}
	return templates, nil
}

func (s *Store) CreateTaskTemplate(ctx context.Context, userID int64, name, payload string) (*TaskTemplate, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("模板名称不能为空")
	}
	if len([]rune(name)) > 120 {
		name = string([]rune(name)[:120])
	}
	payload = strings.TrimSpace(payload)
	if payload == "" || len(payload) > 64<<10 || !json.Valid([]byte(payload)) {
		return nil, fmt.Errorf("模板内容无效")
	}
	template := &TaskTemplate{UserID: userID, Name: name, Payload: payload}
	if err := s.db.WithContext(ctx).Create(template).Error; err != nil {
		return nil, fmt.Errorf("create task template: %w", err)
	}
	return template, nil
}

func (s *Store) DeleteTaskTemplate(ctx context.Context, userID, id int64) error {
	result := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).Delete(&TaskTemplate{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) GetTaskTemplate(ctx context.Context, userID, id int64) (*TaskTemplate, error) {
	var template TaskTemplate
	if err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&template).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &template, nil
}
