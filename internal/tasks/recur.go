package tasks

import (
	"strconv"
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

// NextOccurrenceAfter computes the next occurrence after after while keeping
// start as the series anchor. This preserves COUNT and UNTIL semantics even
// after a task's current due date has advanced.
func NextOccurrenceAfter(rule string, start, after time.Time) (time.Time, bool) {
	rule = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(rule), "RRULE:"))
	if rule == "" || start.IsZero() || after.IsZero() {
		return time.Time{}, false
	}
	option, err := rrule.StrToROptionInLocation(rule, start.Location())
	if err != nil {
		return time.Time{}, false
	}
	option.Dtstart = start
	recurrence, err := rrule.NewRRule(*option)
	if err != nil {
		return time.Time{}, false
	}
	next := recurrence.After(after, false)
	if next.IsZero() || !next.After(after) {
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

// RecurrenceRuleForCurrent rewrites a COUNT rule so the master VTODO exposes
// only the occurrences that remain from current onward. This keeps CalDAV
// clients aligned after a task's due date has rolled forward.
func RecurrenceRuleForCurrent(rule string, anchor, current time.Time) string {
	rule = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(rule), "RRULE:"))
	if rule == "" || anchor.IsZero() || current.IsZero() {
		return rule
	}
	option, err := rrule.StrToROptionInLocation(rule, anchor.Location())
	if err != nil || option.Count <= 0 {
		return rule
	}
	option.Dtstart = anchor
	recurrence, err := rrule.NewRRule(*option)
	if err != nil {
		return rule
	}
	occurrences := recurrence.Between(anchor.Add(-time.Second), current.Add(time.Second), true)
	if len(occurrences) == 0 {
		return rule
	}
	remaining := option.Count - (len(occurrences) - 1)
	if remaining < 1 {
		remaining = 1
	}
	parts := strings.Split(rule, ";")
	for index, part := range parts {
		if eq := strings.IndexByte(part, '='); eq > 0 && strings.EqualFold(strings.TrimSpace(part[:eq]), "COUNT") {
			parts[index] = "COUNT=" + strconv.Itoa(remaining)
			return strings.Join(parts, ";")
		}
	}
	return rule
}
