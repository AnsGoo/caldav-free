package web

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"caldav-free/internal/ical"
	"caldav-free/internal/store"
)

func TestTaskAPICalendarEvents(t *testing.T) {
	env := newAPIEnv(t)
	ctx := context.Background()
	cal, err := env.store.CreateCalendar(ctx, env.userID, "work", "工作", "", "#4772fa", "Asia/Shanghai", 0, []string{"VEVENT"})
	if err != nil {
		t.Fatal(err)
	}
	ics := "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//test//EN\r\nBEGIN:VEVENT\r\nUID:meeting@test\r\nDTSTART;TZID=Asia/Shanghai:20261020T090000\r\nDTEND;TZID=Asia/Shanghai:20261020T100000\r\nRRULE:FREQ=DAILY;COUNT=3\r\nSUMMARY:每日同步\r\nLOCATION:会议室\r\nATTENDEE;ROLE=REQ-PARTICIPANT:mailto:a@example.com\r\nATTENDEE:mailto:b@example.com\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
	parsed, err := ical.Load([]byte(ics), cal.Timezone)
	if err != nil {
		t.Fatal(err)
	}
	info, err := parsed.Analyze()
	if err != nil {
		t.Fatal(err)
	}
	obj := &store.Object{
		CalendarID: cal.ID, Href: "meeting.ics", UID: "meeting@test", ETag: "etag-1",
		ContentType: "text/calendar; charset=utf-8", Data: []byte(ics), ComponentType: "VEVENT",
		FirstStart: info.FirstStart.Unix(), LastEnd: info.LastEnd.Unix(), Recurring: true, Size: int64(len(ics)),
	}
	if _, _, _, err := env.store.PutObject(ctx, obj); err != nil {
		t.Fatal(err)
	}

	status, body := env.request(t, "GET", "/api/admin/tasks/calendar?from=2026-10-19T00:00:00%2B08:00&to=2026-10-26T00:00:00%2B08:00", nil, "")
	if status != http.StatusOK {
		t.Fatalf("calendar events = %d: %s", status, body)
	}
	result := decode[struct {
		Calendars []struct {
			Name string `json:"name"`
		} `json:"calendars"`
		Events []struct {
			Summary    string   `json:"summary"`
			Location   string   `json:"location"`
			CalendarID int64    `json:"calendarId"`
			AllDay     bool     `json:"allDay"`
			Start      string   `json:"start"`
			Attendees  []string `json:"attendees"`
		} `json:"events"`
	}](t, body)
	if len(result.Calendars) != 2 || result.Calendars[0].Name != "工作" || result.Calendars[1].Name != "节假日" {
		t.Fatalf("calendars = %+v", result.Calendars)
	}
	if len(result.Events) != 3 {
		t.Fatalf("events = %d: %+v", len(result.Events), result.Events)
	}
	for _, event := range result.Events {
		if event.Summary != "每日同步" || event.Location != "会议室" || event.CalendarID != cal.ID || event.AllDay {
			t.Fatalf("unexpected event: %+v", event)
		}
		if len(event.Attendees) != 2 || event.Attendees[0] != "a@example.com" || event.Attendees[1] != "b@example.com" {
			t.Fatalf("attendees = %+v", event.Attendees)
		}
		when, err := time.Parse(time.RFC3339, event.Start)
		if err != nil || when.Hour() != 9 {
			t.Fatalf("unexpected start: %q (%v)", event.Start, err)
		}
	}

	status, _ = env.request(t, "GET", "/api/admin/tasks/calendar?from=bad&to=worse", nil, "")
	if status != http.StatusBadRequest {
		t.Fatalf("invalid range = %d", status)
	}
}

