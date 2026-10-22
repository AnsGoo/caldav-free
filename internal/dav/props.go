package dav

import (
	"encoding/xml"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/store"
)

type resource struct {
	kind     targetKind
	href     string
	current  *store.User
	owner    *store.User
	calendar *store.Calendar
	object   *store.Object
}

func (r *resource) username() string {
	if r.owner != nil {
		return r.owner.Username
	}
	if r.current != nil {
		return r.current.Username
	}
	return ""
}

func quoteETag(etag string) string {
	if etag == "" {
		return ""
	}
	return `"` + strings.Trim(etag, `"`) + `"`
}

func calendarCTag(cal *store.Calendar) string {
	return fmt.Sprintf("caldav-free-%d-%d", cal.ID, cal.ModifiedAt.UnixNano())
}

func hrefNode(space, local, href string) node {
	return el(space, local, txt(nsDAV, "href", href))
}

func privilege(name string) node {
	return el(nsDAV, "privilege", el(nsDAV, name))
}

func supportedReports(reports ...node) node {
	items := make([]node, 0, len(reports))
	for _, report := range reports {
		items = append(items, el(nsDAV, "supported-report", el(nsDAV, "report", report)))
	}
	return el(nsDAV, "supported-report-set", items...)
}

func reportEl(space, local string) node { return el(space, local) }

func compSet(components []string) node {
	items := make([]node, 0, len(components))
	for _, c := range components {
		items = append(items, node{
			Name:  xml.Name{Space: nsCalDAV, Local: "comp"},
			Attrs: []xml.Attr{attr("name", c)},
		})
	}
	return el(nsCalDAV, "supported-calendar-component-set", items...)
}

func currentUserPrincipal(user *store.User) node {
	return hrefNode(nsDAV, "current-user-principal", principalHref(user.Username))
}

func principalProperties(user *store.User) node {
	return hrefNode(nsDAV, "principal-URL", principalHref(user.Username))
}

func userAddressSet(user *store.User) node {
	children := []node{}
	if user.Email != "" {
		children = append(children, txt(nsDAV, "href", "mailto:"+user.Email))
	}
	children = append(children, txt(nsDAV, "href", principalHref(user.Username)))
	return el(nsCalDAV, "calendar-user-address-set", children...)
}

func resourcetype(kind targetKind) node {
	switch kind {
	case targetRoot:
		return el(nsDAV, "resourcetype", el(nsDAV, "collection"))
	case targetPrincipalCollection:
		return el(nsDAV, "resourcetype", el(nsDAV, "collection"))
	case targetPrincipal:
		return el(nsDAV, "resourcetype", el(nsDAV, "collection"), el(nsDAV, "principal"))
	case targetHome:
		return el(nsDAV, "resourcetype", el(nsDAV, "collection"))
	case targetCalendar:
		return el(nsDAV, "resourcetype", el(nsDAV, "collection"), el(nsCalDAV, "calendar"))
	default:
		return el(nsDAV, "resourcetype")
	}
}

func httpDate(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.UTC().Format(http.TimeFormat)
}

func isoDate(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.UTC().Format("2006-01-02T15:04:05Z")
}

