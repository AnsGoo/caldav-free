package web

import (
	"io"
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

func (s *Server) apiCountdownReorder(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		IDs []int64 `json:"ids"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if err := s.store.SetCountdownOrder(r.Context(), current.ID, body.IDs); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) apiCountdownBackground(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeAPIError(w, http.StatusNotFound, "倒数记录不存在")
		return
	}
	switch r.Method {
	case http.MethodGet:
		background, err := s.store.GetCountdownBackground(r.Context(), current.ID, id)
		if err != nil {
			if err == store.ErrNotFound {
				http.NotFound(w, r)
				return
			}
			s.apiServerError(w, err)
			return
		}
		w.Header().Set("Content-Type", background.Mime)
		w.Header().Set("Cache-Control", "private, max-age=3600")
		_, _ = w.Write(background.Data)
	case http.MethodDelete:
		if err := s.store.DeleteCountdownBackground(r.Context(), current.ID, id); err != nil {
			if err == store.ErrNotFound {
				writeAPIError(w, http.StatusNotFound, "背景图片不存在")
				return
			}
			s.apiServerError(w, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		r.Body = http.MaxBytesReader(w, r.Body, 3<<20)
		if err := r.ParseMultipartForm(3 << 20); err != nil {
			writeAPIError(w, http.StatusBadRequest, "读取背景图片失败")
			return
		}
		file, _, err := r.FormFile("file")
		if err != nil {
			writeAPIError(w, http.StatusBadRequest, "请选择背景图片")
			return
		}
		defer file.Close()
		data, err := io.ReadAll(io.LimitReader(file, (2<<20)+1))
		if err != nil || len(data) == 0 {
			writeAPIError(w, http.StatusBadRequest, "读取背景图片失败")
			return
		}
		if len(data) > 2<<20 {
			writeAPIError(w, http.StatusBadRequest, "背景图片不能超过 2MB")
			return
		}
		mime := http.DetectContentType(data)
		switch mime {
		case "image/jpeg", "image/png", "image/webp", "image/gif":
		default:
			writeAPIError(w, http.StatusBadRequest, "仅支持 JPG、PNG、WEBP 或 GIF 图片")
			return
		}
		if err := s.store.SaveCountdownBackground(r.Context(), current.ID, id, mime, data); err != nil {
			if err == store.ErrNotFound {
				writeAPIError(w, http.StatusNotFound, "倒数记录不存在")
				return
			}
			s.apiServerError(w, err)
			return
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"ok": true})
	}
}
