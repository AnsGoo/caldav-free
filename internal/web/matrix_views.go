package web

import (
	"net/http"
	"strconv"
	"strings"

	"caldav-free/internal/store"
)

type apiMatrixView struct {
	ID    int64  `json:"id"`
	Name  string `json:"name"`
	Mode  string `json:"mode"`
	Order int    `json:"order"`
}

func matrixViewDTO(view *store.MatrixView) apiMatrixView {
	return apiMatrixView{ID: view.ID, Name: view.Name, Mode: view.Mode, Order: view.Order}
}

func (s *Server) apiMatrixViews(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	if r.Method == http.MethodGet {
		views, err := s.store.ListMatrixViews(r.Context(), current.ID)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		rows := make([]apiMatrixView, 0, len(views))
		for _, view := range views {
			rows = append(rows, matrixViewDTO(view))
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"views": rows})
		return
	}
	var body struct {
		Name  string `json:"name"`
		Mode  string `json:"mode"`
		Order int    `json:"order"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Name) == "" {
		writeAPIError(w, http.StatusBadRequest, "请填写视图名称")
		return
	}
	view, err := s.store.CreateMatrixView(r.Context(), current.ID, body.Name, body.Mode)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"view": matrixViewDTO(view)})
}

func (s *Server) apiMatrixView(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "视图不存在")
		return
	}
	if r.Method == http.MethodDelete {
		if err := s.store.DeleteMatrixView(r.Context(), current.ID, id); err != nil {
			writeAPIError(w, http.StatusNotFound, "视图不存在")
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	var body struct {
		Name  string `json:"name"`
		Mode  string `json:"mode"`
		Order int    `json:"order"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	view, err := s.store.UpdateMatrixView(r.Context(), current.ID, id, body.Name, body.Mode, body.Order)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "视图不存在")
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"view": matrixViewDTO(view)})
}
