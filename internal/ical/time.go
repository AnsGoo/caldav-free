package ical

import (
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"
	_ "time/tzdata" // embed the IANA database so deployments need no tzdata
)

// TimeValue is a parsed DATE or DATE-TIME value.
type TimeValue struct {
	Time     time.Time
	Date     bool // VALUE=DATE (all-day)
	Floating bool // no TZID and no UTC suffix
	UTC      bool // value ended in Z
	TZID     string
}

// Calendar wraps a parsed VCALENDAR with timezone resolution.
type Calendar struct {
	Root            *Component
	DefaultLocation *time.Location
	vtimezones      map[string]*Component
	zoneCache       map[string]*time.Location
}

// Load parses iCalendar data and resolves the calendar's default timezone.
func Load(data []byte, defaultTZ string) (*Calendar, error) {
	root, err := Parse(data)
	if err != nil {
		return nil, err
	}
	return NewCalendar(root, defaultTZ), nil
}

// NewCalendar wraps root and prepares timezone lookup.
func NewCalendar(root *Component, defaultTZ string) *Calendar {
	loc := time.UTC
	if defaultTZ != "" {
		if l, err := time.LoadLocation(defaultTZ); err == nil {
			loc = l
		}
	}
	c := &Calendar{
		Root:            root,
		DefaultLocation: loc,
		vtimezones:      map[string]*Component{},
		zoneCache:       map[string]*time.Location{},
	}
	for _, tz := range root.ChildrenNamed("VTIMEZONE") {
		if id := tz.Value("TZID"); id != "" {
			c.vtimezones[id] = tz
			// Some clients prefix TZIDs; index the last path segments too.
			for _, alias := range tzidAliases(id) {
				if _, exists := c.vtimezones[alias]; !exists {
					c.vtimezones[alias] = tz
				}
			}
		}
	}
	return c
}

// Components returns all components of the given type.
func (c *Calendar) Components(name string) []*Component {
	return c.Root.ChildrenNamed(name)
}

// Location resolves a TZID to a Go location. Unknown zones fall back to a
// fixed-offset zone derived from the embedded VTIMEZONE (or the default).
func (c *Calendar) Location(tzid string) *time.Location {
	tzid = strings.TrimSpace(tzid)
	if tzid == "" {
		return c.DefaultLocation
	}
	if loc, ok := c.zoneCache[tzid]; ok {
		return loc
	}
	loc := c.resolveLocation(tzid)
	c.zoneCache[tzid] = loc
	return loc
}

func (c *Calendar) resolveLocation(tzid string) *time.Location {
	for _, candidate := range append([]string{tzid}, tzidAliases(tzid)...) {
		if mapped, ok := windowsZones[strings.ToLower(candidate)]; ok {
			if loc, err := time.LoadLocation(mapped); err == nil {
				return loc
			}
		}
		if loc, err := time.LoadLocation(strings.TrimPrefix(candidate, "/")); err == nil {
			return loc
		}
	}
	if tz, ok := c.vtimezones[tzid]; ok {
		if off, ok := vtimezoneOffset(tz, time.Now()); ok {
			return time.FixedZone(tzid, off)
		}
	}
	return c.DefaultLocation
}

// tzidAliases produces progressively shorter path suffixes for vendor-prefixed
// TZIDs such as /mozilla.org/20050126_1/Europe/Paris.
func tzidAliases(tzid string) []string {
	trimmed := strings.Trim(tzid, "/")
	parts := strings.Split(trimmed, "/")
	if len(parts) < 2 {
		return nil
	}
	var out []string
	for i := 1; i < len(parts); i++ {
		out = append(out, strings.Join(parts[i:], "/"))
	}
	return out
}

// ParseTimeProp parses a date/date-time property.
func (c *Calendar) ParseTimeProp(p *Prop) (TimeValue, error) {
	if p == nil {
		return TimeValue{}, fmt.Errorf("missing time property")
	}
	return c.ParseTime(p.Value, p.Params)
}