func TestCreateCalendarEventWithAttendees(t *testing.T) {
	env := newAPIEnv(t)
	ctx := context.Background()
	cal, err := env.store.CreateCalendar(ctx, env.userID, "team", "团队", "", "#4772fa", "Asia/Shanghai", 0, []string{"VEVENT"})
	if err != nil {
		t.Fatal(err)
	}
	status, body := env.request(t, http.MethodPost, "/api/admin/calendars/"+strconv.FormatInt(cal.ID, 10)+"/events", map[string]any{
		"summary": "评审", "start": "2026-10-28T10:00:00+08:00", "end": "2026-10-28T11:00:00+08:00", "allDay": false,
		"attendees": []string{"a@example.com", "b@example.com", "a@example.com"},
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create event = %d: %s", status, body)
	}
	created := decode[struct {
		Event struct {
			Href      string   `json:"href"`
			Attendees []string `json:"attendees"`
		} `json:"event"`
	}](t, body)
	if len(created.Event.Attendees) != 2 {
		t.Fatalf("attendees = %+v", created.Event.Attendees)
	}
	status, body = env.request(t, http.MethodPatch, "/api/admin/calendars/"+strconv.FormatInt(cal.ID, 10)+"/events/"+created.Event.Href, map[string]any{
		"summary": "评审（改）", "start": "2026-10-28T10:00:00+08:00", "end": "2026-10-28T11:00:00+08:00", "allDay": false,
		"attendees": []string{"a@example.com", "b@example.com", "a@example.com"},
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("update event = %d: %s", status, body)
	}
	updated := decode[struct {
		Event struct {
			Summary   string   `json:"summary"`
			Attendees []string `json:"attendees"`
		} `json:"event"`
	}](t, body)
	if updated.Event.Summary != "评审（改）" || len(updated.Event.Attendees) != 2 {
		t.Fatalf("unexpected updated event: %+v", updated.Event)
	}
}

func TestCalendarSubscriptionsAndHolidays(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/calendar")
		_, _ = w.Write([]byte("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//test//EN\r\nBEGIN:VEVENT\r\nUID:sub-event@test\r\nDTSTART:20261028T100000Z\r\nDTEND:20261028T110000Z\r\nSUMMARY:订阅事件\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"))
	}))
	defer upstream.Close()
	env := newAPIEnv(t)
	status, body := env.request(t, http.MethodPost, "/api/admin/calendar-subscriptions", map[string]any{
		"name": "测试订阅", "url": upstream.URL, "color": "#f0a020",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create subscription = %d: %s", status, body)
	}
	created := decode[struct {
		Subscription struct {
			ID int64 `json:"id"`
		} `json:"subscription"`
	}](t, body)
	status, body = env.request(t, http.MethodGet, "/api/admin/tasks/calendar?from=2026-10-01T00:00:00%2B08:00&to=2026-11-01T00:00:00%2B08:00", nil, "")
	if status != http.StatusOK {
		t.Fatalf("calendar = %d: %s", status, body)
	}
	result := decode[struct {
		Calendars []struct {
			Name string `json:"name"`
		} `json:"calendars"`
		Events []struct {
			Summary    string `json:"summary"`
			CalendarID int64  `json:"calendarId"`
			ReadOnly   bool   `json:"readonly"`
		} `json:"events"`
	}](t, body)
	hasHolidaySource, hasHolidayEvent, hasSubscriptionEvent := false, false, false
	for _, source := range result.Calendars {
		if source.Name == "节假日" {
			hasHolidaySource = true
		}
	}
	for _, event := range result.Events {
		if event.Summary == "国庆节" && event.ReadOnly {
			hasHolidayEvent = true
		}
		if event.Summary == "订阅事件" && event.ReadOnly && event.CalendarID < 0 {
			hasSubscriptionEvent = true
		}
	}
	if !hasHolidaySource || !hasHolidayEvent || !hasSubscriptionEvent {
		t.Fatalf("holiday=%v event=%v subscription=%v calendars=%+v events=%+v", hasHolidaySource, hasHolidayEvent, hasSubscriptionEvent, result.Calendars, result.Events)
	}
	status, _ = env.request(t, http.MethodDelete, "/api/admin/calendar-subscriptions/"+strconv.FormatInt(created.Subscription.ID, 10), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete subscription = %d", status)
	}
}
