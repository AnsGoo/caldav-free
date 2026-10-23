package web

import (
	"sort"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/ical"
)

func normalizeEventReminders(values []int) []int {
	seen := map[int]bool{}
	out := make([]int, 0, len(values))
	for _, value := range values {
		if value < 0 || value > 10080 || seen[value] {
			continue
		}
		seen[value] = true
		out = append(out, value)
	}
	sort.Ints(out)
	return out
}

func parseEventReminders(comp *ical.Component) []int {
	values := make([]int, 0, 2)
	for _, alarm := range comp.ChildrenNamed("VALARM") {
		raw := strings.TrimSpace(alarm.Value("TRIGGER"))
		if raw == "" {
			continue
		}
		negative := strings.HasPrefix(raw, "-")
		raw = strings.TrimPrefix(raw, "-")
		if raw == "" || (raw[0] >= '0' && raw[0] <= '9') {
			continue
		}
		duration, err := ical.ParseDuration(raw)
		if err != nil {
			continue
		}
		if duration < 0 {
			duration = -duration
		}
		minutes := int(duration.Minutes())
		if minutes < 0 || (!negative && minutes > 0) {
			continue
		}
		values = append(values, minutes)
	}
	return normalizeEventReminders(values)
}

func addEventReminders(event *ical.Component, title string, offsets []int) {
	for _, offset := range normalizeEventReminders(offsets) {
		alarm := ical.NewComponent("VALARM")
		alarm.AddProp("ACTION", "DISPLAY", nil)
		alarm.AddProp("DESCRIPTION", ical.EscapeText(strings.TrimSpace(title)), nil)
		alarm.AddProp("TRIGGER", eventReminderTrigger(offset), nil)
		event.AddChild(alarm)
	}
}

func eventReminderTrigger(minutes int) string {
	if minutes <= 0 {
		return "PT0M"
	}
	if minutes%1440 == 0 {
		return "-P" + strconv.Itoa(minutes/1440) + "D"
	}
	if minutes%60 == 0 {
		return "-PT" + strconv.Itoa(minutes/60) + "H"
	}
	return "-PT" + strconv.Itoa(minutes) + "M"
}

func eventReminderTime(start time.Time, allDay bool, offset int) time.Time {
	if allDay {
		start = time.Date(start.Year(), start.Month(), start.Day(), 9, 0, 0, 0, start.Location())
	}
	return start.Add(-time.Duration(offset) * time.Minute)
}
