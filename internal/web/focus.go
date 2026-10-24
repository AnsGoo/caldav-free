package web

import (
	"net/http"
	"strconv"
	"time"

	"caldav-free/internal/store"
)

func (s *Server) apiFocus(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	dashboard, err := s.store.FocusDashboard(r.Context(), current.ID, 100)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, dashboard)
}

func (s *Server) apiFocusPreferences(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body store.FocusPreference
	if !readAPIJSON(w, r, &body) {
		return
	}
	body.UserID = current.ID
	pref, err := s.store.SaveFocusPreferences(r.Context(), &body)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"preferences": pref})
}

func (s *Server) apiFocusSessions(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		TaskID          int64     `json:"taskId"`
		HabitID         int64     `json:"habitId"`
		Mode            string    `json:"mode"`
		StartedAt       time.Time `json:"startedAt"`
		EndedAt         time.Time `json:"endedAt"`
		PauseSeconds    int       `json:"pauseSeconds"`
		DurationSeconds int       `json:"durationSeconds"`
		PomodoroCount   int       `json:"pomodoroCount"`
		Note            string    `json:"note"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	focusSession := &store.FocusSession{
		UserID: current.ID, TaskID: body.TaskID, HabitID: body.HabitID, Mode: body.Mode,
		StartedAt: body.StartedAt, EndedAt: body.EndedAt, PauseSeconds: body.PauseSeconds,
		DurationSeconds: body.DurationSeconds, PomodoroCount: body.PomodoroCount, Note: body.Note,
	}
	created, err := s.store.CreateFocusSession(r.Context(), focusSession)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"session": created})
}

func (s *Server) apiFocusSession(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeAPIError(w, http.StatusNotFound, "专注记录不存在")
		return
	}
	if err := s.store.DeleteFocusSession(r.Context(), current.ID, id); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "专注记录不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
