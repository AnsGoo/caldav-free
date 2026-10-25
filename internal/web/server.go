package web

import (
	"context"
	"crypto/md5"
	"embed"
	"encoding/hex"
	"fmt"
	"html/template"
	"io/fs"
	"log/slog"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"caldav-free/internal/auth"
	"caldav-free/internal/dav"
	"caldav-free/internal/ical"
	"caldav-free/internal/store"
	"caldav-free/internal/syncapi"
	"caldav-free/internal/tasksync"
)

//go:embed templates/*.html
var templateFS embed.FS

//go:embed static/*
var staticFS embed.FS

const sessionCookie = "caldav_admin"

// dummyAdminHash keeps login timing uniform for unknown usernames.
var dummyAdminHash = func() string {
	h, err := auth.HashPassword("caldav-free-dummy-admin-password")
	if err != nil {
		return ""
	}
	return h
}()

// Server serves the admin UI.
type Server struct {
	store         *store.Store
	dav           *dav.Handler
	logger        *slog.Logger
	templates     *template.Template
	assets        http.Handler
	sessions      *sessionStore
	limiter       *loginLimiter
	publicLimiter *publicRateLimiter
	externalURL   string
	// CalDAVURL is the public CalDAV base URL shown to administrators.
	CalDAVURL     string
	taskSync      *tasksync.Syncer
	syncService   *syncapi.Service
	notifications *notificationHub
	focusStreams  *focusHub
	taskStreams   *taskSyncHub
}

// New creates the admin web server. externalURL may be empty to derive URLs
// from the request.
func New(st *store.Store, davHandler *dav.Handler, logger *slog.Logger, externalURL string) (*Server, error) {
	if logger == nil {
		logger = slog.Default()
	}
	funcs := template.FuncMap{
		"pathescape": url.PathEscape,
		"datetime":   formatDateTime,
		"date":       formatDate,
		"initials":   initials,
		"contains": func(list []string, value string) bool {
			for _, item := range list {
				if item == value {
					return true
				}
			}
			return false
		},
	}
	tmpl, err := template.New("").Funcs(funcs).ParseFS(templateFS, "templates/*.html")
	if err != nil {
		return nil, fmt.Errorf("parse templates: %w", err)
	}
	sub, err := fs.Sub(staticFS, "static")
	if err != nil {
		return nil, err
	}
	fileServer := http.FileServer(http.FS(sub))
	assets := http.StripPrefix("/assets/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-cache")
		fileServer.ServeHTTP(w, r)
	}))
	notifications := newNotificationHub()
	st.SetNotificationListener(func(notification *store.Notification) {
		notifications.publish(notification.UserID)
	})
	taskSync := tasksync.New(st)
	return &Server{
		store:         st,
		notifications: notifications,
		focusStreams:  newFocusHub(),
		taskStreams:   newTaskSyncHub(),
		dav:           davHandler,
		logger:        logger,
		templates:     tmpl,
		assets:        assets,
		sessions:      newSessionStore(),
		limiter:       newLoginLimiter(),
		publicLimiter: newPublicRateLimiter(60, time.Minute),
		externalURL:   strings.TrimRight(externalURL, "/"),
		taskSync:      taskSync,
		syncService:   syncapi.New(st, taskSync),
	}, nil
}