// propValue computes a property value. The bool reports support/presence.
func (h *Handler) propValue(res *resource, name xml.Name) (*node, bool) {
	local := name.Local
	space := name.Space
	isDAV := space == nsDAV || space == ""
	isCal := space == nsCalDAV
	isCS := space == nsCS
	isApple := space == nsApple

	switch {
	case isDAV && local == "resourcetype":
		n := resourcetype(res.kind)
		return &n, true
	case isDAV && local == "displayname":
		var value string
		switch res.kind {
		case targetRoot:
			value = "caldav-free"
		case targetPrincipalCollection:
			value = "Principals"
		case targetPrincipal:
			value = res.owner.DisplayName
			if value == "" {
				value = res.owner.Username
			}
		case targetHome:
			value = "Calendars"
		case targetCalendar:
			value = res.calendar.DisplayName
			if value == "" {
				value = res.calendar.Slug
			}
		case targetObject:
			value = res.object.UID
		}
		n := txt(nsDAV, "displayname", value)
		return &n, true
	case isDAV && local == "getetag":
		switch res.kind {
		case targetObject:
			n := txt(nsDAV, "getetag", quoteETag(res.object.ETag))
			return &n, true
		case targetCalendar:
			n := txt(nsDAV, "getetag", quoteETag(calendarCTag(res.calendar)))
			return &n, true
		}
		return nil, false
	case isDAV && local == "getcontenttype":
		switch res.kind {
		case targetObject:
			n := txt(nsDAV, "getcontenttype", res.object.ContentType)
			return &n, true
		case targetCalendar:
			n := txt(nsDAV, "getcontenttype", "text/calendar; charset=utf-8")
			return &n, true
		}
		return nil, false
	case isDAV && local == "getcontentlength":
		if res.kind == targetObject {
			n := txt(nsDAV, "getcontentlength", strconv.FormatInt(res.object.Size, 10))
			return &n, true
		}
		return nil, false
	case isDAV && local == "getlastmodified":
		switch res.kind {
		case targetCalendar:
			n := txt(nsDAV, "getlastmodified", httpDate(res.calendar.ModifiedAt))
			return &n, true
		case targetObject:
			n := txt(nsDAV, "getlastmodified", httpDate(res.object.ModifiedAt))
			return &n, true
		}
		return nil, false
	case isDAV && local == "creationdate":
		switch res.kind {
		case targetCalendar:
			n := txt(nsDAV, "creationdate", isoDate(res.calendar.CreatedAt))
			return &n, true
		case targetObject:
			n := txt(nsDAV, "creationdate", isoDate(res.object.CreatedAt))
			return &n, true
		}
		return nil, false
	case isDAV && local == "current-user-principal":
		if res.current == nil {
			return nil, false
		}
		n := currentUserPrincipal(res.current)
		return &n, true
	case isDAV && local == "principal-URL":
		if res.kind != targetPrincipal || res.owner == nil {
			return nil, false
		}
		n := principalProperties(res.owner)
		return &n, true
	case isDAV && local == "principal-collection-set":
		n := hrefNode(nsDAV, "principal-collection-set", "/principals/")
		return &n, true
	case isDAV && local == "owner":
		if res.owner != nil {
			n := hrefNode(nsDAV, "owner", principalHref(res.owner.Username))
			return &n, true
		}
		return nil, false
	case isDAV && local == "current-user-privilege-set":
		privs := []node{privilege("read"), privilege("read-current-user-privilege-set")}
		switch res.kind {
		case targetCalendar, targetObject, targetHome:
			privs = append(privs, privilege("write"), privilege("write-content"))
		}
		n := el(nsDAV, "current-user-privilege-set", privs...)
		return &n, true
	case isDAV && local == "supportedlock":
		n := el(nsDAV, "supportedlock")
		return &n, true
	case isDAV && local == "lockdiscovery":
		n := el(nsDAV, "lockdiscovery")
		return &n, true
	case isDAV && local == "supported-report-set":
		switch res.kind {
		case targetCalendar:
			n := supportedReports(
				reportEl(nsCalDAV, "calendar-query"),
				reportEl(nsCalDAV, "calendar-multiget"),
				reportEl(nsDAV, "sync-collection"),
				reportEl(nsCalDAV, "free-busy-query"),
			)
			return &n, true
		default:
			n := supportedReports()
			return &n, true
		}
	case isDAV && local == "sync-token":
		if res.kind == targetCalendar {
			n := txt(nsDAV, "sync-token", syncToken(res.calendar.ID, res.calendar.SyncSeq))
			return &n, true
		}
		return nil, false
	case isCal && local == "calendar-home-set":
		if res.kind == targetPrincipal && res.owner != nil {
			n := hrefNode(nsCalDAV, "calendar-home-set", homeHref(res.owner.Username))
			return &n, true
		}
		return nil, false
	case isCal && local == "calendar-user-address-set":
		if res.kind == targetPrincipal && res.owner != nil {
			n := userAddressSet(res.owner)
			return &n, true
		}
		return nil, false
	case isCal && local == "calendar-description":
		if res.kind == targetCalendar {
			n := txt(nsCalDAV, "calendar-description", res.calendar.Description)
			return &n, true
		}
		return nil, false
	case isCal && local == "calendar-timezone":
		if res.kind == targetCalendar && res.calendar.TimezoneData != "" {
			n := txt(nsCalDAV, "calendar-timezone", res.calendar.TimezoneData)
			return &n, true
		}
		return nil, false
	case isCal && local == "supported-calendar-component-set":
		if res.kind == targetCalendar {
			n := compSet(res.calendar.Components)
			return &n, true
		}
		return nil, false
	case isCal && local == "supported-calendar-data":
		if res.kind == targetCalendar {
			n := node{
				Name: xml.Name{Space: nsCalDAV, Local: "supported-calendar-data"},
				Children: []node{{
					Name:  xml.Name{Space: nsCalDAV, Local: "calendar-data"},
					Attrs: []xml.Attr{attr("content-type", "text/calendar"), attr("version", "2.0")},
				}},
			}
			return &n, true
		}
		return nil, false
	case isCal && local == "max-resource-size":
		if res.kind == targetCalendar {
			n := txt(nsCalDAV, "max-resource-size", strconv.FormatInt(h.MaxBodySize, 10))
			return &n, true
		}
		return nil, false
	case isCal && local == "min-date-time":
		if res.kind == targetCalendar {
			n := txt(nsCalDAV, "min-date-time", "19000101T000000Z")
			return &n, true
		}
		return nil, false
	case isCal && local == "max-date-time":
		if res.kind == targetCalendar {
			n := txt(nsCalDAV, "max-date-time", "21001231T235959Z")
			return &n, true
		}
		return nil, false
	case isCal && local == "calendar-data":
		// calendar-data is only returned in REPORT responses.
		return nil, false
	case (isCS || isApple) && local == "getctag":
		if res.kind == targetCalendar {
			n := txt(nsCS, "getctag", quoteETag(calendarCTag(res.calendar)))
			return &n, true
		}
		return nil, false
	case (isApple || isCS) && local == "calendar-color":
		if res.kind == targetCalendar {
			n := txt(nsApple, "calendar-color", res.calendar.Color)
			return &n, true
		}
		return nil, false
	case (isApple || isCS) && local == "calendar-order":
		if res.kind == targetCalendar {
			n := txt(nsApple, "calendar-order", strconv.Itoa(res.calendar.Order))
			return &n, true
		}
		return nil, false
	}
	return nil, false
}

