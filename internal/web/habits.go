package web

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/store"
)

func habitID(r *http.Request, key string) (int64, bool) {
	value, err := strconv.ParseInt(r.PathValue(key), 10, 64)
	return value, err == nil && value > 0
}

func habitMonth(r *http.Request) string {
	month := strings.TrimSpace(r.URL.Query().Get("month"))
	if _, err := time.Parse("2006-01", month); err != nil {
		return time.Now().Format("2006-01")
	}
	return month
}

func (s *Server) apiHabits(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	if r.Method == http.MethodPost {
		var habit store.Habit
		if !readAPIJSON(w, r, &habit) {
			return
		}
		habit.UserID = current.ID
		habit.ID = 0
		created, err := s.store.CreateHabit(r.Context(), &habit)
		if err != nil {
			writeAPIError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeAPIJSON(w, http.StatusCreated, map[string]any{"habit": created})
		return
	}
	includeArchived := r.URL.Query().Get("archived") == "1"
	habits, err := s.store.ListHabits(r.Context(), current.ID, includeArchived)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	if includeArchived {
		filtered := habits[:0]
		for _, habit := range habits {
			if habit.Status == 1 {
				filtered = append(filtered, habit)
			}
		}
		habits = filtered
	}
	sections, err := s.store.ListHabitSections(r.Context(), current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	preference, err := s.store.GetHabitPreference(r.Context(), current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	ids := make([]int64, 0, len(habits))
	for _, habit := range habits {
		ids = append(ids, habit.ID)
	}
	after, _ := strconv.Atoi(time.Now().AddDate(0, 0, -60).Format("20060102"))
	checkins, err := s.store.ListHabitCheckins(r.Context(), current.ID, ids, after)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"habits":      habits,
		"sections":    sections,
		"preferences": preference,
		"checkins":    checkins,
	})
}

func (s *Server) apiHabitReorder(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		IDs []int64 `json:"ids"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if err := s.store.SetHabitOrder(r.Context(), current.ID, body.IDs); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) apiHabit(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, ok := habitID(r, "id")
	if !ok {
		writeAPIError(w, http.StatusNotFound, "习惯不存在")
		return
	}
	if r.Method == http.MethodDelete {
		if err := s.store.DeleteHabit(r.Context(), current.ID, id); err != nil {
			writeAPIError(w, http.StatusNotFound, "习惯不存在")
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	var habit store.Habit
	if !readAPIJSON(w, r, &habit) {
		return
	}
	updated, err := s.store.UpdateHabit(r.Context(), current.ID, id, &habit)
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "习惯不存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"habit": updated})
}

func (s *Server) apiHabitCheckin(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, ok := habitID(r, "id")
	if !ok {
		writeAPIError(w, http.StatusNotFound, "习惯不存在")
		return
	}
	var body struct {
		Stamp int      `json:"stamp"`
		Value *float64 `json:"value"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	checkin, habit, err := s.store.ToggleHabitCheckin(r.Context(), current.ID, id, body.Stamp, body.Value)
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "习惯不存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	detail, _ := s.store.HabitDetail(r.Context(), current.ID, id, habitMonth(r))
	writeAPIJSON(w, http.StatusOK, map[string]any{"checkin": checkin, "habit": habit, "detail": detail})
}

func (s *Server) apiHabitCheckinsQuery(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		HabitIDs   []int64 `json:"habitIds"`
		AfterStamp int     `json:"afterStamp"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	checkins, err := s.store.ListHabitCheckins(r.Context(), current.ID, body.HabitIDs, body.AfterStamp)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"checkins": checkins})
}

func (s *Server) apiHabitDetail(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, ok := habitID(r, "id")
	if !ok {
		writeAPIError(w, http.StatusNotFound, "习惯不存在")
		return
	}
	detail, err := s.store.HabitDetail(r.Context(), current.ID, id, habitMonth(r))
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "习惯不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, detail)
}

func (s *Server) apiHabitRecords(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, ok := habitID(r, "id")
	if !ok {
		writeAPIError(w, http.StatusNotFound, "习惯不存在")
		return
	}
	var record store.HabitRecord
	if !readAPIJSON(w, r, &record) {
		return
	}
	record.UserID = current.ID
	record.HabitID = id
	record.ID = 0
	created, err := s.store.CreateHabitRecord(r.Context(), &record)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"record": created})
}

func (s *Server) apiHabitRecord(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	habitIDValue, ok := habitID(r, "id")
	if !ok {
		writeAPIError(w, http.StatusNotFound, "习惯不存在")
		return
	}
	recordID, ok := habitID(r, "recordId")
	if !ok {
		writeAPIError(w, http.StatusNotFound, "日志不存在")
		return
	}
	if r.Method == http.MethodDelete {
		if err := s.store.DeleteHabitRecord(r.Context(), current.ID, habitIDValue, recordID); err != nil {
			writeAPIError(w, http.StatusNotFound, "日志不存在")
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	var body struct {
		Content string `json:"content"`
		Emoji   string `json:"emoji"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	record, err := s.store.UpdateHabitRecord(r.Context(), current.ID, habitIDValue, recordID, body.Content, body.Emoji)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日志不存在")
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"record": record})
}