// Register adds the admin routes to mux.
func (s *Server) Register(mux *http.ServeMux) {
	mux.Handle("GET /assets/", s.assets)
	mux.HandleFunc("GET /{$}", s.handleRoot)
	mux.HandleFunc("GET /login", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/admin/login", http.StatusSeeOther)
	})
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("GET /api/public/habit-shares/{token}", s.apiPublicHabitShare)
	// Machine sync protocol (Basic Auth, no CSRF).
	mux.HandleFunc("GET /api/sync/pull", s.apiSyncPull)
	mux.HandleFunc("POST /api/sync/push", s.apiSyncPush)
	mux.HandleFunc("GET /api/sync/calendar", s.apiSyncCalendar)
	mux.HandleFunc("GET /api/sync/habits", s.apiSyncHabits)
	mux.HandleFunc("POST /api/sync/habits", s.apiSyncHabits)
	mux.HandleFunc("PATCH /api/sync/habits/{id}", s.apiSyncHabit)
	mux.HandleFunc("DELETE /api/sync/habits/{id}", s.apiSyncHabit)
	mux.HandleFunc("POST /api/sync/habits/{id}/checkin", s.apiSyncHabitCheckin)
	mux.HandleFunc("GET /api/sync/habits/{id}/detail", s.apiSyncHabitDetail)
	mux.HandleFunc("GET /api/sync/subscriptions", s.apiSyncSubscriptions)
	mux.HandleFunc("POST /api/sync/subscriptions", s.apiSyncSubscriptions)
	mux.HandleFunc("DELETE /api/sync/subscriptions/{id}", s.apiSyncSubscriptionDelete)
	mux.HandleFunc("POST /api/sync/events", s.apiSyncCreateEvent)
	mux.HandleFunc("PUT /api/sync/events", s.apiSyncUpdateEvent)
	mux.HandleFunc("DELETE /api/sync/events", s.apiSyncDeleteEvent)

	// JSON API used by the Vue admin SPA.
	mux.HandleFunc("POST /api/admin/login", s.apiLogin)
	mux.HandleFunc("GET /api/admin/me", s.apiAdmin(s.apiMe))
	mux.HandleFunc("POST /api/admin/logout", s.apiAdmin(s.apiLogout))
	mux.HandleFunc("GET /api/admin/dashboard", s.apiAdmin(s.apiDashboard))
	mux.HandleFunc("GET /api/admin/notifications", s.apiAdmin(s.apiNotifications))
	mux.HandleFunc("GET /api/admin/notifications/stream", s.apiAdmin(s.apiNotificationStream))
	mux.HandleFunc("GET /api/admin/tasks/stream", s.apiAdmin(s.apiTaskStream))
	mux.HandleFunc("GET /api/admin/focus/stream", s.apiAdmin(s.apiFocusStream))
	mux.HandleFunc("POST /api/admin/notifications/read", s.apiAdmin(s.apiNotificationsRead))
	mux.HandleFunc("POST /api/admin/notifications/{id}/snooze", s.apiAdmin(s.apiSnoozeNotification))
	mux.HandleFunc("GET /api/admin/users", s.apiAdmin(s.apiUsers))
	mux.HandleFunc("POST /api/admin/users", s.apiAdmin(s.apiCreateUser))
	mux.HandleFunc("GET /api/admin/users/{id}", s.apiAdmin(s.apiUserDetail))
	mux.HandleFunc("PATCH /api/admin/users/{id}", s.apiAdmin(s.apiUpdateUser))
	mux.HandleFunc("DELETE /api/admin/users/{id}", s.apiAdmin(s.apiDeleteUser))
	mux.HandleFunc("POST /api/admin/users/{id}/calendars", s.apiAdmin(s.apiCreateCalendar))
	mux.HandleFunc("GET /api/admin/calendars/{id}", s.apiAdmin(s.apiCalendarDetail))
	mux.HandleFunc("PATCH /api/admin/calendars/{id}", s.apiAdmin(s.apiUpdateCalendar))
	mux.HandleFunc("DELETE /api/admin/calendars/{id}", s.apiAdmin(s.apiDeleteCalendar))
	mux.HandleFunc("POST /api/admin/calendars/{id}/events", s.apiAdmin(s.apiCreateEvent))
	mux.HandleFunc("GET /api/admin/calendars/{id}/events/{name}", s.apiAdmin(s.apiEventDetail))
	mux.HandleFunc("PUT /api/admin/calendars/{id}/events/{name}", s.apiAdmin(s.apiUpdateEvent))
	mux.HandleFunc("PATCH /api/admin/calendars/{id}/events/{name}", s.apiAdmin(s.apiPatchEvent))
	mux.HandleFunc("DELETE /api/admin/calendars/{id}/events/{name}", s.apiAdmin(s.apiDeleteEvent))

	// Task workspace.
	mux.HandleFunc("GET /api/admin/calendar-subscriptions", s.apiAdmin(s.apiCalendarSubscriptions))
	mux.HandleFunc("POST /api/admin/calendar-subscriptions", s.apiAdmin(s.apiCalendarSubscriptions))
	mux.HandleFunc("DELETE /api/admin/calendar-subscriptions/{id}", s.apiAdmin(s.apiCalendarSubscription))
	mux.HandleFunc("GET /api/admin/tasks/{id}/attachments", s.apiAdmin(s.apiTaskAttachments))
	mux.HandleFunc("POST /api/admin/tasks/{id}/attachments", s.apiAdmin(s.apiTaskAttachments))
	mux.HandleFunc("GET /api/admin/tasks/{id}/attachments/{attachmentId}", s.apiAdmin(s.apiTaskAttachment))
	mux.HandleFunc("DELETE /api/admin/tasks/{id}/attachments/{attachmentId}", s.apiAdmin(s.apiTaskAttachment))
	mux.HandleFunc("GET /api/admin/task-templates", s.apiAdmin(s.apiTaskTemplates))
	mux.HandleFunc("POST /api/admin/task-templates", s.apiAdmin(s.apiTaskTemplates))
	mux.HandleFunc("DELETE /api/admin/task-templates/{id}", s.apiAdmin(s.apiTaskTemplate))
	mux.HandleFunc("GET /api/admin/tasks", s.apiAdmin(s.apiTaskWorkspace))
	mux.HandleFunc("POST /api/admin/tasks", s.apiAdmin(s.apiCreateTask))
	mux.HandleFunc("PATCH /api/admin/tasks/{id}", s.apiAdmin(s.apiUpdateTask))
	mux.HandleFunc("DELETE /api/admin/tasks/{id}", s.apiAdmin(s.apiDeleteTask))
	mux.HandleFunc("GET /api/admin/tasks/reminders", s.apiAdmin(s.apiTaskReminders))
	mux.HandleFunc("GET /api/admin/tasks/shared", s.apiAdmin(s.apiSharedTasks))
	mux.HandleFunc("GET /api/admin/tasks/{id}/recurrence", s.apiAdmin(s.apiTaskRecurrence))
	mux.HandleFunc("POST /api/admin/tasks/{id}/recurrence/complete", s.apiAdmin(s.apiCompleteTaskOccurrence))
	mux.HandleFunc("POST /api/admin/tasks/{id}/recurrence/skip", s.apiAdmin(s.apiSkipTaskOccurrence))
	mux.HandleFunc("POST /api/admin/tasks/{id}/recurrence/postpone", s.apiAdmin(s.apiPostponeTaskOccurrence))
	mux.HandleFunc("GET /api/admin/tasks/{id}/shares", s.apiAdmin(s.apiTaskShares))
	mux.HandleFunc("POST /api/admin/tasks/{id}/shares", s.apiAdmin(s.apiTaskShares))
	mux.HandleFunc("DELETE /api/admin/tasks/{id}/shares/{userId}", s.apiAdmin(s.apiTaskShare))
	mux.HandleFunc("GET /api/admin/tasks/{id}/activities", s.apiAdmin(s.apiTaskActivities))
	mux.HandleFunc("GET /api/admin/tasks/{id}/comments", s.apiAdmin(s.apiTaskComments))
	mux.HandleFunc("POST /api/admin/tasks/{id}/comments", s.apiAdmin(s.apiTaskComments))
	mux.HandleFunc("PATCH /api/admin/tasks/{id}/comments/{commentId}", s.apiAdmin(s.apiUpdateTaskComment))
	mux.HandleFunc("DELETE /api/admin/tasks/{id}/comments/{commentId}", s.apiAdmin(s.apiDeleteTaskComment))
	mux.HandleFunc("POST /api/admin/tasks/{id}/comments/{commentId}/attachments", s.apiAdmin(s.apiCommentAttachments))
	mux.HandleFunc("GET /api/admin/tasks/{id}/comments/{commentId}/attachments/{attachmentId}", s.apiAdmin(s.apiCommentAttachment))
	mux.HandleFunc("DELETE /api/admin/tasks/{id}/comments/{commentId}/attachments/{attachmentId}", s.apiAdmin(s.apiCommentAttachment))
	mux.HandleFunc("GET /api/admin/tasks/push/public-key", s.apiAdmin(s.apiPushPublicKey))
	mux.HandleFunc("GET /api/admin/tasks/push/subscriptions", s.apiAdmin(s.apiPushSubscriptions))
	mux.HandleFunc("POST /api/admin/tasks/push/subscribe", s.apiAdmin(s.apiPushSubscribe))
	mux.HandleFunc("DELETE /api/admin/tasks/push/subscribe", s.apiAdmin(s.apiUnsubscribePush))
	mux.HandleFunc("GET /api/admin/tasks/notifications/email", s.apiAdmin(s.apiEmailSettings))
	mux.HandleFunc("PUT /api/admin/tasks/notifications/email", s.apiAdmin(s.apiEmailSettings))
	mux.HandleFunc("POST /api/admin/tasks/notifications/email/test", s.apiAdmin(s.apiTestEmail))
	mux.HandleFunc("GET /api/admin/tasks/calendar", s.apiAdmin(s.apiTaskCalendarEvents))
	mux.HandleFunc("GET /api/admin/tasks/stats", s.apiAdmin(s.apiTaskStats))
	mux.HandleFunc("GET /api/admin/tasks/summary", s.apiAdmin(s.apiTaskSummary))
	mux.HandleFunc("GET /api/admin/task-summary-documents", s.apiAdmin(s.apiSummaryDocuments))
	mux.HandleFunc("POST /api/admin/task-summary-documents", s.apiAdmin(s.apiSummaryDocuments))
	mux.HandleFunc("PATCH /api/admin/task-summary-documents/{id}", s.apiAdmin(s.apiSummaryDocument))
	mux.HandleFunc("DELETE /api/admin/task-summary-documents/{id}", s.apiAdmin(s.apiSummaryDocument))
	mux.HandleFunc("POST /api/admin/tasks/summary/optimize", s.apiAdmin(s.apiOptimizeSummary))
	mux.HandleFunc("GET /api/admin/tasks/ai/settings", s.apiAdmin(s.apiAISettings))
	mux.HandleFunc("PUT /api/admin/tasks/ai/settings", s.apiAdmin(s.apiAISettings))
	mux.HandleFunc("POST /api/admin/tasks/ai/models", s.apiAdmin(s.apiAIModels))
	mux.HandleFunc("POST /api/admin/tasks/ai/test", s.apiAdmin(s.apiAITestModel))
	mux.HandleFunc("POST /api/admin/tasks/ai/chat", s.apiAdmin(s.apiAIChat))
	mux.HandleFunc("POST /api/admin/tasks/ai/chat/stream", s.apiAdmin(s.apiAIChatStream))
	mux.HandleFunc("POST /api/admin/tasks/batch", s.apiAdmin(s.apiBatchTasks))
	mux.HandleFunc("POST /api/admin/tasks/reorder", s.apiAdmin(s.apiReorderTasks))
	mux.HandleFunc("POST /api/admin/tasks/{id}/restore", s.apiAdmin(s.apiRestoreTask))
	mux.HandleFunc("DELETE /api/admin/tasks/{id}/purge", s.apiAdmin(s.apiPurgeTask))
	mux.HandleFunc("DELETE /api/admin/tasks/trash", s.apiAdmin(s.apiEmptyTrash))
	mux.HandleFunc("POST /api/admin/task-folders", s.apiAdmin(s.apiCreateTaskFolder))
	mux.HandleFunc("PATCH /api/admin/task-folders/{id}", s.apiAdmin(s.apiUpdateTaskFolder))
	mux.HandleFunc("DELETE /api/admin/task-folders/{id}", s.apiAdmin(s.apiDeleteTaskFolder))
	mux.HandleFunc("GET /api/admin/task-tags", s.apiAdmin(s.apiTaskTags))
	mux.HandleFunc("POST /api/admin/task-tags/rename", s.apiAdmin(s.apiRenameTaskTag))
	mux.HandleFunc("PUT /api/admin/task-tags/color", s.apiAdmin(s.apiTaskTagColor))
	mux.HandleFunc("POST /api/admin/task-tags/delete", s.apiAdmin(s.apiDeleteTaskTag))
	mux.HandleFunc("GET /api/admin/countdowns", s.apiAdmin(s.apiCountdowns))
	mux.HandleFunc("POST /api/admin/countdowns", s.apiAdmin(s.apiCountdowns))
	mux.HandleFunc("POST /api/admin/countdowns/reorder", s.apiAdmin(s.apiCountdownReorder))
	mux.HandleFunc("PATCH /api/admin/countdowns/{id}", s.apiAdmin(s.apiCountdown))
	mux.HandleFunc("DELETE /api/admin/countdowns/{id}", s.apiAdmin(s.apiCountdown))
	mux.HandleFunc("GET /api/admin/countdowns/{id}/background", s.apiAdmin(s.apiCountdownBackground))
	mux.HandleFunc("POST /api/admin/countdowns/{id}/background", s.apiAdmin(s.apiCountdownBackground))
	mux.HandleFunc("DELETE /api/admin/countdowns/{id}/background", s.apiAdmin(s.apiCountdownBackground))
	mux.HandleFunc("GET /api/admin/focus", s.apiAdmin(s.apiFocus))
	mux.HandleFunc("PATCH /api/admin/focus/preferences", s.apiAdmin(s.apiFocusPreferences))
	mux.HandleFunc("GET /api/admin/focus/stats", s.apiAdmin(s.apiFocusStats))
	mux.HandleFunc("GET /api/admin/focus/timer", s.apiAdmin(s.apiFocusTimer))
	mux.HandleFunc("PUT /api/admin/focus/timer", s.apiAdmin(s.apiFocusTimer))
	mux.HandleFunc("DELETE /api/admin/focus/timer", s.apiAdmin(s.apiFocusTimer))
	mux.HandleFunc("POST /api/admin/focus/sessions", s.apiAdmin(s.apiFocusSessions))
	mux.HandleFunc("DELETE /api/admin/focus/sessions/{id}", s.apiAdmin(s.apiFocusSession))
	mux.HandleFunc("GET /api/admin/habits", s.apiAdmin(s.apiHabits))
	mux.HandleFunc("POST /api/admin/habits", s.apiAdmin(s.apiHabits))
	mux.HandleFunc("GET /api/admin/habits/export", s.apiAdmin(s.apiHabitExport))
	mux.HandleFunc("GET /api/admin/habits/calendar", s.apiAdmin(s.apiHabitCalendar))
	mux.HandleFunc("POST /api/admin/habits/import", s.apiAdmin(s.apiHabitImport))
	mux.HandleFunc("POST /api/admin/habits/import-dida", s.apiAdmin(s.apiHabitImportDida))
	mux.HandleFunc("POST /api/admin/habits/reorder", s.apiAdmin(s.apiHabitReorder))
	mux.HandleFunc("POST /api/admin/habits/checkins/query", s.apiAdmin(s.apiHabitCheckinsQuery))
	mux.HandleFunc("PATCH /api/admin/habits/{id}", s.apiAdmin(s.apiHabit))
	mux.HandleFunc("DELETE /api/admin/habits/{id}", s.apiAdmin(s.apiHabit))
	mux.HandleFunc("POST /api/admin/habits/{id}/checkin", s.apiAdmin(s.apiHabitCheckin))
	mux.HandleFunc("POST /api/admin/habits/{id}/focus", s.apiAdmin(s.apiHabitFocus))
	mux.HandleFunc("GET /api/admin/habits/{id}/export", s.apiAdmin(s.apiHabitExportByID))
	mux.HandleFunc("POST /api/admin/habits/{id}/share", s.apiAdmin(s.apiHabitShare))
	mux.HandleFunc("DELETE /api/admin/habits/{id}/share", s.apiAdmin(s.apiHabitShare))
	mux.HandleFunc("GET /api/admin/habits/{id}/detail", s.apiAdmin(s.apiHabitDetail))
	mux.HandleFunc("POST /api/admin/habits/{id}/records", s.apiAdmin(s.apiHabitRecords))
	mux.HandleFunc("PATCH /api/admin/habits/{id}/records/{recordId}", s.apiAdmin(s.apiHabitRecord))
	mux.HandleFunc("DELETE /api/admin/habits/{id}/records/{recordId}", s.apiAdmin(s.apiHabitRecord))
	mux.HandleFunc("GET /api/admin/habit-preferences", s.apiAdmin(s.apiHabitPreferences))
	mux.HandleFunc("PATCH /api/admin/habit-preferences", s.apiAdmin(s.apiHabitPreferences))
	mux.HandleFunc("GET /api/admin/habit-sections", s.apiAdmin(s.apiHabitSections))
	mux.HandleFunc("POST /api/admin/habit-sections", s.apiAdmin(s.apiHabitSections))
	mux.HandleFunc("PATCH /api/admin/habit-sections/{id}", s.apiAdmin(s.apiHabitSection))
	mux.HandleFunc("DELETE /api/admin/habit-sections/{id}", s.apiAdmin(s.apiHabitSection))
	mux.HandleFunc("GET /api/admin/task-matrix-templates", s.apiAdmin(s.apiMatrixRuleTemplates))
	mux.HandleFunc("POST /api/admin/task-matrix-templates", s.apiAdmin(s.apiMatrixRuleTemplates))
	mux.HandleFunc("PATCH /api/admin/task-matrix-templates/{id}", s.apiAdmin(s.apiMatrixRuleTemplate))
	mux.HandleFunc("DELETE /api/admin/task-matrix-templates/{id}", s.apiAdmin(s.apiMatrixRuleTemplate))
	mux.HandleFunc("GET /api/admin/task-matrix-views", s.apiAdmin(s.apiMatrixViews))
	mux.HandleFunc("POST /api/admin/task-matrix-views", s.apiAdmin(s.apiMatrixViews))
	mux.HandleFunc("PATCH /api/admin/task-matrix-views/{id}", s.apiAdmin(s.apiMatrixView))
	mux.HandleFunc("DELETE /api/admin/task-matrix-views/{id}", s.apiAdmin(s.apiMatrixView))
	mux.HandleFunc("GET /api/admin/task-filters", s.apiAdmin(s.apiSavedFilters))
	mux.HandleFunc("POST /api/admin/task-filters", s.apiAdmin(s.apiCreateSavedFilter))
	mux.HandleFunc("PATCH /api/admin/task-filters/{id}", s.apiAdmin(s.apiUpdateSavedFilter))
	mux.HandleFunc("DELETE /api/admin/task-filters/{id}", s.apiAdmin(s.apiDeleteSavedFilter))
	mux.HandleFunc("GET /api/admin/task-lists/{id}/members", s.apiAdmin(s.apiTaskListMembers))
	mux.HandleFunc("GET /api/admin/task-lists/{id}/shares", s.apiAdmin(s.apiTaskListShares))
	mux.HandleFunc("POST /api/admin/task-lists/{id}/shares", s.apiAdmin(s.apiTaskListShares))
	mux.HandleFunc("DELETE /api/admin/task-lists/{id}/shares/{userId}", s.apiAdmin(s.apiTaskListShare))
	mux.HandleFunc("POST /api/admin/task-lists", s.apiAdmin(s.apiCreateTaskList))
	mux.HandleFunc("POST /api/admin/task-lists/{id}/copy", s.apiAdmin(s.apiCopyTaskList))
	mux.HandleFunc("GET /api/admin/task-sections", s.apiAdmin(s.apiTaskSections))
	mux.HandleFunc("POST /api/admin/task-sections", s.apiAdmin(s.apiCreateTaskSection))
	mux.HandleFunc("PATCH /api/admin/task-sections/{id}", s.apiAdmin(s.apiUpdateTaskSection))
	mux.HandleFunc("DELETE /api/admin/task-sections/{id}", s.apiAdmin(s.apiDeleteTaskSection))
	mux.HandleFunc("PATCH /api/admin/task-lists/{id}", s.apiAdmin(s.apiUpdateTaskList))
	mux.HandleFunc("DELETE /api/admin/task-lists/{id}", s.apiAdmin(s.apiDeleteTaskList))

	// Vue SPA. Nginx adds an additional Basic Auth layer for this path.
	mux.Handle("/share/", s.spaHandler())
	mux.Handle("/admin/", s.spaHandler())
	mux.HandleFunc("GET /admin", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/admin/", http.StatusMovedPermanently)
	})
}

