package store

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// TaskListShare grants another user read-only access to a task list. The
// share row stores the owner explicitly to keep authorization checks cheap.
type TaskListShare struct {
	ID        int64     `gorm:"primaryKey"`
	ListID    int64     `gorm:"not null;uniqueIndex:idx_task_list_share,priority:1"`
	OwnerID   int64     `gorm:"not null;index:idx_task_list_share_owner"`
	UserID    int64     `gorm:"not null;uniqueIndex:idx_task_list_share,priority:2;index:idx_task_list_share_user"`
	Role      string    `gorm:"size:16;not null;default:'viewer'"`
	CreatedAt time.Time `gorm:"not null;autoCreateTime"`
}

// TaskListShareView is a share joined with the recipient's profile.
type TaskListShareView struct {
	ID          int64
	ListID      int64
	UserID      int64
	Username    string
	DisplayName string
	Role        string
	CreatedAt   time.Time
}

// SharedTaskList is a list shared with the current user.
type SharedTaskList struct {
	ListID        int64
	Name          string
	Color         string
	OwnerID       int64
	OwnerUsername string
	OwnerDisplay  string
	Role          string
	Count         int64
}

// ShareTaskList shares one of the owner's lists with a username.
func (s *Store) ShareTaskList(ctx context.Context, ownerID, listID int64, username, role string) (*TaskListShareView, error) {
	list, err := s.GetTaskList(ctx, ownerID, listID)
	if err != nil {
		return nil, err
	}
	if list.IsInbox {
		return nil, errors.New("收集箱不能共享")
	}
	user, err := s.GetUserByUsername(ctx, username)
	if err != nil {
		return nil, errors.New("用户不存在")
	}
	if user.ID == ownerID {
		return nil, errors.New("不能共享给自己")
	}
	role = strings.ToLower(strings.TrimSpace(role))
	if role == "" {
		role = "viewer"
	}
	if role != "viewer" {
		return nil, errors.New("当前版本仅支持只读共享")
	}
	share := TaskListShare{ListID: listID, OwnerID: ownerID, UserID: user.ID, Role: role}
	err = s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "list_id"}, {Name: "user_id"}},
		DoUpdates: clause.AssignmentColumns([]string{"owner_id", "role"}),
	}).Create(&share).Error
	if err != nil {
		return nil, fmt.Errorf("share task list: %w", err)
	}
	return &TaskListShareView{
		ID: share.ID, ListID: listID, UserID: user.ID,
		Username: user.Username, DisplayName: user.DisplayName, Role: role,
		CreatedAt: share.CreatedAt,
	}, nil
}

// ListTaskListShares returns the recipients of a list.
func (s *Store) ListTaskListShares(ctx context.Context, ownerID, listID int64) ([]TaskListShareView, error) {
	if _, err := s.GetTaskList(ctx, ownerID, listID); err != nil {
		return nil, err
	}
	var shares []TaskListShare
	if err := s.db.WithContext(ctx).Where("list_id = ? AND owner_id = ?", listID, ownerID).
		Order("created_at ASC").Find(&shares).Error; err != nil {
		return nil, fmt.Errorf("list task list shares: %w", err)
	}
	out := make([]TaskListShareView, 0, len(shares))
	for _, share := range shares {
		user, err := s.GetUser(ctx, share.UserID)
		if err != nil {
			continue
		}
		out = append(out, TaskListShareView{
			ID: share.ID, ListID: share.ListID, UserID: share.UserID,
			Username: user.Username, DisplayName: user.DisplayName, Role: share.Role,
			CreatedAt: share.CreatedAt,
		})
	}
	return out, nil
}

// DeleteTaskListShare removes a recipient.
func (s *Store) DeleteTaskListShare(ctx context.Context, ownerID, listID, userID int64) error {
	if _, err := s.GetTaskList(ctx, ownerID, listID); err != nil {
		return err
	}
	res := s.db.WithContext(ctx).
		Where("list_id = ? AND owner_id = ? AND user_id = ?", listID, ownerID, userID).
		Delete(&TaskListShare{})
	if res.Error != nil {
		return fmt.Errorf("delete task list share: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// ListSharedTaskLists returns lists shared with a user.
func (s *Store) ListSharedTaskLists(ctx context.Context, userID int64) ([]SharedTaskList, error) {
	var shares []TaskListShare
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).Order("created_at ASC").Find(&shares).Error; err != nil {
		return nil, fmt.Errorf("list shared task lists: %w", err)
	}
	out := make([]SharedTaskList, 0, len(shares))
	for _, share := range shares {
		list, err := s.GetTaskList(ctx, share.OwnerID, share.ListID)
		if err != nil {
			continue
		}
		owner, err := s.GetUser(ctx, share.OwnerID)
		if err != nil {
			continue
		}
		count, _ := s.CountTasksInList(ctx, share.OwnerID, list.ID)
		out = append(out, SharedTaskList{
			ListID: list.ID, Name: list.Name, Color: list.Color,
			OwnerID: owner.ID, OwnerUsername: owner.Username,
			OwnerDisplay: owner.DisplayName, Role: share.Role, Count: count,
		})
	}
	return out, nil
}

// GetSharedTaskList returns a shared list and role for a recipient.
func (s *Store) GetSharedTaskList(ctx context.Context, userID, listID int64) (*TaskList, string, error) {
	var share TaskListShare
	err := s.db.WithContext(ctx).Where("list_id = ? AND user_id = ?", listID, userID).First(&share).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, "", ErrNotFound
	}
	if err != nil {
		return nil, "", fmt.Errorf("get shared task list: %w", err)
	}
	list, err := s.GetTaskList(ctx, share.OwnerID, listID)
	if err != nil {
		return nil, "", err
	}
	return list, share.Role, nil
}

// ListSharedTasks returns tasks in a list shared with the user.
func (s *Store) ListSharedTasks(ctx context.Context, userID, listID int64) ([]*Task, error) {
	list, _, err := s.GetSharedTaskList(ctx, userID, listID)
	if err != nil {
		return nil, err
	}
	return s.ListTasks(ctx, list.UserID, TaskFilter{View: "all", ListID: listID})
}

func (s *Store) deleteTaskListSharesTx(tx *gorm.DB, listID int64) error {
	return tx.Where("list_id = ?", listID).Delete(&TaskListShare{}).Error
}
