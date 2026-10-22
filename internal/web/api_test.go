package web

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"

	"caldav-free/internal/auth"
	"caldav-free/internal/dav"
	"caldav-free/internal/store"
)

type apiEnv struct {
	server *httptest.Server
	store  *store.Store
	client *http.Client
	csrf   string
	userID int64
}

func newAPIEnv(t *testing.T) *apiEnv {
	t.Helper()
	st, err := store.Open(t.TempDir() + "/web.db")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	hash, _ := auth.HashPassword("adminpass123")
	admin, err := st.CreateUser(context.Background(), "admin", "Admin", "admin@example.com", hash, true)
	if err != nil {
		t.Fatal(err)
	}
	srv, err := New(st, dav.New(st, nil), nil, "https://example.test")
	if err != nil {
		t.Fatalf("new web server: %v", err)
	}
	mux := http.NewServeMux()
	srv.Register(mux)
	ts := httptest.NewServer(mux)
	t.Cleanup(ts.Close)
	jar, _ := cookiejar.New(nil)
	client := &http.Client{Jar: jar, CheckRedirect: func(req *http.Request, via []*http.Request) error {
		return http.ErrUseLastResponse
	}}
	env := &apiEnv{server: ts, store: st, client: client, userID: admin.ID}
	status, body := env.request(t, "POST", "/api/admin/login", map[string]any{
		"username": "admin", "password": "adminpass123",
	}, "")
	if status != http.StatusOK {
		t.Fatalf("login = %d: %s", status, body)
	}
	var login struct {
		CSRF string `json:"csrf"`
	}
	if err := json.Unmarshal(body, &login); err != nil {
		t.Fatal(err)
	}
	env.csrf = login.CSRF
	return env
}

func (e *apiEnv) request(t *testing.T, method, path string, payload any, csrf string) (int, []byte) {
	t.Helper()
	var reader io.Reader
	if payload != nil {
		data, err := json.Marshal(payload)
		if err != nil {
			t.Fatal(err)
		}
		reader = bytes.NewReader(data)
	}
	req, err := http.NewRequest(method, e.server.URL+path, reader)
	if err != nil {
		t.Fatal(err)
	}
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if csrf != "" {
		req.Header.Set("X-CSRF-Token", csrf)
	}
	resp, err := e.client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, body
}

func decode[T any](t *testing.T, data []byte) T {
	t.Helper()
	var value T
	if err := json.Unmarshal(data, &value); err != nil {
		t.Fatalf("decode: %v (%s)", err, data)
	}
	return value
}

