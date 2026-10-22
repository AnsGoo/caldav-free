package ical

import (
	"fmt"
	"sort"
	"strings"
	"time"

	rrule "github.com/teambition/rrule-go"
)

// MaxInstances bounds recurrence expansion to protect the server from
// pathological rules. Clients should never need more in a single query.
const MaxInstances = 20000

var (
	// InfiniteEnd is used for unbounded recurrences.
	infiniteEnd   = time.Date(9999, 12, 31, 23, 59, 59, 0, time.UTC)
	infiniteStart = time.Date(1, 1, 1, 0, 0, 0, 0, time.UTC)
)

// Instance is one expanded occurrence of a calendar component.
type Instance struct {
	Start        time.Time
	End          time.Time
	AllDay       bool
	Component    *Component
	RecurrenceID *time.Time
}

// ObjectInfo describes the time extent of a calendar object resource.
type ObjectInfo struct {
	UID           string
	ComponentType string
	FirstStart    time.Time
	LastEnd       time.Time
	Recurring     bool
	Unbounded     bool
}

// Analyze validates a calendar object and computes its cached time bounds.
func (c *Calendar) Analyze() (*ObjectInfo, error) {
	components := c.calendarComponents()
	if len(components) == 0 {
		return nil, fmt.Errorf("calendar contains no VEVENT, VTODO or VJOURNAL")
	}
	info := &ObjectInfo{}
	info.FirstStart = infiniteEnd
	info.LastEnd = infiniteStart

	seenUID := ""
	for _, comp := range components {
		uid := strings.TrimSpace(UnescapeText(comp.Value("UID")))
		if uid == "" {
			return nil, fmt.Errorf("%s is missing UID", comp.Name)
		}
		if seenUID == "" {
			seenUID = uid
		} else if seenUID != uid {
			return nil, fmt.Errorf("calendar object contains multiple UIDs")
		}
		if info.ComponentType == "" {
			info.ComponentType = comp.Name
		} else if info.ComponentType != comp.Name {
			return nil, fmt.Errorf("calendar object mixes %s and %s", info.ComponentType, comp.Name)
		}
	}
	info.UID = seenUID

	for _, comp := range components {
		start, end, _, err := c.ComponentTimes(comp)
		if err != nil {
			return nil, err
		}
		if start.IsZero() {
			continue
		}
		if start.Before(info.FirstStart) {
			info.FirstStart = start
		}
		recurring := comp.Get("RRULE") != nil || len(comp.All("RDATE")) > 0
		if comp.Get("RECURRENCE-ID") != nil {
			recurring = false
		}
		if recurring {
			info.Recurring = true
			last, bounded := c.lastOccurrenceEnd(comp, start, end)
			if !bounded {
				info.Unbounded = true
				info.LastEnd = infiniteEnd
			} else if last.After(info.LastEnd) {
				info.LastEnd = last
			}
		} else if end.After(info.LastEnd) {
			info.LastEnd = end
		}
	}
	if info.FirstStart.Equal(infiniteEnd) {
		info.FirstStart = time.Time{}
	}
	if info.LastEnd.Equal(infiniteStart) {
		info.LastEnd = time.Time{}
	}
	return info, nil
}

func (c *Calendar) calendarComponents() []*Component {
	var out []*Component
	for _, comp := range c.Root.Children {
		switch comp.Name {
		case "VEVENT", "VTODO", "VJOURNAL", "VFREEBUSY":
			out = append(out, comp)
		}
	}
	return out
}

