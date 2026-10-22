package dav

import (
	"net/http"
	"strings"

	"caldav-free/internal/store"
)

func parseDepth(header string) int {
	switch strings.ToLower(strings.TrimSpace(header)) {
	case "0":
		return 0
	case "1", "infinity":
		return 1
	default:
		return 0
	}
}

func (h *Handler) handlePropfind(w http.ResponseWriter, r *http.Request, t target, current *store.User) {
	body, ok := readBody(w, r, h.MaxBodySize)
	if !ok {
		return
	}
	req, err := parsePropfind(body)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	depth := parseDepth(r.Header.Get("Depth"))
	ctx := r.Context()
	var responses []davResponse

	add := func(res *resource) {
		responses = append(responses, davResponse{
			Href:  res.href,
			Props: h.buildProps(res, req),
		})
	}

	switch t.kind {
	case targetRoot:
		add(&resource{kind: targetRoot, href: "/", current: current})
	case targetPrincipalCollection:
		if depth == 0 {
			add(&resource{kind: targetPrincipalCollection, href: "/principals/", current: current, owner: current})
			break
		}
		users := []*store.User{current}
		if current.IsAdmin {
			all, err := h.Store.ListUsers(ctx)
			if err != nil {
				http.Error(w, "failed to list principals", http.StatusInternalServerError)
				return
			}
			users = all
		}
		for _, u := range users {
			u := u
			add(&resource{kind: targetPrincipal, href: principalHref(u.Username), current: current, owner: u})
		}
	case targetPrincipal:
		if !current.IsAdmin && !strings.EqualFold(t.user, current.Username) {
			http.NotFound(w, r)
			return
		}
		u, err := h.Store.GetUserByUsername(ctx, t.user)
		if err != nil {
			http.NotFound(w, r)
			return
		}
		add(&resource{kind: targetPrincipal, href: principalHref(u.Username), current: current, owner: u})
	case targetHome:
		owner, ok := h.loadOwner(ctx, t.user, current)
		if !ok {
			http.NotFound(w, r)
			return
		}
		add(&resource{kind: targetHome, href: homeHref(owner.Username), current: current, owner: owner})
		if depth > 0 {
			cals, err := h.Store.ListCalendars(ctx, owner.ID)
			if err != nil {
				h.Logger.Error("list calendars", "error", err)
				http.Error(w, "failed to list calendars", http.StatusInternalServerError)
				return
			}
			for _, cal := range cals {
				add(&resource{
					kind:     targetCalendar,
					href:     calendarHref(owner.Username, cal.Slug),
					current:  current,
					owner:    owner,
					calendar: cal,
				})
			}
		}
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
		add(&resource{
			kind:     targetCalendar,
			href:     calendarHref(owner.Username, cal.Slug),
			current:  current,
			owner:    owner,
			calendar: cal,
		})
		if depth > 0 {
			objs, err := h.Store.ListObjects(ctx, cal.ID)
			if err != nil {
				http.Error(w, "failed to list calendar objects", http.StatusInternalServerError)
				return
			}
			for _, obj := range objs {
				add(&resource{
					kind:     targetObject,
					href:     objectHref(owner.Username, cal.Slug, obj.Href),
					current:  current,
					owner:    owner,
					calendar: cal,
					object:   obj,
				})
			}
		}
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
		add(&resource{
			kind:     targetObject,
			href:     objectHref(owner.Username, cal.Slug, obj.Href),
			current:  current,
			owner:    owner,
			calendar: cal,
			object:   obj,
		})
	default:
		http.NotFound(w, r)
		return
	}

	writeMultistatus(w, responses)
}

func (h *Handler) handleOptions(w http.ResponseWriter, r *http.Request, t target) {
	w.Header().Set("Allow", allowFor(t.kind))
	w.Header().Set("Content-Length", "0")
	w.WriteHeader(http.StatusOK)
}