func (s *Server) apiHabitPreferences(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	if r.Method == http.MethodGet {
		preference, err := s.store.GetHabitPreference(r.Context(), current.ID)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		writeAPIJSON(w, http.StatusOK, preference)
		return
	}
	existing, err := s.store.GetHabitPreference(r.Context(), current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	var body struct {
		ShowInToday      *bool   `json:"showInToday"`
		ShowInCalendar   *bool   `json:"showInCalendar"`
		GroupByCompleted *bool   `json:"groupByCompleted"`
		DisplayType      *string `json:"displayType"`
		SortType         *string `json:"sortType"`
		DefaultSectionID *int64  `json:"defaultSectionId"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if body.ShowInToday != nil {
		existing.ShowInToday = *body.ShowInToday
	}
	if body.ShowInCalendar != nil {
		existing.ShowInCalendar = *body.ShowInCalendar
	}
	if body.GroupByCompleted != nil {
		existing.GroupByCompleted = *body.GroupByCompleted
	}
	if body.DisplayType != nil {
		existing.DisplayType = *body.DisplayType
	}
	if body.SortType != nil {
		existing.SortType = *body.SortType
	}
	if body.DefaultSectionID != nil {
		existing.DefaultSectionID = *body.DefaultSectionID
	}
	saved, err := s.store.SaveHabitPreference(r.Context(), existing)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, saved)
}

func (s *Server) apiHabitSections(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	if r.Method == http.MethodGet {
		sections, err := s.store.ListHabitSections(r.Context(), current.ID)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"sections": sections})
		return
	}
	var body struct {
		Name string `json:"name"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	section, err := s.store.CreateHabitSection(r.Context(), current.ID, body.Name)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"section": section})
}

func (s *Server) apiHabitSection(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, ok := habitID(r, "id")
	if !ok {
		writeAPIError(w, http.StatusNotFound, "分组不存在")
		return
	}
	if r.Method == http.MethodDelete {
		if err := s.store.DeleteHabitSection(r.Context(), current.ID, id); err != nil {
			writeAPIError(w, http.StatusNotFound, "分组不存在")
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	var body struct {
		Name      string `json:"name"`
		SortOrder int64  `json:"sortOrder"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	section, err := s.store.UpdateHabitSection(r.Context(), current.ID, id, body.Name, body.SortOrder)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "分组不存在")
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"section": section})
}

func (s *Server) apiHabitExport(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	csv, err := s.store.ExportHabitsCSV(r.Context(), current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=habits-%s.csv", time.Now().Format("20060102")))
	_, _ = w.Write([]byte(csv))
}
