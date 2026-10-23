package web

import (
	"context"
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"caldav-free/internal/store"
)

var mentionPattern = regexp.MustCompile(`(?i)@([a-z0-9][a-z0-9._-]{1,63})`)

type apiTaskComment struct {
	ID          int64  `json:"id"`
	TaskID      int64  `json:"taskId"`
	UserID      int64  `json:"userId"`
	Username    string `json:"username"`
	DisplayName string `json:"displayName"`
	Body        string `json:"body"`
	CreatedAt   string `json:"createdAt"`
	CanDelete   bool   `json:"canDelete"`
}

func (s *Server) apiTaskComments(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	taskID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	access, err := s.store.GetTaskAccess(r.Context(), current.ID, taskID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	if r.Method == http.MethodGet {
		s.writeTaskComments(w, r, current, access)
		return
	}
	if access.Role == "viewer" {
		writeAPIError(w, http.StatusForbidden, "只读共享不能发表评论")
		return
	}
	var body struct {
		Body string `json:"body"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	text := strings.TrimSpace(body.Body)
	if text == "" {
		writeAPIError(w, http.StatusBadRequest, "评论不能为空")
		return
	}
	if utf8.RuneCountInString(text) > 4000 {
		writeAPIError(w, http.StatusBadRequest, "评论最多 4000 字")
		return
	}
	comment, err := s.store.CreateTaskComment(r.Context(), access.Task.ID, current.ID, text)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	s.notifyComment(r.Context(), r, current, access, comment, text)
	writeAPIJSON(w, http.StatusCreated, map[string]any{"comment": apiTaskComment{
		ID: comment.ID, TaskID: comment.TaskID, UserID: current.ID,
		Username: current.Username, DisplayName: current.DisplayName,
		Body: comment.Body, CreatedAt: comment.CreatedAt.Format(time.RFC3339),
		CanDelete: true,
	}})
}

func (s *Server) writeTaskComments(w http.ResponseWriter, r *http.Request, current *store.User, access *store.TaskAccess) {
	comments, err := s.store.ListTaskComments(r.Context(), access.Task.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	rows := make([]apiTaskComment, 0, len(comments))
	for _, comment := range comments {
		rows = append(rows, apiTaskComment{
			ID: comment.ID, TaskID: comment.TaskID, UserID: comment.UserID,
			Username: comment.Username, DisplayName: comment.DisplayName,
			Body: comment.Body, CreatedAt: comment.CreatedAt.Format(time.RFC3339),
			CanDelete: comment.UserID == current.ID || access.List.UserID == current.ID,
		})
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"comments": rows})
}

func (s *Server) apiDeleteTaskComment(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	taskID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	commentID, err := strconv.ParseInt(r.PathValue("commentId"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "评论不存在")
		return
	}
	access, err := s.store.GetTaskAccess(r.Context(), current.ID, taskID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	comment, err := s.store.GetTaskComment(r.Context(), taskID, commentID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "评论不存在")
		return
	}
	if comment.UserID != current.ID && access.List.UserID != current.ID {
		writeAPIError(w, http.StatusForbidden, "不能删除其他成员的评论")
		return
	}
	if err := s.store.DeleteTaskComment(r.Context(), taskID, commentID); err != nil {
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) notifyComment(ctx context.Context, r *http.Request, actor *store.User, access *store.TaskAccess, comment *store.TaskComment, text string) {
	members, err := s.store.ListTaskListMembers(ctx, access.List.UserID, access.List.ID)
	if err != nil {
		s.logger.Warn("comment notification: list members", "list", access.List.ID, "error", err)
		return
	}
	memberNames := make(map[string]bool, len(members))
	for _, member := range members {
		memberNames[member.Username] = true
	}
	mentioned := make(map[string]bool)
	for _, match := range mentionPattern.FindAllStringSubmatch(text, -1) {
		username := strings.ToLower(match[1])
		if memberNames[username] {
			mentioned[username] = true
		}
	}
	recipients := make(map[string]bool)
	for username := range mentioned {
		recipients[username] = true
	}
	if access.Task.Assignee != "" {
		recipients[access.Task.Assignee] = true
	}
	owner, err := s.store.GetUser(ctx, access.List.UserID)
	if err == nil {
		recipients[owner.Username] = true
	}
	delete(recipients, actor.Username)
	actorName := actor.DisplayName
	if strings.TrimSpace(actorName) == "" {
		actorName = actor.Username
	}
	preview := []rune(text)
	if len(preview) > 120 {
		preview = append(preview[:120], '…')
	}
	for username := range recipients {
		recipient, err := s.store.GetUserByUsername(ctx, username)
		if err != nil || recipient.ID == actor.ID {
			continue
		}
		isMention := mentioned[username]
		title := "任务评论"
		body := fmt.Sprintf("%s 评论了任务「%s」：%s", actorName, access.Task.Title, string(preview))
		if isMention {
			title = "任务提及"
			body = fmt.Sprintf("%s 在任务「%s」中提到了你：%s", actorName, access.Task.Title, string(preview))
		}
		relativeURL := taskURLForUser(access.List, recipient.ID, access.Task.ID)
		if _, err := s.store.CreateNotification(ctx, &store.Notification{
			UserID: recipient.ID, Type: "comment", Title: title, Body: body,
			URL: relativeURL, TaskID: access.Task.ID,
		}); err != nil {
			s.logger.Warn("create comment notification", "user", recipient.ID, "error", err)
			continue
		}
		absoluteURL := s.baseURL(r) + "/admin" + relativeURL
		go s.sendUserNotification(recipient, title, body, absoluteURL, access.Task)
	}
}