// ComponentTimes returns the base start/end of a component. For a recurring
// master this is just the first occurrence's extent.
func (c *Calendar) ComponentTimes(comp *Component) (start, end time.Time, allDay bool, err error) {
	parse := func(name string) (TimeValue, bool, error) {
		p := comp.Get(name)
		if p == nil {
			return TimeValue{}, false, nil
		}
		tv, err := c.ParseTimeProp(p)
		return tv, true, err
	}

	dtstart, hasStart, err := parse("DTSTART")
	if err != nil {
		return time.Time{}, time.Time{}, false, fmt.Errorf("DTSTART: %w", err)
	}
	allDay = hasStart && dtstart.Date

	switch comp.Name {
	case "VEVENT", "VFREEBUSY":
		if !hasStart {
			return time.Time{}, time.Time{}, false, fmt.Errorf("%s is missing DTSTART", comp.Name)
		}
		start = dtstart.Time
		if dtend, ok, err := parse("DTEND"); err != nil {
			return time.Time{}, time.Time{}, false, fmt.Errorf("DTEND: %w", err)
		} else if ok {
			end = dtend.Time
		} else if dur := comp.Get("DURATION"); dur != nil {
			d, err := ParseDuration(dur.Value)
			if err != nil {
				return time.Time{}, time.Time{}, false, fmt.Errorf("DURATION: %w", err)
			}
			end = start.Add(d)
		} else if allDay {
			end = start.AddDate(0, 0, 1)
		} else {
			end = start
		}
	case "VTODO":
		if hasStart {
			start = dtstart.Time
		} else if due, ok, err := parse("DUE"); err != nil {
			return time.Time{}, time.Time{}, false, fmt.Errorf("DUE: %w", err)
		} else if ok {
			start = due.Time
			allDay = due.Date
		} else if p := comp.Get("COMPLETED"); p != nil {
			if tv, err := c.ParseTimeProp(p); err == nil {
				start = tv.Time
			}
		}
		if due, ok, err := parse("DUE"); err != nil {
			return time.Time{}, time.Time{}, false, fmt.Errorf("DUE: %w", err)
		} else if ok {
			end = due.Time
		} else if dur := comp.Get("DURATION"); dur != nil && !start.IsZero() {
			d, err := ParseDuration(dur.Value)
			if err != nil {
				return time.Time{}, time.Time{}, false, fmt.Errorf("DURATION: %w", err)
			}
			end = start.Add(d)
		} else {
			end = start
		}
	case "VJOURNAL":
		if hasStart {
			start = dtstart.Time
		} else if p := comp.Get("DTSTAMP"); p != nil {
			if tv, err := c.ParseTimeProp(p); err == nil {
				start = tv.Time
			}
		}
		if allDay {
			end = start.AddDate(0, 0, 1)
		} else {
			end = start
		}
	default:
		return time.Time{}, time.Time{}, false, fmt.Errorf("unsupported component %s", comp.Name)
	}
	if !start.IsZero() && !end.IsZero() && end.Before(start) {
		end = start
	}
	return start, end, allDay, nil
}

