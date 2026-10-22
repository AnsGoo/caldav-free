package dav

import (
	"bytes"
	"encoding/xml"
	"net/http"
	"strconv"
	"strings"

	"caldav-free/internal/ical"
	"caldav-free/internal/store"
)

type propSetXML struct {
	Prop propContainer `xml:"DAV: prop"`
}

type propertyUpdateXML struct {
	XMLName xml.Name
	Set     []propSetXML `xml:"DAV: set"`
	Remove  []propSetXML `xml:"DAV: remove"`
}

type mkcalendarXML struct {
	XMLName xml.Name
	Set     []propSetXML `xml:"DAV: set"`
}

type mkcolXML struct {
	XMLName xml.Name
	Set     []propSetXML `xml:"DAV: set"`
}

type propChange struct {
	Name   xml.Name
	Remove bool
	Raw    string
}

func collectPropChanges(sets []propSetXML, remove bool) []propChange {
	var out []propChange
	for _, set := range sets {
		for _, prop := range set.Prop.Props {
			out = append(out, propChange{Name: prop.XMLName, Remove: remove, Raw: prop.InnerXML})
		}
	}
	return out
}

func innerText(raw string) string {
	var value string
	if err := xml.Unmarshal([]byte("<v>"+raw+"</v>"), &value); err != nil {
		return ""
	}
	return value
}

type calendarValues struct {
	DisplayName  string
	Description  string
	Color        string
	Order        int
	Timezone     string
	TimezoneData string
	Components   []string
}

func calendarValuesFrom(cal *store.Calendar) calendarValues {
	return calendarValues{
		DisplayName:  cal.DisplayName,
		Description:  cal.Description,
		Color:        cal.Color,
		Order:        cal.Order,
		Timezone:     cal.Timezone,
		TimezoneData: cal.TimezoneData,
		Components:   append([]string(nil), cal.Components...),
	}
}

func defaultCalendarValues(slug string) calendarValues {
	return calendarValues{
		DisplayName: slug,
		Timezone:    store.DefaultTimezone,
		Components:  []string{"VEVENT", "VTODO", "VJOURNAL"},
	}
}

// applyCalendarChanges validates and applies a set of PROPPATCH-style changes.
// It is atomic: on any failure the returned values are unchanged and failures
// are reported per property.
func applyCalendarChanges(base calendarValues, changes []propChange) (calendarValues, []propResult, bool) {
	out := base
	failures := []propResult{}
	for _, change := range changes {
		name := change.Name
		local := name.Local
		value := ""
		if !change.Remove {
			value = innerText(change.Raw)
		}
		switch {
		case (name.Space == nsDAV || name.Space == "") && local == "displayname":
			out.DisplayName = strings.TrimSpace(value)
		case (name.Space == nsCalDAV || name.Space == "") && local == "calendar-description":
			out.Description = value
		case (name.Space == nsApple || name.Space == nsCS || name.Space == nsCalDAV || name.Space == "") && local == "calendar-color":
			out.Color = strings.TrimSpace(value)
		case (name.Space == nsApple || name.Space == nsCS || name.Space == nsCalDAV || name.Space == "") && local == "calendar-order":
			if change.Remove || strings.TrimSpace(value) == "" {
				out.Order = 0
				continue
			}
			n, err := strconv.Atoi(strings.TrimSpace(value))
			if err != nil {
				failures = append(failures, propResult{Name: name, Status: http.StatusConflict})
				continue
			}
			out.Order = n
		case (name.Space == nsCalDAV || name.Space == "") && local == "calendar-timezone":
			if change.Remove || strings.TrimSpace(value) == "" {
				out.Timezone = store.DefaultTimezone
				out.TimezoneData = ""
				continue
			}
			id, data, ok := parseCalendarTimezone(value)
			if !ok {
				failures = append(failures, propResult{Name: name, Status: http.StatusForbidden})
				continue
			}
			out.Timezone = id
			out.TimezoneData = data
		case (name.Space == nsCalDAV || name.Space == "") && local == "supported-calendar-component-set":
			if change.Remove {
				out.Components = []string{"VEVENT", "VTODO", "VJOURNAL"}
				continue
			}
			components, ok := parseComponentSet(change.Raw)
			if !ok {
				failures = append(failures, propResult{Name: name, Status: http.StatusForbidden})
				continue
			}
			out.Components = components
		default:
			// Protected or unknown properties cannot be modified.
			failures = append(failures, propResult{Name: name, Status: http.StatusForbidden})
		}
	}
	if len(failures) > 0 {
		results := make([]propResult, 0, len(changes))
		failed := map[xml.Name]bool{}
		for _, f := range failures {
			failed[f.Name] = true
		}
		for _, change := range changes {
			if failed[change.Name] {
				results = append(results, propResult{Name: change.Name, Status: http.StatusForbidden})
			} else {
				results = append(results, propResult{Name: change.Name, Status: http.StatusFailedDependency})
			}
		}
		return base, results, false
	}
	results := make([]propResult, 0, len(changes))
	for _, change := range changes {
		results = append(results, propResult{Name: change.Name, Status: http.StatusOK})
	}
	return out, results, true
}

