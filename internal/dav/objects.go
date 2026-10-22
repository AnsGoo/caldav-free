package dav

import (
	"bytes"
	"context"
	"crypto/md5"
	"encoding/hex"
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"caldav-free/internal/ical"
	"caldav-free/internal/store"
)

func computeETag(data []byte) string {
	sum := md5.Sum(data)
	return hex.EncodeToString(sum[:])
}

// hasInvalidControl rejects control characters that are not legal in XML 1.0;
// they would otherwise break REPORT responses containing calendar-data.
func hasInvalidControl(data []byte) bool {
	for _, b := range data {
		if b < 0x20 && b != '\t' && b != '\n' && b != '\r' {
			return true
		}
	}
	return false
}

func (h *Handler) handleGet(w http.ResponseWriter, r *http.Request, t target, current *store.User) {
	ctx := r.Context()
	switch t.kind {
	case targetObject:
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
		obj, err := h.Store.GetObject(ctx, cal.ID, t.object)
		if err != nil {
			http.NotFound(w, r)
			return
		}
		if matchesETag(r.Header.Get("If-None-Match"), obj.ETag, true) && r.Header.Get("If-None-Match") != "" {
			w.Header().Set("ETag", quoteETag(obj.ETag))
			w.WriteHeader(http.StatusNotModified)
			return
		}
		if !modifiedSince(r, obj.ModifiedAt) && r.Header.Get("If-None-Match") == "" {
			w.Header().Set("ETag", quoteETag(obj.ETag))
			w.WriteHeader(http.StatusNotModified)
			return
		}
		w.Header().Set("ETag", quoteETag(obj.ETag))
		w.Header().Set("Content-Type", obj.ContentType)
		w.Header().Set("Content-Length", strconv.FormatInt(int64(len(obj.Data)), 10))
		w.Header().Set("Last-Modified", httpDate(obj.ModifiedAt))
		if r.Method == http.MethodHead {
			w.WriteHeader(http.StatusOK)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(obj.Data)
	case targetCalendar:
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
		etag := calendarCTag(cal)
		if matchesETag(r.Header.Get("If-None-Match"), etag, true) && r.Header.Get("If-None-Match") != "" {
			w.Header().Set("ETag", quoteETag(etag))
			w.WriteHeader(http.StatusNotModified)
			return
		}
		data, err := h.aggregateCalendar(ctx, cal)
		if err != nil {
			h.Logger.Error("aggregate calendar", "error", err)
			http.Error(w, "failed to render calendar", http.StatusInternalServerError)
			return
		}
		w.Header().Set("ETag", quoteETag(etag))
		w.Header().Set("Content-Type", "text/calendar; charset=utf-8")
		w.Header().Set("Content-Length", strconv.Itoa(len(data)))
		w.Header().Set("Last-Modified", httpDate(cal.ModifiedAt))
		if r.Method == http.MethodHead {
			w.WriteHeader(http.StatusOK)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(data)
	default:
		w.Header().Set("Allow", allowFor(t.kind))
		http.Error(w, "GET is not supported on this resource", http.StatusMethodNotAllowed)
	}
}

func modifiedSince(r *http.Request, modified time.Time) bool {
	header := r.Header.Get("If-Modified-Since")
	if header == "" {
		return true
	}
	t, err := http.ParseTime(header)
	if err != nil {
		return true
	}
	return modified.Truncate(time.Second).After(t)
}

func (h *Handler) aggregateCalendar(ctx context.Context, cal *store.Calendar) ([]byte, error) {
	objs, err := h.Store.ListObjects(ctx, cal.ID)
	if err != nil {
		return nil, err
	}
	root := ical.NewComponent("VCALENDAR")
	root.AddProp("VERSION", "2.0", nil)
	root.AddProp("PRODID", "-//caldav-free//CalDAV Server//EN", nil)
	root.AddProp("CALSCALE", "GREGORIAN", nil)
	if cal.DisplayName != "" {
		root.AddProp("X-WR-CALNAME", ical.EscapeText(cal.DisplayName), nil)
	}
	if cal.Timezone != "" {
		root.AddProp("X-WR-TIMEZONE", cal.Timezone, nil)
	}
	seenZones := map[string]bool{}
	for _, obj := range objs {
		parsed, err := ical.Load(obj.Data, cal.Timezone)
		if err != nil {
			h.Logger.Warn("skipping unparsable object", "href", obj.Href, "error", err)
			continue
		}
		for _, tz := range parsed.Root.ChildrenNamed("VTIMEZONE") {
			id := tz.Value("TZID")
			if id == "" || seenZones[id] {
				continue
			}
			seenZones[id] = true
			root.AddChild(tz.Clone())
		}
		for _, child := range parsed.Root.Children {
			if child.Name == "VTIMEZONE" {
				continue
			}
			root.AddChild(child.Clone())
		}
	}
	return []byte(root.Encode()), nil
}

func (h *Handler) handlePut(w http.ResponseWriter, r *http.Request, t target, current *store.User) {
	if t.kind != targetObject {
		w.Header().Set("Allow", allowFor(t.kind))
		http.Error(w, "PUT is only supported on calendar object resources", http.StatusMethodNotAllowed)
		return
	}
	name, ok := cleanSegment(t.object)
	if !ok {
		http.Error(w, "invalid object name", http.StatusBadRequest)
		return
	}
	if ct := r.Header.Get("Content-Type"); ct != "" {
		mediaType := strings.ToLower(strings.TrimSpace(strings.Split(ct, ";")[0]))
		if mediaType != "text/calendar" && mediaType != "application/octet-stream" {
			writeDAVError(w, http.StatusUnsupportedMediaType, davError(nsCalDAV, "supported-calendar-data"))
			return
		}
	}
	body, ok := readBody(w, r, h.MaxBodySize)
	if !ok {
		return
	}
	if !utf8.Valid(body) {
		writeDAVError(w, http.StatusForbidden, davError(nsCalDAV, "valid-calendar-data"))
		return
	}
	if hasInvalidControl(body) {
		writeDAVError(w, http.StatusForbidden, davError(nsCalDAV, "valid-calendar-data"))
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
		http.Error(w, "parent calendar does not exist", http.StatusConflict)
		return
	}

	parsed, err := ical.Load(body, cal.Timezone)
	if err != nil {
		writeDAVError(w, http.StatusForbidden, davError(nsCalDAV, "valid-calendar-data"))
		return
	}
	info, err := parsed.Analyze()
	if err != nil {
		writeDAVError(w, http.StatusForbidden, davError(nsCalDAV, "valid-calendar-object-resource"))
		return
	}
	if !cal.SupportsComponent(info.ComponentType) {
		writeDAVError(w, http.StatusForbidden, davError(nsCalDAV, "supported-calendar-component"))
		return
	}
	etag := computeETag(body)

	existing, err := h.Store.GetObject(ctx, cal.ID, name)
	exists := err == nil
	if err != nil && err != store.ErrNotFound {
		http.Error(w, "failed to load object", http.StatusInternalServerError)
		return
	}

	if header := r.Header.Get("If-Match"); header != "" {
		if !exists || !matchesETag(header, existing.ETag, true) {
			http.Error(w, "precondition failed", http.StatusPreconditionFailed)
			return
		}
	}
	if header := r.Header.Get("If-None-Match"); header != "" {
		if exists && matchesETag(header, existing.ETag, true) {
			http.Error(w, "precondition failed", http.StatusPreconditionFailed)
			return
		}
	}

	if other, err := h.Store.GetObjectByUID(ctx, cal.ID, info.UID); err == nil && other.Href != name {
		writeDAVError(w, http.StatusForbidden, el(nsCalDAV, "no-uid-conflict",
			txt(nsDAV, "href", objectHref(owner.Username, cal.Slug, other.Href))))
		return
	}

	if exists && bytes.Equal(existing.Data, body) {
		w.Header().Set("ETag", quoteETag(etag))
		w.WriteHeader(http.StatusNoContent)
		return
	}

	first := int64(0)
	if !info.FirstStart.IsZero() {
		first = info.FirstStart.Unix()
	}
	last := int64(0)
	if !info.LastEnd.IsZero() {
		last = info.LastEnd.Unix()
	}
	obj := &store.Object{
		CalendarID:    cal.ID,
		Href:          name,
		UID:           info.UID,
		ETag:          etag,
		ContentType:   "text/calendar; charset=utf-8",
		Data:          body,
		ComponentType: info.ComponentType,
		FirstStart:    first,
		LastEnd:       last,
		Recurring:     info.Recurring,
		Size:          int64(len(body)),
	}
	_, created, _, err := h.Store.PutObject(ctx, obj)
	if err != nil {
		h.Logger.Error("store object", "error", err)
		http.Error(w, "failed to store object", http.StatusInternalServerError)
		return
	}
	w.Header().Set("ETag", quoteETag(etag))
	if created {
		w.Header().Set("Location", objectHref(owner.Username, cal.Slug, name))
		w.Header().Set("Content-Length", "0")
		w.WriteHeader(http.StatusCreated)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) handleDelete(w http.ResponseWriter, r *http.Request, t target, current *store.User) {
	ctx := r.Context()
	switch t.kind {
	case targetObject:
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
		obj, err := h.Store.GetObject(ctx, cal.ID, t.object)
		if err != nil {
			http.NotFound(w, r)
			return
		}
		if header := r.Header.Get("If-Match"); header != "" && !matchesETag(header, obj.ETag, true) {
			http.Error(w, "precondition failed", http.StatusPreconditionFailed)
			return
		}
		if _, _, err := h.Store.DeleteObject(ctx, cal.ID, t.object); err != nil {
			if err == store.ErrNotFound {
				http.NotFound(w, r)
				return
			}
			h.Logger.Error("delete object", "error", err)
			http.Error(w, "failed to delete object", http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	case targetCalendar:
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
		if header := r.Header.Get("If-Match"); header != "" && !matchesETag(header, calendarCTag(cal), true) {
			http.Error(w, "precondition failed", http.StatusPreconditionFailed)
			return
		}
		if err := h.Store.DeleteCalendar(ctx, cal.ID); err != nil {
			if err == store.ErrNotFound {
				http.NotFound(w, r)
				return
			}
			h.Logger.Error("delete calendar", "error", err)
			http.Error(w, "failed to delete calendar", http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		http.Error(w, "this resource cannot be deleted", http.StatusForbidden)
	}
}
