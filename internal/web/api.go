package web

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"caldav-free/internal/auth"
	"caldav-free/internal/ical"
	"caldav-free/internal/store"
	"caldav-free/internal/tasksync"
)

// ---------------------------------------------------------------- API plumbing

func writeAPIJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	if value != nil {
		_ = json.NewEncoder(w).Encode(value)
	}
}

func writeAPIError(w http.ResponseWriter, status int, message string) {
	writeAPIJSON(w, status, map[string]string{"error": message})
}

func readAPIJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(dst); err != nil {
		writeAPIError(w, http.StatusBadRequest, "请求数据格式不正确")
		return false
	}
	return true
}

func (s *Server) apiAdmin(next func(http.ResponseWriter, *http.Request, *store.User, *session)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		user, sess, ok := s.current(r)
		if !ok {
			writeAPIError(w, http.StatusUnauthorized, "未登录或会话已过期")
			return
		}
		if !user.IsAdmin {
			writeAPIError(w, http.StatusForbidden, "需要管理员权限")
			return
		}
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			if r.Header.Get("X-CSRF-Token") == "" || r.Header.Get("X-CSRF-Token") != sess.CSRF {
				writeAPIError(w, http.StatusForbidden, "CSRF 校验失败，请刷新页面后重试")
				return
			}
		}
		next(w, r, user, sess)
	}
}

func (s *Server) apiSetSessionCookie(w http.ResponseWriter, r *http.Request, id string) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookie,
		Value:    id,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   s.isSecure(r),
		MaxAge:   int((12 * time.Hour).Seconds()),
	})
}

func (s *Server) apiClearSessionCookie(w http.ResponseWriter, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookie,
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		MaxAge:   -1,
		Secure:   s.isSecure(r),
	})
}

// ---------------------------------------------------------------- DTOs

type apiUser struct {
	ID          int64  `json:"id"`
	Username    string `json:"username"`
	DisplayName string `json:"displayName"`
	Email       string `json:"email"`
	IsAdmin     bool   `json:"isAdmin"`
	CreatedAt   string `json:"createdAt"`
	Calendars   int64  `json:"calendars,omitempty"`
	Objects     int64  `json:"objects,omitempty"`
}

type apiCalendar struct {
	ID          int64    `json:"id"`
	UserID      int64    `json:"userId"`
	Slug        string   `json:"slug"`
	DisplayName string   `json:"displayName"`
	Description string   `json:"description"`
	Color       string   `json:"color"`
	Order       int      `json:"order"`
	Timezone    string   `json:"timezone"`
	Components  []string `json:"components"`
	SyncSeq     int64    `json:"syncSeq"`
	CreatedAt   string   `json:"createdAt"`
	ModifiedAt  string   `json:"modifiedAt"`
	EventCount  int64    `json:"eventCount,omitempty"`
}

type apiEvent struct {
	Href          string `json:"href"`
	UID           string `json:"uid"`
	Summary       string `json:"summary"`
	Location      string `json:"location"`
	Start         string `json:"start"`
	End           string `json:"end"`
	AllDay        bool   `json:"allDay"`
	Recurring     bool   `json:"recurring"`
	Size          int64  `json:"size"`
	ComponentType string `json:"componentType"`
}

type apiStats struct {
	Users     int64 `json:"users"`
	Calendars int64 `json:"calendars"`
	Objects   int64 `json:"objects"`
}

func userDTO(u *store.User) apiUser {
	return apiUser{
		ID:          u.ID,
		Username:    u.Username,
		DisplayName: u.DisplayName,
		Email:       u.Email,
		IsAdmin:     u.IsAdmin,
		CreatedAt:   u.CreatedAt.Format(time.RFC3339),
	}
}

func calendarDTO(c *store.Calendar) apiCalendar {
	return apiCalendar{
		ID:          c.ID,
		UserID:      c.UserID,
		Slug:        c.Slug,
		DisplayName: c.DisplayName,
		Description: c.Description,
		Color:       c.Color,
		Order:       c.Order,
		Timezone:    c.Timezone,
		Components:  append([]string(nil), c.Components...),
		SyncSeq:     c.SyncSeq,
		CreatedAt:   c.CreatedAt.Format(time.RFC3339),
		ModifiedAt:  c.ModifiedAt.Format(time.RFC3339),
	}
}

