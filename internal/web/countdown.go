package web

import (
	"net/http"
	"strconv"

	"caldav-free/internal/store"
)

func (s *Server) apiCountdowns(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	if r.Method == http.MethodGet {
		includeArchived := r.URL.Query().Get("archived") == "1"
		items, err := s.store.ListCountdowns(r.Context(), current.ID, includeArchived)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"countdowns": items})
		return
	}
	var body store.CountdownEvent
	if !readAPIJSON(w, r, &body) {
		return
	}
	body.UserID = current.ID
	item, err := s.store.CreateCountdown(r.Context(), &body)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"countdown": item})
}

func (s *Server) apiCountdown(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeAPIError(w, http.StatusNotFound, "倒数记录不存在")
		return
	}
	if r.Method == http.MethodDelete {
		if err := s.store.DeleteCountdown(r.Context(), current.ID, id); err != nil {
			if err == store.ErrNotFound {
				writeAPIError(w, http.StatusNotFound, "倒数记录不存在")
				return
			}
			s.apiServerError(w, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	var patch store.CountdownPatch
	if !readAPIJSON(w, r, &patch) {
		return
	}
	item, err := s.store.UpdateCountdown(r.Context(), current.ID, id, &patch)
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "倒数记录不存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"countdown": item})
}
