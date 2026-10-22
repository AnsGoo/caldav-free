package ical

import (
	"strings"
	"time"
)

// TimeRange is a CalDAV time-range filter. Zero bounds are open-ended.
type TimeRange struct {
	Start time.Time
	End   time.Time
}

// CompFilter is a CalDAV comp-filter.
type CompFilter struct {
	Name         string
	IsNotDefined bool
	TimeRange    *TimeRange
	PropFilters  []PropFilter
	CompFilters  []CompFilter
}

// PropFilter is a CalDAV prop-filter.
type PropFilter struct {
	Name         string
	IsNotDefined bool
	TimeRange    *TimeRange
	TextMatch    *TextMatch
	ParamFilters []ParamFilter
}

// ParamFilter is a CalDAV param-filter.
type ParamFilter struct {
	Name         string
	IsNotDefined bool
	TextMatch    *TextMatch
}

// TextMatch is a CalDAV text-match.
type TextMatch struct {
	Value  string
	Negate bool
}

// MatchObject reports whether the object satisfies the filter. The root
// filter must be VCALENDAR (the common CalDAV case).
func (c *Calendar) MatchObject(filter *CompFilter) bool {
	if filter == nil {
		return true
	}
	if !strings.EqualFold(filter.Name, "VCALENDAR") {
		return false
	}
	if filter.IsNotDefined {
		return false
	}
	if filter.TimeRange != nil && !c.matchesRootTimeRange(filter.TimeRange) {
		return false
	}
	if len(filter.CompFilters) == 0 {
		return true
	}
	for i := range filter.CompFilters {
		if c.matchComponent(&filter.CompFilters[i]) {
			return true
		}
	}
	return false
}

// matchesRootTimeRange matches any timed component in the object.
func (c *Calendar) matchesRootTimeRange(tr *TimeRange) bool {
	start, end := normalizeRange(tr)
	for _, comp := range c.calendarComponents() {
		if c.MatchesTimeRange(comp, start, end) {
			return true
		}
	}
	return false
}

func (c *Calendar) matchComponent(f *CompFilter) bool {
	var candidates []*Component
	for _, child := range c.Root.Children {
		if strings.EqualFold(child.Name, f.Name) {
			candidates = append(candidates, child)
		}
	}
	if f.IsNotDefined {
		return len(candidates) == 0
	}
	if len(candidates) == 0 {
		return false
	}

	for _, comp := range candidates {
		if c.componentMatches(comp, f) {
			return true
		}
	}
	return false
}

func (c *Calendar) componentMatches(comp *Component, f *CompFilter) bool {
	if f.TimeRange != nil {
		start, end := normalizeRange(f.TimeRange)
		if !c.MatchesTimeRange(comp, start, end) {
			return false
		}
	}
	for i := range f.PropFilters {
		if !c.componentMatchesProp(comp, &f.PropFilters[i]) {
			return false
		}
	}
	if len(f.CompFilters) > 0 {
		matchedAny := false
		for i := range f.CompFilters {
			child := &f.CompFilters[i]
			if child.IsNotDefined {
				if len(comp.ChildrenNamed(child.Name)) == 0 {
					matchedAny = true
				}
				continue
			}
			for _, sub := range comp.ChildrenNamed(child.Name) {
				if c.componentMatches(sub, child) {
					matchedAny = true
					break
				}
			}
		}
		if !matchedAny {
			return false
		}
	}
	return true
}

func (c *Calendar) componentMatchesProp(comp *Component, f *PropFilter) bool {
	props := comp.All(f.Name)
	if f.IsNotDefined {
		return len(props) == 0
	}
	if len(props) == 0 {
		return false
	}
	for _, p := range props {
		ok := true
		if f.TimeRange != nil {
			tv, err := c.ParseTimeProp(p)
			if err != nil {
				ok = false
			} else {
				propEnd := tv.Time
				if tv.Date {
					propEnd = propEnd.AddDate(0, 0, 1)
				}
				start, end := normalizeRange(f.TimeRange)
				if !overlapsRange(tv.Time, propEnd, tv.Date, start, end) {
					ok = false
				}
			}
		}
		if ok && f.TextMatch != nil {
			found := strings.Contains(strings.ToLower(UnescapeText(p.Value)), strings.ToLower(f.TextMatch.Value))
			if f.TextMatch.Negate {
				found = !found
			}
			if !found {
				ok = false
			}
		}
		for i := range f.ParamFilters {
			if ok && !paramMatches(p, &f.ParamFilters[i]) {
				ok = false
			}
		}
		if ok {
			return true
		}
	}
	return false
}

func paramMatches(p *Prop, f *ParamFilter) bool {
	values := p.Params.Values(f.Name)
	if f.IsNotDefined {
		return len(values) == 0
	}
	if len(values) == 0 {
		return false
	}
	if f.TextMatch == nil {
		return true
	}
	for _, v := range values {
		found := strings.Contains(strings.ToLower(v), strings.ToLower(f.TextMatch.Value))
		if f.TextMatch.Negate {
			found = !found
		}
		if found {
			return true
		}
	}
	return false
}

func normalizeRange(tr *TimeRange) (time.Time, time.Time) {
	start, end := tr.Start, tr.End
	if start.IsZero() {
		start = infiniteStart
	}
	if end.IsZero() {
		end = infiniteEnd
	}
	return start, end
}
