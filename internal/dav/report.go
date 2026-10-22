package dav

import (
	"encoding/xml"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/auth"
	"caldav-free/internal/ical"
	"caldav-free/internal/store"
)

type timeRangeXML struct {
	Start string `xml:"start,attr"`
	End   string `xml:"end,attr"`
}

type textMatchXML struct {
	Collation string `xml:"collation,attr"`
	Negate    string `xml:"negate-condition,attr"`
	Value     string `xml:",chardata"`
}

type paramFilterXML struct {
	Name         string        `xml:"name,attr"`
	IsNotDefined *struct{}     `xml:"urn:ietf:params:xml:ns:caldav is-not-defined"`
	TextMatch    *textMatchXML `xml:"urn:ietf:params:xml:ns:caldav text-match"`
}

type propFilterXML struct {
	Name         string           `xml:"name,attr"`
	IsNotDefined *struct{}        `xml:"urn:ietf:params:xml:ns:caldav is-not-defined"`
	TimeRange    *timeRangeXML    `xml:"urn:ietf:params:xml:ns:caldav time-range"`
	TextMatch    *textMatchXML    `xml:"urn:ietf:params:xml:ns:caldav text-match"`
	ParamFilters []paramFilterXML `xml:"urn:ietf:params:xml:ns:caldav param-filter"`
}

type compFilterXML struct {
	Name         string          `xml:"name,attr"`
	IsNotDefined *struct{}       `xml:"urn:ietf:params:xml:ns:caldav is-not-defined"`
	TimeRange    *timeRangeXML   `xml:"urn:ietf:params:xml:ns:caldav time-range"`
	PropFilters  []propFilterXML `xml:"urn:ietf:params:xml:ns:caldav prop-filter"`
	CompFilters  []compFilterXML `xml:"urn:ietf:params:xml:ns:caldav comp-filter"`
}

type limitXML struct {
	NResults int `xml:"urn:ietf:params:xml:ns:caldav nresults"`
}

type filterXML struct {
	CompFilters []compFilterXML `xml:"urn:ietf:params:xml:ns:caldav comp-filter"`
}

type reportEnvelope struct {
	XMLName   xml.Name
	Prop      propContainer `xml:"DAV: prop"`
	Filter    *filterXML    `xml:"urn:ietf:params:xml:ns:caldav filter"`
	TimeRange *timeRangeXML `xml:"urn:ietf:params:xml:ns:caldav time-range"`
	Hrefs     []string      `xml:"DAV: href"`
	SyncToken string        `xml:"DAV: sync-token"`
	SyncLevel string        `xml:"DAV: sync-level"`
	Limit     *limitXML     `xml:"urn:ietf:params:xml:ns:caldav limit"`
}

func parseXMLTime(value string) (time.Time, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return time.Time{}, nil
	}
	layouts := []string{"20060102T150405Z", "20060102T150405", "20060102"}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, value); err == nil {
			return t.UTC(), nil
		}
	}
	return time.Time{}, fmt.Errorf("invalid time %q", value)
}

func (tr *timeRangeXML) toFilter() (*ical.TimeRange, error) {
	if tr == nil {
		return nil, nil
	}
	start, err := parseXMLTime(tr.Start)
	if err != nil {
		return nil, err
	}
	end, err := parseXMLTime(tr.End)
	if err != nil {
		return nil, err
	}
	return &ical.TimeRange{Start: start, End: end}, nil
}

func (cm *compFilterXML) toFilter() (*ical.CompFilter, error) {
	tr, err := cm.TimeRange.toFilter()
	if err != nil {
		return nil, err
	}
	out := &ical.CompFilter{
		Name:         strings.ToUpper(strings.TrimSpace(cm.Name)),
		IsNotDefined: cm.IsNotDefined != nil,
		TimeRange:    tr,
	}
	for i := range cm.PropFilters {
		pf, err := cm.PropFilters[i].toFilter()
		if err != nil {
			return nil, err
		}
		out.PropFilters = append(out.PropFilters, *pf)
	}
	for i := range cm.CompFilters {
		cf, err := cm.CompFilters[i].toFilter()
		if err != nil {
			return nil, err
		}
		out.CompFilters = append(out.CompFilters, *cf)
	}
	return out, nil
}

