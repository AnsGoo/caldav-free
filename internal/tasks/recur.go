package tasks

import (
	"strings"
	"time"

	"github.com/teambition/rrule-go"
)

// NextOccurrence computes the next occurrence after current for a standard
// RRULE body such as "FREQ=WEEKLY;BYDAY=MO,WE".
func NextOccurrence(rule string, current time.Time) (time.Time, bool) {
	rule = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(rule), "RRULE:"))
	if rule == "" || current.IsZero() {
		return time.Time{}, false
	}
	option, err := rrule.StrToROptionInLocation(rule, current.Location())
	if err != nil {
		return time.Time{}, false
	}
	option.Dtstart = current
	recurrence, err := rrule.NewRRule(*option)
	if err != nil {
		return time.Time{}, false
	}
	next := recurrence.After(current, false)
	if next.IsZero() || !next.After(current) {
		return time.Time{}, false
	}
	return next, true
}

// OccurrencesBetween expands a recurrence rule from start into the inclusive
// [from, to] window. It keeps COUNT/UNTIL semantics relative to start and is
// used by calendar views to show future task instances.
func OccurrencesBetween(rule string, start, from, to time.Time, limit int) []time.Time {
	rule = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(rule), "RRULE:"))
	if rule == "" || start.IsZero() || from.IsZero() || to.IsZero() || to.Before(from) {
		return nil
	}
	if limit <= 0 || limit > 1000 {
		limit = 500
	}
	option, err := rrule.StrToROptionInLocation(rule, start.Location())
	if err != nil {
		return nil
	}
	option.Dtstart = start
	recurrence, err := rrule.NewRRule(*option)
	if err != nil {
		return nil
	}
	raw := recurrence.Between(from, to, true)
	out := make([]time.Time, 0, len(raw))
	for _, occurrence := range raw {
		if occurrence.Before(start) {
			continue
		}
		out = append(out, occurrence)
		if len(out) >= limit {
			break
		}
	}
	return out
}

// ValidRule reports whether a recurrence body can be parsed.
func ValidRule(rule string) bool {
	rule = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(rule), "RRULE:"))
	if rule == "" {
		return false
	}
	_, err := rrule.StrToROption(rule)
	return err == nil
}
