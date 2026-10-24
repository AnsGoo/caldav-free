package store

import (
	"context"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

// MatrixView is a saved Eisenhower-matrix configuration.
type MatrixView struct {
	ID         int64     `gorm:"primaryKey"`
	UserID     int64     `gorm:"not null;index:idx_matrix_view_user"`
	Name       string    `gorm:"size:100;not null"`
	Mode       string    `gorm:"size:16;not null;default:'simple'"`
	Rules      string    `gorm:"type:text;not null;default:''"`
	Order      int       `gorm:"column:order_index;not null;default:0"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime"`
}

func (s *Store) ListMatrixViews(ctx context.Context, userID int64) ([]*MatrixView, error) {
	var views []*MatrixView
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("order_index ASC, id ASC").Find(&views).Error; err != nil {
		return nil, fmt.Errorf("list matrix views: %w", err)
	}
	return views, nil
}

// DefaultMatrixRulesJSON mirrors the built-in "important + urgent" split.
const DefaultMatrixRulesJSON = `{"q1":{"priorities":[2,3],"due":"urgent"},"q2":{"priorities":[2,3],"due":"any"},"q3":{"priorities":[0,1],"due":"urgent"},"q4":{}}`

func (s *Store) CreateMatrixView(ctx context.Context, userID int64, name, mode, rules string) (*MatrixView, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("视图名称不能为空")
	}
	mode = normalizeMatrixMode(mode)
	var maxOrder int
	_ = s.db.WithContext(ctx).Model(&MatrixView{}).Where("user_id = ?", userID).
		Select("COALESCE(MAX(order_index), 0)").Scan(&maxOrder).Error
	rules = normalizeMatrixRules(mode, rules)
	view := &MatrixView{UserID: userID, Name: name, Mode: mode, Rules: rules, Order: maxOrder + 1}
	if err := s.db.WithContext(ctx).Create(view).Error; err != nil {
		return nil, fmt.Errorf("create matrix view: %w", err)
	}
	return view, nil
}

func (s *Store) UpdateMatrixView(ctx context.Context, userID, id int64, name, mode, rules string, order int) (*MatrixView, error) {
	updates := map[string]any{}
	if trimmed := strings.TrimSpace(mode); trimmed != "" {
		updates["mode"] = normalizeMatrixMode(trimmed)
	}
	if order > 0 {
		updates["order_index"] = order
	}
	if trimmed := strings.TrimSpace(name); trimmed != "" {
		updates["name"] = trimmed
	}
	if trimmed := strings.TrimSpace(rules); trimmed != "" {
		updates["rules"] = trimmed
	}
	if len(updates) == 0 {
		if _, err := s.GetMatrixView(ctx, userID, id); err != nil {
			return nil, err
		}
	} else {
		res := s.db.WithContext(ctx).Model(&MatrixView{}).Where("id = ? AND user_id = ?", id, userID).Updates(updates)
		if res.Error != nil {
			return nil, fmt.Errorf("update matrix view: %w", res.Error)
		}
		if res.RowsAffected == 0 {
			return nil, ErrNotFound
		}
	}
	view, err := s.GetMatrixView(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	if view.Mode == "custom" && strings.TrimSpace(view.Rules) == "" {
		view.Rules = DefaultMatrixRulesJSON
		if err := s.db.WithContext(ctx).Model(&MatrixView{}).Where("id = ? AND user_id = ?", id, userID).
			Update("rules", view.Rules).Error; err != nil {
			return nil, fmt.Errorf("update matrix view rules: %w", err)
		}
	}
	return view, nil
}

func (s *Store) GetMatrixView(ctx context.Context, userID, id int64) (*MatrixView, error) {
	var view MatrixView
	if err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&view).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &view, nil
}

func (s *Store) DeleteMatrixView(ctx context.Context, userID, id int64) error {
	res := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).Delete(&MatrixView{})
	if res.Error != nil {
		return fmt.Errorf("delete matrix view: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

func normalizeMatrixMode(mode string) string {
	switch strings.ToLower(strings.TrimSpace(mode)) {
	case "complex":
		return "complex"
	case "custom":
		return "custom"
	default:
		return "simple"
	}
}

func normalizeMatrixRules(mode, rules string) string {
	rules = strings.TrimSpace(rules)
	if rules == "" && mode == "custom" {
		return DefaultMatrixRulesJSON
	}
	return rules
}
