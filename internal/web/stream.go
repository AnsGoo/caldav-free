package web

import (
	"context"
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

type taskSyncUser struct {
	ch      chan string
	clients int
	stop    chan struct{}
}

type taskSyncHub struct {
	mu    sync.Mutex
	users map[int64]*taskSyncUser
}

func newTaskSyncHub() *taskSyncHub {
	return &taskSyncHub{users: map[int64]*taskSyncUser{}}
}

func (h *taskSyncHub) subscribe(
	userID int64,
	syncFn func(context.Context) error,
	revisionFn func(context.Context) (string, error),
) (chan string, func()) {
	h.mu.Lock()
	state := h.users[userID]
	if state == nil {
		state = &taskSyncUser{ch: make(chan string, 1), stop: make(chan struct{})}
		h.users[userID] = state
		go h.loop(userID, state, syncFn, revisionFn)
	}
	state.clients++
	h.mu.Unlock()
	return state.ch, func() {
		h.mu.Lock()
		state.clients--
		if state.clients <= 0 {
			delete(h.users, userID)
			close(state.stop)
		}
		h.mu.Unlock()
	}
}

func (h *taskSyncHub) loop(
	userID int64,
	state *taskSyncUser,
	syncFn func(context.Context) error,
	revisionFn func(context.Context) (string, error),
) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	last, _ := revisionFn(ctx)
	cancel()
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-state.stop:
			return
		case <-ticker.C:
			runCtx, runCancel := context.WithTimeout(context.Background(), 20*time.Second)
			_ = syncFn(runCtx)
			revision, _ := revisionFn(runCtx)
			runCancel()
			if revision != "" && revision != last {
				last = revision
				select {
				case state.ch <- revision:
				default:
				}
			}
		}
	}
}

func (s *Server) apiTaskStream(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		writeAPIError(w, http.StatusInternalServerError, "当前服务器不支持流式响应")
		return
	}
	w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	ch, unsubscribe := s.taskStreams.subscribe(
		current.ID,
		func(ctx context.Context) error { return s.taskSync.Sync(ctx, current.ID) },
		func(ctx context.Context) (string, error) { return s.store.TaskWorkspaceRevision(ctx, current.ID) },
	)
	defer unsubscribe()
	_, _ = fmt.Fprint(w, "data: {\"ready\":true}\n\n")
	flusher.Flush()
	ticker := time.NewTicker(25 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case revision := <-ch:
			_, _ = fmt.Fprintf(w, "data: {\"revision\":%q}\n\n", revision)
			flusher.Flush()
		case <-ticker.C:
			_, _ = fmt.Fprint(w, ": ping\n\n")
			flusher.Flush()
		}
	}
}