func eventDTO(cal *store.Calendar, obj *store.Object) apiEvent {
	dto := apiEvent{
		Href:          obj.Href,
		UID:           obj.UID,
		Summary:       obj.UID,
		Recurring:     obj.Recurring,
		Size:          obj.Size,
		ComponentType: obj.ComponentType,
	}
	parsed, err := ical.Load(obj.Data, cal.Timezone)
	if err != nil {
		return dto
	}
	var comp *ical.Component
	for _, name := range []string{"VEVENT", "VTODO", "VJOURNAL"} {
		if ev := parsed.Root.Child(name); ev != nil {
			comp = ev
			break
		}
	}
	if comp == nil {
		return dto
	}
	dto.Summary = ical.UnescapeText(comp.Value("SUMMARY"))
	if dto.Summary == "" {
		dto.Summary = obj.UID
	}
	dto.Location = ical.UnescapeText(comp.Value("LOCATION"))
	start, end, allDay, err := parsed.ComponentTimes(comp)
	if err == nil {
		dto.AllDay = allDay
		if !start.IsZero() {
			dto.Start = start.Format(time.RFC3339)
		}
		if !end.IsZero() {
			dto.End = end.Format(time.RFC3339)
		}
	}
	return dto
}

func (s *Server) userWithCounts(r *http.Request, u *store.User) (apiUser, error) {
	dto := userDTO(u)
	ctx := r.Context()
	cals, err := s.store.CountCalendars(ctx, u.ID)
	if err != nil {
		return dto, err
	}
	dto.Calendars = cals
	list, err := s.store.ListCalendars(ctx, u.ID)
	if err != nil {
		return dto, err
	}
	var objects int64
	for _, cal := range list {
		n, err := s.store.CountObjects(ctx, cal.ID)
		if err != nil {
			return dto, err
		}
		objects += n
	}
	dto.Objects = objects
	return dto, nil
}

func (s *Server) calendarWithCount(r *http.Request, c *store.Calendar) (apiCalendar, error) {
	dto := calendarDTO(c)
	n, err := s.store.CountObjects(r.Context(), c.ID)
	if err != nil {
		return dto, err
	}
	dto.EventCount = n
	return dto, nil
}

// ---------------------------------------------------------------- auth

func (s *Server) apiLogin(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	ip := clientIP(r)
	if !s.limiter.allowed(ip) {
		writeAPIError(w, http.StatusTooManyRequests, "尝试次数过多，请稍后再试")
		return
	}
	u, err := s.store.GetUserByUsername(r.Context(), strings.TrimSpace(body.Username))
	if err != nil {
		auth.VerifyPassword(body.Password, dummyAdminHash)
		s.limiter.fail(ip)
		writeAPIError(w, http.StatusUnauthorized, "用户名或密码错误")
		return
	}
	if !auth.VerifyPassword(body.Password, u.PasswordHash) {
		s.limiter.fail(ip)
		writeAPIError(w, http.StatusUnauthorized, "用户名或密码错误")
		return
	}
	if !u.IsAdmin {
		s.limiter.fail(ip)
		writeAPIError(w, http.StatusForbidden, "该账号不是管理员")
		return
	}
	s.limiter.reset(ip)
	id, sess := s.sessions.create(u.ID)
	s.apiSetSessionCookie(w, r, id)
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"user":      userDTO(u),
		"csrf":      sess.CSRF,
		"baseUrl":   s.baseURL(r),
		"caldavUrl": s.CalDAVURL,
	})
}

func (s *Server) apiMe(w http.ResponseWriter, r *http.Request, u *store.User, sess *session) {
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"user":      userDTO(u),
		"csrf":      sess.CSRF,
		"baseUrl":   s.baseURL(r),
		"caldavUrl": s.CalDAVURL,
	})
}