func allPropNames(res *resource) []xml.Name {
	name := func(space, local string) xml.Name { return xml.Name{Space: space, Local: local} }
	common := []xml.Name{name(nsDAV, "resourcetype"), name(nsDAV, "displayname")}
	switch res.kind {
	case targetRoot:
		return append(common,
			name(nsDAV, "current-user-principal"),
			name(nsDAV, "principal-collection-set"),
			name(nsDAV, "current-user-privilege-set"),
			name(nsDAV, "supported-report-set"),
		)
	case targetPrincipalCollection:
		return append(common,
			name(nsDAV, "current-user-principal"),
			name(nsDAV, "principal-collection-set"),
			name(nsDAV, "current-user-privilege-set"),
		)
	case targetPrincipal:
		out := append(common,
			name(nsDAV, "current-user-principal"),
			name(nsDAV, "principal-URL"),
			name(nsDAV, "principal-collection-set"),
			name(nsDAV, "owner"),
			name(nsDAV, "current-user-privilege-set"),
			name(nsDAV, "supported-report-set"),
			name(nsCalDAV, "calendar-home-set"),
			name(nsCalDAV, "calendar-user-address-set"),
		)
		return out
	case targetHome:
		return append(common,
			name(nsDAV, "current-user-principal"),
			name(nsDAV, "owner"),
			name(nsDAV, "current-user-privilege-set"),
			name(nsDAV, "supported-report-set"),
		)
	case targetCalendar:
		out := append(common,
			name(nsDAV, "owner"),
			name(nsDAV, "getetag"),
			name(nsDAV, "getcontenttype"),
			name(nsDAV, "getlastmodified"),
			name(nsDAV, "creationdate"),
			name(nsDAV, "current-user-principal"),
			name(nsDAV, "current-user-privilege-set"),
			name(nsDAV, "supported-report-set"),
			name(nsDAV, "sync-token"),
			name(nsCS, "getctag"),
			name(nsCalDAV, "supported-calendar-component-set"),
			name(nsCalDAV, "supported-calendar-data"),
			name(nsCalDAV, "max-resource-size"),
			name(nsCalDAV, "min-date-time"),
			name(nsCalDAV, "max-date-time"),
			name(nsApple, "calendar-order"),
		)
		if res.calendar.Description != "" {
			out = append(out, name(nsCalDAV, "calendar-description"))
		}
		if res.calendar.Color != "" {
			out = append(out, name(nsApple, "calendar-color"))
		}
		if res.calendar.TimezoneData != "" {
			out = append(out, name(nsCalDAV, "calendar-timezone"))
		}
		return out
	case targetObject:
		return []xml.Name{
			name(nsDAV, "resourcetype"),
			name(nsDAV, "getetag"),
			name(nsDAV, "getcontenttype"),
			name(nsDAV, "getcontentlength"),
			name(nsDAV, "getlastmodified"),
			name(nsDAV, "creationdate"),
			name(nsDAV, "owner"),
			name(nsDAV, "current-user-principal"),
			name(nsDAV, "current-user-privilege-set"),
		}
	}
	return common
}

// buildProps resolves a PROPFIND request into per-property results.
func (h *Handler) buildProps(res *resource, req propfindReq) []propResult {
	var names []xml.Name
	if req.AllProp {
		names = allPropNames(res)
		for _, inc := range req.Include {
			names = append(names, inc)
		}
	} else if req.PropName && len(req.Props) == 0 {
		names = allPropNames(res)
	} else {
		names = req.Props
	}
	out := make([]propResult, 0, len(names))
	seen := map[xml.Name]bool{}
	for _, name := range names {
		if seen[name] {
			continue
		}
		seen[name] = true
		if req.PropName {
			out = append(out, propResult{Name: name, Value: &node{Name: xml.Name{Space: name.Space, Local: name.Local}}})
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
