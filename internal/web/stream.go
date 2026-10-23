package web

import (
	"fmt"
	"net/http"
	"sync"
	"time"

	"caldav-free/internal/store"
)

type notificationHub struct {
	mu      sync.Mutex
	clients map[int64]map[chan struct{}]struct{}
}

func newNotificationHub() *notificationHub {
	return &notificationHub{clients: map[int64]map[chan struct{}]struct{}{}}
}

func (h *notificationHub) subscribe(userID int64) (chan struct{}, func()) {
	ch := make(chan struct{}, 1)
	h.mu.Lock()
	if h.clients[userID] == nil {
		h.clients[userID] = map[chan struct{}]struct{}{}
	}
	h.clients[userID][ch] = struct{}{}
	h.mu.Unlock()
	return ch, func() {
		h.mu.Lock()
		if clients := h.clients[userID]; clients != nil {
			delete(clients, ch)
			if len(clients) == 0 {
				delete(h.clients, userID)
			}
		}
		h.mu.Unlock()
	}
}

func (h *notificationHub) publish(userID int64) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for ch := range h.clients[userID] {
		select {
		case ch <- struct{}{}:
		default:
		}
	}
}

func (s *Server) apiNotificationStream(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		writeAPIError(w, http.StatusInternalServerError, "当前服务器不支持流式响应")
		return
	}
	w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	ch, unsubscribe := s.notifications.subscribe(current.ID)
	defer unsubscribe()
	send := func() {
		unread, _ := s.store.CountUnreadNotifications(r.Context(), current.ID)
		_, _ = fmt.Fprintf(w, "data: {\"unread\":%d}\n\n", unread)
		flusher.Flush()
	}
	send()
	ticker := time.NewTicker(25 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case <-ch:
			send()
		case <-ticker.C:
			_, _ = fmt.Fprint(w, ": ping\n\n")
			flusher.Flush()
		}
	}
}
