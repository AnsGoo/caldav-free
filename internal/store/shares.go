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
	Kind          string
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
	if role != "viewer" && role != "editor" {
		return nil, errors.New("共享角色必须是 viewer 或 editor")
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
			ListID: list.ID, Name: list.Name, Color: list.Color, Kind: list.Kind,
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

// GetSharedTask returns a task from a list shared with the user.
func (s *Store) GetSharedTask(ctx context.Context, userID, taskID int64) (*Task, *TaskList, string, error) {
	var task Task
	err := s.db.WithContext(ctx).Where("id = ? AND deleted = ?", taskID, false).First(&task).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil, "", ErrNotFound
	}
	if err != nil {
		return nil, nil, "", fmt.Errorf("get shared task: %w", err)
	}
	list, role, err := s.GetSharedTaskList(ctx, userID, task.ListID)
	if err == nil {
		if list.UserID != task.UserID {
			return nil, nil, "", ErrNotFound
		}
		return &task, list, role, nil
	}
	var share TaskShare
	if shareErr := s.db.WithContext(ctx).Where("task_id = ? AND user_id = ?", taskID, userID).First(&share).Error; shareErr != nil {
		return nil, nil, "", ErrNotFound
	}
	list, err = s.GetTaskList(ctx, share.OwnerID, task.ListID)
	if err != nil || task.UserID != share.OwnerID {
		return nil, nil, "", ErrNotFound
	}
	return &task, list, share.Role, nil
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

// TaskListMember is an owner or shared member eligible for assignment.
type TaskListMember struct {
	Username    string
	DisplayName string
	Role        string
}

// ListTaskListMembers returns the owner and members of an accessible list.
func (s *Store) ListTaskListMembers(ctx context.Context, userID, listID int64) ([]TaskListMember, error) {
	var ownerID int64
	if list, err := s.GetTaskList(ctx, userID, listID); err == nil {
		ownerID = list.UserID
	} else {
		list, _, shareErr := s.GetSharedTaskList(ctx, userID, listID)
		if shareErr != nil {
			return nil, ErrNotFound
		}
		ownerID = list.UserID
	}
	owner, err := s.GetUser(ctx, ownerID)
	if err != nil {
		return nil, err
	}
	members := []TaskListMember{{
		Username: owner.Username, DisplayName: owner.DisplayName, Role: "owner",
	}}
	shares, err := s.ListTaskListShares(ctx, ownerID, listID)
	if err != nil {
		return nil, err
	}
	for _, share := range shares {
		members = append(members, TaskListMember{
			Username: share.Username, DisplayName: share.DisplayName, Role: share.Role,
		})
	}
	return members, nil
}

// TaskShare grants another user access to one note without sharing its list.
type TaskShare struct {
	ID        int64     `gorm:"primaryKey"`
	TaskID    int64     `gorm:"not null;uniqueIndex:idx_task_share,priority:1;index:idx_task_share_task"`
	OwnerID   int64     `gorm:"not null;index:idx_task_share_owner"`
	UserID    int64     `gorm:"not null;uniqueIndex:idx_task_share,priority:2;index:idx_task_share_user"`
	Role      string    `gorm:"size:16;not null;default:'viewer'"`
	CreatedAt time.Time `gorm:"not null;autoCreateTime"`
}

// TaskShareView is a single-note share joined with the recipient profile.
type TaskShareView struct {
	ID          int64
	TaskID      int64
	UserID      int64
	Username    string
	DisplayName string
	Role        string
	CreatedAt   time.Time
}

// SharedNote is a single note shared with the current user.
type SharedNote struct {
	Task          *Task
	List          *TaskList
	OwnerID       int64
	OwnerUsername string
	OwnerDisplay  string
	Role          string
}

// ShareTask shares one note with another user.
func (s *Store) ShareTask(ctx context.Context, ownerID, taskID int64, username, role string) (*TaskShareView, error) {
	task, err := s.GetTask(ctx, ownerID, taskID)
	if err != nil {
		return nil, err
	}
	if task.Kind != "NOTE" {
		return nil, errors.New("仅笔记支持单篇共享")
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
	if role != "viewer" && role != "editor" {
		return nil, errors.New("共享角色必须是 viewer 或 editor")
	}
	share := TaskShare{TaskID: taskID, OwnerID: ownerID, UserID: user.ID, Role: role}
	err = s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "task_id"}, {Name: "user_id"}},
		DoUpdates: clause.AssignmentColumns([]string{"owner_id", "role"}),
	}).Create(&share).Error
	if err != nil {
		return nil, fmt.Errorf("share task: %w", err)
	}
	return &TaskShareView{
		ID: share.ID, TaskID: taskID, UserID: user.ID,
		Username: user.Username, DisplayName: user.DisplayName, Role: role,
		CreatedAt: share.CreatedAt,
	}, nil
}

// ListTaskShares returns the recipients of one note.
func (s *Store) ListTaskShares(ctx context.Context, ownerID, taskID int64) ([]TaskShareView, error) {
	task, err := s.GetTask(ctx, ownerID, taskID)
	if err != nil {
		return nil, err
	}
	if task.Kind != "NOTE" {
		return nil, errors.New("仅笔记支持单篇共享")
	}
	var shares []TaskShare
	if err := s.db.WithContext(ctx).Where("task_id = ? AND owner_id = ?", taskID, ownerID).
		Order("created_at ASC").Find(&shares).Error; err != nil {
		return nil, fmt.Errorf("list task shares: %w", err)
	}
	out := make([]TaskShareView, 0, len(shares))
	for _, share := range shares {
		user, err := s.GetUser(ctx, share.UserID)
		if err != nil {
			continue
		}
		out = append(out, TaskShareView{
			ID: share.ID, TaskID: share.TaskID, UserID: share.UserID,
			Username: user.Username, DisplayName: user.DisplayName,
			Role: share.Role, CreatedAt: share.CreatedAt,
		})
	}
	return out, nil
}

// DeleteTaskShare removes one recipient from a note.
func (s *Store) DeleteTaskShare(ctx context.Context, ownerID, taskID, userID int64) error {
	result := s.db.WithContext(ctx).Where("task_id = ? AND owner_id = ? AND user_id = ?", taskID, ownerID, userID).
		Delete(&TaskShare{})
	if result.Error != nil {
		return fmt.Errorf("delete task share: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// ListSharedNotes returns single notes shared directly with a user.
func (s *Store) ListSharedNotes(ctx context.Context, userID int64) ([]SharedNote, error) {
	var shares []TaskShare
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).Order("created_at ASC").Find(&shares).Error; err != nil {
		return nil, fmt.Errorf("list shared notes: %w", err)
	}
	out := make([]SharedNote, 0, len(shares))
	for _, share := range shares {
		task, err := s.GetTask(ctx, share.OwnerID, share.TaskID)
		if err != nil || task.Kind != "NOTE" {
			continue
		}
		list, err := s.GetTaskList(ctx, share.OwnerID, task.ListID)
		if err != nil {
			continue
		}
		owner, err := s.GetUser(ctx, share.OwnerID)
		if err != nil {
			continue
		}
		out = append(out, SharedNote{
			Task: task, List: list, OwnerID: owner.ID,
			OwnerUsername: owner.Username, OwnerDisplay: owner.DisplayName, Role: share.Role,
		})
	}
	return out, nil
}
