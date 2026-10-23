package web

import (
	"net/http"
	"time"

	"caldav-free/internal/store"
)

type apiNotification struct {
	ID        int64  `json:"id"`
	Type      string `json:"type"`
	Title     string `json:"title"`
	Body      string `json:"body"`
	URL       string `json:"url"`
	TaskID    int64  `json:"taskId"`
	Read      bool   `json:"read"`
	CreatedAt string `json:"createdAt"`
}

func (s *Server) apiNotifications(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	notifications, err := s.store.ListNotifications(r.Context(), current.ID, 50)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	unread, err := s.store.CountUnreadNotifications(r.Context(), current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	rows := make([]apiNotification, 0, len(notifications))
	for _, item := range notifications {
		rows = append(rows, apiNotification{
			ID: item.ID, Type: item.Type, Title: item.Title, Body: item.Body,
			URL: item.URL, TaskID: item.TaskID, Read: item.Read,
			CreatedAt: item.CreatedAt.Format(time.RFC3339),
		})
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"notifications": rows, "unread": unread})
}

func (s *Server) apiNotificationsRead(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		ID  int64 `json:"id"`
		All bool  `json:"all"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if body.All {
		if err := s.store.MarkAllNotificationsRead(r.Context(), current.ID); err != nil {
			s.apiServerError(w, err)
			return
		}
	} else if body.ID > 0 {
		if err := s.store.MarkNotificationRead(r.Context(), current.ID, body.ID); err != nil {
			s.apiServerError(w, err)
			return
		}
	} else {
		writeAPIError(w, http.StatusBadRequest, "通知 ID 无效")
		return
	}
	unread, _ := s.store.CountUnreadNotifications(r.Context(), current.ID)
	writeAPIJSON(w, http.StatusOK, map[string]any{"unread": unread})
}