func (s *Server) apiLogout(w http.ResponseWriter, r *http.Request, _ *store.User, sess *session) {
	if cookie, err := r.Cookie(sessionCookie); err == nil {
		s.sessions.destroy(cookie.Value)
	}
	s.apiClearSessionCookie(w, r)
	_ = sess
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------- dashboard/users

func (s *Server) apiDashboard(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	ctx := r.Context()
	stats := apiStats{}
	var err error
	if stats.Users, err = s.store.CountUsers(ctx); err != nil {
		s.apiServerError(w, err)
		return
	}
	if stats.Calendars, err = s.store.CountAllCalendars(ctx); err != nil {
		s.apiServerError(w, err)
		return
	}
	if stats.Objects, err = s.store.CountAllObjects(ctx); err != nil {
		s.apiServerError(w, err)
		return
	}
	users, err := s.store.ListUsers(ctx)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	rows := make([]apiUser, 0, len(users))
	for _, u := range users {
		row, err := s.userWithCounts(r, u)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		rows = append(rows, row)
	}
	base := s.baseURL(r)
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"stats":        stats,
		"users":        rows,
		"baseUrl":      base,
		"caldavUrl":    s.CalDAVURL,
		"principalUrl": base + principalPath(current.Username),
		"calendarHome": base + "/calendars/" + current.Username + "/",
	})
}

func (s *Server) apiUsers(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	users, err := s.store.ListUsers(r.Context())
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	rows := make([]apiUser, 0, len(users))
	for _, u := range users {
		row, err := s.userWithCounts(r, u)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		rows = append(rows, row)
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"users": rows})
}

func (s *Server) apiUserDetail(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "用户不存在")
		return
	}
	u, err := s.store.GetUser(r.Context(), id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "用户不存在")
		return
	}
	row, err := s.userWithCounts(r, u)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	cals, err := s.store.ListCalendars(r.Context(), u.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	calRows := make([]apiCalendar, 0, len(cals))
	for _, cal := range cals {
		row, err := s.calendarWithCount(r, cal)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		calRows = append(calRows, row)
	}
	admins, _ := s.countAdmins(r.Context())
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"user":       row,
		"calendars":  calRows,
		"timezones":  timezones(),
		"isSelf":     u.ID == current.ID,
		"adminCount": admins,
	})
}

func (s *Server) apiCreateUser(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	var body struct {
		Username    string `json:"username"`
		DisplayName string `json:"displayName"`
		Email       string `json:"email"`
		Password    string `json:"password"`
		IsAdmin     bool   `json:"isAdmin"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	username := strings.ToLower(strings.TrimSpace(body.Username))
	if !validUsername(username) {
		writeAPIError(w, http.StatusBadRequest, "用户名需为 2-64 位小写字母、数字、点、下划线或连字符")
		return
	}
	if len(body.Password) < 8 {
		writeAPIError(w, http.StatusBadRequest, "密码至少 8 位")
		return
	}
	hash, err := auth.HashPassword(body.Password)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	u, err := s.store.CreateUser(r.Context(), username, body.DisplayName, body.Email, hash, body.IsAdmin)
	if err == store.ErrConflict {
		writeAPIError(w, http.StatusConflict, "用户名已存在")
		return
	}
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"user": userDTO(u)})
}

func (s *Server) apiUpdateUser(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "用户不存在")
		return
	}
	ctx := r.Context()
	u, err := s.store.GetUser(ctx, id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "用户不存在")
		return
	}
	var body struct {
		DisplayName string `json:"displayName"`
		Email       string `json:"email"`
		IsAdmin     bool   `json:"isAdmin"`
		Password    string `json:"password"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if u.IsAdmin && !body.IsAdmin {
		admins, _ := s.countAdmins(ctx)
		if admins <= 1 {
			writeAPIError(w, http.StatusBadRequest, "不能移除最后一个管理员")
			return
		}
	}
	hash := ""
	if body.Password != "" {
		if len(body.Password) < 8 {
			writeAPIError(w, http.StatusBadRequest, "新密码至少 8 位")
			return
		}
		hash, err = auth.HashPassword(body.Password)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
	}
	if err := s.store.UpdateUser(ctx, id, body.DisplayName, body.Email, body.IsAdmin, hash); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "用户不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	if hash != "" {
		s.dav.InvalidateCredentials()
	}
	updated, _ := s.store.GetUser(ctx, id)
	if body.Password != "" && id == current.ID {
		// Keep the current session usable; the password is only used for new logins.
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"user": userDTO(updated)})
}

