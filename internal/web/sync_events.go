package web

import (
	"context"
	"net/http"
	"strconv"
	"strings"

	"caldav-free/internal/auth"
	"caldav-free/internal/ical"
	"caldav-free/internal/store"
	"caldav-free/internal/tasksync"
)

type syncEventBody struct {
	CalendarID   int64    `json:"calendarId"`
	Href         string   `json:"href"`
	Summary      string   `json:"summary"`
	Location     string   `json:"location"`
	Description  string   `json:"description"`
	Start        string   `json:"start"`
	End          string   `json:"end"`
	AllDay       bool     `json:"allDay"`
	RRule        string   `json:"rrule"`
	Count        int      `json:"count"`
	Reminders    []int    `json:"reminders"`
	Attendees    []string `json:"attendees"`
	Scope        string   `json:"scope"`
	RecurrenceID string   `json:"recurrenceId"`
}

func (s *Server) syncEventCalendar(ctx context.Context, userID, calendarID int64) (*store.Calendar, bool) {
	cal, err := s.store.GetCalendar(ctx, calendarID)
	if err != nil || cal.UserID != userID || !cal.SupportsComponent("VEVENT") ||
		cal.Slug == tasksync.CalendarSlug {
		return nil, false
	}
	return cal, true
}

func (s *Server) apiSyncCreateEvent(w http.ResponseWriter, r *http.Request) {
	current, ok := s.apiSyncUser(w, r)
	if !ok {
		return
	}
	var body syncEventBody
	if !readAPIJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Summary) == "" {
		writeAPIError(w, http.StatusBadRequest, "请填写事件标题")
		return
	}
	ctx := r.Context()
	cal, ok := s.syncEventCalendar(ctx, current.ID, body.CalendarID)
	if !ok {
		writeAPIError(w, http.StatusNotFound, "日历不存在或不可写")
		return
	}
	loc, tzid := calendarLocation(cal.Timezone)
	start, end, err := parseAPITimes(body.Start, body.End, body.AllDay, loc)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	data, uid, err := buildEventICS(
		cal, "", body.Summary, body.Location, body.Description,
		start, end, body.AllDay, tzid, body.RRule, body.Count,
		body.Reminders, body.Attendees,
	)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	parsed, err := ical.Load(data, cal.Timezone)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "事件数据无效")
		return
	}
	info, err := parsed.Analyze()
	if err != nil || info.ComponentType != "VEVENT" {
		writeAPIError(w, http.StatusBadRequest, "事件数据无效")
		return
	}
	obj := &store.Object{
		CalendarID:    cal.ID,
		Href:          strings.ToLower(auth.RandomToken(6)) + ".ics",
		UID:           uid,
		ETag:          hashData(data),
		ContentType:   "text/calendar; charset=utf-8",
		Data:          data,
		ComponentType: info.ComponentType,
		FirstStart:    unixOrZero(info.FirstStart),
		LastEnd:       unixOrZero(info.LastEnd),
		Recurring:     info.Recurring,
		Size:          int64(len(data)),
	}
	if _, _, _, err := s.store.PutObject(ctx, obj); err != nil {
		writeAPIError(w, http.StatusInternalServerError, "保存事件失败")
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{
		"href": obj.Href,
		"uid":  obj.UID,
	})
}

