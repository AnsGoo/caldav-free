package ical

import (
	"strings"
	"testing"
	"time"
)

func mustLoad(t *testing.T, data, tz string) *Calendar {
	t.Helper()
	cal, err := Load([]byte(data), tz)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	return cal
}

func TestParseAndEncode(t *testing.T) {
	src := "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//test//EN\r\nBEGIN:VEVENT\r\nUID:abc\r\nDTSTART;TZID=Asia/Shanghai:20261021T090000\r\nDTEND;TZID=Asia/Shanghai:20261021T100000\r\nSUMMARY:Hello\\, world\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
	root, err := Parse([]byte(src))
	if err != nil {
		t.Fatal(err)
	}
	if root.Value("VERSION") != "2.0" {
		t.Fatalf("version = %q", root.Value("VERSION"))
	}
	ev := root.Child("VEVENT")
	if ev == nil {
		t.Fatal("no event")
	}
	if got := ev.Get("DTSTART").Params.Get("TZID"); got != "Asia/Shanghai" {
		t.Fatalf("tzid = %q", got)
	}
	if got := UnescapeText(ev.Value("SUMMARY")); got != "Hello, world" {
		t.Fatalf("summary = %q", got)
	}
	round := root.Encode()
	root2, err := Parse([]byte(round))
	if err != nil {
		t.Fatalf("reparse: %v", err)
	}
	if root2.Child("VEVENT").Value("UID") != "abc" {
		t.Fatal("roundtrip lost uid")
	}
}

func TestParseFoldedLine(t *testing.T) {
	src := "BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\nSUMMARY:long\n  summary\nEND:VEVENT\nEND:VCALENDAR\n"
	root, err := Parse([]byte(src))
	if err != nil {
		t.Fatal(err)
	}
	if got := root.Child("VEVENT").Value("SUMMARY"); got != "long summary" {
		t.Fatalf("summary = %q", got)
	}
}

func TestParseTimeZones(t *testing.T) {
	cal := mustLoad(t, "BEGIN:VCALENDAR\nEND:VCALENDAR\n", "Europe/Paris")
	utc, err := cal.ParseTime("20261021T090000Z", nil)
	if err != nil {
		t.Fatal(err)
	}
	if utc.Time.Location() != time.UTC {
		t.Fatalf("expected UTC, got %v", utc.Time.Location())
	}
	local, err := cal.ParseTime("20261021T090000", nil)
	if err != nil {
		t.Fatal(err)
	}
	if local.Time.Hour() != 9 || local.Time.Location().String() != "Europe/Paris" {
		t.Fatalf("unexpected local time %v", local.Time)
	}
	allDay, err := cal.ParseTime("20261021", Params{"VALUE": {"DATE"}})
	if err != nil {
		t.Fatal(err)
	}
	if !allDay.Date || allDay.Time.Day() != 21 {
		t.Fatalf("unexpected date %v", allDay)
	}
}

func TestParseDuration(t *testing.T) {
	cases := map[string]time.Duration{
		"PT1H":    time.Hour,
		"PT30M":   30 * time.Minute,
		"P1D":     24 * time.Hour,
		"P1DT2H":  26 * time.Hour,
		"P2W":     14 * 24 * time.Hour,
		"PT1H30M": 90 * time.Minute,
		"-PT15M":  -15 * time.Minute,
		"P1DT1M":  24*time.Hour + time.Minute,
	}
	for in, want := range cases {
		got, err := ParseDuration(in)
		if err != nil {
			t.Fatalf("%s: %v", in, err)
		}
		if got != want {
			t.Fatalf("%s = %v, want %v", in, got, want)
		}
	}
	for _, invalid := range []string{"", "P", "PT", "1H", "P1X", "PT1"} {
		if _, err := ParseDuration(invalid); err == nil {
			t.Fatalf("expected %q to be invalid", invalid)
		}
	}
	if d, err := ParseDuration("PT0S"); err != nil || d != 0 {
		t.Fatalf("PT0S = %v, %v", d, err)
	}
}