func (s *Server) apiDeleteUser(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "用户不存在")
		return
	}
	if id == current.ID {
		writeAPIError(w, http.StatusBadRequest, "不能删除当前登录的账号")
		return
	}
	ctx := r.Context()
	u, err := s.store.GetUser(ctx, id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "用户不存在")
		return
	}
	if u.IsAdmin {
		admins, _ := s.countAdmins(ctx)
		if admins <= 1 {
			writeAPIError(w, http.StatusBadRequest, "不能删除最后一个管理员")
			return
		}
	}
	if err := s.store.DeleteUser(ctx, id); err != nil {
		s.apiServerError(w, err)
		return
	}
	s.dav.InvalidateCredentials()
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------- calendars

func (s *Server) apiCreateCalendar(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	userID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "用户不存在")
		return
	}
	var body struct {
		Slug        string   `json:"slug"`
		DisplayName string   `json:"displayName"`
		Timezone    string   `json:"timezone"`
		Components  []string `json:"components"`
		Color       string   `json:"color"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if !validSlug(strings.TrimSpace(body.Slug)) {
		writeAPIError(w, http.StatusBadRequest, "日历标识需为 2-64 位字母、数字、点、下划线或连字符")
		return
	}
	timezone := strings.TrimSpace(body.Timezone)
	if timezone == "" {
		timezone = store.DefaultTimezone
	}
	canonical, ok := ical.CanonicalTZID(timezone)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "无效的时区")
		return
	}
	displayName := strings.TrimSpace(body.DisplayName)
	if displayName == "" {
		displayName = body.Slug
	}
	components := body.Components
	if len(components) == 0 {
		components = []string{"VEVENT", "VTODO", "VJOURNAL"}
	}
	color := body.Color
	if color == "" {
		color = "#3366CC"
	}
	cal, err := s.store.CreateCalendar(r.Context(), userID, strings.TrimSpace(body.Slug), displayName, "", color, canonical, 0, components)
	if err == store.ErrConflict {
		writeAPIError(w, http.StatusConflict, "该用户已有同名日历")
		return
	}
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"calendar": calendarDTO(cal)})
}

func (s *Server) apiCalendarDetail(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历不存在")
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历不存在")
		return
	}
	owner, err := s.store.GetUser(ctx, cal.UserID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历所有者不存在")
		return
	}
	calDTO, _ := s.calendarWithCount(r, cal)
	objs, err := s.store.ListObjects(ctx, cal.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	events := make([]apiEvent, 0, len(objs))
	for _, obj := range objs {
		events = append(events, eventDTO(cal, obj))
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"calendar":  calDTO,
		"owner":     userDTO(owner),
		"events":    events,
		"timezones": timezones(),
	})
}

func (s *Server) apiUpdateCalendar(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历不存在")
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历不存在")
		return
	}
	var body struct {
		DisplayName string   `json:"displayName"`
		Description string   `json:"description"`
		Color       string   `json:"color"`
		Timezone    string   `json:"timezone"`
		Order       int      `json:"order"`
		Components  []string `json:"components"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	timezone := strings.TrimSpace(body.Timezone)
	if timezone == "" {
		timezone = cal.Timezone
	}
	canonical, ok := ical.CanonicalTZID(timezone)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "无效的时区")
		return
	}
	components := body.Components
	if len(components) == 0 {
		writeAPIError(w, http.StatusBadRequest, "至少选择一种组件类型")
		return
	}
	displayName := strings.TrimSpace(body.DisplayName)
	if displayName == "" {
		displayName = cal.Slug
	}
	if err := s.store.UpdateCalendar(ctx, id, displayName, strings.TrimSpace(body.Description), body.Color, canonical, body.Order, components); err != nil {
		s.apiServerError(w, err)
		return
	}
	if canonical != cal.Timezone {
		_ = s.store.SetCalendarTimezoneData(ctx, id, "")
	}
	updated, _ := s.store.GetCalendar(ctx, id)
	dto, _ := s.calendarWithCount(r, updated)
	writeAPIJSON(w, http.StatusOK, map[string]any{"calendar": dto})
}