// ParseTime parses an iCalendar DATE or DATE-TIME value.
func (c *Calendar) ParseTime(value string, params Params) (TimeValue, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return TimeValue{}, fmt.Errorf("empty time value")
	}
	tzid := ""
	if params != nil {
		tzid = params.Get("TZID")
	}
	valueType := ""
	if params != nil {
		valueType = strings.ToUpper(params.Get("VALUE"))
	}

	if valueType == "DATE" || (len(value) == 8 && !strings.Contains(value, "T")) {
		if len(value) < 8 {
			return TimeValue{}, fmt.Errorf("invalid DATE %q", value)
		}
		loc := c.locationForDate(tzid, value)
		t, err := time.ParseInLocation("20060102", value[:8], loc)
		if err != nil {
			return TimeValue{}, fmt.Errorf("invalid DATE %q: %w", value, err)
		}
		return TimeValue{Time: t, Date: true, Floating: tzid == "", TZID: tzid}, nil
	}

	tv := TimeValue{TZID: tzid}
	layout := ""
	s := value
	switch {
	case strings.HasSuffix(s, "Z"):
		tv.UTC = true
		layout = "20060102T150405"
		s = strings.TrimSuffix(s, "Z")
		layout = "20060102T150405"
	case len(s) == 15: // YYYYMMDDTHHMMSS
		layout = "20060102T150405"
		tv.Floating = tzid == ""
	case len(s) == 13: // YYYYMMDDTHHMM (non-standard but seen in the wild)
		layout = "20060102T1504"
		tv.Floating = tzid == ""
	default:
		return TimeValue{}, fmt.Errorf("unsupported DATE-TIME %q", value)
	}

	loc := time.UTC
	if !tv.UTC {
		loc = c.locationForDateTime(tzid, s)
	}
	t, err := time.ParseInLocation(layout, s, loc)
	if err != nil {
		return TimeValue{}, fmt.Errorf("invalid DATE-TIME %q: %w", value, err)
	}
	tv.Time = t
	return tv, nil
}

func (c *Calendar) locationForDate(tzid, date string) *time.Location {
	if tzid == "" {
		return c.DefaultLocation
	}
	return c.locationForDateTime(tzid, date+"T120000")
}

// locationForDateTime returns a concrete zone, using a fixed offset derived
// from a VTIMEZONE for custom TZIDs that Go's tzdata cannot resolve.
func (c *Calendar) locationForDateTime(tzid, compact string) *time.Location {
	if tzid == "" {
		return c.DefaultLocation
	}
	for _, candidate := range append([]string{tzid}, tzidAliases(tzid)...) {
		if mapped, ok := windowsZones[strings.ToLower(candidate)]; ok {
			if loc, err := time.LoadLocation(mapped); err == nil {
				return loc
			}
		}
		if loc, err := time.LoadLocation(strings.TrimPrefix(candidate, "/")); err == nil {
			return loc
		}
	}
	if tz, ok := c.vtimezones[tzid]; ok {
		var naive time.Time
		var err error
		if len(compact) >= 8 {
			if len(compact) >= 15 {
				naive, err = time.ParseInLocation("20060102T150405", compact[:15], time.UTC)
			} else {
				naive, err = time.ParseInLocation("20060102", compact[:8], time.UTC)
			}
			if err == nil {
				if off, ok := vtimezoneOffset(tz, naive); ok {
					return time.FixedZone(tzid, off)
				}
			}
		}
	}
	return c.DefaultLocation
}