// ---------------------------------------------------------------- sessions

type session struct {
	UserID  int64
	CSRF    string
	Expires time.Time
}

type sessionStore struct {
	mu sync.Mutex
	m  map[string]*session
}

func newSessionStore() *sessionStore {
	return &sessionStore{m: map[string]*session{}}
}

func (s *sessionStore) create(userID int64) (string, *session) {
	id := auth.RandomToken(32)
	sess := &session{UserID: userID, CSRF: auth.RandomToken(24), Expires: time.Now().Add(12 * time.Hour)}
	s.mu.Lock()
	defer s.mu.Unlock()
	// Opportunistic cleanup.
	if len(s.m) > 1024 {
		now := time.Now()
		for k, v := range s.m {
			if now.After(v.Expires) {
				delete(s.m, k)
			}
		}
	}
	s.m[id] = sess
	return id, sess
}

func (s *sessionStore) get(id string) *session {
	if id == "" {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	sess := s.m[id]
	if sess == nil {
		return nil
	}
	if time.Now().After(sess.Expires) {
		delete(s.m, id)
		return nil
	}
	return sess
}

func (s *sessionStore) destroy(id string) {
	s.mu.Lock()
	delete(s.m, id)
	s.mu.Unlock()
}

type ctxKey int

const (
	ctxUser ctxKey = iota
	ctxSession
)

type loginLimiter struct {
	mu sync.Mutex
	m  map[string]*loginAttempt
}

type loginAttempt struct {
	count int
	until time.Time
}

func newLoginLimiter() *loginLimiter {
	return &loginLimiter{m: map[string]*loginAttempt{}}
}

func (l *loginLimiter) allowed(ip string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	a := l.m[ip]
	if a == nil {
		return true
	}
	if time.Now().After(a.until) {
		delete(l.m, ip)
		return true
	}
	return a.count < 10
}

func (l *loginLimiter) fail(ip string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	a := l.m[ip]
	if a == nil {
		a = &loginAttempt{}
		l.m[ip] = a
	}
	a.count++
	if a.count >= 10 {
		a.until = time.Now().Add(5 * time.Minute)
	}
}

func (l *loginLimiter) reset(ip string) {
	l.mu.Lock()
	delete(l.m, ip)
	l.mu.Unlock()
}

type publicRateLimiter struct {
	mu     sync.Mutex
	m      map[string]*publicRateBucket
	limit  int
	window time.Duration
}

type publicRateBucket struct {
	count int
	reset time.Time
}

func newPublicRateLimiter(limit int, window time.Duration) *publicRateLimiter {
	if limit <= 0 {
		limit = 60
	}
	if window <= 0 {
		window = time.Minute
	}
	return &publicRateLimiter{m: map[string]*publicRateBucket{}, limit: limit, window: window}
}

func (l *publicRateLimiter) allow(key string) (bool, time.Duration) {
	now := time.Now()
	l.mu.Lock()
	defer l.mu.Unlock()
	bucket := l.m[key]
	if bucket == nil || now.After(bucket.reset) {
		if bucket == nil && len(l.m) >= 4096 {
			for k, v := range l.m {
				if now.After(v.reset) {
					delete(l.m, k)
				}
			}
		}
		bucket = &publicRateBucket{reset: now.Add(l.window)}
		l.m[key] = bucket
	}
	if bucket.count >= l.limit {
		return false, time.Until(bucket.reset)
	}
	bucket.count++
	return true, 0
}

// ---------------------------------------------------------------- middleware

func (s *Server) current(r *http.Request) (*store.User, *session, bool) {
	cookie, err := r.Cookie(sessionCookie)
	if err != nil {
		return nil, nil, false
	}
	sess := s.sessions.get(cookie.Value)
	if sess == nil {
		return nil, nil, false
	}
	u, err := s.store.GetUser(r.Context(), sess.UserID)
	if err != nil {
		return nil, nil, false
	}
	return u, sess, true
}

func (s *Server) requireAdmin(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		user, sess, ok := s.current(r)
		if !ok {
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}
		if !user.IsAdmin {
			s.render(w, r, http.StatusForbidden, "layout", pageData{
				Title: "无访问权限",
				Page:  "error",
				User:  user,
				CSRF:  sess.CSRF,
				Error: "管理界面仅对管理员开放。请使用 CalDAV 客户端连接你的账户。",
			})
			return
		}
		ctx := context.WithValue(r.Context(), ctxUser, user)
		ctx = context.WithValue(ctx, ctxSession, sess)
		next(w, r.WithContext(ctx))
	}
}