func (s *Server) apiDeleteCalendar(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历不存在")
		return
	}
	cal, err := s.store.GetCalendar(r.Context(), id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历不存在")
		return
	}
	if cal.Slug == tasksync.CalendarSlug {
		writeAPIError(w, http.StatusConflict, "任务同步日历由任务工作台维护，不能删除")
		return
	}
	if err := s.store.DeleteCalendar(r.Context(), id); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "日历不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------- events

func (s *Server) apiEventDetail(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	calID, name, ok := eventPath(r)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "事件路径无效")
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, calID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历不存在")
		return
	}
	obj, err := s.store.GetObject(ctx, calID, name)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "事件不存在")
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"event": eventDTO(cal, obj),
		"data":  string(obj.Data),
	})
}

func (s *Server) apiCreateEvent(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	calID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历不存在")
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, calID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历不存在")
		return
	}
	if !cal.SupportsComponent("VEVENT") {
		writeAPIError(w, http.StatusBadRequest, "该日历未启用 VEVENT 组件")
		return
	}
	var body struct {
		Summary     string `json:"summary"`
		Location    string `json:"location"`
		Description string `json:"description"`
		Start       string `json:"start"`
		End         string `json:"end"`
		AllDay      bool   `json:"allDay"`
		RRule       string `json:"rrule"`
		Count       int    `json:"count"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Summary) == "" {
		writeAPIError(w, http.StatusBadRequest, "请填写事件标题")
		return
	}
	loc, tzid := calendarLocation(cal.Timezone)
	start, end, err := parseAPITimes(body.Start, body.End, body.AllDay, loc)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	data, uid, err := buildEventICS(cal, body.Summary, body.Location, body.Description, start, end, body.AllDay, tzid, body.RRule, body.Count)
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
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "事件数据无效："+err.Error())
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
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"event": eventDTO(cal, obj)})
}

func (s *Server) apiUpdateEvent(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	calID, name, ok := eventPath(r)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "事件路径无效")
		return
	}
	var body struct {
		Data string `json:"data"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	ctx := r.Context()
	cal, err := s.store.GetCalendar(ctx, calID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "日历不存在")
		return
	}
	obj, err := s.store.GetObject(ctx, calID, name)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "事件不存在")
		return
	}
	data := []byte(body.Data)
	if !utf8.Valid(data) || hasControl(data) {
		writeAPIError(w, http.StatusBadRequest, "ICS 内容包含无效字符")
		return
	}
	parsed, err := ical.Load(data, cal.Timezone)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "日历数据无法解析："+err.Error())
		return
	}
	info, err := parsed.Analyze()
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "日历数据无效："+err.Error())
		return
	}
	if !cal.SupportsComponent(info.ComponentType) {
		writeAPIError(w, http.StatusBadRequest, "该日历不支持 "+info.ComponentType)
		return
	}
	if other, err := s.store.GetObjectByUID(ctx, cal.ID, info.UID); err == nil && other.Href != name {
		writeAPIError(w, http.StatusConflict, "UID 已被另一个事件使用")
		return
	}
	obj.Data = data
	obj.UID = info.UID
	obj.ETag = hashData(data)
	obj.ComponentType = info.ComponentType
	obj.FirstStart = unixOrZero(info.FirstStart)
	obj.LastEnd = unixOrZero(info.LastEnd)
	obj.Recurring = info.Recurring
	obj.Size = int64(len(data))
	if _, _, _, err := s.store.PutObject(ctx, obj); err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"event": eventDTO(cal, obj), "data": string(data)})
}

func (s *Server) apiDeleteEvent(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	calID, name, ok := eventPath(r)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "事件路径无效")
		return
	}
	if _, _, err := s.store.DeleteObject(r.Context(), calID, name); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "事件不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------- helpers

func (s *Server) apiServerError(w http.ResponseWriter, err error) {
	s.logger.Error("admin API failed", "error", err)
	writeAPIError(w, http.StatusInternalServerError, "服务器内部错误")
}

func eventPath(r *http.Request) (int64, string, bool) {
	calID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		return 0, "", false
	}
	name := strings.TrimSpace(r.PathValue("name"))
	if _, ok := validObjectName(name); !ok {
		return 0, "", false
	}
	return calID, name, true
}