// ParseDuration parses an RFC 5545 DURATION value.
func ParseDuration(value string) (time.Duration, error) {
	s := strings.TrimSpace(strings.ToUpper(value))
	if s == "" {
		return 0, fmt.Errorf("empty duration")
	}
	neg := false
	if s[0] == '+' {
		s = s[1:]
	} else if s[0] == '-' {
		neg = true
		s = s[1:]
	}
	if !strings.HasPrefix(s, "P") {
		return 0, fmt.Errorf("invalid duration %q", value)
	}
	s = s[1:]

	var total time.Duration
	inTime := false
	sawUnit := false
	num := ""
	for i := 0; i < len(s); i++ {
		ch := s[i]
		switch {
		case ch == 'T':
			inTime = true
			num = ""
		case ch >= '0' && ch <= '9':
			num += string(ch)
		case ch == 'W' || ch == 'D' || ch == 'H' || ch == 'M' || ch == 'S':
			if num == "" {
				return 0, fmt.Errorf("invalid duration %q", value)
			}
			n, err := strconv.Atoi(num)
			if err != nil {
				return 0, fmt.Errorf("invalid duration %q", value)
			}
			num = ""
			sawUnit = true
			switch ch {
			case 'W':
				total += time.Duration(n) * 7 * 24 * time.Hour
			case 'D':
				total += time.Duration(n) * 24 * time.Hour
			case 'H':
				if !inTime {
					return 0, fmt.Errorf("invalid duration %q", value)
				}
				total += time.Duration(n) * time.Hour
			case 'M':
				if !inTime {
					return 0, fmt.Errorf("invalid duration %q", value)
				}
				total += time.Duration(n) * time.Minute
			case 'S':
				if !inTime {
					return 0, fmt.Errorf("invalid duration %q", value)
				}
				total += time.Duration(n) * time.Second
			}
		default:
			return 0, fmt.Errorf("invalid duration %q", value)
		}
	}
	if num != "" {
		return 0, fmt.Errorf("invalid duration %q", value)
	}
	if !sawUnit {
		return 0, fmt.Errorf("invalid duration %q", value)
	}
	if neg {
		total = -total
	}
	return total, nil
}

// CanonicalTZID resolves a TZID to an IANA identifier, accepting common
// Windows names and vendor-prefixed identifiers. It returns false if the zone
// cannot be resolved by the embedded tzdata.
func CanonicalTZID(tzid string) (string, bool) {
	tzid = strings.TrimSpace(tzid)
	if tzid == "" {
		return "", false
	}
	candidates := append([]string{tzid}, tzidAliases(tzid)...)
	for _, candidate := range candidates {
		if mapped, ok := windowsZones[strings.ToLower(candidate)]; ok {
			if _, err := time.LoadLocation(mapped); err == nil {
				return mapped, true
			}
		}
		trimmed := strings.TrimPrefix(candidate, "/")
		if _, err := time.LoadLocation(trimmed); err == nil {
			return trimmed, true
		}
	}
	return "", false
}

func parseUTCOffset(value string) (int, bool) {
	v := strings.TrimSpace(strings.ReplaceAll(value, ":", ""))
	if len(v) != 5 && len(v) != 7 {
		return 0, false
	}
	sign := 1
	switch v[0] {
	case '+':
	case '-':
		sign = -1
	default:
		return 0, false
	}
	hh, err1 := strconv.Atoi(v[1:3])
	mm, err2 := strconv.Atoi(v[3:5])
	ss := 0
	var err3 error
	if len(v) == 7 {
		ss, err3 = strconv.Atoi(v[5:7])
	}
	if err1 != nil || err2 != nil || err3 != nil {
		return 0, false
	}
	return sign * (hh*3600 + mm*60 + ss), true
}

