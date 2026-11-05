package web

import (
	"bufio"
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"testing"
	"time"

	"caldav-free/internal/store"
)

func readSSEFrame(t *testing.T, reader *bufio.Reader) int {
	t.Helper()
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			t.Fatalf("read notification stream: %v", err)
		}
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		var payload struct {
			Unread int `json:"unread"`
		}
		if err := json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &payload); err != nil {
			t.Fatalf("decode stream frame %q: %v", line, err)
		}
		return payload.Unread
	}
}

func TestNotificationCenterAPIAndStream(t *testing.T) {
	env := newAPIEnv(t)
	ctx := context.Background()

	// --- SSE: initial frame, then a live push from the store listener.
	streamCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(streamCtx, http.MethodGet, env.server.URL+"/api/admin/notifications/stream", nil)
	if err != nil {
		t.Fatal(err)
	}
	resp, err := env.client.Do(req)
	if err != nil {
		t.Fatalf("open stream: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK || !strings.HasPrefix(resp.Header.Get("Content-Type"), "text/event-stream") {
		t.Fatalf("stream = %d %q", resp.StatusCode, resp.Header.Get("Content-Type"))
	}
	reader := bufio.NewReader(resp.Body)
	if unread := readSSEFrame(t, reader); unread != 0 {
		t.Fatalf("initial unread = %d, want 0", unread)
	}

	first, err := env.store.CreateNotification(ctx, &store.Notification{
		UserID: env.userID, Type: "task", Title: "任务提醒", Body: "提交周报", TaskID: 42,
		URL: "/tasks?view=list&list=1&task=42",
	})
	if err != nil {
		t.Fatalf("create notification: %v", err)
	}
	if unread := readSSEFrame(t, reader); unread != 1 {
		t.Fatalf("stream unread after create = %d, want 1", unread)
	}

	// --- list
	status, body := env.request(t, "GET", "/api/admin/notifications", nil, "")
	if status != http.StatusOK {
		t.Fatalf("list notifications = %d: %s", status, body)
	}
	listed := decode[struct {
		Notifications []apiNotification `json:"notifications"`
		Unread        int               `json:"unread"`
	}](t, body)
	if len(listed.Notifications) != 1 || listed.Unread != 1 {
		t.Fatalf("listed = %+v", listed)
	}
	if item := listed.Notifications[0]; item.Title != "任务提醒" || item.Type != "task" || item.TaskID != 42 || item.Read {
		t.Fatalf("unexpected item: %+v", item)
	}

	// --- mark one as read
	status, body = env.request(t, "POST", "/api/admin/notifications/read", map[string]any{"id": first.ID}, env.csrf)
	if status != http.StatusOK || decode[struct {
		Unread int `json:"unread"`
	}](t, body).Unread != 0 {
		t.Fatalf("mark read = %d: %s", status, body)
	}

	// --- invalid payloads
	if status, _ := env.request(t, "POST", "/api/admin/notifications/read", map[string]any{"id": 0}, env.csrf); status != http.StatusBadRequest {
		t.Fatalf("read without id = %d, want 400", status)
	}
	if status, _ := env.request(t, "POST", "/api/admin/notifications/read", map[string]any{"all": true}, ""); status != http.StatusForbidden {
		t.Fatalf("read without csrf = %d, want 403", status)
	}

	// --- snooze: tasks are rejected, events are accepted
	if status, body := env.request(t, "POST", "/api/admin/notifications/"+itoa(first.ID)+"/snooze", map[string]any{"minutes": 10}, env.csrf); status != http.StatusBadRequest {
		t.Fatalf("snooze task = %d: %s", status, body)
	}
	cal, err := env.store.CreateCalendar(ctx, env.userID, "work", "工作", "", "#4772fa", "Asia/Shanghai", 0, []string{"VEVENT"})
	if err != nil {
		t.Fatalf("create calendar: %v", err)
	}
	event, err := env.store.CreateNotification(ctx, &store.Notification{
		UserID: env.userID, Type: "event", Title: "日程提醒", Body: "周会 · 11月5日 10:00",
		URL: "/tasks?view=all&mode=calendar&calendar=" + itoa(cal.ID) + "&event=weekly.ics&occurrence=2026-11-05T10%3A00%3A00%2B08%3A00",
	})
	if err != nil {
		t.Fatalf("create event notification: %v", err)
	}
	status, body = env.request(t, "POST", "/api/admin/notifications/"+itoa(event.ID)+"/snooze", map[string]any{"minutes": 30}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("snooze event = %d: %s", status, body)
	}
	snoozed := decode[struct {
		Snooze struct {
			ID       int64  `json:"id"`
			RemindAt string `json:"remindAt"`
		} `json:"snooze"`
		Unread int `json:"unread"`
	}](t, body)
	if snoozed.Snooze.ID == 0 || snoozed.Snooze.RemindAt == "" {
		t.Fatalf("snooze response = %+v", snoozed)
	}
	remindAt, err := time.Parse(time.RFC3339, snoozed.Snooze.RemindAt)
	if err != nil || time.Until(remindAt) < 25*time.Minute {
		t.Fatalf("snooze remindAt = %s (%v)", snoozed.Snooze.RemindAt, err)
	}
	if status, _ := env.request(t, "POST", "/api/admin/notifications/"+itoa(event.ID)+"/snooze", map[string]any{"minutes": 5000}, env.csrf); status != http.StatusBadRequest {
		t.Fatalf("snooze over 24h = %d, want 400", status)
	}

	// --- delete
	if status, _ := env.request(t, "DELETE", "/api/admin/notifications/"+itoa(event.ID), nil, env.csrf); status != http.StatusOK {
		t.Fatalf("delete = %d", status)
	}
	if status, _ := env.request(t, "DELETE", "/api/admin/notifications/"+itoa(event.ID), nil, env.csrf); status != http.StatusNotFound {
		t.Fatalf("delete twice = %d, want 404", status)
	}

	// --- auth required
	anon := &http.Client{}
	anonResp, err := anon.Get(env.server.URL + "/api/admin/notifications")
	if err != nil {
		t.Fatal(err)
	}
	defer anonResp.Body.Close()
	if anonResp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("anonymous list = %d, want 401", anonResp.StatusCode)
	}
}