func userFrom(r *http.Request) *store.User {
	u, _ := r.Context().Value(ctxUser).(*store.User)
	return u
}

func sessionFrom(r *http.Request) *session {
	s, _ := r.Context().Value(ctxSession).(*session)
	return s
}

func (s *Server) verifyCSRF(w http.ResponseWriter, r *http.Request, sess *session) bool {
	if r.FormValue("csrf") != sess.CSRF {
		http.Error(w, "CSRF token mismatch", http.StatusForbidden)
		return false
	}
	return true
}

// ---------------------------------------------------------------- rendering

type pageData struct {
	Title      string
	Active     string
	Page       string
	User       *store.User
	CSRF       string
	BaseURL    string
	Flash      string
	Error      string
	Stats      *dashboardStats
	Users      []*userRow
	UserDetail *store.User
	Calendars  []*calendarRow
	Calendar   *store.Calendar
	Owner      *store.User
	Events     []*eventRow
	EditEvent  *store.Object
	EventName  string
	EventData  string
	Timezones  []string
	AdminCount int64
	IsSelf     bool
}

func (s *Server) render(w http.ResponseWriter, r *http.Request, status int, name string, data pageData) {
	data.BaseURL = s.baseURL(r)
	if data.Flash == "" {
		data.Flash = truncate(r.URL.Query().Get("ok"), 200)
	}
	if data.Error == "" {
		data.Error = truncate(r.URL.Query().Get("err"), 300)
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("X-Frame-Options", "DENY")
	w.Header().Set("Referrer-Policy", "same-origin")
	w.Header().Set("Content-Security-Policy", "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; script-src 'self'; form-action 'self'; frame-ancestors 'none'")
	w.WriteHeader(status)
	if err := s.templates.ExecuteTemplate(w, name, data); err != nil {
		s.logger.Error("render template", "template", name, "error", err)
	}
}

func (s *Server) baseURL(r *http.Request) string {
	if s.externalURL != "" {
		return s.externalURL
	}
	scheme := "http"
	if r.TLS != nil || strings.EqualFold(r.Header.Get("X-Forwarded-Proto"), "https") {
		scheme = "https"
	}
	host := r.Host
	if fwd := r.Header.Get("X-Forwarded-Host"); fwd != "" {
		host = fwd
	}
	return scheme + "://" + host
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}

func formatDateTime(t time.Time) string {
	if t.IsZero() {
		return "—"
	}
	return t.Format("2006-01-02 15:04")
}

func formatDate(t time.Time) string {
	if t.IsZero() {
		return "—"
	}
	return t.Format("2006-01-02")
}

func initials(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return "?"
	}
	parts := strings.Fields(name)
	if len(parts) == 1 {
		r := []rune(parts[0])
		if len(r) > 1 {
			return strings.ToUpper(string(r[0]))
		}
		return strings.ToUpper(parts[0])
	}
	out := ""
	for _, p := range parts {
		r := []rune(p)
		if len(r) > 0 {
			out += strings.ToUpper(string(r[0]))
		}
		if len([]rune(out)) >= 2 {
			break
		}
	}
	return out
}

