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

func (s *Store) CreateMatrixView(ctx context.Context, userID int64, name, mode string) (*MatrixView, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("视图名称不能为空")
	}
	mode = normalizeMatrixMode(mode)
	var maxOrder int
	_ = s.db.WithContext(ctx).Model(&MatrixView{}).Where("user_id = ?", userID).
		Select("COALESCE(MAX(order_index), 0)").Scan(&maxOrder).Error
	view := &MatrixView{UserID: userID, Name: name, Mode: mode, Order: maxOrder + 1}
	if err := s.db.WithContext(ctx).Create(view).Error; err != nil {
		return nil, fmt.Errorf("create matrix view: %w", err)
	}
	return view, nil
}

func (s *Store) UpdateMatrixView(ctx context.Context, userID, id int64, name, mode string, order int) (*MatrixView, error) {
	updates := map[string]any{"mode": normalizeMatrixMode(mode)}
	if order > 0 {
		updates["order_index"] = order
	}
	if trimmed := strings.TrimSpace(name); trimmed != "" {
		updates["name"] = trimmed
	}
	res := s.db.WithContext(ctx).Model(&MatrixView{}).Where("id = ? AND user_id = ?", id, userID).Updates(updates)
	if res.Error != nil {
		return nil, fmt.Errorf("update matrix view: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return nil, ErrNotFound
	}
	return s.GetMatrixView(ctx, userID, id)
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
	if strings.EqualFold(strings.TrimSpace(mode), "complex") {
		return "complex"
	}
	return "simple"
}