// ExpandObject expands every component of the calendar into instances that
// overlap [rangeStart, rangeEnd). A zero rangeEnd means "no upper bound".
func (c *Calendar) ExpandObject(rangeStart, rangeEnd time.Time, limit int) ([]Instance, error) {
	if limit <= 0 || limit > MaxInstances {
		limit = MaxInstances
	}
	components := c.calendarComponents()
	if len(components) == 0 {
		return nil, nil
	}

	// Group overrides by recurrence ID (per UID).
	overrides := map[string]map[int64]*Component{}
	for _, comp := range components {
		rid := comp.Get("RECURRENCE-ID")
		if rid == nil {
			continue
		}
		tv, err := c.ParseTimeProp(rid)
		if err != nil {
			continue
		}
		uid := comp.Value("UID")
		if overrides[uid] == nil {
			overrides[uid] = map[int64]*Component{}
		}
		overrides[uid][tv.Time.UTC().Unix()] = comp
	}

	var out []Instance
	for _, comp := range components {
		if comp.Get("RECURRENCE-ID") != nil {
			continue
		}
		start, end, allDay, err := c.ComponentTimes(comp)
		if err != nil || start.IsZero() {
			continue
		}
		instances, err := c.expandComponent(comp, start, end, allDay, rangeStart, rangeEnd, limit-len(out), overrides[comp.Value("UID")])
		if err != nil {
			return nil, err
		}
		out = append(out, instances...)
	}

	// Overrides are emitted as their own instances. The corresponding master
	// occurrence was skipped above, so moved events appear exactly once.
	for _, byID := range overrides {
		for rid, comp := range byID {
			start, end, allDay, err := c.ComponentTimes(comp)
			if err != nil || start.IsZero() {
				continue
			}
			if overlapsRange(start, end, allDay, rangeStart, rangeEnd) {
				ridTime := time.Unix(rid, 0).UTC()
				out = append(out, Instance{Start: start, End: end, AllDay: allDay, Component: comp, RecurrenceID: &ridTime})
			}
		}
	}

	sort.SliceStable(out, func(i, j int) bool { return out[i].Start.Before(out[j].Start) })
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func (c *Calendar) expandComponent(comp *Component, start, end time.Time, allDay bool, rangeStart, rangeEnd time.Time, limit int, overrides map[int64]*Component) ([]Instance, error) {
	if limit <= 0 {
		limit = MaxInstances
	}
	duration := end.Sub(start)
	if duration < 0 {
		duration = 0
	}

	hasRule := false
	set := &rrule.Set{}
	for _, p := range comp.All("RRULE") {
		opt, err := rrule.StrToROptionInLocation(strings.TrimPrefix(p.Value, "RRULE:"), start.Location())
		if err != nil {
			continue
		}
		opt.Dtstart = start
		rule, err := rrule.NewRRule(*opt)
		if err != nil {
			continue
		}
		set.RRule(rule)
		hasRule = true
	}

	for _, p := range comp.All("RDATE") {
		for _, raw := range strings.Split(p.Value, ",") {
			raw = strings.TrimSpace(raw)
			if raw == "" {
				continue
			}
			// PERIOD values are "start/end" or "start/duration".
			if idx := strings.Index(raw, "/"); idx >= 0 {
				raw = raw[:idx]
			}
			tv, err := c.ParseTime(raw, p.Params)
			if err != nil {
				continue
			}
			set.RDate(tv.Time.In(start.Location()))
			hasRule = true
		}
	}

	for _, p := range comp.All("EXDATE") {
		for _, raw := range strings.Split(p.Value, ",") {
			raw = strings.TrimSpace(raw)
			if raw == "" {
				continue
			}
			tv, err := c.ParseTime(raw, p.Params)
			if err != nil {
				continue
			}
			set.ExDate(tv.Time.In(start.Location()))
		}
	}

	if !hasRule {
		if overrides != nil {
			if _, overridden := overrides[start.UTC().Unix()]; overridden {
				return nil, nil
			}
		}
		if overlapsRange(start, end, allDay, rangeStart, rangeEnd) {
			return []Instance{{Start: start, End: end, AllDay: allDay, Component: comp}}, nil
		}
		return nil, nil
	}

	from := start
	if !rangeStart.IsZero() && rangeStart.Before(start) {
		from = start
	} else if !rangeStart.IsZero() {
		from = rangeStart.Add(-duration)
		if from.Before(start) {
			from = start
		}
	}
	to := rangeEnd
	if to.IsZero() {
		to = start.AddDate(10, 0, 0)
	}
	if to.Before(from) {
		to = from
	}

	occurrences := set.Between(from, to, true)
	if len(occurrences) > limit {
		occurrences = occurrences[:limit]
	}
	seen := map[int64]bool{}
	var out []Instance
	for _, occ := range occurrences {
		key := occ.UTC().Unix()
		rid := time.Unix(key, 0).UTC()
		if overrides != nil {
			if _, overridden := overrides[key]; overridden {
				continue
			}
		}
		if seen[key] {
			continue
		}
		seen[key] = true
		occEnd := occ.Add(duration)
		if allDay && duration == 0 {
			occEnd = occ.AddDate(0, 0, 1)
		}
		if overlapsRange(occ, occEnd, allDay, rangeStart, rangeEnd) {
			out = append(out, Instance{Start: occ, End: occEnd, AllDay: allDay, Component: comp, RecurrenceID: &rid})
		}
	}
	return out, nil
}

// overlapsRange implements the RFC 4791 time-range overlap test. A zero
// Duration component (e.g. a VJOURNAL without DTEND) matches when its start
// falls inside the range.
func overlapsRange(start, end time.Time, allDay bool, rangeStart, rangeEnd time.Time) bool {
	if start.IsZero() {
		return false
	}
	if allDay && !end.After(start) {
		end = start.AddDate(0, 0, 1)
	}
	if !rangeStart.IsZero() && !rangeEnd.IsZero() && !rangeEnd.After(rangeStart) {
		return false
	}
	if !rangeEnd.IsZero() && !start.Before(rangeEnd) {
		return false
	}
	if end.Equal(start) {
		// Zero-length: only the start instant matters.
		if !rangeStart.IsZero() && start.Before(rangeStart) {
			return false
		}
		return true
	}
	if !rangeStart.IsZero() && !end.After(rangeStart) {
		return false
	}
	return true
}

// MatchesTimeRange reports whether any instance of comp overlaps the range.
func (c *Calendar) MatchesTimeRange(comp *Component, rangeStart, rangeEnd time.Time) bool {
	start, end, allDay, err := c.ComponentTimes(comp)
	if err != nil || start.IsZero() {
		return false
	}
	if comp.Get("RRULE") == nil && len(comp.All("RDATE")) == 0 {
		return overlapsRange(start, end, allDay, rangeStart, rangeEnd)
	}
	limit := 5000
	if !rangeStart.IsZero() && !rangeEnd.IsZero() {
		// A rough cap based on range length keeps daily rules manageable while
		// still allowing sub-daily rules.
		days := int(rangeEnd.Sub(rangeStart).Hours()/24) + 2
		if days*4 < limit {
			limit = days*4 + 10
		}
	}
	instances, err := c.expandComponent(comp, start, end, allDay, rangeStart, rangeEnd, limit, nil)
	if err != nil {
		return false
	}
	return len(instances) > 0
}

// lastOccurrenceEnd computes the final end time of a recurrence. The boolean
// is false when the rule is unbounded (or too expensive to enumerate).
func (c *Calendar) lastOccurrenceEnd(comp *Component, start, end time.Time) (time.Time, bool) {
	duration := end.Sub(start)
	last := end
	bounded := true

	set := &rrule.Set{}
	hasRule := false
	for _, p := range comp.All("RRULE") {
		fields := parseRuleFields(strings.TrimPrefix(p.Value, "RRULE:"))
		if fields["COUNT"] == "" && fields["UNTIL"] == "" {
			bounded = false
		}
		if count := fields["COUNT"]; count != "" {
			if n, err := parsePositiveInt(count); err != nil || n > 5000 {
				bounded = false
			}
		}
		opt, err := rrule.StrToROptionInLocation(strings.TrimPrefix(p.Value, "RRULE:"), start.Location())
		if err != nil {
			continue
		}
		opt.Dtstart = start
		rule, err := rrule.NewRRule(*opt)
		if err != nil {
			continue
		}
		set.RRule(rule)
		hasRule = true
	}
	for _, p := range comp.All("RDATE") {
		for _, raw := range strings.Split(p.Value, ",") {
			if idx := strings.Index(raw, "/"); idx >= 0 {
				raw = raw[:idx]
			}
			tv, err := c.ParseTime(strings.TrimSpace(raw), p.Params)
			if err != nil {
				continue
			}
			set.RDate(tv.Time.In(start.Location()))
			hasRule = true
			if tv.Time.Add(duration).After(last) {
				last = tv.Time.Add(duration)
			}
		}
	}
	if !hasRule {
		return end, true
	}
	if !bounded {
		return infiniteEnd, false
	}
	// Finite rule: walk occurrences with a hard cap.
	next := set.Iterator()
	for i := 0; i < 5000; i++ {
		occ, ok := next()
		if !ok {
			return last, true
		}
		if occ.Add(duration).After(last) {
			last = occ.Add(duration)
		}
	}
	if _, more := next(); more {
		return infiniteEnd, false
	}
	return last, true
}

func parsePositiveInt(s string) (int, error) {
	n := 0
	if s == "" {
		return 0, fmt.Errorf("empty")
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return 0, fmt.Errorf("not a number")
		}
		n = n*10 + int(r-'0')
		if n > 1_000_000 {
			return n, nil
		}
	}
	return n, nil
}