func redirectWith(w http.ResponseWriter, r *http.Request, path, ok, errMsg string) {
	q := url.Values{}
	if ok != "" {
		q.Set("ok", ok)
	}
	if errMsg != "" {
		q.Set("err", errMsg)
	}
	if len(q) > 0 {
		path += "?" + q.Encode()
	}
	http.Redirect(w, r, path, http.StatusSeeOther)
}

// ---------------------------------------------------------------- login

func (s *Server) handleRoot(w http.ResponseWriter, r *http.Request) {
	if _, _, ok := s.current(r); ok {
		http.Redirect(w, r, "/admin", http.StatusSeeOther)
		return
	}
	s.render(w, r, http.StatusOK, "landing", pageData{Title: "caldav-free"})
}

func (s *Server) handleLoginGet(w http.ResponseWriter, r *http.Request) {
	if _, _, ok := s.current(r); ok {
		http.Redirect(w, r, "/admin", http.StatusSeeOther)
		return
	}
	s.render(w, r, http.StatusOK, "login", pageData{Title: "登录"})
}

func (s *Server) handleLoginPost(w http.ResponseWriter, r *http.Request) {
	ip := clientIP(r)
	if !s.limiter.allowed(ip) {
		redirectWith(w, r, "/login", "", "尝试次数过多，请 5 分钟后再试")
		return
	}
	username := strings.TrimSpace(r.FormValue("username"))
	password := r.FormValue("password")
	u, err := s.store.GetUserByUsername(r.Context(), username)
	if err != nil {
		auth.VerifyPassword(password, dummyAdminHash)
		s.limiter.fail(ip)
		redirectWith(w, r, "/login", "", "用户名或密码错误")
		return
	}
	if !auth.VerifyPassword(password, u.PasswordHash) {
		s.limiter.fail(ip)
		redirectWith(w, r, "/login", "", "用户名或密码错误")
		return
	}
	if !u.IsAdmin {
		s.limiter.fail(ip)
		redirectWith(w, r, "/login", "", "该账号不是管理员")
		return
	}
	s.limiter.reset(ip)
	id, sess := s.sessions.create(u.ID)
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookie,
		Value:    id,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   s.isSecure(r),
		MaxAge:   int((12 * time.Hour).Seconds()),
	})
	_ = sess
	http.Redirect(w, r, "/admin", http.StatusSeeOther)
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	sess := sessionFrom(r)
	if sess == nil || !s.verifyCSRF(w, r, sess) {
		return
	}
	if cookie, err := r.Cookie(sessionCookie); err == nil {
		s.sessions.destroy(cookie.Value)
	}
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookie,
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		MaxAge:   -1,
		Secure:   s.isSecure(r),
	})
	http.Redirect(w, r, "/login", http.StatusSeeOther)
}

func (s *Server) isSecure(r *http.Request) bool {
	return r.TLS != nil || strings.EqualFold(r.Header.Get("X-Forwarded-Proto"), "https")
}

func clientIP(r *http.Request) string {
	if fwd := r.Header.Get("X-Forwarded-For"); fwd != "" {
		parts := strings.Split(fwd, ",")
		return strings.TrimSpace(parts[0])
	}
	host := r.RemoteAddr
	if i := strings.LastIndex(host, ":"); i >= 0 {
		host = host[:i]
	}
	return host
}

// ---------------------------------------------------------------- dashboard

type dashboardStats struct {
	Users     int64
	Calendars int64
	Objects   int64
}

type userRow struct {
	User      *store.User
	Calendars int64
	Objects   int64
	Created   string
}

type calendarRow struct {
	Calendar *store.Calendar
	Owner    *store.User
	Count    int64
}

type eventRow struct {
	Href      string
	UID       string
	Summary   string
	Location  string
	Start     time.Time
	End       time.Time
	AllDay    bool
	Recurring bool
	Size      int64
}

func (s *Server) handleDashboard(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user := userFrom(r)
	stats := &dashboardStats{}
	stats.Users, _ = s.store.CountUsers(ctx)
	stats.Calendars, _ = s.store.CountAllCalendars(ctx)
	stats.Objects, _ = s.store.CountAllObjects(ctx)
	users, err := s.store.ListUsers(ctx)
	if err != nil {
		s.serverError(w, r, err)
		return
	}
	rows := make([]*userRow, 0, len(users))
	for _, u := range users {
		cals, _ := s.store.CountCalendars(ctx, u.ID)
		var objects int64
		list, _ := s.store.ListCalendars(ctx, u.ID)
		for _, cal := range list {
			n, _ := s.store.CountObjects(ctx, cal.ID)
			objects += n
		}
		rows = append(rows, &userRow{
			User:      u,
			Calendars: cals,
			Objects:   objects,
			Created:   formatDate(u.CreatedAt),
		})
	}
	s.render(w, r, http.StatusOK, "layout", pageData{
		Title:  "控制台",
		Active: "dashboard",
		Page:   "dashboard",
		User:   user,
		CSRF:   sessionFrom(r).CSRF,
		Stats:  stats,
		Users:  rows,
	})
}