// vtimezoneOffset works out the UTC offset of a VTIMEZONE at the supplied
// wall-clock time. It evaluates STANDARD/DAYLIGHT observances and their
// recurrence rules rather than relying on the host tzdata.
func vtimezoneOffset(tz *Component, when time.Time) (int, bool) {
	type observance struct {
		onset  time.Time
		offset int
	}
	var observances []observance
	for _, child := range tz.Children {
		if child.Name != "STANDARD" && child.Name != "DAYLIGHT" {
			continue
		}
		off, ok := parseUTCOffset(child.Value("TZOFFSETTO"))
		if !ok {
			continue
		}
		startProp := child.Get("DTSTART")
		if startProp == nil {
			continue
		}
		start, err := time.ParseInLocation("20060102T150405", strings.TrimSuffix(startProp.Value, "Z"), time.UTC)
		if err != nil {
			if start, err = time.ParseInLocation("20060102", startProp.Value, time.UTC); err != nil {
				continue
			}
		}
		observances = append(observances, observance{onset: start, offset: off})

		if rule := child.Get("RRULE"); rule != nil {
			onsets := expandNaiveRule(start, rule.Value, when.Year())
			for _, onset := range onsets {
				observances = append(observances, observance{onset: onset, offset: off})
			}
		}
		for _, rdate := range child.All("RDATE") {
			for _, v := range strings.Split(rdate.Value, ",") {
				v = strings.TrimSpace(v)
				if len(v) >= 15 {
					if t, err := time.ParseInLocation("20060102T150405", strings.TrimSuffix(v, "Z")[:15], time.UTC); err == nil {
						observances = append(observances, observance{onset: t, offset: off})
					}
				}
			}
		}
	}
	if len(observances) == 0 {
		return 0, false
	}
	sort.Slice(observances, func(i, j int) bool { return observances[i].onset.Before(observances[j].onset) })
	naive := time.Date(when.Year(), when.Month(), when.Day(), when.Hour(), when.Minute(), when.Second(), 0, time.UTC)
	chosen := observances[0]
	for _, o := range observances {
		if o.onset.After(naive) {
			break
		}
		chosen = o
	}
	return chosen.offset, true
}

// expandNaiveRule expands an RRULE for a VTIMEZONE observance around year.
func expandNaiveRule(start time.Time, rule string, year int) []time.Time {
	// A small, dependency-free expansion sufficient for timezone rules, which
	// are almost always FREQ=YEARLY with BYMONTH/BYDAY/BYSETPOS.
	fields := parseRuleFields(rule)
	freq := strings.ToUpper(fields["FREQ"])
	if freq != "YEARLY" && freq != "MONTHLY" {
		return nil
	}
	var out []time.Time
	for y := year - 2; y <= year+1; y++ {
		if freq == "YEARLY" {
			months := []int{int(start.Month())}
			if v := fields["BYMONTH"]; v != "" {
				months = parseInts(v)
			}
			for _, m := range months {
				if m < 1 || m > 12 {
					continue
				}
				days := monthDays(y, time.Month(m), fields, start.Day())
				for _, d := range days {
					out = append(out, time.Date(y, time.Month(m), d, start.Hour(), start.Minute(), start.Second(), 0, time.UTC))
				}
			}
		}
	}
	return out
}

func parseRuleFields(rule string) map[string]string {
	out := map[string]string{}
	for _, part := range strings.Split(strings.TrimSpace(rule), ";") {
		k, v, ok := strings.Cut(part, "=")
		if !ok {
			continue
		}
		out[strings.ToUpper(strings.TrimSpace(k))] = strings.TrimSpace(v)
	}
	return out
}

func parseInts(s string) []int {
	var out []int
	for _, part := range strings.Split(s, ",") {
		if n, err := strconv.Atoi(strings.TrimSpace(part)); err == nil {
			out = append(out, n)
		}
	}
	return out
}

// monthDays returns the days in a month selected by BYMONTHDAY/BYDAY rules.
func monthDays(year int, month time.Month, fields map[string]string, fallback int) []int {
	last := time.Date(year, month+1, 0, 0, 0, 0, 0, time.UTC).Day()
	if v := fields["BYMONTHDAY"]; v != "" {
		var out []int
		for _, d := range parseInts(v) {
			if d < 0 {
				d = last + 1 + d
			}
			if d >= 1 && d <= last {
				out = append(out, d)
			}
		}
		return out
	}
	if v := fields["BYDAY"]; v != "" {
		var all []int
		for _, token := range strings.Split(v, ",") {
			token = strings.TrimSpace(strings.ToUpper(token))
			ord := 0
			day := ""
			if len(token) >= 2 {
				day = token[len(token)-2:]
				if len(token) > 2 {
					ord, _ = strconv.Atoi(token[:len(token)-2])
				}
			}
			wd, ok := weekdayNumbers[day]
			if !ok {
				continue
			}
			if ord == 0 {
				for d := 1; d <= last; d++ {
					if int(time.Date(year, month, d, 0, 0, 0, 0, time.UTC).Weekday()) == wd {
						all = append(all, d)
					}
				}
			} else if ord > 0 {
				count := 0
				for d := 1; d <= last; d++ {
					if int(time.Date(year, month, d, 0, 0, 0, 0, time.UTC).Weekday()) == wd {
						count++
						if count == ord {
							all = append(all, d)
							break
						}
					}
				}
			} else {
				count := 0
				for d := last; d >= 1; d-- {
					if int(time.Date(year, month, d, 0, 0, 0, 0, time.UTC).Weekday()) == wd {
						count++
						if count == -ord {
							all = append(all, d)
							break
						}
					}
				}
			}
		}
		return all
	}
	if fallback >= 1 && fallback <= last {
		return []int{fallback}
	}
	return nil
}