func TestExpandWeeklyWithExdateAndOverride(t *testing.T) {
	data := `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:weekly
DTSTART;TZID=Asia/Shanghai:20261005T090000
DTEND;TZID=Asia/Shanghai:20261005T100000
RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=4
EXDATE;TZID=Asia/Shanghai:20261012T090000
SUMMARY:Standup
END:VEVENT
BEGIN:VEVENT
UID:weekly
RECURRENCE-ID;TZID=Asia/Shanghai:20261019T090000
DTSTART;TZID=Asia/Shanghai:20261020T110000
DTEND;TZID=Asia/Shanghai:20261020T113000
SUMMARY:Standup moved
END:VEVENT
END:VCALENDAR`
	cal := mustLoad(t, data, "UTC")
	instances, err := cal.ExpandObject(
		time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC), 100)
	if err != nil {
		t.Fatal(err)
	}
	if len(instances) != 3 {
		t.Fatalf("got %d instances: %+v", len(instances), instances)
	}
	want := []time.Time{
		time.Date(2026, 10, 5, 9, 0, 0, 0, cal.Location("Asia/Shanghai")),
		time.Date(2026, 10, 20, 11, 0, 0, 0, cal.Location("Asia/Shanghai")),
		time.Date(2026, 10, 26, 9, 0, 0, 0, cal.Location("Asia/Shanghai")),
	}
	for i, inst := range instances {
		if !inst.Start.Equal(want[i]) {
			t.Fatalf("instance %d = %v, want %v", i, inst.Start, want[i])
		}
	}
	if got := instances[1].Component.Value("SUMMARY"); got != "Standup moved" {
		t.Fatalf("override not used: %q", got)
	}
}

func TestExpandAcrossDST(t *testing.T) {
	data := `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:dst
DTSTART;TZID=America/New_York:20261024T090000
DTEND;TZID=America/New_York:20261024T100000
RRULE:FREQ=WEEKLY;COUNT=4
END:VEVENT
END:VCALENDAR`
	cal := mustLoad(t, data, "UTC")
	instances, err := cal.ExpandObject(
		time.Date(2026, 10, 20, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 11, 20, 0, 0, 0, 0, time.UTC), 100)
	if err != nil {
		t.Fatal(err)
	}
	if len(instances) != 4 {
		t.Fatalf("got %d instances", len(instances))
	}
	ny := cal.Location("America/New_York")
	for _, inst := range instances {
		local := inst.Start.In(ny)
		if local.Hour() != 9 || local.Minute() != 0 {
			t.Fatalf("local time drifted: %v", local)
		}
	}
	// Nov 1 2026 is the US DST transition: 09:00 EDT = 13:00 UTC, 09:00 EST = 14:00 UTC.
	if got := instances[1].Start.UTC().Hour(); got != 13 {
		t.Fatalf("first occurrence UTC hour = %d", got)
	}
	if got := instances[2].Start.UTC().Hour(); got != 14 {
		t.Fatalf("post-DST UTC hour = %d", got)
	}
}

func TestAllDayTimeRange(t *testing.T) {
	data := `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:allday
DTSTART;VALUE=DATE:20261021
DTEND;VALUE=DATE:20261024
SUMMARY:Conference
END:VEVENT
END:VCALENDAR`
	cal := mustLoad(t, data, "Asia/Shanghai")
	comp := cal.Root.Child("VEVENT")
	if !cal.MatchesTimeRange(comp, time.Date(2026, 10, 22, 12, 0, 0, 0, time.UTC), time.Date(2026, 10, 23, 0, 0, 0, 0, time.UTC)) {
		t.Fatal("expected overlap inside all-day event")
	}
	if cal.MatchesTimeRange(comp, time.Date(2026, 10, 25, 0, 0, 0, 0, time.UTC), time.Date(2026, 10, 26, 0, 0, 0, 0, time.UTC)) {
		t.Fatal("unexpected overlap after event")
	}
}

