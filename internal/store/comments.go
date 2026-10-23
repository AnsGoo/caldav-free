package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
)

// TaskComment is a comment attached to a task. Comments are workspace-only
// and are not written to CalDAV.
type TaskComment struct {
	ID        int64  `gorm:"primaryKey"`
	TaskID    int64  `gorm:"not null;index:idx_task_comment_task,priority:1"`
	UserID    int64  `gorm:"not null;index:idx_task_comment_user"`
	Body      string `gorm:"type:text;not null"`
	EditedAt  *time.Time
	CreatedAt time.Time `gorm:"not null;autoCreateTime;index:idx_task_comment_task,priority:2"`
}

// TaskCommentView joins a comment with its author.
type TaskCommentView struct {
	ID          int64
	TaskID      int64
	UserID      int64
	Username    string
	DisplayName string
	Body        string
	EditedAt    *time.Time
	CreatedAt   time.Time
}

// ListTaskComments returns comments oldest-first for a task.
func (s *Store) ListTaskComments(ctx context.Context, taskID int64) ([]TaskCommentView, error) {
	var comments []TaskComment
	if err := s.db.WithContext(ctx).Where("task_id = ?", taskID).
		Order("created_at ASC, id ASC").Find(&comments).Error; err != nil {
		return nil, fmt.Errorf("list task comments: %w", err)
	}
	if len(comments) == 0 {
		return []TaskCommentView{}, nil
	}
	users, err := s.ListUsers(ctx)
	if err != nil {
		return nil, err
	}
	byID := make(map[int64]*User, len(users))
	for _, user := range users {
		byID[user.ID] = user
	}
	out := make([]TaskCommentView, 0, len(comments))
	for _, comment := range comments {
		user := byID[comment.UserID]
		view := TaskCommentView{
			ID: comment.ID, TaskID: comment.TaskID, UserID: comment.UserID,
			Body: comment.Body, EditedAt: comment.EditedAt, CreatedAt: comment.CreatedAt,
		}
		if user != nil {
			view.Username = user.Username
			view.DisplayName = user.DisplayName
		}
		out = append(out, view)
	}
	return out, nil
}

// CreateTaskComment stores a comment.
func (s *Store) CreateTaskComment(ctx context.Context, taskID, userID int64, body string) (*TaskComment, error) {
	comment := &TaskComment{TaskID: taskID, UserID: userID, Body: body}
	if err := s.db.WithContext(ctx).Create(comment).Error; err != nil {
		return nil, fmt.Errorf("create task comment: %w", err)
	}
	return comment, nil
}

// GetTaskComment returns one comment.
func (s *Store) GetTaskComment(ctx context.Context, taskID, id int64) (*TaskComment, error) {
	var comment TaskComment
	if err := s.db.WithContext(ctx).Where("id = ? AND task_id = ?", id, taskID).First(&comment).Error; err != nil {
		return nil, ErrNotFound
	}
	return &comment, nil
}

// UpdateTaskComment edits a comment body.
func (s *Store) UpdateTaskComment(ctx context.Context, taskID, id, userID int64, body string) (*TaskComment, error) {
	now := time.Now().UTC()
	res := s.db.WithContext(ctx).Model(&TaskComment{}).
		Where("id = ? AND task_id = ? AND user_id = ?", id, taskID, userID).
		Updates(map[string]any{"body": body, "edited_at": now})
	if res.Error != nil {
		return nil, fmt.Errorf("update task comment: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return nil, ErrNotFound
	}
	return s.GetTaskComment(ctx, taskID, id)
}

// DeleteTaskComment removes a comment and its attachments.
func (s *Store) DeleteTaskComment(ctx context.Context, taskID, id int64) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("comment_id = ? AND task_id = ?", id, taskID).Delete(&CommentAttachment{}).Error; err != nil {
			return fmt.Errorf("delete comment attachments: %w", err)
		}
		res := tx.Where("id = ? AND task_id = ?", id, taskID).Delete(&TaskComment{})
		if res.Error != nil {
			return fmt.Errorf("delete task comment: %w", res.Error)
		}
		if res.RowsAffected == 0 {
			return ErrNotFound
		}
		return nil
	})
}

// TaskAccess describes how a user can reach a task.
type TaskAccess struct {
	Task *Task
	List *TaskList
	Role string
}

// GetTaskAccess resolves a task for its owner or a shared-list member.
func (s *Store) GetTaskAccess(ctx context.Context, userID, taskID int64) (*TaskAccess, error) {
	if task, err := s.GetTask(ctx, userID, taskID); err == nil {
		list, listErr := s.GetTaskList(ctx, userID, task.ListID)
		if listErr != nil {
			return nil, listErr
		}
		return &TaskAccess{Task: task, List: list, Role: "owner"}, nil
	}
	task, list, role, err := s.GetSharedTask(ctx, userID, taskID)
	if err != nil {
		return nil, err
	}
	return &TaskAccess{Task: task, List: list, Role: role}, nil
}

// CommentAttachment is a file attached to a task comment. Data is stored in
// SQLite to keep self-hosted deployments to a single backup unit.
type CommentAttachment struct {
	ID          int64     `gorm:"primaryKey"`
	TaskID      int64     `gorm:"not null;index:idx_comment_attachment_task"`
	CommentID   int64     `gorm:"not null;index:idx_comment_attachment_comment"`
	UserID      int64     `gorm:"not null;index:idx_comment_attachment_user"`
	Filename    string    `gorm:"size:255;not null"`
	ContentType string    `gorm:"size:190;not null;default:'application/octet-stream'"`
	Size        int64     `gorm:"not null;default:0"`
	Data        []byte    `gorm:"type:blob;not null"`
	CreatedAt   time.Time `gorm:"not null;autoCreateTime"`
}

// CommentAttachmentInfo is attachment metadata without the blob.
type CommentAttachmentInfo struct {
	ID          int64
	CommentID   int64
	TaskID      int64
	UserID      int64
	Filename    string
	ContentType string
	Size        int64
	CreatedAt   time.Time
}

func (s *Store) CreateCommentAttachment(ctx context.Context, attachment *CommentAttachment) error {
	return s.db.WithContext(ctx).Create(attachment).Error
}

func (s *Store) ListAttachmentInfo(ctx context.Context, taskID int64) ([]CommentAttachmentInfo, error) {
	var rows []CommentAttachmentInfo
	err := s.db.WithContext(ctx).Model(&CommentAttachment{}).
		Select("id, comment_id, task_id, user_id, filename, content_type, size, created_at").
		Where("task_id = ?", taskID).Order("id ASC").Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("list comment attachments: %w", err)
	}
	return rows, nil
}

func (s *Store) GetCommentAttachment(ctx context.Context, taskID, commentID, id int64) (*CommentAttachment, error) {
	var attachment CommentAttachment
	err := s.db.WithContext(ctx).Where("id = ? AND task_id = ? AND comment_id = ?", id, taskID, commentID).First(&attachment).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &attachment, nil
}

func (s *Store) DeleteCommentAttachment(ctx context.Context, taskID, commentID, id int64) error {
	res := s.db.WithContext(ctx).Where("id = ? AND task_id = ? AND comment_id = ?", id, taskID, commentID).Delete(&CommentAttachment{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}
