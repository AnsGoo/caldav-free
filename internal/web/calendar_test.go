package web

import (
	"context"
	"net/http"
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
	ics := "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//test//EN\r\nBEGIN:VEVENT\r\nUID:meeting@test\r\nDTSTART;TZID=Asia/Shanghai:20261020T090000\r\nDTEND;TZID=Asia/Shanghai:20261020T100000\r\nRRULE:FREQ=DAILY;COUNT=3\r\nSUMMARY:每日同步\r\nLOCATION:会议室\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
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
			Summary    string `json:"summary"`
			Location   string `json:"location"`
			CalendarID int64  `json:"calendarId"`
			AllDay     bool   `json:"allDay"`
			Start      string `json:"start"`
		} `json:"events"`
	}](t, body)
	if len(result.Calendars) != 1 || result.Calendars[0].Name != "工作" {
		t.Fatalf("calendars = %+v", result.Calendars)
	}
	if len(result.Events) != 3 {
		t.Fatalf("events = %d: %+v", len(result.Events), result.Events)
	}
	for _, event := range result.Events {
		if event.Summary != "每日同步" || event.Location != "会议室" || event.CalendarID != cal.ID || event.AllDay {
			t.Fatalf("unexpected event: %+v", event)
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
