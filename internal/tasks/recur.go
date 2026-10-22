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

// ValidRule reports whether a recurrence body can be parsed.
func ValidRule(rule string) bool {
	rule = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(rule), "RRULE:"))
	if rule == "" {
		return false
	}
	_, err := rrule.StrToROption(rule)
	return err == nil
}
