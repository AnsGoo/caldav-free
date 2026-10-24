package store

import (
	"context"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

// MatrixRuleTemplate is a saved set of custom quadrant rules.
type MatrixRuleTemplate struct {
	ID         int64     `gorm:"primaryKey"`
	UserID     int64     `gorm:"not null;index:idx_matrix_template_user"`
	Name       string    `gorm:"size:100;not null"`
	Rules      string    `gorm:"type:text;not null;default:''"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime"`
}

func (s *Store) ListMatrixRuleTemplates(ctx context.Context, userID int64) ([]*MatrixRuleTemplate, error) {
	var templates []*MatrixRuleTemplate
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("created_at DESC, id DESC").Find(&templates).Error; err != nil {
		return nil, fmt.Errorf("list matrix rule templates: %w", err)
	}
	return templates, nil
}

func (s *Store) CreateMatrixRuleTemplate(ctx context.Context, userID int64, name, rules string) (*MatrixRuleTemplate, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("模板名称不能为空")
	}
	rules = strings.TrimSpace(rules)
	if rules == "" {
		return nil, fmt.Errorf("模板规则不能为空")
	}
	template := &MatrixRuleTemplate{UserID: userID, Name: name, Rules: rules}
	if err := s.db.WithContext(ctx).Create(template).Error; err != nil {
		return nil, fmt.Errorf("create matrix rule template: %w", err)
	}
	return template, nil
}

func (s *Store) UpdateMatrixRuleTemplate(ctx context.Context, userID, id int64, name, rules string) (*MatrixRuleTemplate, error) {
	updates := map[string]any{}
	if trimmed := strings.TrimSpace(name); trimmed != "" {
		updates["name"] = trimmed
	}
	if trimmed := strings.TrimSpace(rules); trimmed != "" {
		updates["rules"] = trimmed
	}
	if len(updates) > 0 {
		res := s.db.WithContext(ctx).Model(&MatrixRuleTemplate{}).Where("id = ? AND user_id = ?", id, userID).Updates(updates)
		if res.Error != nil {
			return nil, fmt.Errorf("update matrix rule template: %w", res.Error)
		}
		if res.RowsAffected == 0 {
			return nil, ErrNotFound
		}
	}
	return s.GetMatrixRuleTemplate(ctx, userID, id)
}

func (s *Store) DeleteMatrixRuleTemplate(ctx context.Context, userID, id int64) error {
	res := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).Delete(&MatrixRuleTemplate{})
	if res.Error != nil {
		return fmt.Errorf("delete matrix rule template: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) GetMatrixRuleTemplate(ctx context.Context, userID, id int64) (*MatrixRuleTemplate, error) {
	var template MatrixRuleTemplate
	if err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&template).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &template, nil
}