// ExpandedObject renders a VCALENDAR containing expanded instances within the
// given range, suitable for a CalDAV calendar-data <expand> response.
func (c *Calendar) ExpandedObject(rangeStart, rangeEnd time.Time) (*Component, error) {
	root := NewComponent("VCALENDAR")
	for _, prop := range c.Root.Props {
		switch prop.Name {
		case "VERSION", "PRODID", "CALSCALE", "METHOD":
			root.Props = append(root.Props, prop.Clone())
		}
	}
	if root.Get("VERSION") == nil {
		root.AddProp("VERSION", "2.0", nil)
	}
	if root.Get("PRODID") == nil {
		root.AddProp("PRODID", "-//caldav-free//CalDAV Server//EN", nil)
	}
	for _, tz := range c.Root.ChildrenNamed("VTIMEZONE") {
		root.AddChild(tz.Clone())
	}
	instances, err := c.ExpandObject(rangeStart, rangeEnd, MaxInstances)
	if err != nil {
		return nil, err
	}
	for _, inst := range instances {
		comp := inst.Component.Clone()
		comp.RemoveProps("RRULE")
		comp.RemoveProps("RDATE")
		comp.RemoveProps("EXDATE")
		comp.RemoveProps("DTSTART")
		comp.RemoveProps("DTEND")
		comp.RemoveProps("DUE")
		comp.RemoveProps("DURATION")
		comp.RemoveProps("RECURRENCE-ID")
		if inst.AllDay {
			comp.AddProp("DTSTART", inst.Start.Format("20060102"), Params{"VALUE": {"DATE"}})
		} else {
			comp.AddProp("DTSTART", inst.Start.UTC().Format("20060102T150405Z"), nil)
		}
		switch comp.Name {
		case "VEVENT", "VFREEBUSY":
			if inst.End.After(inst.Start) {
				if inst.AllDay {
					comp.AddProp("DTEND", inst.End.Format("20060102"), Params{"VALUE": {"DATE"}})
				} else {
					comp.AddProp("DTEND", inst.End.UTC().Format("20060102T150405Z"), nil)
				}
			}
		case "VTODO":
			if inst.End.After(inst.Start) {
				comp.AddProp("DUE", inst.End.UTC().Format("20060102T150405Z"), nil)
			}
		}
		if inst.RecurrenceID != nil {
			if inst.AllDay {
				comp.AddProp("RECURRENCE-ID", inst.RecurrenceID.Format("20060102"), Params{"VALUE": {"DATE"}})
			} else {
				comp.AddProp("RECURRENCE-ID", inst.RecurrenceID.UTC().Format("20060102T150405Z"), nil)
			}
		}
		root.AddChild(comp)
	}
	return root, nil
}