func (pf *propFilterXML) toFilter() (*ical.PropFilter, error) {
	tr, err := pf.TimeRange.toFilter()
	if err != nil {
		return nil, err
	}
	out := &ical.PropFilter{
		Name:         strings.ToUpper(strings.TrimSpace(pf.Name)),
		IsNotDefined: pf.IsNotDefined != nil,
		TimeRange:    tr,
	}
	if pf.TextMatch != nil {
		out.TextMatch = &ical.TextMatch{
			Value:  strings.TrimSpace(pf.TextMatch.Value),
			Negate: strings.EqualFold(pf.TextMatch.Negate, "yes") || strings.EqualFold(pf.TextMatch.Negate, "true"),
		}
	}
	for i := range pf.ParamFilters {
		p := pf.ParamFilters[i]
		item := ical.ParamFilter{
			Name:         strings.ToUpper(strings.TrimSpace(p.Name)),
			IsNotDefined: p.IsNotDefined != nil,
		}
		if p.TextMatch != nil {
			item.TextMatch = &ical.TextMatch{
				Value:  strings.TrimSpace(p.TextMatch.Value),
				Negate: strings.EqualFold(p.TextMatch.Negate, "yes") || strings.EqualFold(p.TextMatch.Negate, "true"),
			}
		}
		out.ParamFilters = append(out.ParamFilters, item)
	}
	return out, nil
}