func principalPath(username string) string {
	return "/principals/" + username + "/"
}

func calendarLocation(tz string) (*time.Location, string) {
	loc, err := time.LoadLocation(tz)
	if err != nil || tz == "" {
		loc, err = time.LoadLocation(store.DefaultTimezone)
		if err != nil {
			return time.UTC, "UTC"
		}
		return loc, store.DefaultTimezone
	}
	return loc, tz
}

func parseAPITimes(startRaw, endRaw string, allDay bool, loc *time.Location) (time.Time, time.Time, error) {
	startRaw = strings.TrimSpace(startRaw)
	endRaw = strings.TrimSpace(endRaw)
	if startRaw == "" {
		return time.Time{}, time.Time{}, fmt.Errorf("请填写开始时间")
	}
	if allDay {
		if len(startRaw) > 10 {
			startRaw = startRaw[:10]
		}
		if len(endRaw) > 10 {
			endRaw = endRaw[:10]
		}
		start, err := time.ParseInLocation("2006-01-02", startRaw, loc)
		if err != nil {
			return time.Time{}, time.Time{}, fmt.Errorf("开始日期格式无效")
		}
		end := start.AddDate(0, 0, 1)
		if endRaw != "" {
			if parsed, err := time.ParseInLocation("2006-01-02", endRaw, loc); err == nil && parsed.After(start) {
				end = parsed
			}
		}
		return start, end, nil
	}
	start, err := time.ParseInLocation("2006-01-02T15:04", startRaw, loc)
	if err != nil {
		if start, err = time.ParseInLocation(time.RFC3339, startRaw, loc); err != nil {
			return time.Time{}, time.Time{}, fmt.Errorf("开始时间格式无效")
		}
	}
	end := start.Add(time.Hour)
	if endRaw != "" {
		if parsed, err := time.ParseInLocation("2006-01-02T15:04", endRaw, loc); err == nil && parsed.After(start) {
			end = parsed
		} else if parsed, err := time.ParseInLocation(time.RFC3339, endRaw, loc); err == nil && parsed.After(start) {
			end = parsed
		}
	}
	return start, end, nil
}

func buildEventICS(cal *store.Calendar, summary, location, description string, start, end time.Time, allDay bool, tzid, rrule string, count int) ([]byte, string, error) {
	uid := auth.RandomToken(12) + "@caldav-free"
	root := ical.NewComponent("VCALENDAR")
	root.AddProp("VERSION", "2.0", nil)
	root.AddProp("PRODID", "-//caldav-free//CalDAV Server//EN", nil)
	root.AddProp("CALSCALE", "GREGORIAN", nil)
	ev := ical.NewComponent("VEVENT")
	ev.AddProp("UID", uid, nil)
	ev.AddProp("DTSTAMP", time.Now().UTC().Format("20060102T150405Z"), nil)
	if allDay {
		ev.AddProp("DTSTART", start.Format("20060102"), ical.Params{"VALUE": {"DATE"}})
		ev.AddProp("DTEND", end.Format("20060102"), ical.Params{"VALUE": {"DATE"}})
	} else {
		ev.AddProp("DTSTART", start.Format("20060102T150405"), ical.Params{"TZID": {tzid}})
		ev.AddProp("DTEND", end.Format("20060102T150405"), ical.Params{"TZID": {tzid}})
	}
	ev.AddProp("SUMMARY", ical.EscapeText(strings.TrimSpace(summary)), nil)
	if strings.TrimSpace(description) != "" {
		ev.AddProp("DESCRIPTION", ical.EscapeText(strings.TrimSpace(description)), nil)
	}
	if strings.TrimSpace(location) != "" {
		ev.AddProp("LOCATION", ical.EscapeText(strings.TrimSpace(location)), nil)
	}
	ev.AddProp("STATUS", "CONFIRMED", nil)
	freq := strings.ToUpper(strings.TrimSpace(rrule))
	if freq != "" && freq != "NONE" {
		rule := "FREQ=" + freq
		if count > 0 {
			rule += fmt.Sprintf(";COUNT=%d", count)
		}
		ev.AddProp("RRULE", rule, nil)
	}
	root.AddChild(ev)
	return []byte(root.Encode()), uid, nil
}
