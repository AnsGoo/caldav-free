package web

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	"caldav-free/internal/mailer"
	"caldav-free/internal/reminders"
	"caldav-free/internal/store"
)

// notifyAssignment creates an in-app notification and sends best-effort Web
// Push / email to the newly assigned user.
func (s *Server) notifyAssignment(ctx context.Context, r *http.Request, actor *store.User, previous string, task *store.Task) {
	assigneeName := strings.ToLower(strings.TrimSpace(task.Assignee))
	if assigneeName == "" || strings.EqualFold(assigneeName, previous) || strings.EqualFold(assigneeName, actor.Username) {
		return
	}
	assignee, err := s.store.GetUserByUsername(ctx, assigneeName)
	if err != nil {
		s.logger.Warn("assignment notification: user not found", "assignee", assigneeName)
		return
	}
	list, err := s.store.GetTaskList(ctx, task.UserID, task.ListID)
	if err != nil {
		s.logger.Warn("assignment notification: list not found", "list", task.ListID)
		return
	}
	relativeURL := fmt.Sprintf("/tasks?view=list&list=%d&task=%d", list.ID, task.ID)
	if assignee.ID != list.UserID {
		relativeURL = fmt.Sprintf("/tasks?view=shared&shared=%d&task=%d", list.ID, task.ID)
	}
	actorName := actor.DisplayName
	if strings.TrimSpace(actorName) == "" {
		actorName = actor.Username
	}
	title := "任务指派"
	body := fmt.Sprintf("%s 将任务「%s」指派给你", actorName, task.Title)
	notification := &store.Notification{
		UserID: assignee.ID, Type: "assignment", Title: title,
		Body: body, URL: relativeURL, TaskID: task.ID,
	}
	if _, err := s.store.CreateNotification(ctx, notification); err != nil {
		s.logger.Warn("create assignment notification", "user", assignee.ID, "error", err)
	}
	absoluteURL := s.baseURL(r) + "/admin" + relativeURL
	go s.sendAssignmentPush(assignee, title, body, absoluteURL, task)
}

func (s *Server) sendAssignmentPush(assignee *store.User, title, body, url string, task *store.Task) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if _, err := reminders.NotifyUser(ctx, s.store, s.logger, assignee.ID, reminders.PushMessage{
		Title: title, Body: body, Tag: fmt.Sprintf("assign-%d-%d", task.ID, time.Now().Unix()), TaskID: task.ID, URL: url,
	}); err != nil {
		s.logger.Warn("send assignment push", "user", assignee.ID, "error", err)
	}
	cfg, err := mailer.Load(ctx, s.store)
	if err != nil || !cfg.Enabled || strings.TrimSpace(assignee.Email) == "" {
		return
	}
	content := body + "\n\n任务：" + task.Title + "\n打开任务：" + url + "\n"
	if err := cfg.Send(ctx, assignee.Email, "任务指派："+task.Title, content); err != nil {
		s.logger.Warn("send assignment email", "user", assignee.ID, "error", err)
	}
}