func (h *Handler) handleReport(w http.ResponseWriter, r *http.Request, t target, current *store.User) {
	if t.kind != targetCalendar {
		w.Header().Set("Allow", allowFor(t.kind))
		http.Error(w, "REPORT is only supported on calendar collections", http.StatusForbidden)
		return
	}
	body, ok := readBody(w, r, h.MaxBodySize)
	if !ok {
		return
	}
	var env reportEnvelope
	if err := xml.Unmarshal(body, &env); err != nil {
		http.Error(w, "invalid REPORT body", http.StatusBadRequest)
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

	switch strings.ToLower(env.XMLName.Local) {
	case "calendar-query":
		h.reportCalendarQuery(w, r, owner, cal, &env)
	case "calendar-multiget":
		h.reportMultiget(w, r, owner, cal, &env)
	case "sync-collection":
		h.reportSync(w, r, owner, cal, &env)
	case "free-busy-query":
		h.reportFreeBusy(w, r, owner, cal, &env)
	default:
		writeDAVError(w, http.StatusForbidden, davError(nsDAV, "supported-report"))
	}
}

func (h *Handler) reportCalendarQuery(w http.ResponseWriter, r *http.Request, owner *store.User, cal *store.Calendar, env *reportEnvelope) {
	var filter *ical.CompFilter
	if env.Filter != nil && len(env.Filter.CompFilters) > 0 {
		if len(env.Filter.CompFilters) == 1 {
			f, err := env.Filter.CompFilters[0].toFilter()
			if err != nil {
				http.Error(w, "invalid calendar-query filter: "+err.Error(), http.StatusBadRequest)
				return
			}
			filter = f
		} else {
			root := &ical.CompFilter{Name: "VCALENDAR"}
			for i := range env.Filter.CompFilters {
				f, err := env.Filter.CompFilters[i].toFilter()
				if err != nil {
					http.Error(w, "invalid calendar-query filter: "+err.Error(), http.StatusBadRequest)
					return
				}
				root.CompFilters = append(root.CompFilters, *f)
			}
			filter = root
		}
	}
	start, end := filterRange(filter)
	ctx := r.Context()
	var objs []*store.Object
	var err error
	if !start.IsZero() && !end.IsZero() {
		objs, err = h.Store.ObjectRange(ctx, cal.ID, start, end)
	} else {
		objs, err = h.Store.ListObjects(ctx, cal.ID)
	}
	if err != nil {
		http.Error(w, "failed to query calendar", http.StatusInternalServerError)
		return
	}
	responses := make([]davResponse, 0, len(objs))
	for _, obj := range objs {
		if filter != nil {
			parsed, err := ical.Load(obj.Data, cal.Timezone)
			if err != nil || !parsed.MatchObject(filter) {
				continue
			}
		}
		responses = append(responses, h.objectResponse(owner, cal, obj, env.Prop))
	}
	writeMultistatus(w, responses)
}

// filterRange returns the union of all time ranges in the filter. It is used
// only as a cheap SQL pre-filter; the precise test happens in Go.
func filterRange(filter *ical.CompFilter) (time.Time, time.Time) {
	if filter == nil {
		return time.Time{}, time.Time{}
	}
	var start, end time.Time
	reset := false
	var walk func(f *ical.CompFilter)
	walk = func(f *ical.CompFilter) {
		if reset {
			return
		}
		if f.TimeRange != nil {
			if f.TimeRange.Start.IsZero() || f.TimeRange.End.IsZero() {
				start, end = time.Time{}, time.Time{}
				reset = true
				return
			}
			if start.IsZero() || f.TimeRange.Start.Before(start) {
				start = f.TimeRange.Start
			}
			if end.IsZero() || f.TimeRange.End.After(end) {
				end = f.TimeRange.End
			}
		}
		for i := range f.CompFilters {
			walk(&f.CompFilters[i])
		}
	}
	walk(filter)
	if reset {
		return time.Time{}, time.Time{}
	}
	return start, end
}

func (h *Handler) reportMultiget(w http.ResponseWriter, r *http.Request, owner *store.User, cal *store.Calendar, env *reportEnvelope) {
	if len(env.Hrefs) == 0 {
		http.Error(w, "calendar-multiget requires at least one href", http.StatusBadRequest)
		return
	}
	ctx := r.Context()
	seen := map[string]bool{}
	responses := make([]davResponse, 0, len(env.Hrefs))
	for _, raw := range env.Hrefs {
		hrefPath, ok := normalizeHref(raw)
		if !ok {
			responses = append(responses, davResponse{Href: raw, Status: http.StatusNotFound})
			continue
		}
		u, err := url.Parse(hrefPath)
		if err != nil {
			responses = append(responses, davResponse{Href: raw, Status: http.StatusNotFound})
			continue
		}
		t, ok := parseTarget(u)
		if !ok || t.kind != targetObject || !strings.EqualFold(t.user, owner.Username) || t.slug != cal.Slug {
			responses = append(responses, davResponse{Href: hrefPath, Status: http.StatusNotFound})
			continue
		}
		if seen[t.object] {
			continue
		}
		seen[t.object] = true
		obj, err := h.Store.GetObject(ctx, cal.ID, t.object)
		if err != nil {
			responses = append(responses, davResponse{Href: hrefPath, Status: http.StatusNotFound})
			continue
		}
		responses = append(responses, h.objectResponse(owner, cal, obj, env.Prop))
	}
	writeMultistatus(w, responses)
}

func (h *Handler) reportSync(w http.ResponseWriter, r *http.Request, owner *store.User, cal *store.Calendar, env *reportEnvelope) {
	ctx := r.Context()
	current := cal.SyncSeq
	token := strings.TrimSpace(env.SyncToken)
	responses := []davResponse{}

	if token == "" {
		objs, err := h.Store.ListObjects(ctx, cal.ID)
		if err != nil {
			http.Error(w, "failed to list calendar", http.StatusInternalServerError)
			return
		}
		for _, obj := range objs {
			responses = append(responses, h.objectResponse(owner, cal, obj, env.Prop))
		}
		writeMultistatus(w, responses, txt(nsDAV, "sync-token", syncToken(cal.ID, current)))
		return
	}

	seq, ok := parseSyncToken(token, cal.ID)
	if !ok || seq > current {
		writeDAVError(w, http.StatusForbidden, davError(nsDAV, "valid-sync-token"))
		return
	}
	changes, err := h.Store.ChangesSince(ctx, cal.ID, seq)
	if err != nil {
		http.Error(w, "failed to read sync changes", http.StatusInternalServerError)
		return
	}
	limit := 0
	if env.Limit != nil {
		limit = env.Limit.NResults
	}
	if limit > 0 && len(changes) > limit {
		writeDAVError(w, http.StatusInsufficientStorage, davError(nsDAV, "number-of-matches-within-limits"))
		return
	}
	for _, change := range changes {
		if change.Op == "delete" {
			responses = append(responses, davResponse{
				Href:   objectHref(owner.Username, cal.Slug, change.Href),
				Status: http.StatusNotFound,
			})
			continue
		}
		obj, err := h.Store.GetObject(ctx, cal.ID, change.Href)
		if err != nil {
			responses = append(responses, davResponse{
				Href:   objectHref(owner.Username, cal.Slug, change.Href),
				Status: http.StatusNotFound,
			})
			continue
		}
		responses = append(responses, h.objectResponse(owner, cal, obj, env.Prop))
	}
	writeMultistatus(w, responses, txt(nsDAV, "sync-token", syncToken(cal.ID, current)))
}

func (h *Handler) reportFreeBusy(w http.ResponseWriter, r *http.Request, owner *store.User, cal *store.Calendar, env *reportEnvelope) {
	tr, err := env.TimeRange.toFilter()
	if err != nil || tr == nil || tr.Start.IsZero() || tr.End.IsZero() {
		http.Error(w, "free-busy-query requires a complete time-range", http.StatusBadRequest)
		return
	}
	objs, err := h.Store.ListObjects(r.Context(), cal.ID)
	if err != nil {
		http.Error(w, "failed to read calendar", http.StatusInternalServerError)
		return
	}
	var periods []ical.FreeBusyPeriod
	for _, obj := range objs {
		parsed, err := ical.Load(obj.Data, cal.Timezone)
		if err != nil {
			continue
		}
		periods = append(periods, parsed.FreeBusy(tr.Start, tr.End)...)
	}
	sort.Slice(periods, func(i, j int) bool { return periods[i].Start.Before(periods[j].Start) })
	merged := make([]ical.FreeBusyPeriod, 0, len(periods))
	for _, p := range periods {
		if len(merged) == 0 || p.Start.After(merged[len(merged)-1].End) {
			merged = append(merged, p)
			continue
		}
		if p.End.After(merged[len(merged)-1].End) {
			merged[len(merged)-1].End = p.End
		}
	}

	root := ical.NewComponent("VCALENDAR")
	root.AddProp("VERSION", "2.0", nil)
	root.AddProp("PRODID", "-//caldav-free//CalDAV Server//EN", nil)
	fb := ical.NewComponent("VFREEBUSY")
	fb.AddProp("UID", auth.RandomToken(12)+"@caldav-free", nil)
	fb.AddProp("DTSTAMP", time.Now().UTC().Format("20060102T150405Z"), nil)
	fb.AddProp("DTSTART", tr.Start.UTC().Format("20060102T150405Z"), nil)
	fb.AddProp("DTEND", tr.End.UTC().Format("20060102T150405Z"), nil)
	for _, p := range merged {
		fb.AddProp("FREEBUSY", p.Start.UTC().Format("20060102T150405Z")+"/"+p.End.UTC().Format("20060102T150405Z"), ical.Params{"FBTYPE": {"BUSY"}})
	}
	root.AddChild(fb)
	data := []byte(root.Encode())
	w.Header().Set("Content-Type", "text/calendar; charset=utf-8")
	w.Header().Set("Content-Length", strconv.Itoa(len(data)))
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func (h *Handler) objectResponse(owner *store.User, cal *store.Calendar, obj *store.Object, propReq propContainer) davResponse {
	res := &resource{
		kind:     targetObject,
		href:     objectHref(owner.Username, cal.Slug, obj.Href),
		current:  owner,
		owner:    owner,
		calendar: cal,
		object:   obj,
	}
	return davResponse{Href: res.href, Props: h.reportProps(res, propReq)}
}

func (h *Handler) reportProps(res *resource, container propContainer) []propResult {
	if len(container.Props) == 0 {
		value, ok := h.propValue(res, xml.Name{Space: nsDAV, Local: "getetag"})
		if !ok {
			return nil
		}
		return []propResult{{Name: xml.Name{Space: nsDAV, Local: "getetag"}, Value: value}}
	}
	out := make([]propResult, 0, len(container.Props))
	for _, prop := range container.Props {
		name := prop.XMLName
		if name.Space == nsCalDAV && name.Local == "calendar-data" {
			if res.object == nil {
				out = append(out, propResult{Name: name, Status: http.StatusNotFound})
				continue
			}
			data := res.object.Data
			if options, ok := parseExpandOptions(prop.InnerXML); ok {
				parsed, err := ical.Load(res.object.Data, res.calendar.Timezone)
				if err != nil {
					out = append(out, propResult{Name: name, Status: http.StatusInternalServerError})
					continue
				}
				expanded, err := parsed.ExpandedObject(options.start, options.end)
				if err != nil {
					out = append(out, propResult{Name: name, Status: http.StatusInternalServerError})
					continue
				}
				data = []byte(expanded.Encode())
			}
			n := node{
				Name:  xml.Name{Space: nsCalDAV, Local: "calendar-data"},
				Attrs: []xml.Attr{attr("content-type", "text/calendar"), attr("version", "2.0")},
				Text:  string(data),
			}
			out = append(out, propResult{Name: name, Value: &n})
			continue
		}
		value, ok := h.propValue(res, name)
		if !ok {
			out = append(out, propResult{Name: name, Status: http.StatusNotFound})
			continue
		}
		out = append(out, propResult{Name: name, Value: value})
	}
	return out
}

type expandOptions struct {
	start time.Time
	end   time.Time
}

func parseExpandOptions(inner string) (expandOptions, bool) {
	if !strings.Contains(inner, "expand") {
		return expandOptions{}, false
	}
	var doc struct {
		Expand *struct {
			Start string `xml:"start,attr"`
			End   string `xml:"end,attr"`
		} `xml:"expand"`
	}
	if err := xml.Unmarshal([]byte("<d>"+inner+"</d>"), &doc); err != nil || doc.Expand == nil {
		return expandOptions{}, false
	}
	start, err := parseXMLTime(doc.Expand.Start)
	if err != nil || start.IsZero() {
		return expandOptions{}, false
	}
	end, err := parseXMLTime(doc.Expand.End)
	if err != nil || end.IsZero() {
		return expandOptions{}, false
	}
	return expandOptions{start: start, end: end}, true
}
