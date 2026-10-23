package web

import (
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/ical"
	"caldav-free/internal/store"
	"caldav-free/internal/tasksync"
)

type apiCalendarSource struct {
	ID    int64  `json:"id"`
	Name  string `json:"name"`
	Color string `json:"color"`
}

type apiCalendarEvent struct {
	ID           string `json:"id"`
	UID          string `json:"uid"`
	Href         string `json:"href"`
	CalendarID   int64  `json:"calendarId"`
	CalendarName string `json:"calendarName"`
	Color        string `json:"color"`
	Summary      string `json:"summary"`
	Location     string `json:"location"`
	Description  string `json:"description"`
	RRule        string `json:"rrule"`
	Start        string `json:"start"`
	End          string `json:"end"`
	AllDay       bool   `json:"allDay"`
	Recurring    bool   `json:"recurring"`
	Reminders    []int  `json:"reminders"`
	RecurrenceID string `json:"recurrenceId,omitempty"`
}

// apiTaskCalendarEvents expands VEVENTs from all of the current user's
// calendars into a bounded date range for the workspace calendar views.
func (s *Server) apiTaskCalendarEvents(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	from, to, ok := parseEventRange(r)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "时间范围无效")
		return
	}
	ctx := r.Context()
	calendars, err := s.store.ListCalendars(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	sources := make([]apiCalendarSource, 0, len(calendars))
	events := make([]apiCalendarEvent, 0, 64)
	for _, cal := range calendars {
		if cal.Slug == tasksync.CalendarSlug || !cal.SupportsComponent("VEVENT") {
			continue
		}
		sources = append(sources, apiCalendarSource{ID: cal.ID, Name: cal.DisplayNameOrSlug(), Color: cal.Color})
		objects, err := s.store.ObjectRange(ctx, cal.ID, from, to)
		if err != nil {
			s.logger.Warn("list calendar objects", "calendar", cal.ID, "error", err)
			continue
		}
		for _, obj := range objects {
			parsed, err := ical.Load(obj.Data, cal.Timezone)
			if err != nil {
				continue
			}
			instances, err := parsed.ExpandObject(from, to, 500)
			if err != nil {
				continue
			}
			for _, instance := range instances {
				comp := instance.Component
				if comp == nil || comp.Name != "VEVENT" {
					continue
				}
				summary := strings.TrimSpace(ical.UnescapeText(comp.Value("SUMMARY")))
				if summary == "" {
					summary = "未命名事件"
				}
				uid := strings.TrimSpace(comp.Value("UID"))
				if uid == "" {
					uid = obj.UID
				}
				key := strconv.FormatInt(cal.ID, 10) + ":" + obj.Href + ":" + strconv.FormatInt(instance.Start.Unix(), 10)
				recurrenceID := ""
				if instance.RecurrenceID != nil {
					loc, _ := time.LoadLocation(cal.Timezone)
					if instance.AllDay {
						recurrenceID = instance.RecurrenceID.In(loc).Format("2006-01-02")
					} else {
						recurrenceID = instance.RecurrenceID.In(loc).Format(time.RFC3339)
					}
				}
				events = append(events, apiCalendarEvent{
					ID:           key,
					UID:          uid,
					Href:         obj.Href,
					CalendarID:   cal.ID,
					CalendarName: cal.DisplayNameOrSlug(),
					Color:        cal.Color,
					Summary:      summary,
					Location:     strings.TrimSpace(ical.UnescapeText(comp.Value("LOCATION"))),
					Description:  strings.TrimSpace(ical.UnescapeText(comp.Value("DESCRIPTION"))),
					RRule:        strings.TrimSpace(comp.Value("RRULE")),
					Start:        instance.Start.Format(time.RFC3339),
					End:          instance.End.Format(time.RFC3339),
					AllDay:       instance.AllDay,
					Recurring:    obj.Recurring,
					Reminders:    parseEventReminders(comp),
					RecurrenceID: recurrenceID,
				})
				if len(events) >= 2000 {
					break
				}
			}
			if len(events) >= 2000 {
				break
			}
		}
		if len(events) >= 2000 {
			break
		}
	}
	sort.SliceStable(events, func(i, j int) bool {
		return events[i].Start < events[j].Start
	})
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"calendars": sources,
		"events":    events,
		"from":      from.Format(time.RFC3339),
		"to":        to.Format(time.RFC3339),
	})
}

func parseEventRange(r *http.Request) (time.Time, time.Time, bool) {
	loc := taskLocation("")
	parse := func(value string) (time.Time, bool) {
		if parsed, err := time.Parse(time.RFC3339, value); err == nil {
			return parsed, true
		}
		if parsed, err := time.ParseInLocation("2006-01-02", value, loc); err == nil {
			return parsed, true
		}
		return time.Time{}, false
	}
	from, ok := parse(strings.TrimSpace(r.URL.Query().Get("from")))
	if !ok {
		return time.Time{}, time.Time{}, false
	}
	to, ok := parse(strings.TrimSpace(r.URL.Query().Get("to")))
	if !ok || !to.After(from) {
		return time.Time{}, time.Time{}, false
	}
	if to.Sub(from) > 120*24*time.Hour {
		return time.Time{}, time.Time{}, false
	}
	return from, to, true
}
