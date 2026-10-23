package web

import (
	"encoding/json"
	"net/http"
	"net/url"
	"testing"
)

func TestRecurringEventSingleException(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, http.MethodPost, "/api/admin/users/"+itoa(env.userID)+"/calendars", map[string]any{
		"slug": "recur", "displayName": "Recurring", "timezone": "Asia/Shanghai",
		"components": []string{"VEVENT"},
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create calendar = %d: %s", status, body)
	}
	var calendar struct {
		Calendar struct {
			ID int64 `json:"id"`
		} `json:"calendar"`
	}
	if err := json.Unmarshal(body, &calendar); err != nil {
		t.Fatal(err)
	}
	calID := calendar.Calendar.ID
	status, body = env.request(t, http.MethodPost, "/api/admin/calendars/"+itoa(calID)+"/events", map[string]any{
		"summary": "Weekly", "start": "2026-10-26T10:00", "end": "2026-10-26T11:00",
		"allDay": false, "rrule": "FREQ=WEEKLY", "count": 3,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create event = %d: %s", status, body)
	}
	var created struct {
		Event struct {
			Href string `json:"href"`
		} `json:"event"`
	}
	if err := json.Unmarshal(body, &created); err != nil {
		t.Fatal(err)
	}
	href := created.Event.Href
	rangePath := "/api/admin/tasks/calendar?from=" + url.QueryEscape("2026-10-25T00:00:00+08:00") + "&to=" + url.QueryEscape("2026-11-30T00:00:00+08:00")
	loadEvents := func() []struct {
		Summary      string `json:"summary"`
		Start        string `json:"start"`
		RecurrenceID string `json:"recurrenceId"`
	} {
		status, body := env.request(t, http.MethodGet, rangePath, nil, "")
		if status != http.StatusOK {
			t.Fatalf("calendar events = %d: %s", status, body)
		}
		var data struct {
			Events []struct {
				Summary      string `json:"summary"`
				Start        string `json:"start"`
				RecurrenceID string `json:"recurrenceId"`
			} `json:"events"`
		}
		if err := json.Unmarshal(body, &data); err != nil {
			t.Fatal(err)
		}
		return data.Events
	}
	events := loadEvents()
	if len(events) != 3 {
		t.Fatalf("events = %+v", events)
	}
	recurrenceID := events[0].RecurrenceID
	status, body = env.request(t, http.MethodPatch, "/api/admin/calendars/"+itoa(calID)+"/events/"+href, map[string]any{
		"summary": "Weekly Exception", "start": "2026-10-27T14:00", "end": "2026-10-27T15:00",
		"allDay": false, "scope": "single", "recurrenceId": recurrenceID,
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("single update = %d: %s", status, body)
	}
	events = loadEvents()
	if len(events) != 3 || events[0].Summary != "Weekly Exception" || events[0].Start[:10] != "2026-10-27" {
		t.Fatalf("events after exception = %+v", events)
	}
	status, body = env.request(t, http.MethodDelete,
		"/api/admin/calendars/"+itoa(calID)+"/events/"+href+"?recurrenceId="+url.QueryEscape(events[1].RecurrenceID), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("single delete = %d: %s", status, body)
	}
	if events = loadEvents(); len(events) != 2 {
		t.Fatalf("events after single delete = %+v", events)
	}
}
