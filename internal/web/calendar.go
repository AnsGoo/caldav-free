package web

import (
	"context"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/ical"
	"caldav-free/internal/store"
	taskparse "caldav-free/internal/tasks"
	"caldav-free/internal/tasksync"
)

type apiCalendarSource struct {
	ID    int64  `json:"id"`
	Name  string `json:"name"`
	Color string `json:"color"`
}

type apiCalendarEvent struct {
	ID           string   `json:"id"`
	UID          string   `json:"uid"`
	Href         string   `json:"href"`
	CalendarID   int64    `json:"calendarId"`
	CalendarName string   `json:"calendarName"`
	Color        string   `json:"color"`
	Summary      string   `json:"summary"`
	Location     string   `json:"location"`
	Description  string   `json:"description"`
	RRule        string   `json:"rrule"`
	Start        string   `json:"start"`
	End          string   `json:"end"`
	AllDay       bool     `json:"allDay"`
	Recurring    bool     `json:"recurring"`
	Reminders    []int    `json:"reminders"`
	Attendees    []string `json:"attendees,omitempty"`
	ReadOnly     bool     `json:"readonly,omitempty"`
	RecurrenceID string   `json:"recurrenceId,omitempty"`
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
					Attendees:    parseEventAttendees(comp),
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
	tasks, err := s.taskOccurrencesInRange(ctx, current.ID, from, to)
	if err != nil {
		s.logger.Warn("expand recurring tasks", "user", current.Username, "error", err)
	}
	sources = append(sources, apiCalendarSource{ID: 0, Name: "节假日", Color: "#f0a020"})
	events = appendHolidayEvents(events, from, to)
	subscriptions := s.loadCalendarSubscriptions(ctx, current.ID)
	sources = append(sources, subscriptionSources(subscriptions)...)
	events = appendSubscriptionEvents(events, subscriptions, from, to)
	sort.SliceStable(events, func(i, j int) bool {
		return events[i].Start < events[j].Start
	})
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"calendars": sources,
		"events":    events,
		"tasks":     tasks,
		"from":      from.Format(time.RFC3339),
		"to":        to.Format(time.RFC3339),
	})
}

// taskOccurrencesInRange expands recurring tasks into virtual task rows so
// calendar views can show every instance in the visible range. The task ID is
// preserved; only due/occurrence fields change. Postponed instances are added
// from the recurrence history at their new time.
func (s *Server) taskOccurrencesInRange(ctx context.Context, userID int64, from, to time.Time) ([]apiTask, error) {
	tasks, err := s.store.ListAllTasks(ctx, userID, 2000)
	if err != nil {
		return nil, err
	}
	lists, err := s.store.ListTaskLists(ctx, userID)
	if err != nil {
		return nil, err
	}
	byID := make(map[int64]*store.TaskList, len(lists))
	for _, list := range lists {
		byID[list.ID] = list
	}
	taskByID := make(map[int64]*store.Task, len(tasks))
	for _, task := range tasks {
		taskByID[task.ID] = task
	}
	instances, err := s.store.ListRecurrenceInstancesInRange(ctx, userID, from, to)
	if err != nil {
		return nil, err
	}
	instanceByOccurrence := make(map[string]*store.TaskRecurrenceInstance, len(instances))
	for _, instance := range instances {
		instanceByOccurrence[recurrenceOccurrenceKey(instance.TaskID, instance.OccurrenceAt)] = instance
	}
	out := make([]apiTask, 0, 64)
	// Non-recurring tasks appear once at their due (or start) time.
	for _, task := range tasks {
		if task.Kind == "NOTE" || task.Deleted || task.Recurrence != "" {
			continue
		}
		when := task.DueAt
		if when == nil {
			when = task.StartAt
		}
		if when == nil || when.Before(from) || !when.Before(to) {
			continue
		}
		dto := apiTaskDTO(task, byID[task.ListID])
		dto.Due = when.Format(time.RFC3339)
		dto.Occurrence = when.Format(time.RFC3339)
		dto.Virtual = false
		out = append(out, dto)
		if len(out) >= 2000 {
			return out, nil
		}
	}
	add := func(task *store.Task, due time.Time, occurrence time.Time, postponed, completed bool) {
		dto := apiTaskDTO(task, byID[task.ListID])
		dto.Due = due.Format(time.RFC3339)
		dto.Occurrence = occurrence.Format(time.RFC3339)
		dto.Virtual = true
		dto.Postponed = postponed
		dto.Completed = completed
		if completed {
			dto.CompletedAt = due.Format(time.RFC3339)
		} else {
			dto.CompletedAt = ""
		}
		out = append(out, dto)
	}
	for _, task := range tasks {
		if task.Kind == "NOTE" || task.Recurrence == "" || task.DueAt == nil {
			continue
		}
		anchor := *task.DueAt
		if task.RecurrenceAnchor != nil {
			anchor = *task.RecurrenceAnchor
		}
		windowStart := from
		if task.DueAt.After(windowStart) {
			windowStart = *task.DueAt
		}
		if !task.Completed && !windowStart.After(to) {
			occurrences := taskparse.OccurrencesBetween(task.Recurrence, anchor, windowStart, to, 500)
			for _, occurrence := range occurrences {
				if instance := instanceByOccurrence[recurrenceOccurrenceKey(task.ID, occurrence)]; instance != nil {
					if instance.Status == "completed" || instance.Status == "skipped" || instance.Status == "postponed" {
						continue
					}
				}
				add(task, occurrence, occurrence, false, false)
				if len(out) >= 2000 {
					return out, nil
				}
			}
		}
	}
	for _, instance := range instances {
		if instance.PostponedTo == nil || instance.PostponedTo.Before(from) || !instance.PostponedTo.Before(to) {
			continue
		}
		if instance.Status != "postponed" && instance.Status != "completed" {
			continue
		}
		task := taskByID[instance.TaskID]
		if task == nil || task.Kind == "NOTE" {
			continue
		}
		add(task, *instance.PostponedTo, instance.OccurrenceAt, true, instance.Status == "completed")
		if len(out) >= 2000 {
			return out, nil
		}
	}
	return out, nil
}

func recurrenceOccurrenceKey(taskID int64, occurrence time.Time) string {
	return strconv.FormatInt(taskID, 10) + ":" + strconv.FormatInt(occurrence.UTC().Unix(), 10)
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

func parseEventAttendees(comp *ical.Component) []string {
	seen := make(map[string]bool)
	out := make([]string, 0, 4)
	for _, prop := range comp.All("ATTENDEE") {
		value := strings.TrimSpace(ical.UnescapeText(prop.Value))
		value = strings.TrimPrefix(value, "mailto:")
		value = strings.TrimPrefix(value, "MAILTO:")
		if value == "" || seen[value] {
			continue
		}
		seen[value] = true
		out = append(out, value)
		if len(out) >= 50 {
			break
		}
	}
	return out
}
