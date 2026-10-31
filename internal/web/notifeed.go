package web

import (
	"net/http"
	"net/url"
	"strconv"
	"strings"
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

func (s *Server) apiSnoozeNotification(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	notificationID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "通知不存在")
		return
	}
	notification, err := s.store.GetNotification(r.Context(), current.ID, notificationID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "通知不存在")
		return
	}
	if notification.Type != "event" && notification.Type != "task" {
		writeAPIError(w, http.StatusBadRequest, "该通知不支持稍后提醒")
		return
	}
	var body struct {
		Minutes int `json:"minutes"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if body.Minutes <= 0 {
		body.Minutes = 10
	}
	if body.Minutes > 1440 {
		writeAPIError(w, http.StatusBadRequest, "稍后提醒不能超过 24 小时")
		return
	}
	parsed, err := url.Parse(notification.URL)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "通知链接无效")
		return
	}
	query := parsed.Query()
	calendarID, _ := strconv.ParseInt(query.Get("calendar"), 10, 64)
	href := strings.TrimSpace(query.Get("event"))
	if calendarID <= 0 || href == "" {
		writeAPIError(w, http.StatusBadRequest, "通知缺少日程信息")
		return
	}
	calendar, err := s.store.GetCalendar(r.Context(), calendarID)
	if err != nil || calendar.UserID != current.ID {
		writeAPIError(w, http.StatusForbidden, "无权操作该日程")
		return
	}
	snooze, err := s.store.CreateEventSnooze(r.Context(), &store.EventSnooze{
		UserID: current.ID, CalendarID: calendarID, Href: href,
		Occurrence: strings.TrimSpace(query.Get("occurrence")),
		Title:      "日程提醒", Body: notification.Body, URL: notification.URL,
		RemindAt: time.Now().UTC().Add(time.Duration(body.Minutes) * time.Minute),
	})
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	_ = s.store.MarkNotificationRead(r.Context(), current.ID, notificationID)
	unread, _ := s.store.CountUnreadNotifications(r.Context(), current.ID)
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"snooze": map[string]any{"id": snooze.ID, "remindAt": snooze.RemindAt.Format(time.RFC3339)},
		"unread": unread,
	})
}

func (s *Server) apiDeleteNotification(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	notificationID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "通知不存在")
		return
	}
	if err := s.store.DeleteNotification(r.Context(), current.ID, notificationID); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "通知不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	unread, _ := s.store.CountUnreadNotifications(r.Context(), current.ID)
	writeAPIJSON(w, http.StatusOK, map[string]any{"unread": unread})
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
