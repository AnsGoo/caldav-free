package store

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

// SummaryDocument stores a saved summary template or history document.
type SummaryDocument struct {
	ID         int64     `gorm:"primaryKey"`
	UserID     int64     `gorm:"not null;index:idx_summary_doc_user_kind,priority:1"`
	Kind       string    `gorm:"size:16;not null;index:idx_summary_doc_user_kind,priority:2"` // template | history
	Name       string    `gorm:"size:190;not null"`
	Content    string    `gorm:"type:text;not null"`
	CreatedAt  time.Time `gorm:"not null;autoCreateTime"`
	ModifiedAt time.Time `gorm:"not null;autoUpdateTime"`
}

// ListSummaryDocuments returns documents of one kind, newest first.
func (s *Store) ListSummaryDocuments(ctx context.Context, userID int64, kind string) ([]*SummaryDocument, error) {
	var documents []*SummaryDocument
	query := s.db.WithContext(ctx).Where("user_id = ?", userID)
	if kind != "" {
		query = query.Where("kind = ?", kind)
	}
	if err := query.Order("created_at DESC, id DESC").Limit(100).Find(&documents).Error; err != nil {
		return nil, fmt.Errorf("list summary documents: %w", err)
	}
	return documents, nil
}

// GetSummaryDocument returns a document scoped to its owner.
func (s *Store) GetSummaryDocument(ctx context.Context, userID, id int64) (*SummaryDocument, error) {
	var document SummaryDocument
	err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).First(&document).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get summary document: %w", err)
	}
	return &document, nil
}

// CreateSummaryDocument stores a template or history entry.
func (s *Store) CreateSummaryDocument(ctx context.Context, userID int64, kind, name, content string) (*SummaryDocument, error) {
	kind = strings.ToLower(strings.TrimSpace(kind))
	if kind != "template" && kind != "history" {
		return nil, errors.New("invalid summary document kind")
	}
	name = strings.TrimSpace(name)
	if name == "" {
		name = "未命名摘要"
	}
	document := SummaryDocument{UserID: userID, Kind: kind, Name: name, Content: content}
	if err := s.db.WithContext(ctx).Create(&document).Error; err != nil {
		return nil, fmt.Errorf("create summary document: %w", err)
	}
	return &document, nil
}

// UpdateSummaryDocument updates name/content of a saved document.
func (s *Store) UpdateSummaryDocument(ctx context.Context, userID, id int64, name, content string) (*SummaryDocument, error) {
	document, err := s.GetSummaryDocument(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	if strings.TrimSpace(name) != "" {
		document.Name = strings.TrimSpace(name)
	}
	document.Content = content
	err = s.db.WithContext(ctx).Model(&SummaryDocument{}).Where("id = ? AND user_id = ?", id, userID).
		Updates(map[string]any{"name": document.Name, "content": document.Content}).Error
	if err != nil {
		return nil, fmt.Errorf("update summary document: %w", err)
	}
	return s.GetSummaryDocument(ctx, userID, id)
}

// DeleteSummaryDocument removes a saved document.
func (s *Store) DeleteSummaryDocument(ctx context.Context, userID, id int64) error {
	res := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, userID).Delete(&SummaryDocument{})
	if res.Error != nil {
		return fmt.Errorf("delete summary document: %w", res.Error)
	}
	return nil
}
