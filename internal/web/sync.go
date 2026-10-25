package web

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"caldav-free/internal/auth"
	"caldav-free/internal/store"
	"caldav-free/internal/syncapi"
)

// ---------------------------------------------------------------- sync API

// apiSyncUser authenticates a sync client with HTTP Basic credentials. Session
// cookies are deliberately not accepted: the sync API is a machine interface,
// and cookie authentication would reintroduce CSRF for non-GET requests.
func (s *Server) apiSyncUser(w http.ResponseWriter, r *http.Request) (*store.User, bool) {
	username, password, ok := r.BasicAuth()
	if !ok || strings.TrimSpace(username) == "" {
		w.Header().Set("WWW-Authenticate", `Basic realm="caldav-free sync"`)
		writeAPIError(w, http.StatusUnauthorized, "需要 HTTP Basic 认证")
		return nil, false
	}
	ip := clientIP(r)
	if !s.limiter.allowed(ip) {
		writeAPIError(w, http.StatusTooManyRequests, "尝试次数过多，请稍后再试")
		return nil, false
	}
	if s.dav != nil {
		user, ok := s.dav.Authenticate(r)
		if !ok {
			s.limiter.fail(ip)
			w.Header().Set("WWW-Authenticate", `Basic realm="caldav-free sync"`)
			writeAPIError(w, http.StatusUnauthorized, "用户名或密码错误")
			return nil, false
		}
		s.limiter.reset(ip)
		return user, true
	}
	user, err := s.store.GetUserByUsername(r.Context(), username)
	if err != nil || !auth.VerifyPassword(password, user.PasswordHash) {
		s.limiter.fail(ip)
		w.Header().Set("WWW-Authenticate", `Basic realm="caldav-free sync"`)
		writeAPIError(w, http.StatusUnauthorized, "用户名或密码错误")
		return nil, false
	}
	s.limiter.reset(ip)
	return user, true
}

func (s *Server) apiSyncPull(w http.ResponseWriter, r *http.Request) {
	current, ok := s.apiSyncUser(w, r)
	if !ok {
		return
	}
	since, err := strconv.ParseInt(strings.TrimSpace(r.URL.Query().Get("since")), 10, 64)
	if err != nil && strings.TrimSpace(r.URL.Query().Get("since")) != "" {
		writeAPIError(w, http.StatusBadRequest, "无效的 since 游标")
		return
	}
	if r.URL.Query().Get("full") == "1" {
		since = 0
	}
	if r.URL.Query().Get("refresh") == "1" {
		if err := s.syncService.Refresh(r.Context(), current.ID); err != nil {
			s.apiServerError(w, err)
			return
		}
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	response, err := s.syncService.Pull(r.Context(), current.ID, since, limit)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, response)
}

func (s *Server) apiSyncPush(w http.ResponseWriter, r *http.Request) {
	current, ok := s.apiSyncUser(w, r)
	if !ok {
		return
	}
	request := syncapi.PushRequest{}
	r.Body = http.MaxBytesReader(w, r.Body, 4<<20)
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(&request); err != nil {
		writeAPIError(w, http.StatusBadRequest, "请求数据格式不正确")
		return
	}
	response, err := s.syncService.Push(r.Context(), current.ID, &request)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusOK, response)
}

// apiSyncCalendar exposes the workspace calendar (CalDAV VEVENTs, task
// occurrences, holidays and subscriptions) to Basic-auth sync clients.
func (s *Server) apiSyncCalendar(w http.ResponseWriter, r *http.Request) {
	current, ok := s.apiSyncUser(w, r)
	if !ok {
		return
	}
	s.apiTaskCalendarEvents(w, r, current, nil)
}

func (s *Server) apiSyncSubscriptions(w http.ResponseWriter, r *http.Request) {
	current, ok := s.apiSyncUser(w, r)
	if !ok {
		return
	}
	s.apiCalendarSubscriptions(w, r, current, nil)
}

func (s *Server) apiSyncSubscriptionDelete(w http.ResponseWriter, r *http.Request) {
	current, ok := s.apiSyncUser(w, r)
	if !ok {
		return
	}
	s.apiCalendarSubscription(w, r, current, nil)
}