func parseComponentSet(raw string) ([]string, bool) {
	if strings.TrimSpace(raw) == "" {
		return nil, false
	}
	var doc struct {
		Comps []struct {
			Name string `xml:"name,attr"`
		} `xml:"comp"`
	}
	if err := xml.Unmarshal([]byte("<set>"+raw+"</set>"), &doc); err != nil {
		return nil, false
	}
	var out []string
	seen := map[string]bool{}
	for _, comp := range doc.Comps {
		name := strings.ToUpper(strings.TrimSpace(comp.Name))
		if !ical.ValidComponentType(name) || seen[name] {
			continue
		}
		seen[name] = true
		out = append(out, name)
	}
	if len(out) == 0 {
		return nil, false
	}
	return out, true
}

// parseCalendarTimezone accepts either a VTIMEZONE payload or a bare TZID.
func parseCalendarTimezone(value string) (id, data string, ok bool) {
	value = strings.TrimSpace(value)
	if value == "" {
		return "", "", false
	}
	if !strings.Contains(value, "BEGIN:VTIMEZONE") {
		canonical, ok := ical.CanonicalTZID(value)
		if !ok {
			return "", "", false
		}
		return canonical, "", true
	}
	payload := strings.TrimSpace(value)
	if !strings.HasPrefix(payload, "BEGIN:VCALENDAR") {
		payload = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n" + payload + "\r\nEND:VCALENDAR"
	}
	root, err := ical.Parse([]byte(payload))
	if err != nil {
		return "", "", false
	}
	tz := root.Child("VTIMEZONE")
	if tz == nil {
		return "", "", false
	}
	tzid := strings.TrimSpace(tz.Value("TZID"))
	if tzid == "" {
		return "", "", false
	}
	canonical, ok := ical.CanonicalTZID(tzid)
	if !ok {
		// Accept the VTIMEZONE even when the host tzdata cannot resolve its
		// TZID; it is still useful for clients and the raw payload is retained.
		canonical = strings.TrimPrefix(tzid, "/")
	}
	return canonical, value, true
}

func (h *Handler) handleProppatch(w http.ResponseWriter, r *http.Request, t target, current *store.User) {
	if t.kind != targetCalendar {
		w.Header().Set("Allow", allowFor(t.kind))
		http.Error(w, "PROPPATCH is only supported on calendars", http.StatusForbidden)
		return
	}
	body, ok := readBody(w, r, h.MaxBodySize)
	if !ok {
		return
	}
	var doc propertyUpdateXML
	if err := xml.Unmarshal(body, &doc); err != nil {
		http.Error(w, "invalid PROPPATCH body", http.StatusBadRequest)
		return
	}
	ctx := r.Context()
	owner, ok := h.loadOwner(ctx, t.user, current)
	if !ok {
		http.NotFound(w, r)
		return
	}
	cal, err := h.Store.GetCalendarBySlug(ctx, owner.ID, t.slug)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	changes := append(collectPropChanges(doc.Set, false), collectPropChanges(doc.Remove, true)...)
	if len(changes) == 0 {
		http.Error(w, "no properties supplied", http.StatusBadRequest)
		return
	}

	values, results, ok := applyCalendarChanges(calendarValuesFrom(cal), changes)
	if !ok {
		writeMultistatus(w, []davResponse{{
			Href:  calendarHref(owner.Username, cal.Slug),
			Props: results,
		}})
		return
	}
	if err := h.Store.UpdateCalendar(ctx, cal.ID, values.DisplayName, values.Description, values.Color,
		values.Timezone, values.Order, values.Components); err != nil {
		h.Logger.Error("update calendar", "error", err)
		http.Error(w, "failed to update calendar", http.StatusInternalServerError)
		return
	}
	if values.TimezoneData != cal.TimezoneData {
		if err := h.Store.SetCalendarTimezoneData(ctx, cal.ID, values.TimezoneData); err != nil {
			h.Logger.Error("update calendar timezone", "error", err)
		}
	}
	writeMultistatus(w, []davResponse{{
		Href:  calendarHref(owner.Username, cal.Slug),
		Props: results,
	}})
}

