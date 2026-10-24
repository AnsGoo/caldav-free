package web

import (
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"caldav-free/internal/store"
)

func (s *Server) apiCalendarSubscriptions(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	if r.Method == http.MethodGet {
		subscriptions, err := s.store.ListCalendarSubscriptions(r.Context(), current.ID)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"subscriptions": subscriptions})
		return
	}
	var body struct {
		Name  string `json:"name"`
		URL   string `json:"url"`
		Color string `json:"color"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	name := strings.TrimSpace(body.Name)
	rawURL := strings.TrimSpace(body.URL)
	if name == "" || len([]rune(name)) > 120 {
		writeAPIError(w, http.StatusBadRequest, "请填写订阅名称")
		return
	}
	parsed, err := url.Parse(rawURL)
	if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") || parsed.Host == "" || len(rawURL) > 1000 {
		writeAPIError(w, http.StatusBadRequest, "订阅地址必须是 http/https URL")
		return
	}
	color := strings.TrimSpace(body.Color)
	if color == "" {
		color = "#f0a020"
	}
	subscription, err := s.store.CreateCalendarSubscription(r.Context(), &store.CalendarSubscription{
		UserID: current.ID, Name: name, URL: rawURL, Color: color,
	})
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"subscription": subscription})
}

func (s *Server) apiCalendarSubscription(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeAPIError(w, http.StatusNotFound, "订阅不存在")
		return
	}
	if err := s.store.DeleteCalendarSubscription(r.Context(), current.ID, id); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "订阅不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
