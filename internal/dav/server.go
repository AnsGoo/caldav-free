package dav

import (
	"context"
	"crypto/sha256"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"path"
	"strconv"
	"strings"
	"sync"
	"time"

	"caldav-free/internal/auth"
	"caldav-free/internal/store"
)

const maxBodySize = 12 << 20 // 12 MiB

// dummyPasswordHash equalizes authentication timing for unknown usernames.
var dummyPasswordHash = func() string {
	h, err := auth.HashPassword("caldav-free-dummy-password")
	if err != nil {
		return ""
	}
	return h
}()

// Handler serves the CalDAV/WebDAV endpoint.
type Handler struct {
	Store       *store.Store
	Logger      *slog.Logger
	MaxBodySize int64
	Realm       string
	ExternalURL string

	mu    sync.Mutex
	cache map[[32]byte]cachedCredential
}

type cachedCredential struct {
	userID       int64
	passwordHash string
	expires      time.Time
}

// New creates a CalDAV handler.
func New(st *store.Store, logger *slog.Logger) *Handler {
	if logger == nil {
		logger = slog.Default()
	}
	return &Handler{
		Store:       st,
		Logger:      logger,
		MaxBodySize: maxBodySize,
		Realm:       "CalDAV",
		cache:       map[[32]byte]cachedCredential{},
	}
}

type targetKind int

const (
	targetRoot targetKind = iota
	targetPrincipalCollection
	targetPrincipal
	targetHome
	targetCalendar
	targetObject
)