func (s *Server) handleUsers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	users, err := s.store.ListUsers(ctx)
	if err != nil {
		s.serverError(w, r, err)
		return
	}
	rows := make([]*userRow, 0, len(users))
	var admins int64
	for _, u := range users {
		if u.IsAdmin {
			admins++
		}
		cals, _ := s.store.CountCalendars(ctx, u.ID)
		rows = append(rows, &userRow{User: u, Calendars: cals, Created: formatDate(u.CreatedAt)})
	}
	s.render(w, r, http.StatusOK, "layout", pageData{
		Title:      "用户",
		Active:     "users",
		Page:       "users",
		User:       userFrom(r),
		CSRF:       sessionFrom(r).CSRF,
		Users:      rows,
		AdminCount: admins,
	})
}

func (s *Server) handleUser(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	ctx := r.Context()
	u, err := s.store.GetUser(ctx, id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	cals, err := s.store.ListCalendars(ctx, u.ID)
	if err != nil {
		s.serverError(w, r, err)
		return
	}
	rows := make([]*calendarRow, 0, len(cals))
	for _, cal := range cals {
		count, _ := s.store.CountObjects(ctx, cal.ID)
		rows = append(rows, &calendarRow{Calendar: cal, Owner: u, Count: count})
	}
	all, _ := s.store.ListUsers(ctx)
	var admins int64
	for _, other := range all {
		if other.IsAdmin {
			admins++
		}
	}
	s.render(w, r, http.StatusOK, "layout", pageData{
		Title:      "用户 · " + u.Username,
		Active:     "users",
		Page:       "user",
		User:       userFrom(r),
		CSRF:       sessionFrom(r).CSRF,
		UserDetail: u,
		Calendars:  rows,
		Timezones:  timezones(),
		AdminCount: admins,
		IsSelf:     u.ID == userFrom(r).ID,
	})
}

func (s *Server) handleCalendar(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	owner, err := s.store.GetUser(ctx, cal.UserID)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	objs, err := s.store.ListObjects(ctx, cal.ID)
	if err != nil {
		s.serverError(w, r, err)
		return
	}
	events := make([]*eventRow, 0, len(objs))
	for _, obj := range objs {
		row := &eventRow{Href: obj.Href, UID: obj.UID, Size: obj.Size, Recurring: obj.Recurring}
		if parsed, err := ical.Load(obj.Data, cal.Timezone); err == nil {
			if ev := parsed.Root.Child("VEVENT"); ev != nil {
				row.Summary = ical.UnescapeText(ev.Value("SUMMARY"))
				row.Location = ical.UnescapeText(ev.Value("LOCATION"))
				if start, end, allDay, err := parsed.ComponentTimes(ev); err == nil {
					row.Start, row.End, row.AllDay = start, end, allDay
				}
			}
		}
		if row.Summary == "" {
			row.Summary = obj.UID
		}
		events = append(events, row)
	}
	sort.SliceStable(events, func(i, j int) bool {
		if events[i].Start.IsZero() {
			return false
		}
		if events[j].Start.IsZero() {
			return true
		}
		return events[i].Start.Before(events[j].Start)
	})
	s.render(w, r, http.StatusOK, "layout", pageData{
		Title:     cal.DisplayName,
		Active:    "users",
		Page:      "calendar",
		User:      userFrom(r),
		CSRF:      sessionFrom(r).CSRF,
		Calendar:  cal,
		Owner:     owner,
		Events:    events,
		Timezones: timezones(),
	})
}

func timezones() []string {
	base := []string{
		"Asia/Shanghai",
		"UTC",
		"Asia/Hong_Kong",
		"Asia/Taipei",
		"Asia/Tokyo",
		"Asia/Singapore",
		"Asia/Kolkata",
		"Europe/London",
		"Europe/Paris",
		"Europe/Berlin",
		"Europe/Moscow",
		"America/New_York",
		"America/Chicago",
		"America/Denver",
		"America/Los_Angeles",
		"America/Sao_Paulo",
		"Australia/Sydney",
		"Pacific/Auckland",
	}
	return base
}

// ---------------------------------------------------------------- mutations

func (s *Server) handleCreateUser(w http.ResponseWriter, r *http.Request) {
	if !s.verifyCSRF(w, r, sessionFrom(r)) {
		return
	}
	username := strings.ToLower(strings.TrimSpace(r.FormValue("username")))
	displayName := strings.TrimSpace(r.FormValue("display_name"))
	email := strings.TrimSpace(r.FormValue("email"))
	password := r.FormValue("password")
	if !validUsername(username) {
		redirectWith(w, r, "/admin/users", "", "用户名需为 2-64 位小写字母、数字、点、下划线或连字符")
		return
	}
	if len(password) < 8 {
		redirectWith(w, r, "/admin/users", "", "密码至少 8 位")
		return
	}
	hash, err := auth.HashPassword(password)
	if err != nil {
		redirectWith(w, r, "/admin/users", "", "密码处理失败")
		return
	}
	_, err = s.store.CreateUser(r.Context(), username, displayName, email, hash, r.FormValue("is_admin") == "on")
	if err == store.ErrConflict {
		redirectWith(w, r, "/admin/users", "", "用户名已存在")
		return
	}
	if err != nil {
		s.serverError(w, r, err)
		return
	}
	redirectWith(w, r, "/admin/users", "用户 "+username+" 已创建", "")
}

func (s *Server) handleUpdateUser(w http.ResponseWriter, r *http.Request) {
	if !s.verifyCSRF(w, r, sessionFrom(r)) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	ctx := r.Context()
	u, err := s.store.GetUser(ctx, id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	displayName := strings.TrimSpace(r.FormValue("display_name"))
	email := strings.TrimSpace(r.FormValue("email"))
	isAdmin := r.FormValue("is_admin") == "on"
	if u.IsAdmin && !isAdmin {
		admins, _ := s.countAdmins(ctx)
		if admins <= 1 {
			redirectWith(w, r, fmt.Sprintf("/admin/users/%d", id), "", "不能移除最后一个管理员")
			return
		}
	}
	password := r.FormValue("password")
	hash := ""
	if password != "" {
		if len(password) < 8 {
			redirectWith(w, r, fmt.Sprintf("/admin/users/%d", id), "", "新密码至少 8 位")
			return
		}
		hash, err = auth.HashPassword(password)
		if err != nil {
			s.serverError(w, r, err)
			return
		}
	}
	if err := s.store.UpdateUser(ctx, id, displayName, email, isAdmin, hash); err != nil {
		s.serverError(w, r, err)
		return
	}
	if hash != "" {
		s.dav.InvalidateCredentials()
	}
	redirectWith(w, r, fmt.Sprintf("/admin/users/%d", id), "资料已更新", "")
}

func (s *Server) handleDeleteUser(w http.ResponseWriter, r *http.Request) {
	if !s.verifyCSRF(w, r, sessionFrom(r)) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	current := userFrom(r)
	if id == current.ID {
		redirectWith(w, r, "/admin/users", "", "不能删除当前登录的账号")
		return
	}
	ctx := r.Context()
	u, err := s.store.GetUser(ctx, id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	if u.IsAdmin {
		admins, _ := s.countAdmins(ctx)
		if admins <= 1 {
			redirectWith(w, r, "/admin/users", "", "不能删除最后一个管理员")
			return
		}
	}
	if err := s.store.DeleteUser(ctx, id); err != nil {
		s.serverError(w, r, err)
		return
	}
	s.dav.InvalidateCredentials()
	redirectWith(w, r, "/admin/users", "用户已删除", "")
}

func (s *Server) handleCreateCalendar(w http.ResponseWriter, r *http.Request) {
	if !s.verifyCSRF(w, r, sessionFrom(r)) {
		return
	}
	userID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	slug := strings.TrimSpace(r.FormValue("slug"))
	displayName := strings.TrimSpace(r.FormValue("display_name"))
	timezone := strings.TrimSpace(r.FormValue("timezone"))
	if timezone == "" {
		timezone = store.DefaultTimezone
	}
	if canonical, ok := ical.CanonicalTZID(timezone); ok {
		timezone = canonical
	} else {
		redirectWith(w, r, fmt.Sprintf("/admin/users/%d", userID), "", "无效的时区")
		return
	}
	if !validSlug(slug) {
		redirectWith(w, r, fmt.Sprintf("/admin/users/%d", userID), "", "日历标识需为 2-64 位字母、数字、点、下划线或连字符")
		return
	}
	if displayName == "" {
		displayName = slug
	}
	_, err = s.store.CreateCalendar(r.Context(), userID, slug, displayName, "", "#3366CC", timezone, 0, nil)
	if err == store.ErrConflict {
		redirectWith(w, r, fmt.Sprintf("/admin/users/%d", userID), "", "该用户已有同名日历")
		return
	}
	if err != nil {
		s.serverError(w, r, err)
		return
	}
	redirectWith(w, r, fmt.Sprintf("/admin/users/%d", userID), "日历已创建", "")
}

func (s *Server) handleUpdateCalendar(w http.ResponseWriter, r *http.Request) {
	if !s.verifyCSRF(w, r, sessionFrom(r)) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	displayName := strings.TrimSpace(r.FormValue("display_name"))
	if displayName == "" {
		displayName = cal.Slug
	}
	description := strings.TrimSpace(r.FormValue("description"))
	color := strings.TrimSpace(r.FormValue("color"))
	timezone := strings.TrimSpace(r.FormValue("timezone"))
	if timezone == "" {
		timezone = cal.Timezone
	}
	if canonical, ok := ical.CanonicalTZID(timezone); ok {
		timezone = canonical
	} else {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "", "无效的时区")
		return
	}
	order, _ := strconv.Atoi(r.FormValue("order"))
	var components []string
	for _, key := range []string{"VEVENT", "VTODO", "VJOURNAL"} {
		if r.FormValue("comp_"+key) == "on" {
			components = append(components, key)
		}
	}
	if len(components) == 0 {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "", "至少选择一种组件类型")
		return
	}
	if err := s.store.UpdateCalendar(ctx, id, displayName, description, color, timezone, order, components); err != nil {
		s.serverError(w, r, err)
		return
	}
	if timezone != cal.Timezone {
		_ = s.store.SetCalendarTimezoneData(ctx, id, "")
	}
	redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "日历设置已保存", "")
}

