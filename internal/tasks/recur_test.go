package tasks

import (
	"testing"
	"time"
)

func TestNextOccurrence(t *testing.T) {
	loc, _ := time.LoadLocation("Asia/Shanghai")
	base := time.Date(2026, 10, 22, 9, 0, 0, 0, loc) // Thursday
	next, ok := NextOccurrence("FREQ=DAILY", base)
	if !ok || !next.Equal(base.AddDate(0, 0, 1)) {
		t.Fatalf("daily next = %v (%v)", next, ok)
	}
	next, ok = NextOccurrence("FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", base)
	if !ok || !next.Equal(time.Date(2026, 10, 23, 9, 0, 0, 0, loc)) {
		t.Fatalf("weekday next = %v (%v)", next, ok)
	}
	friday := time.Date(2026, 10, 23, 9, 0, 0, 0, loc)
	next, ok = NextOccurrence("FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", friday)
	if !ok || !next.Equal(time.Date(2026, 10, 26, 9, 0, 0, 0, loc)) {
		t.Fatalf("weekend skip = %v (%v)", next, ok)
	}
	next, ok = NextOccurrence("FREQ=MONTHLY", base)
	if !ok || !next.Equal(time.Date(2026, 11, 22, 9, 0, 0, 0, loc)) {
		t.Fatalf("monthly next = %v (%v)", next, ok)
	}
	if _, ok := NextOccurrence("", base); ok {
		t.Fatal("empty rule should not advance")
	}
	if _, ok := NextOccurrence("NOT A RULE", base); ok {
		t.Fatal("invalid rule should not advance")
	}
}

func TestValidRule(t *testing.T) {
	if !ValidRule("FREQ=WEEKLY;BYDAY=MO,WE") {
		t.Fatal("valid rule rejected")
	}
	if ValidRule("nonsense") {
		t.Fatal("invalid rule accepted")
	}
}