// FreeBusyPeriod is a busy interval.
type FreeBusyPeriod struct {
	Start time.Time
	End   time.Time
}

// FreeBusy computes merged busy periods for VEVENTs in [start, end).
func (c *Calendar) FreeBusy(start, end time.Time) []FreeBusyPeriod {
	instances, err := c.ExpandObject(start, end, MaxInstances)
	if err != nil {
		return nil
	}
	var periods []FreeBusyPeriod
	for _, inst := range instances {
		if inst.Component.Name != "VEVENT" {
			continue
		}
		if strings.EqualFold(inst.Component.Value("STATUS"), "CANCELLED") {
			continue
		}
		if strings.EqualFold(inst.Component.Value("TRANSP"), "TRANSPARENT") {
			continue
		}
		s, e := inst.Start, inst.End
		if e.Equal(s) {
			continue
		}
		if s.Before(start) {
			s = start
		}
		if e.After(end) {
			e = end
		}
		if !e.After(s) {
			continue
		}
		periods = append(periods, FreeBusyPeriod{Start: s, End: e})
	}
	sort.Slice(periods, func(i, j int) bool { return periods[i].Start.Before(periods[j].Start) })
	merged := make([]FreeBusyPeriod, 0, len(periods))
	for _, p := range periods {
		if len(merged) == 0 {
			merged = append(merged, p)
			continue
		}
		last := &merged[len(merged)-1]
		if !p.Start.After(last.End) {
			if p.End.After(last.End) {
				last.End = p.End
			}
			continue
		}
		merged = append(merged, p)
	}
	return merged
}