func (s *Server) handleDeleteCalendar(w http.ResponseWriter, r *http.Request) {
	if !s.verifyCSRF(w, r, sessionFrom(r)) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	if err := s.store.DeleteCalendar(ctx, id); err != nil {
		s.serverError(w, r, err)
		return
	}
	redirectWith(w, r, fmt.Sprintf("/admin/users/%d", cal.UserID), "日历已删除", "")
}

func (s *Server) handleCreateEvent(w http.ResponseWriter, r *http.Request) {
	if !s.verifyCSRF(w, r, sessionFrom(r)) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	loc, err := time.LoadLocation(cal.Timezone)
	tzid := cal.Timezone
	if err != nil || tzid == "" {
		loc, err = time.LoadLocation(store.DefaultTimezone)
		if err != nil {
			loc = time.UTC
			tzid = "UTC"
		} else {
			tzid = store.DefaultTimezone
		}
	}
	allDay := r.FormValue("all_day") == "on"
	summary := strings.TrimSpace(r.FormValue("summary"))
	if summary == "" {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "", "请填写事件标题")
		return
	}
	if !cal.SupportsComponent("VEVENT") {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "", "该日历未启用 VEVENT 组件")
		return
	}
	start, end, err := parseFormTimes(r, allDay, loc)
	if err != nil {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "", err.Error())
		return
	}

	uid := auth.RandomToken(12) + "@caldav-free"
	root := ical.NewComponent("VCALENDAR")
	root.AddProp("VERSION", "2.0", nil)
	root.AddProp("PRODID", "-//caldav-free//CalDAV Server//EN", nil)
	root.AddProp("CALSCALE", "GREGORIAN", nil)
	ev := ical.NewComponent("VEVENT")
	ev.AddProp("UID", uid, nil)
	ev.AddProp("DTSTAMP", time.Now().UTC().Format("20060102T150405Z"), nil)
	if allDay {
		ev.AddProp("DTSTART", start.Format("20060102"), ical.Params{"VALUE": {"DATE"}})
		ev.AddProp("DTEND", end.Format("20060102"), ical.Params{"VALUE": {"DATE"}})
	} else {
		ev.AddProp("DTSTART", start.Format("20060102T150405"), ical.Params{"TZID": {tzid}})
		ev.AddProp("DTEND", end.Format("20060102T150405"), ical.Params{"TZID": {tzid}})
	}
	ev.AddProp("SUMMARY", ical.EscapeText(summary), nil)
	if description := strings.TrimSpace(r.FormValue("description")); description != "" {
		ev.AddProp("DESCRIPTION", ical.EscapeText(description), nil)
	}
	if location := strings.TrimSpace(r.FormValue("location")); location != "" {
		ev.AddProp("LOCATION", ical.EscapeText(location), nil)
	}
	ev.AddProp("STATUS", "CONFIRMED", nil)
	if freq := strings.ToUpper(strings.TrimSpace(r.FormValue("rrule"))); freq != "" && freq != "NONE" {
		rule := "FREQ=" + freq
		if count := strings.TrimSpace(r.FormValue("count")); count != "" {
			if n, err := strconv.Atoi(count); err == nil && n > 0 {
				rule += fmt.Sprintf(";COUNT=%d", n)
			}
		}
		ev.AddProp("RRULE", rule, nil)
	}
	root.AddChild(ev)
	data := []byte(root.Encode())

	parsed, err := ical.Load(data, cal.Timezone)
	if err != nil {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "", "事件数据无效")
		return
	}
	info, err := parsed.Analyze()
	if err != nil {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "", "事件数据无效："+err.Error())
		return
	}
	obj := &store.Object{
		CalendarID:    cal.ID,
		Href:          strings.ToLower(auth.RandomToken(6)) + ".ics",
		UID:           uid,
		ETag:          hashData(data),
		ContentType:   "text/calendar; charset=utf-8",
		Data:          data,
		ComponentType: info.ComponentType,
		FirstStart:    unixOrZero(info.FirstStart),
		LastEnd:       unixOrZero(info.LastEnd),
		Recurring:     info.Recurring,
		Size:          int64(len(data)),
	}
	if _, _, _, err := s.store.PutObject(ctx, obj); err != nil {
		s.serverError(w, r, err)
		return
	}
	redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "事件已创建", "")
}

