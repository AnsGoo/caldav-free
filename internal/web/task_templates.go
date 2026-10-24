package web

import (
	"net/http"
	"strconv"

	"caldav-free/internal/store"
)

func (s *Server) apiTaskTemplates(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	if r.Method == http.MethodGet {
		templates, err := s.store.ListTaskTemplates(r.Context(), current.ID)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"templates": templates})
		return
	}
	var body struct {
		Name    string `json:"name"`
		Payload string `json:"payload"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	template, err := s.store.CreateTaskTemplate(r.Context(), current.ID, body.Name, body.Payload)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"template": template})
}

func (s *Server) apiTaskTemplate(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeAPIError(w, http.StatusNotFound, "模板不存在")
		return
	}
	if err := s.store.DeleteTaskTemplate(r.Context(), current.ID, id); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "模板不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