func TestAnalyze(t *testing.T) {
	bounded := `BEGIN:VCALENDAR
BEGIN:VEVENT
UID:bounded
DTSTART:20260101T100000Z
DTEND:20260101T110000Z
RRULE:FREQ=DAILY;COUNT=3
END:VEVENT
END:VCALENDAR`
	cal := mustLoad(t, bounded, "UTC")
	info, err := cal.Analyze()
	if err != nil {
		t.Fatal(err)
	}
	if !info.Recurring || info.Unbounded {
		t.Fatalf("info = %+v", info)
	}
	if want := time.Date(2026, 1, 3, 11, 0, 0, 0, time.UTC); !info.LastEnd.Equal(want) {
		t.Fatalf("last end = %v, want %v", info.LastEnd, want)
	}

	unbounded := strings.Replace(bounded, ";COUNT=3", "", 1)
	cal = mustLoad(t, unbounded, "UTC")
	info, err = cal.Analyze()
	if err != nil {
		t.Fatal(err)
	}
	if !info.Unbounded {
		t.Fatalf("expected unbounded: %+v", info)
	}
}

func TestFilter(t *testing.T) {
	data := `BEGIN:VCALENDAR
BEGIN:VEVENT
UID:e1
DTSTART:20261021T090000Z
DTEND:20261021T100000Z
SUMMARY:Team Meeting
CATEGORIES:WORK
END:VEVENT
END:VCALENDAR`
	cal := mustLoad(t, data, "UTC")
	filter := &CompFilter{
		Name: "VCALENDAR",
		CompFilters: []CompFilter{{
			Name: "VEVENT",
			TimeRange: &TimeRange{
				Start: time.Date(2026, 10, 21, 0, 0, 0, 0, time.UTC),
				End:   time.Date(2026, 10, 22, 0, 0, 0, 0, time.UTC),
			},
			PropFilters: []PropFilter{{
				Name:      "SUMMARY",
				TextMatch: &TextMatch{Value: "team"},
			}},
		}},
	}
	if !cal.MatchObject(filter) {
		t.Fatal("expected match")
	}
	filter.CompFilters[0].PropFilters[0].TextMatch.Value = "gym"
	if cal.MatchObject(filter) {
		t.Fatal("unexpected match")
	}
	filter.CompFilters[0].PropFilters[0].TextMatch = &TextMatch{Value: "gym", Negate: true}
	if !cal.MatchObject(filter) {
		t.Fatal("expected negated match")
	}
}

func TestFreeBusy(t *testing.T) {
	data := `BEGIN:VCALENDAR
BEGIN:VEVENT
UID:a
DTSTART:20261021T090000Z
DTEND:20261021T100000Z
END:VEVENT
BEGIN:VEVENT
UID:b
DTSTART:20261021T093000Z
DTEND:20261021T110000Z
END:VEVENT
BEGIN:VEVENT
UID:c
DTSTART:20261021T120000Z
DTEND:20261021T130000Z
TRANSP:TRANSPARENT
END:VEVENT
END:VCALENDAR`
	cal := mustLoad(t, data, "UTC")
	periods := cal.FreeBusy(
		time.Date(2026, 10, 21, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 10, 22, 0, 0, 0, 0, time.UTC))
	if len(periods) != 1 {
		t.Fatalf("periods = %+v", periods)
	}
	if !periods[0].Start.Equal(time.Date(2026, 10, 21, 9, 0, 0, 0, time.UTC)) ||
		!periods[0].End.Equal(time.Date(2026, 10, 21, 11, 0, 0, 0, time.UTC)) {
		t.Fatalf("bad merged period: %+v", periods[0])
	}
}

func TestVTIMEZONEFallback(t *testing.T) {
	data := `BEGIN:VCALENDAR
BEGIN:VTIMEZONE
TZID:Custom/Shanghai
BEGIN:STANDARD
DTSTART:19700101T000000
TZOFFSETFROM:+0800
TZOFFSETTO:+0800
TZNAME:CST
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
UID:customtz
DTSTART;TZID=Custom/Shanghai:20261021T090000
DTEND;TZID=Custom/Shanghai:20261021T100000
END:VEVENT
END:VCALENDAR`
	cal := mustLoad(t, data, "UTC")
	start, _, _, err := cal.ComponentTimes(cal.Root.Child("VEVENT"))
	if err != nil {
		t.Fatal(err)
	}
	if got := start.UTC().Hour(); got != 1 {
		t.Fatalf("UTC hour = %d, want 1", got)
	}
}