func TestAdminAPIAndSPA(t *testing.T) {
	env := newAPIEnv(t)

	status, body := env.request(t, "GET", "/api/admin/dashboard", nil, "")
	if status != http.StatusOK {
		t.Fatalf("dashboard = %d: %s", status, body)
	}
	var dashboard struct {
		Stats struct {
			Users int64 `json:"users"`
		} `json:"stats"`
		PrincipalURL string `json:"principalUrl"`
	}
	dashboard = decode[struct {
		Stats struct {
			Users int64 `json:"users"`
		} `json:"stats"`
		PrincipalURL string `json:"principalUrl"`
	}](t, body)
	if dashboard.Stats.Users != 1 || !strings.Contains(dashboard.PrincipalURL, "/principals/admin/") {
		t.Fatalf("bad dashboard: %s", body)
	}

	// CSRF is required for mutations.
	status, _ = env.request(t, "POST", "/api/admin/users", map[string]any{
		"username": "csrf-test", "password": "password123",
	}, "")
	if status != http.StatusForbidden {
		t.Fatalf("missing csrf = %d", status)
	}

	status, body = env.request(t, "POST", "/api/admin/users", map[string]any{
		"username": "bob", "displayName": "Bob", "email": "bob@example.com",
		"password": "bobpass123", "isAdmin": false,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create user = %d: %s", status, body)
	}
	createdUser := decode[struct {
		User struct {
			ID int64 `json:"id"`
		} `json:"user"`
	}](t, body)
	bobID := createdUser.User.ID

	status, body = env.request(t, "GET", "/api/admin/users/"+itoa(bobID), nil, "")
	if status != http.StatusOK || !strings.Contains(string(body), `"username":"bob"`) {
		t.Fatalf("user detail = %d: %s", status, body)
	}

	status, body = env.request(t, "POST", "/api/admin/users/"+itoa(bobID)+"/calendars", map[string]any{
		"slug": "work", "displayName": "Work", "timezone": "Asia/Shanghai",
		"components": []string{"VEVENT"}, "color": "#3366CC",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create calendar = %d: %s", status, body)
	}
	createdCalendar := decode[struct {
		Calendar struct {
			ID int64 `json:"id"`
		} `json:"calendar"`
	}](t, body)
	calID := createdCalendar.Calendar.ID

	status, body = env.request(t, "POST", "/api/admin/calendars/"+itoa(calID)+"/events", map[string]any{
		"summary": "Design Review", "location": "Room A", "description": "weekly",
		"start": "2026-10-23T10:00", "end": "2026-10-23T11:00", "allDay": false,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create event = %d: %s", status, body)
	}
	createdEvent := decode[struct {
		Event struct {
			Href string `json:"href"`
		} `json:"event"`
	}](t, body)
	href := createdEvent.Event.Href

	status, body = env.request(t, "GET", "/api/admin/calendars/"+itoa(calID), nil, "")
	if status != http.StatusOK || !strings.Contains(string(body), "Design Review") {
		t.Fatalf("calendar detail = %d: %s", status, body)
	}

	status, body = env.request(t, "GET", "/api/admin/calendars/"+itoa(calID)+"/events/"+href, nil, "")
	if status != http.StatusOK {
		t.Fatalf("event detail = %d: %s", status, body)
	}
	eventDetail := decode[struct {
		Data string `json:"data"`
	}](t, body)
	updated := strings.Replace(eventDetail.Data, "Design Review", "Design Review Updated", 1)
	status, body = env.request(t, "PUT", "/api/admin/calendars/"+itoa(calID)+"/events/"+href, map[string]any{"data": updated}, env.csrf)
	if status != http.StatusOK || !strings.Contains(string(body), "Design Review Updated") {
		t.Fatalf("update event = %d: %s", status, body)
	}

	status, body = env.request(t, "PATCH", "/api/admin/calendars/"+itoa(calID), map[string]any{
		"displayName": "Client Work", "description": "Updated", "color": "#ff0000",
		"timezone": "Asia/Shanghai", "order": 3, "components": []string{"VEVENT"},
	}, env.csrf)
	if status != http.StatusOK || !strings.Contains(string(body), "Client Work") {
		t.Fatalf("update calendar = %d: %s", status, body)
	}

	status, body = env.request(t, "DELETE", "/api/admin/calendars/"+itoa(calID)+"/events/"+href, nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete event = %d: %s", status, body)
	}

	status, body = env.request(t, "DELETE", "/api/admin/users/"+itoa(bobID), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete user = %d: %s", status, body)
	}

	// SPA index and client-side fallback.
	resp, err := env.client.Get(env.server.URL + "/admin/")
	if err != nil {
		t.Fatal(err)
	}
	spaBody, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK || !strings.Contains(string(spaBody), `id="app"`) {
		t.Fatalf("SPA index = %d: %s", resp.StatusCode, spaBody)
	}
	resp, err = env.client.Get(env.server.URL + "/admin/users")
	if err != nil {
		t.Fatal(err)
	}
	spaBody, _ = io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK || !strings.Contains(string(spaBody), `id="app"`) {
		t.Fatalf("SPA fallback = %d: %s", resp.StatusCode, spaBody)
	}

	status, _ = env.request(t, "POST", "/api/admin/logout", nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("logout = %d", status)
	}
	status, _ = env.request(t, "GET", "/api/admin/dashboard", nil, "")
	if status != http.StatusUnauthorized {
		t.Fatalf("dashboard after logout = %d", status)
	}
}

func TestNonAdminAPILoginRejected(t *testing.T) {
	st, err := store.Open(t.TempDir() + "/web.db")
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	hash, _ := auth.HashPassword("userpass123")
	adminHash, _ := auth.HashPassword("adminpass123")
	if _, err := st.CreateUser(context.Background(), "admin", "", "", adminHash, true); err != nil {
		t.Fatal(err)
	}
	if _, err := st.CreateUser(context.Background(), "carol", "", "", hash, false); err != nil {
		t.Fatal(err)
	}
	srv, err := New(st, dav.New(st, nil), nil, "")
	if err != nil {
		t.Fatal(err)
	}
	mux := http.NewServeMux()
	srv.Register(mux)
	ts := httptest.NewServer(mux)
	defer ts.Close()
	jar, _ := cookiejar.New(nil)
	client := &http.Client{Jar: jar}
	payload, _ := json.Marshal(map[string]string{"username": "carol", "password": "userpass123"})
	resp, err := client.Post(ts.URL+"/api/admin/login", "application/json", bytes.NewReader(payload))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("non-admin login = %d", resp.StatusCode)
	}
}

func itoa(v int64) string {
	return strconv.FormatInt(v, 10)
}