func (s *Server) apiSyncUpdateEvent(w http.ResponseWriter, r *http.Request) {
	current, ok := s.apiSyncUser(w, r)
	if !ok {
		return
	}
	var body syncEventBody
	if !readAPIJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Summary) == "" {
		writeAPIError(w, http.StatusBadRequest, "请填写事件标题")
		return
	}
	href := strings.TrimSpace(body.Href)
	if _, valid := validObjectName(href); !valid {
		writeAPIError(w, http.StatusBadRequest, "事件路径无效")
		return
	}
	ctx := r.Context()
	cal, ok := s.syncEventCalendar(ctx, current.ID, body.CalendarID)
	if !ok {
		writeAPIError(w, http.StatusNotFound, "日历不存在或不可写")
		return
	}
	obj, err := s.store.GetObject(ctx, cal.ID, href)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "事件不存在")
		return
	}
	loc, tzid := calendarLocation(cal.Timezone)
	start, end, err := parseAPITimes(body.Start, body.End, body.AllDay, loc)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	if strings.EqualFold(body.Scope, "single") {
		patch := eventPatchBody{
			Summary: body.Summary, Location: body.Location,
			Description: body.Description, Start: body.Start, End: body.End,
			AllDay: body.AllDay, RRule: body.RRule, Count: body.Count,
			Scope: "single", RecurrenceID: body.RecurrenceID,
			Reminders: body.Reminders, Attendees: body.Attendees,
		}
		data, err := buildOccurrenceUpdate(cal, obj, patch, start, end, tzid)
		if err != nil {
			writeAPIError(w, http.StatusBadRequest, err.Error())
			return
		}
		parsed, err := ical.Load(data, cal.Timezone)
		if err != nil {
			writeAPIError(w, http.StatusBadRequest, "事件数据无效")
			return
		}
		info, err := parsed.Analyze()
		if err != nil || info.ComponentType != "VEVENT" {
			writeAPIError(w, http.StatusBadRequest, "事件数据无效")
			return
		}
		obj.Data = data
		obj.ETag = hashData(data)
		obj.ComponentType = info.ComponentType
		obj.FirstStart = unixOrZero(info.FirstStart)
		obj.LastEnd = unixOrZero(info.LastEnd)
		obj.Recurring = info.Recurring
		obj.Size = int64(len(data))
		if _, _, _, err := s.store.PutObject(ctx, obj); err != nil {
			writeAPIError(w, http.StatusInternalServerError, "保存事件失败")
			return
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{
			"href": obj.Href,
			"uid":  obj.UID,
		})
		return
	}
	data, uid, err := buildEventICS(
		cal, obj.UID, body.Summary, body.Location, body.Description,
		start, end, body.AllDay, tzid, body.RRule, body.Count,
		body.Reminders, body.Attendees,
	)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	parsed, err := ical.Load(data, cal.Timezone)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "事件数据无效")
		return
	}
	info, err := parsed.Analyze()
	if err != nil || info.ComponentType != "VEVENT" {
		writeAPIError(w, http.StatusBadRequest, "事件数据无效")
		return
	}
	obj.Data = data
	obj.UID = uid
	obj.ETag = hashData(data)
	obj.ComponentType = info.ComponentType
	obj.FirstStart = unixOrZero(info.FirstStart)
	obj.LastEnd = unixOrZero(info.LastEnd)
	obj.Recurring = info.Recurring
	obj.Size = int64(len(data))
	if _, _, _, err := s.store.PutObject(ctx, obj); err != nil {
		writeAPIError(w, http.StatusInternalServerError, "保存事件失败")
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"href": obj.Href,
		"uid":  obj.UID,
	})
}

func (s *Server) apiSyncDeleteEvent(w http.ResponseWriter, r *http.Request) {
	current, ok := s.apiSyncUser(w, r)
	if !ok {
		return
	}
	calendarID, err := strconv.ParseInt(r.URL.Query().Get("calendarId"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "日历无效")
		return
	}
	href := strings.TrimSpace(r.URL.Query().Get("href"))
	if _, valid := validObjectName(href); !valid {
		writeAPIError(w, http.StatusBadRequest, "事件路径无效")
		return
	}
	ctx := r.Context()
	cal, ok := s.syncEventCalendar(ctx, current.ID, calendarID)
	if !ok {
		writeAPIError(w, http.StatusNotFound, "日历不存在或不可写")
		return
	}
	recurrenceID := strings.TrimSpace(r.URL.Query().Get("recurrenceId"))
	if recurrenceID == "" {
		if _, _, err := s.store.DeleteObject(ctx, cal.ID, href); err != nil {
			if err == store.ErrNotFound {
				writeAPIError(w, http.StatusNotFound, "事件不存在")
				return
			}
			writeAPIError(w, http.StatusInternalServerError, "删除事件失败")
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	obj, err := s.store.GetObject(ctx, cal.ID, href)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "事件不存在")
		return
	}
	data, err := buildOccurrenceDelete(cal, obj, recurrenceID)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	parsed, err := ical.Load(data, cal.Timezone)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "事件数据无效")
		return
	}
	info, err := parsed.Analyze()
	if err != nil || info.ComponentType != "VEVENT" {
		writeAPIError(w, http.StatusBadRequest, "事件数据无效")
		return
	}
	obj.Data = data
	obj.ETag = hashData(data)
	obj.ComponentType = info.ComponentType
	obj.FirstStart = unixOrZero(info.FirstStart)
	obj.LastEnd = unixOrZero(info.LastEnd)
	obj.Recurring = info.Recurring
	obj.Size = int64(len(data))
	if _, _, _, err := s.store.PutObject(ctx, obj); err != nil {
		writeAPIError(w, http.StatusInternalServerError, "删除事件失败")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