func (s *Server) handleDeleteEvent(w http.ResponseWriter, r *http.Request) {
	if !s.verifyCSRF(w, r, sessionFrom(r)) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	name := strings.TrimSpace(r.FormValue("name"))
	if _, ok := validObjectName(name); !ok {
		http.Error(w, "invalid object name", http.StatusBadRequest)
		return
	}
	if _, _, err := s.store.DeleteObject(r.Context(), id, name); err != nil {
		if err == store.ErrNotFound {
			redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "", "事件不存在")
			return
		}
		s.serverError(w, r, err)
		return
	}
	redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "事件已删除", "")
}

func (s *Server) handleRawEvent(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	obj, err := s.store.GetObject(r.Context(), id, r.PathValue("name"))
	if err != nil {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/calendar; charset=utf-8")
	w.Header().Set("Content-Disposition", fmt.Sprintf("inline; filename=%q", obj.Href))
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(obj.Data)
}

func (s *Server) handleEditEvent(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	owner, err := s.store.GetUser(ctx, cal.UserID)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	name := r.PathValue("name")
	obj, err := s.store.GetObject(ctx, id, name)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	s.render(w, r, http.StatusOK, "layout", pageData{
		Title:     "编辑事件 · " + obj.UID,
		Active:    "users",
		Page:      "eventedit",
		User:      userFrom(r),
		CSRF:      sessionFrom(r).CSRF,
		Calendar:  cal,
		Owner:     owner,
		EditEvent: obj,
		EventName: obj.Href,
		EventData: string(obj.Data),
	})
}

func (s *Server) handleUpdateEvent(w http.ResponseWriter, r *http.Request) {
	if !s.verifyCSRF(w, r, sessionFrom(r)) {
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 12<<20)
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	name := strings.TrimSpace(r.FormValue("name"))
	if _, ok := validObjectName(name); !ok {
		http.Error(w, "invalid object name", http.StatusBadRequest)
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	obj, err := s.store.GetObject(ctx, id, name)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	data := []byte(r.FormValue("data"))
	if !utf8.Valid(data) || hasControl(data) {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d/events/%s/edit", id, url.PathEscape(name)), "", "ICS 内容包含无效字符")
		return
	}
	parsed, err := ical.Load(data, cal.Timezone)
	if err != nil {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d/events/%s/edit", id, url.PathEscape(name)), "", "日历数据无法解析："+err.Error())
		return
	}
	info, err := parsed.Analyze()
	if err != nil {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d/events/%s/edit", id, url.PathEscape(name)), "", "日历数据无效："+err.Error())
		return
	}
	if !cal.SupportsComponent(info.ComponentType) {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d/events/%s/edit", id, url.PathEscape(name)), "", "该日历不支持 "+info.ComponentType)
		return
	}
	if other, err := s.store.GetObjectByUID(ctx, cal.ID, info.UID); err == nil && other.Href != name {
		redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d/events/%s/edit", id, url.PathEscape(name)), "", "UID 已被另一个事件使用")
		return
	}
	obj.Data = data
	obj.UID = info.UID
	obj.ETag = hashData(data)
	obj.ComponentType = info.ComponentType
	obj.FirstStart = unixOrZero(info.FirstStart)
	obj.LastEnd = unixOrZero(info.LastEnd)
	obj.Recurring = info.Recurring
	obj.Size = int64(len(data))
	if _, _, _, err := s.store.PutObject(ctx, obj); err != nil {
		s.serverError(w, r, err)
		return
	}
	redirectWith(w, r, fmt.Sprintf("/admin/calendars/%d", id), "事件已保存", "")
}

func hasControl(data []byte) bool {
	for _, b := range data {
		if b < 0x20 && b != '\t' && b != '\n' && b != '\r' {
			return true
		}
	}
	return false
}

// ---------------------------------------------------------------- helpers

func (s *Server) countAdmins(ctx context.Context) (int64, error) {
	users, err := s.store.ListUsers(ctx)
	if err != nil {
		return 0, err
	}
	var n int64
	for _, u := range users {
		if u.IsAdmin {
			n++
		}
	}
	return n, nil
}

func (s *Server) serverError(w http.ResponseWriter, r *http.Request, err error) {
	s.logger.Error("admin request failed", "path", r.URL.Path, "error", err)
	csrf := ""
	if sess := sessionFrom(r); sess != nil {
		csrf = sess.CSRF
	}
	s.render(w, r, http.StatusInternalServerError, "layout", pageData{
		Title: "服务器错误",
		Page:  "error",
		User:  userFrom(r),
		CSRF:  csrf,
		Error: "操作失败，请稍后重试。",
	})
}

func validUsername(name string) bool {
	if len(name) < 2 || len(name) > 64 {
		return false
	}
	for _, r := range name {
		switch {
		case r >= 'a' && r <= 'z':
		case r >= '0' && r <= '9':
		case r == '.' || r == '_' || r == '-':
		default:
			return false
		}
	}
	return true
}

func validSlug(slug string) bool {
	if len(slug) < 2 || len(slug) > 64 {
		return false
	}
	for _, r := range slug {
		switch {
		case r >= 'a' && r <= 'z':
		case r >= 'A' && r <= 'Z':
		case r >= '0' && r <= '9':
		case r == '.' || r == '_' || r == '-':
		default:
			return false
		}
	}
	return strings.Trim(slug, ".-_") != ""
}

func validObjectName(name string) (string, bool) {
	if name == "" || len(name) > 200 || name == "." || name == ".." {
		return "", false
	}
	if strings.ContainsAny(name, "/\\\x00") {
		return "", false
	}
	for _, r := range name {
		if r < 0x20 || r == 0x7f {
			return "", false
		}
	}
	return name, true
}

func parseFormTimes(r *http.Request, allDay bool, loc *time.Location) (time.Time, time.Time, error) {
	startRaw := strings.TrimSpace(r.FormValue("start"))
	endRaw := strings.TrimSpace(r.FormValue("end"))
	if startRaw == "" {
		return time.Time{}, time.Time{}, fmt.Errorf("请填写开始时间")
	}
	if allDay {
		if len(startRaw) > 10 {
			startRaw = startRaw[:10]
		}
		start, err := time.ParseInLocation("2006-01-02", startRaw, loc)
		if err != nil {
			return time.Time{}, time.Time{}, fmt.Errorf("开始日期格式无效")
		}
		end := start.AddDate(0, 0, 1)
		if endRaw != "" {
			if len(endRaw) > 10 {
				endRaw = endRaw[:10]
			}
			parsed, err := time.ParseInLocation("2006-01-02", endRaw, loc)
			if err != nil {
				return time.Time{}, time.Time{}, fmt.Errorf("结束日期格式无效")
			}
			if !parsed.After(start) {
				parsed = start.AddDate(0, 0, 1)
			}
			end = parsed
		}
		return start, end, nil
	}
	start, err := time.ParseInLocation("2006-01-02T15:04", startRaw, loc)
	if err != nil {
		return time.Time{}, time.Time{}, fmt.Errorf("开始时间格式无效")
	}
	end := start.Add(time.Hour)
	if endRaw != "" {
		parsed, err := time.ParseInLocation("2006-01-02T15:04", endRaw, loc)
		if err != nil {
			return time.Time{}, time.Time{}, fmt.Errorf("结束时间格式无效")
		}
		if parsed.After(start) {
			end = parsed
		}
	}
	return start, end, nil
}

func unixOrZero(t time.Time) int64 {
	if t.IsZero() {
		return 0
	}
	return t.Unix()
}

func hashData(data []byte) string {
	// Same MD5 ETag scheme as the CalDAV layer.
	sum := md5.Sum(data)
	return hex.EncodeToString(sum[:])
}