func (h *Handler) handleMkcalendar(w http.ResponseWriter, r *http.Request, t target, current *store.User) {
	body, ok := readBody(w, r, h.MaxBodySize)
	if !ok {
		return
	}
	h.createCalendar(w, r, t, current, body)
}

func (h *Handler) handleMkcol(w http.ResponseWriter, r *http.Request, t target, current *store.User) {
	body, ok := readBody(w, r, h.MaxBodySize)
	if !ok {
		return
	}
	if len(bytes.TrimSpace(body)) > 0 {
		var doc mkcolXML
		if err := xml.Unmarshal(body, &doc); err != nil {
			http.Error(w, "invalid MKCOL body", http.StatusBadRequest)
			return
		}
		hasCalendarType := false
		for _, change := range collectPropChanges(doc.Set, false) {
			if change.Name.Local == "resourcetype" && strings.Contains(change.Raw, "calendar") {
				hasCalendarType = true
			}
		}
		if !hasCalendarType {
			http.Error(w, "only calendar collections can be created", http.StatusForbidden)
			return
		}
	}
	h.createCalendar(w, r, t, current, body)
}

func (h *Handler) createCalendar(w http.ResponseWriter, r *http.Request, t target, current *store.User, body []byte) {
	if t.kind != targetCalendar {
		w.Header().Set("Allow", allowFor(t.kind))
		http.Error(w, "calendars must be created inside a calendar home", http.StatusForbidden)
		return
	}
	ctx := r.Context()
	owner, ok := h.loadOwner(ctx, t.user, current)
	if !ok {
		http.NotFound(w, r)
		return
	}
	if _, err := h.Store.GetCalendarBySlug(ctx, owner.ID, t.slug); err == nil {
		writeDAVError(w, http.StatusMethodNotAllowed, davError(nsDAV, "resource-must-be-null"))
		return
	}
	if !validCalendarSlug(t.slug) {
		writeDAVError(w, http.StatusForbidden, davError(nsCalDAV, "valid-calendar-data"))
		return
	}

	var changes []propChange
	if len(bytes.TrimSpace(body)) > 0 {
		var doc mkcalendarXML
		if err := xml.Unmarshal(body, &doc); err != nil {
			http.Error(w, "invalid calendar creation body", http.StatusBadRequest)
			return
		}
		changes = append(changes, collectPropChanges(doc.Set, false)...)
	}
	filtered := changes[:0]
	for _, change := range changes {
		if strings.EqualFold(change.Name.Local, "resourcetype") {
			continue
		}
		filtered = append(filtered, change)
	}
	changes = filtered
	values, _, valid := applyCalendarChanges(defaultCalendarValues(t.slug), changes)
	if !valid {
		writeDAVError(w, http.StatusForbidden, davError(nsCalDAV, "valid-calendar-data"))
		return
	}
	cal, err := h.Store.CreateCalendar(ctx, owner.ID, t.slug, values.DisplayName, values.Description,
		values.Color, values.Timezone, values.Order, values.Components)
	if err != nil {
		if err == store.ErrConflict {
			writeDAVError(w, http.StatusMethodNotAllowed, davError(nsDAV, "resource-must-be-null"))
			return
		}
		h.Logger.Error("create calendar", "error", err)
		http.Error(w, "failed to create calendar", http.StatusInternalServerError)
		return
	}
	if values.TimezoneData != "" {
		if err := h.Store.SetCalendarTimezoneData(ctx, cal.ID, values.TimezoneData); err != nil {
			h.Logger.Error("store calendar timezone", "error", err)
		}
	}
	w.Header().Set("Location", calendarHref(owner.Username, cal.Slug))
	w.Header().Set("Content-Length", "0")
	w.WriteHeader(http.StatusCreated)
}

func validCalendarSlug(slug string) bool {
	if slug == "" || len(slug) > 100 {
		return false
	}
	if slug == "." || slug == ".." || strings.HasPrefix(slug, ".") {
		return false
	}
	for _, r := range slug {
		switch {
		case r >= 'a' && r <= 'z':
		case r >= 'A' && r <= 'Z':
		case r >= '0' && r <= '9':
		case r == '-' || r == '_' || r == '.':
		default:
			return false
		}
	}
	return true
}