type target struct {
	kind    targetKind
	user    string
	slug    string
	object  string
	rawPath string
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("DAV", "1, 3, calendar-access, sync-collection")
	w.Header().Set("MS-Author-Via", "DAV")
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")

	if r.URL.Path == "/.well-known/caldav" || r.URL.Path == "/.well-known/caldav/" ||
		r.URL.Path == "/caldav" || r.URL.Path == "/caldav/" ||
		r.URL.Path == "/dav" || r.URL.Path == "/dav/" {
		http.Redirect(w, r, "/", http.StatusMovedPermanently)
		return
	}

	t, ok := parseTarget(r.URL)
	if !ok {
		http.NotFound(w, r)
		return
	}

	if r.Method == http.MethodOptions {
		h.handleOptions(w, r, t)
		return
	}

	user, ok := h.authenticate(r)
	if !ok {
		w.Header().Set("WWW-Authenticate", fmt.Sprintf(`Basic realm=%q`, h.Realm))
		w.Header().Set("Content-Length", "0")
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	ctx := r.Context()
	switch t.kind {
	case targetCalendar:
		if r.Method != "MKCALENDAR" && r.Method != "MKCOL" {
			if _, ok := h.loadCalendar(ctx, t, user); !ok {
				http.NotFound(w, r)
				return
			}
		}
	case targetHome:
		if _, ok := h.loadOwner(ctx, t.user, user); !ok {
			http.NotFound(w, r)
			return
		}
	case targetObject:
		if _, ok := h.loadOwner(ctx, t.user, user); !ok {
			http.NotFound(w, r)
			return
		}
	}

	switch r.Method {
	case "PROPFIND":
		h.handlePropfind(w, r, t, user)
	case "PROPPATCH":
		h.handleProppatch(w, r, t, user)
	case "REPORT":
		h.handleReport(w, r, t, user)
	case http.MethodGet, http.MethodHead:
		h.handleGet(w, r, t, user)
	case http.MethodPut:
		h.handlePut(w, r, t, user)
	case http.MethodDelete:
		h.handleDelete(w, r, t, user)
	case "MKCALENDAR":
		h.handleMkcalendar(w, r, t, user)
	case "MKCOL":
		h.handleMkcol(w, r, t, user)
	case http.MethodOptions:
		h.handleOptions(w, r, t)
	default:
		w.Header().Set("Allow", allowFor(t.kind))
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func allowFor(kind targetKind) string {
	switch kind {
	case targetRoot, targetPrincipalCollection, targetPrincipal, targetHome:
		return "OPTIONS, PROPFIND"
	case targetCalendar:
		return "OPTIONS, GET, HEAD, PROPFIND, PROPPATCH, REPORT, DELETE, MKCALENDAR"
	case targetObject:
		return "OPTIONS, GET, HEAD, PROPFIND, PUT, DELETE"
	default:
		return "OPTIONS, PROPFIND"
	}
}

func parseTarget(u *url.URL) (target, bool) {
	escaped := u.EscapedPath()
	t := target{rawPath: u.Path}
	if escaped == "" || escaped == "/" {
		t.kind = targetRoot
		return t, true
	}
	hadTrailingSlash := strings.HasSuffix(escaped, "/")
	trimmed := strings.TrimPrefix(escaped, "/")
	trimmed = strings.TrimSuffix(trimmed, "/")
	if trimmed == "" {
		t.kind = targetRoot
		return t, true
	}
	rawParts := strings.Split(trimmed, "/")
	parts := make([]string, 0, len(rawParts))
	for _, raw := range rawParts {
		if raw == "" {
			return t, false
		}
		decoded, err := url.PathUnescape(raw)
		if err != nil {
			return t, false
		}
		if decoded == "." || decoded == ".." || strings.ContainsAny(decoded, "/\\\x00") {
			return t, false
		}
		for _, r := range decoded {
			if r < 0x20 || r == 0x7f {
				return t, false
			}
		}
		parts = append(parts, decoded)
	}
	if len(parts) == 0 {
		t.kind = targetRoot
		return t, true
	}
	switch parts[0] {
	case "principals":
		switch len(parts) {
		case 1:
			t.kind = targetPrincipalCollection
		case 2:
			t.kind = targetPrincipal
			t.user = parts[1]
		default:
			return t, false
		}
	case "calendars":
		switch len(parts) {
		case 1:
			return t, false
		case 2:
			t.kind = targetHome
			t.user = parts[1]
		case 3:
			t.kind = targetCalendar
			t.user = parts[1]
			t.slug = parts[2]
		case 4:
			if hadTrailingSlash {
				return t, false
			}
			t.kind = targetObject
			t.user = parts[1]
			t.slug = parts[2]
			t.object = parts[3]
		default:
			return t, false
		}
	default:
		return t, false
	}
	return t, true
}

func (h *Handler) authenticate(r *http.Request) (*store.User, bool) {
	username, password, ok := r.BasicAuth()
	if !ok || username == "" {
		return nil, false
	}
	key := sha256.Sum256([]byte(strings.ToLower(username) + "\x00" + password))
	now := time.Now()

	h.mu.Lock()
	entry, cached := h.cache[key]
	if cached && now.After(entry.expires) {
		delete(h.cache, key)
		cached = false
	}
	h.mu.Unlock()

	var userID int64
	var passwordHash string
	if cached {
		u, err := h.Store.GetUser(r.Context(), entry.userID)
		if err == nil && u.PasswordHash == entry.passwordHash {
			return u, true
		}
		cached = false
		h.mu.Lock()
		delete(h.cache, key)
		h.mu.Unlock()
	}
	if !cached {
		u, err := h.Store.GetUserByUsername(r.Context(), username)
		if err != nil {
			// Perform a dummy verification to keep timing uniform.
			auth.VerifyPassword(password, dummyPasswordHash)
			return nil, false
		}
		if !auth.VerifyPassword(password, u.PasswordHash) {
			return nil, false
		}
		userID = u.ID
		passwordHash = u.PasswordHash
		if len(h.cache) > 2048 {
			h.mu.Lock()
			for k, v := range h.cache {
				if now.After(v.expires) {
					delete(h.cache, k)
				}
			}
			h.mu.Unlock()
		}
		h.mu.Lock()
		h.cache[key] = cachedCredential{userID: userID, passwordHash: passwordHash, expires: now.Add(5 * time.Minute)}
		h.mu.Unlock()
	}

	u, err := h.Store.GetUser(r.Context(), userID)
	if err != nil {
		return nil, false
	}
	return u, true
}

// InvalidateCredentials clears the credential cache (used after password changes).
func (h *Handler) InvalidateCredentials() {
	h.mu.Lock()
	h.cache = map[[32]byte]cachedCredential{}
	h.mu.Unlock()
}

func (h *Handler) loadOwner(ctx context.Context, username string, current *store.User) (*store.User, bool) {
	u, err := h.Store.GetUserByUsername(ctx, username)
	if err != nil {
		return nil, false
	}
	if !current.IsAdmin && u.ID != current.ID {
		return nil, false
	}
	return u, true
}

func (h *Handler) loadCalendar(ctx context.Context, t target, current *store.User) (*store.User, bool) {
	owner, ok := h.loadOwner(ctx, t.user, current)
	if !ok {
		return nil, false
	}
	if _, err := h.Store.GetCalendarBySlug(ctx, owner.ID, t.slug); err != nil {
		return nil, false
	}
	return owner, true
}

// ---------------------------------------------------------------- hrefs

func principalHref(username string) string {
	return "/principals/" + url.PathEscape(strings.ToLower(username)) + "/"
}

func homeHref(username string) string {
	return "/calendars/" + url.PathEscape(strings.ToLower(username)) + "/"
}

func calendarHref(username, slug string) string {
	return homeHref(username) + url.PathEscape(slug) + "/"
}

func objectHref(username, slug, name string) string {
	return calendarHref(username, slug) + url.PathEscape(name)
}

func syncToken(calendarID, seq int64) string {
	return fmt.Sprintf("http://caldav-free/sync/%d/%d", calendarID, seq)
}

func parseSyncToken(token string, calendarID int64) (int64, bool) {
	prefix := fmt.Sprintf("http://caldav-free/sync/%d/", calendarID)
	if !strings.HasPrefix(token, prefix) {
		return 0, false
	}
	seq, err := strconv.ParseInt(strings.TrimPrefix(token, prefix), 10, 64)
	if err != nil || seq < 0 {
		return 0, false
	}
	return seq, true
}

// normalizeHref extracts the object path from an href in a REPORT request.
func normalizeHref(raw string) (string, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", false
	}
	if u, err := url.Parse(raw); err == nil && u.Path != "" {
		return u.Path, true
	}
	return raw, strings.HasPrefix(raw, "/")
}

func cleanSegment(s string) (string, bool) {
	if s == "" || len(s) > 200 {
		return "", false
	}
	if s == "." || s == ".." || strings.ContainsAny(s, "/\\\x00") {
		return "", false
	}
	for _, r := range s {
		if r < 0x20 || r == 0x7f {
			return "", false
		}
	}
	if path.Clean(s) != s {
		return "", false
	}
	return s, true
}
