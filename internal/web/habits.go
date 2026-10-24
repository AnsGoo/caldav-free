package web

import (
	"fmt"
	"io"
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

func (s *Server) apiHabitCalendar(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	now := time.Now()
	from := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	to := from.AddDate(0, 1, -1)
	if raw := strings.TrimSpace(r.URL.Query().Get("from")); raw != "" {
		if parsed, err := time.ParseInLocation("2006-01-02", raw, now.Location()); err == nil {
			from = parsed
		}
	}
	if raw := strings.TrimSpace(r.URL.Query().Get("to")); raw != "" {
		if parsed, err := time.ParseInLocation("2006-01-02", raw, now.Location()); err == nil {
			to = parsed
		}
	}
	if to.Before(from) || to.Sub(from) > 92*24*time.Hour {
		writeAPIError(w, http.StatusBadRequest, "日期范围无效")
		return
	}
	entries, err := s.store.HabitCalendar(r.Context(), current.ID, from, to)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"entries": entries})
}

func (s *Server) apiHabitFocus(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, ok := habitID(r, "id")
	if !ok {
		writeAPIError(w, http.StatusNotFound, "习惯不存在")
		return
	}
	if _, err := s.store.GetHabit(r.Context(), current.ID, id); err != nil {
		writeAPIError(w, http.StatusNotFound, "习惯不存在")
		return
	}
	var body struct {
		Minutes     int    `json:"minutes"`
		StartedAt   string `json:"startedAt"`
		CompletedAt string `json:"completedAt"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	session := &store.HabitFocusSession{UserID: current.ID, HabitID: id, Minutes: body.Minutes}
	if parsed, err := time.Parse(time.RFC3339, body.StartedAt); err == nil {
		session.StartedAt = parsed
	}
	if parsed, err := time.Parse(time.RFC3339, body.CompletedAt); err == nil {
		session.CompletedAt = parsed
	}
	created, err := s.store.CreateHabitFocusSession(r.Context(), session)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"session": created})
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
		Timezone         *string `json:"timezone"`
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
	if body.Timezone != nil {
		if _, err := time.LoadLocation(strings.TrimSpace(*body.Timezone)); err != nil {
			writeAPIError(w, http.StatusBadRequest, "时区无效")
			return
		}
		existing.Timezone = strings.TrimSpace(*body.Timezone)
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
	if r.URL.Query().Get("format") == "json" {
		backup, err := s.store.ExportHabitsBackup(r.Context(), current.ID)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=habits-%s.json", time.Now().Format("20060102")))
		writeAPIJSON(w, http.StatusOK, backup)
		return
	}
	csv, err := s.store.ExportHabitsCSV(r.Context(), current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=habits-%s.csv", time.Now().Format("20060102")))
	_, _ = w.Write([]byte(csv))
}

func (s *Server) apiHabitExportByID(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, ok := habitID(r, "id")
	if !ok {
		writeAPIError(w, http.StatusNotFound, "习惯不存在")
		return
	}
	if r.URL.Query().Get("format") == "json" {
		backup, err := s.store.ExportHabitBackup(r.Context(), current.ID, id)
		if err != nil {
			if err == store.ErrNotFound {
				writeAPIError(w, http.StatusNotFound, "习惯不存在")
				return
			}
			s.apiServerError(w, err)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=habit-%d-%s.json", id, time.Now().Format("20060102")))
		writeAPIJSON(w, http.StatusOK, backup)
		return
	}
	csv, err := s.store.ExportHabitCSV(r.Context(), current.ID, id)
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "习惯不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=habit-%d-%s.csv", id, time.Now().Format("20060102")))
	_, _ = w.Write([]byte(csv))
}

func (s *Server) apiHabitShare(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, ok := habitID(r, "id")
	if !ok {
		writeAPIError(w, http.StatusNotFound, "习惯不存在")
		return
	}
	if r.Method == http.MethodDelete {
		if err := s.store.RevokeHabitShare(r.Context(), current.ID, id); err != nil {
			if err == store.ErrNotFound {
				writeAPIError(w, http.StatusNotFound, "分享链接不存在")
				return
			}
			s.apiServerError(w, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	share, err := s.store.GetOrCreateHabitShare(r.Context(), current.ID, id)
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "习惯不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"share": map[string]any{
		"token":     share.Token,
		"path":      "/share/habit/" + share.Token,
		"createdAt": share.CreatedAt,
	}})
}

func (s *Server) apiPublicHabitShare(w http.ResponseWriter, r *http.Request) {
	if allowed, retry := s.publicLimiter.allow(clientIP(r)); !allowed {
		seconds := int(retry.Seconds() + 0.5)
		if seconds < 1 {
			seconds = 1
		}
		w.Header().Set("Retry-After", strconv.Itoa(seconds))
		writeAPIError(w, http.StatusTooManyRequests, "访问过于频繁，请稍后再试")
		return
	}
	share, err := s.store.HabitPublicShare(r.Context(), r.PathValue("token"))
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "分享链接不存在或已停止分享")
			return
		}
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"share": share})
}

func (s *Server) apiHabitImportDida(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	r.Body = http.MaxBytesReader(w, r.Body, 12<<20)
	if err := r.ParseMultipartForm(12 << 20); err != nil {
		writeAPIError(w, http.StatusBadRequest, "读取上传文件失败")
		return
	}
	file, _, err := r.FormFile("file")
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "请选择 Dida 习惯导出文件")
		return
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, (10<<20)+1))
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "读取上传文件失败")
		return
	}
	if len(data) > 10<<20 {
		writeAPIError(w, http.StatusBadRequest, "Dida 导出文件不能超过 10MB")
		return
	}
	result, err := s.store.ImportDidaHabits(r.Context(), current.ID, data, r.URL.Query().Get("mode"))
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusOK, result)
}

func (s *Server) apiHabitImport(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var backup store.HabitBackup
	if !readAPIJSON(w, r, &backup) {
		return
	}
	result, err := s.store.ImportHabitsBackup(r.Context(), current.ID, &backup, r.URL.Query().Get("mode"))
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusOK, result)
}