var weekdayNumbers = map[string]int{"SU": 0, "MO": 1, "TU": 2, "WE": 3, "TH": 4, "FR": 5, "SA": 6}

// windowsZones maps common Windows timezone names to IANA identifiers.
var windowsZones = map[string]string{
	"dateline standard time":         "Etc/GMT+12",
	"utc-11":                         "Etc/GMT+11",
	"hawaiian standard time":         "Pacific/Honolulu",
	"alaskan standard time":          "America/Anchorage",
	"pacific standard time":          "America/Los_Angeles",
	"pacific standard time (mexico)": "America/Tijuana",
	"us mountain standard time":      "America/Phoenix",
	"mountain standard time":         "America/Denver",
	"central standard time":          "America/Chicago",
	"central america standard time":  "America/Guatemala",
	"central standard time (mexico)": "America/Mexico_City",
	"canada central standard time":   "America/Regina",
	"eastern standard time":          "America/New_York",
	"us eastern standard time":       "America/Indiana/Indianapolis",
	"atlantic standard time":         "America/Halifax",
	"newfoundland standard time":     "America/St_Johns",
	"argentina standard time":        "America/Argentina/Buenos_Aires",
	"sa pacific standard time":       "America/Bogota",
	"e. south america standard time": "America/Sao_Paulo",
	"greenwich standard time":        "Atlantic/Reykjavik",
	"gmt standard time":              "Europe/London",
	"utc":                            "Etc/UTC",
	"central europe standard time":   "Europe/Budapest",
	"central european standard time": "Europe/Warsaw",
	"romance standard time":          "Europe/Paris",
	"weurope standard time":          "Europe/Lisbon",
	"w. europe standard time":        "Europe/Berlin",
	"west europe standard time":      "Europe/Berlin",
	"gtb standard time":              "Europe/Bucharest",
	"fle standard time":              "Europe/Kyiv",
	"turkey standard time":           "Europe/Istanbul",
	"russian standard time":          "Europe/Moscow",
	"israel standard time":           "Asia/Jerusalem",
	"arabian standard time":          "Asia/Dubai",
	"arab standard time":             "Asia/Riyadh",
	"iran standard time":             "Asia/Tehran",
	"afghanistan standard time":      "Asia/Kabul",
	"pakistan standard time":         "Asia/Karachi",
	"india standard time":            "Asia/Kolkata",
	"nepal standard time":            "Asia/Kathmandu",
	"bangladesh standard time":       "Asia/Dhaka",
	"se asia standard time":          "Asia/Bangkok",
	"china standard time":            "Asia/Shanghai",
	"singapore standard time":        "Asia/Singapore",
	"taiwan standard time":           "Asia/Taipei",
	"tokyo standard time":            "Asia/Tokyo",
	"korea standard time":            "Asia/Seoul",
	"cen. australia standard time":   "Australia/Adelaide",
	"aus eastern standard time":      "Australia/Sydney",
	"e. australia standard time":     "Australia/Brisbane",
	"aus central w. standard time":   "Australia/Eucla",
	"w. australia standard time":     "Australia/Perth",
	"new zealand standard time":      "Pacific/Auckland",
	"utc+12":                         "Etc/GMT-12",
}
