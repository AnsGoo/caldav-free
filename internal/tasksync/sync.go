// Package tasksync keeps workspace tasks in sync with a CalDAV VTODO
// collection. Tasks are the source of truth for the workspace UI; CalDAV
// clients can read and modify the same objects, and changes are reconciled
// lazily whenever the workspace is loaded.
package tasksync

import (
	"bytes"
	"context"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	"caldav-free/internal/auth"
	"caldav-free/internal/ical"
	"caldav-free/internal/store"
	taskparse "caldav-free/internal/tasks"
)

// CalendarSlug is the dedicated VTODO collection created for each user.
const CalendarSlug = "caldav-tasks"

// Syncer reconciles workspace tasks with their VTODO objects.
type Syncer struct {
	store *store.Store
	mu    sync.Mutex
}

// New creates a Syncer backed by st.
func New(st *store.Store) *Syncer {
	return &Syncer{store: st}
}

// EnsureTaskCalendar returns (and creates when needed) the user's VTODO
// collection.
func (s *Syncer) EnsureTaskCalendar(ctx context.Context, userID int64) (*store.Calendar, error) {
	cal, err := s.store.GetCalendarBySlug(ctx, userID, CalendarSlug)
	if err == nil {
		if !cal.SupportsComponent("VTODO") {
			components := append(append([]string(nil), cal.Components...), "VTODO")
			if err := s.store.UpdateCalendar(ctx, cal.ID, cal.DisplayName, cal.Description, cal.Color, cal.Timezone, cal.Order, components); err != nil {
				return nil, err
			}
			cal.Components = store.StringList(components)
		}
		return cal, nil
	}
	if err != store.ErrNotFound {
		return nil, err
	}
	cal, err = s.store.CreateCalendar(ctx, userID, CalendarSlug, "任务", "任务工作台同步的 VTODO 集合", "#4772fa", store.DefaultTimezone, 0, []string{"VTODO"})
	if err == store.ErrConflict {
		return s.store.GetCalendarBySlug(ctx, userID, CalendarSlug)
	}
	if err != nil {
		return nil, err
	}
	return cal, nil
}

// Sync reconciles all of a user's tasks with the VTODO collection.
func (s *Syncer) Sync(ctx context.Context, userID int64) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	cal, err := s.EnsureTaskCalendar(ctx, userID)
	if err != nil {
		return err
	}
	inbox, err := s.store.EnsureInbox(ctx, userID)
	if err != nil {
		return err
	}
	lists, err := s.store.ListTaskLists(ctx, userID)
	if err != nil {
		return err
	}
	listByName := make(map[string]*store.TaskList, len(lists))
	for _, list := range lists {
		listByName[list.Name] = list
	}
	tasks, err := s.store.ListAllTasks(ctx, userID, 2000)
	if err != nil {
		return err
	}
	objects, err := s.store.ListObjects(ctx, cal.ID)
	if err != nil {
		return err
	}
	tombstones, err := s.store.ListDeletedObjects(ctx, cal.ID)
	if err != nil {
		return err
	}

	liveByHref := make(map[string]*store.Object, len(objects))
	liveByUID := make(map[string]*store.Object, len(objects))
	exceptions := make([]*store.Object, 0, 8)
	for _, obj := range objects {
		// Per-instance RECURRENCE-ID exceptions belong to the master task and
		// must not be imported as new tasks. They are processed separately.
		if isRecurrenceExceptionObject(obj) {
			exceptions = append(exceptions, obj)
			continue
		}
		liveByHref[obj.Href] = obj
		if obj.UID != "" {
			liveByUID[obj.UID] = obj
		}
	}
	tombByHref := make(map[string]*store.Object, len(tombstones))
	for _, obj := range tombstones {
		tombByHref[obj.Href] = obj
	}

	claimed := make(map[string]bool, len(objects))
	var firstErr error
	for _, task := range tasks {
		// Notes are workspace-only and never exposed as VTODO objects.
		if task.Kind == "NOTE" {
			continue
		}
		var obj *store.Object
		if task.VTODOHref != "" {
			obj = liveByHref[task.VTODOHref]
		}
		if obj == nil && task.VTODOUID != "" {
			obj = liveByUID[task.VTODOUID]
		}
		if obj != nil {
			claimed[obj.Href] = true
			if !task.SyncPending && (task.VTODOHref != obj.Href || task.VTODOUID != obj.UID) && task.VTODOETag == obj.ETag {
				// A client renamed the resource or changed its UID without
				// changing the payload; adopt the new identity.
				if err := s.store.SetTaskSync(ctx, userID, task.ID, obj.UID, obj.Href, obj.ETag); err != nil && firstErr == nil {
					firstErr = err
				}
				task.VTODOUID = obj.UID
				task.VTODOHref = obj.Href
			}
		}
		if task.VTODOUID == "" || task.SyncPending {
			if err := s.push(ctx, cal, task); err != nil && firstErr == nil {
				firstErr = err
			}
			continue
		}
		if obj == nil {
			if _, deleted := tombByHref[task.VTODOHref]; deleted {
				if err := s.deleteRecurrenceExceptions(ctx, cal, task); err != nil && firstErr == nil {
					firstErr = err
				}
				if err := s.store.DeleteTask(ctx, userID, task.ID); err != nil && firstErr == nil {
					firstErr = err
				}
				continue
			}
			// The collection was recreated or the object vanished without a
			// tombstone: restore the object from the task.
			if err := s.push(ctx, cal, task); err != nil && firstErr == nil {
				firstErr = err
			}
			continue
		}
		if task.VTODOETag != obj.ETag {
			if err := s.importInto(ctx, cal, task, obj); err != nil && firstErr == nil {
				firstErr = err
			}
		}
	}

	for _, obj := range exceptions {
		if err := s.importRecurrenceException(ctx, cal, userID, obj); err != nil && firstErr == nil {
			firstErr = err
		}
	}
	for _, obj := range objects {
		if claimed[obj.Href] || obj.ComponentType != "VTODO" || isRecurrenceExceptionObject(obj) {
			continue
		}
		if err := s.importNew(ctx, cal, obj, listByName, inbox); err != nil && firstErr == nil {
			firstErr = err
		}
	}
	return firstErr
}

// PushTask writes a single task to its VTODO object immediately.
func (s *Syncer) PushTask(ctx context.Context, userID int64, task *store.Task) error {
	if task.Kind == "NOTE" {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	cal, err := s.EnsureTaskCalendar(ctx, userID)
	if err != nil {
		return err
	}
	return s.push(ctx, cal, task)
}

// DeleteTask removes a task's VTODO object. Call it before deleting the task
// row so a stale object cannot be re-imported on the next sync.
func (s *Syncer) DeleteTask(ctx context.Context, userID int64, task *store.Task) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	cal, err := s.EnsureTaskCalendar(ctx, userID)
	if err != nil {
		return err
	}
	href := task.VTODOHref
	if href == "" && task.VTODOUID != "" {
		href = hrefForUID(task.VTODOUID)
	}
	if href == "" {
		return nil
	}
	if _, _, err := s.store.DeleteObject(ctx, cal.ID, href); err != nil && err != store.ErrNotFound {
		return err
	}
	// Remove generated RECURRENCE-ID exceptions as well. They share the
	// master UID but live at separate hrefs.
	return s.deleteRecurrenceExceptions(ctx, cal, task)
}

// DeleteRecurrenceExceptions removes generated per-instance exceptions when a
// task stops being recurring or changes its rule.
func (s *Syncer) DeleteRecurrenceExceptions(ctx context.Context, userID int64, task *store.Task) error {
	if task == nil {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	cal, err := s.EnsureTaskCalendar(ctx, userID)
	if err != nil {
		return err
	}
	return s.deleteRecurrenceExceptions(ctx, cal, task)
}

func (s *Syncer) deleteRecurrenceExceptions(ctx context.Context, cal *store.Calendar, task *store.Task) error {
	href := task.VTODOHref
	if href == "" && task.VTODOUID != "" {
		href = hrefForUID(task.VTODOUID)
	}
	if href == "" {
		return nil
	}
	objects, err := s.store.ListObjects(ctx, cal.ID)
	if err != nil {
		return err
	}
	base := strings.TrimSuffix(href, ".ics") + "-rid-"
	for _, obj := range objects {
		if obj.Href == href || !strings.Contains(obj.Href, "-rid-") {
			continue
		}
		if !strings.HasPrefix(obj.Href, base) && (task.VTODOUID == "" || obj.UID != task.VTODOUID) {
			continue
		}
		if _, _, err := s.store.DeleteObject(ctx, cal.ID, obj.Href); err != nil && err != store.ErrNotFound {
			return err
		}
	}
	return nil
}

// UpsertRecurrenceException writes a per-instance VTODO exception identified
// by RECURRENCE-ID. Completed instances are marked COMPLETED; skipped ones are
// marked CANCELLED. The master VTODO keeps its RRULE.
func (s *Syncer) UpsertRecurrenceException(ctx context.Context, userID int64, task *store.Task, occurrence time.Time, status string) error {
	return s.UpsertRecurrenceExceptionAt(ctx, userID, task, occurrence, status, nil)
}

// UpsertRecurrenceExceptionAt writes an exception whose effective due date may
// differ from the original occurrence (used by single-instance postponement).
func (s *Syncer) UpsertRecurrenceExceptionAt(ctx context.Context, userID int64, task *store.Task, occurrence time.Time, status string, newDue *time.Time) error {
	if task == nil || task.Recurrence == "" || occurrence.IsZero() || task.VTODOUID == "" {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	cal, err := s.EnsureTaskCalendar(ctx, userID)
	if err != nil {
		return err
	}
	copyTask := *task
	copyTask.Recurrence = ""
	copyTask.DueAt = &occurrence
	if newDue != nil {
		value := newDue.UTC()
		copyTask.DueAt = &value
	}
	copyTask.StartAt = nil
	copyTask.Completed = status == "completed"
	if copyTask.Completed {
		now := time.Now().UTC()
		copyTask.CompletedAt = &now
	} else {
		copyTask.CompletedAt = nil
	}
	data := buildVTODO(cal, &copyTask, "")
	parsed, err := ical.Load(data, cal.Timezone)
	if err != nil {
		return fmt.Errorf("parse recurrence exception: %w", err)
	}
	comp := parsed.Root.Child("VTODO")
	if comp == nil {
		return fmt.Errorf("build recurrence exception: missing VTODO")
	}
	loc := calendarLocation(cal)
	if task.AllDay {
		comp.AddProp("RECURRENCE-ID", occurrence.In(loc).Format("20060102"), ical.Params{"VALUE": {"DATE"}})
	} else {
		comp.AddProp("RECURRENCE-ID", occurrence.UTC().Format("20060102T150405Z"), nil)
	}
	if status == "skipped" {
		comp.SetProp("STATUS", "CANCELLED", nil)
		comp.RemoveProps("COMPLETED")
		comp.SetProp("PERCENT-COMPLETE", "0", nil)
	}
	if status == "postponed" {
		comp.SetProp("STATUS", "NEEDS-ACTION", nil)
		comp.RemoveProps("COMPLETED")
		comp.SetProp("PERCENT-COMPLETE", "0", nil)
		comp.SetProp("X-CALDDAV-POSTPONED", "TRUE", nil)
	}
	data = []byte(parsed.Root.Encode())
	finalCalendar, err := ical.Load(data, cal.Timezone)
	if err != nil {
		return fmt.Errorf("analyze recurrence exception: %w", err)
	}
	info, err := finalCalendar.Analyze()
	if err != nil {
		return fmt.Errorf("analyze recurrence exception: %w", err)
	}
	first := int64(0)
	if !info.FirstStart.IsZero() {
		first = info.FirstStart.Unix()
	}
	last := int64(0)
	if !info.LastEnd.IsZero() {
		last = info.LastEnd.Unix()
	}
	base := strings.TrimSuffix(task.VTODOHref, ".ics")
	if base == "" {
		base = hrefForUID(task.VTODOUID)
		base = strings.TrimSuffix(base, ".ics")
	}
	href := fmt.Sprintf("%s-rid-%s.ics", base, occurrence.UTC().Format("20060102T150405Z"))
	obj := &store.Object{
		CalendarID: cal.ID, Href: href, UID: task.VTODOUID,
		ETag: computeETag(data), ContentType: "text/calendar; charset=utf-8",
		Data: data, ComponentType: info.ComponentType,
		FirstStart: first, LastEnd: last, Recurring: false, Size: int64(len(data)),
	}
	_, _, _, err = s.store.PutObject(ctx, obj)
	return err
}

// ---------------------------------------------------------------- build

func hrefForUID(uid string) string {
	token := uid
	if i := strings.IndexByte(token, '@'); i >= 0 {
		token = token[:i]
	}
	token = strings.TrimSpace(strings.TrimSuffix(token, ".ics"))
	if token == "" {
		token = "task-" + auth.RandomToken(12)
	}
	return token + ".ics"
}

func newUID() string {
	return "task-" + auth.RandomToken(16) + "@caldav-free"
}

func computeETag(data []byte) string {
	sum := md5.Sum(data)
	return hex.EncodeToString(sum[:])
}

func calendarLocation(cal *store.Calendar) *time.Location {
	if cal != nil && cal.Timezone != "" {
		if loc, err := time.LoadLocation(cal.Timezone); err == nil {
			return loc
		}
	}
	return time.UTC
}

func priorityToICS(priority int) int {
	switch priority {
	case 3:
		return 1
	case 2:
		return 5
	case 1:
		return 9
	default:
		return 0
	}
}

func priorityFromICS(priority int) int {
	switch {
	case priority >= 1 && priority <= 4:
		return 3
	case priority == 5:
		return 2
	case priority >= 6 && priority <= 9:
		return 1
	default:
		return 0
	}
}

func buildVTODO(cal *store.Calendar, task *store.Task, listName string) []byte {
	root := ical.NewComponent("VCALENDAR")
	root.AddProp("VERSION", "2.0", nil)
	root.AddProp("PRODID", "-//caldav-free//Task Workspace//EN", nil)
	root.AddProp("CALSCALE", "GREGORIAN", nil)
	todo := ical.NewComponent("VTODO")
	todo.AddProp("UID", task.VTODOUID, nil)
	todo.AddProp("DTSTAMP", time.Now().UTC().Format("20060102T150405Z"), nil)
	if !task.CreatedAt.IsZero() {
		todo.AddProp("CREATED", task.CreatedAt.UTC().Format("20060102T150405Z"), nil)
	}
	if !task.ModifiedAt.IsZero() {
		todo.AddProp("LAST-MODIFIED", task.ModifiedAt.UTC().Format("20060102T150405Z"), nil)
	}
	todo.AddProp("SUMMARY", ical.EscapeText(strings.TrimSpace(task.Title)), nil)
	if strings.TrimSpace(task.Notes) != "" {
		todo.AddProp("DESCRIPTION", ical.EscapeText(task.Notes), nil)
	}
	loc := calendarLocation(cal)
	writeTaskTime := func(name string, value time.Time) {
		if task.AllDay {
			todo.AddProp(name, value.In(loc).Format("20060102"), ical.Params{"VALUE": {"DATE"}})
		} else {
			todo.AddProp(name, value.UTC().Format("20060102T150405Z"), nil)
		}
	}
	if task.StartAt != nil {
		writeTaskTime("DTSTART", *task.StartAt)
	} else if task.DueAt != nil && task.Recurrence != "" {
		// Recurring VTODOs still need a DTSTART when no explicit start exists.
		writeTaskTime("DTSTART", *task.DueAt)
	}
	if task.DueAt != nil {
		writeTaskTime("DUE", *task.DueAt)
	}
	if rule := strings.TrimSpace(strings.TrimPrefix(task.Recurrence, "RRULE:")); rule != "" {
		anchor := time.Time{}
		if task.RecurrenceAnchor != nil {
			anchor = *task.RecurrenceAnchor
		} else if task.DueAt != nil {
			anchor = *task.DueAt
		}
		if task.DueAt != nil {
			rule = taskparse.RecurrenceRuleForCurrent(rule, anchor, *task.DueAt)
		}
		todo.AddProp("RRULE", rule, nil)
	}
	if priority := priorityToICS(task.Priority); priority > 0 {
		todo.AddProp("PRIORITY", strconv.Itoa(priority), nil)
	}
	if task.Completed {
		todo.AddProp("STATUS", "COMPLETED", nil)
		todo.AddProp("PERCENT-COMPLETE", "100", nil)
		completed := task.CompletedAt
		if completed == nil {
			now := time.Now().UTC()
			completed = &now
		}
		todo.AddProp("COMPLETED", completed.UTC().Format("20060102T150405Z"), nil)
	} else {
		todo.AddProp("STATUS", "NEEDS-ACTION", nil)
		todo.AddProp("PERCENT-COMPLETE", "0", nil)
	}
	if len(task.Tags) > 0 {
		parts := make([]string, 0, len(task.Tags))
		for _, tag := range task.Tags {
			parts = append(parts, ical.EscapeText(tag))
		}
		todo.AddProp("CATEGORIES", strings.Join(parts, ","), nil)
	}
	if strings.TrimSpace(task.Checklist) != "" && json.Valid([]byte(task.Checklist)) {
		todo.AddProp("X-CALDDAV-CHECKLIST", ical.EscapeText(task.Checklist), nil)
	}
	if strings.TrimSpace(listName) != "" {
		todo.AddProp("X-CALDDAV-LIST", ical.EscapeText(listName), nil)
	}
	for _, offset := range task.ReminderValues() {
		alarm := ical.NewComponent("VALARM")
		alarm.AddProp("ACTION", "DISPLAY", nil)
		alarm.AddProp("DESCRIPTION", ical.EscapeText(strings.TrimSpace(task.Title)), nil)
		alarm.AddProp("TRIGGER", reminderTrigger(offset), nil)
		todo.AddChild(alarm)
	}
	root.AddChild(todo)
	return []byte(root.Encode())
}

// ---------------------------------------------------------------- push

func (s *Syncer) push(ctx context.Context, cal *store.Calendar, task *store.Task) error {
	if task.VTODOUID == "" {
		task.VTODOUID = newUID()
		if err := s.store.SetTaskSyncIdentity(ctx, task.UserID, task.ID, task.VTODOUID, hrefForUID(task.VTODOUID)); err != nil {
			return err
		}
	}
	if task.VTODOHref == "" {
		task.VTODOHref = hrefForUID(task.VTODOUID)
		if err := s.store.SetTaskSyncIdentity(ctx, task.UserID, task.ID, task.VTODOUID, task.VTODOHref); err != nil {
			return err
		}
	}
	list, err := s.store.GetTaskList(ctx, task.UserID, task.ListID)
	if err != nil && err != store.ErrNotFound {
		return err
	}
	listName := ""
	if list != nil {
		listName = list.Name
	}
	if task.ModifiedAt.IsZero() {
		task.ModifiedAt = time.Now().UTC()
	}
	data := buildVTODO(cal, task, listName)
	etag := computeETag(data)

	if existing, err := s.store.GetObject(ctx, cal.ID, task.VTODOHref); err == nil {
		if bytes.Equal(existing.Data, data) {
			if err := s.store.SetTaskSync(ctx, task.UserID, task.ID, task.VTODOUID, task.VTODOHref, existing.ETag); err != nil {
				return err
			}
			task.VTODOETag = existing.ETag
			task.SyncPending = false
			return nil
		}
	} else if err != store.ErrNotFound {
		return err
	}

	parsed, err := ical.Load(data, cal.Timezone)
	if err != nil {
		return fmt.Errorf("parse generated VTODO: %w", err)
	}
	info, err := parsed.Analyze()
	if err != nil {
		return fmt.Errorf("analyze generated VTODO: %w", err)
	}
	first := int64(0)
	if !info.FirstStart.IsZero() {
		first = info.FirstStart.Unix()
	}
	last := int64(0)
	if !info.LastEnd.IsZero() {
		last = info.LastEnd.Unix()
	}
	obj := &store.Object{
		CalendarID:    cal.ID,
		Href:          task.VTODOHref,
		UID:           task.VTODOUID,
		ETag:          etag,
		ContentType:   "text/calendar; charset=utf-8",
		Data:          data,
		ComponentType: info.ComponentType,
		FirstStart:    first,
		LastEnd:       last,
		Recurring:     info.Recurring,
		Size:          int64(len(data)),
	}
	if _, _, _, err := s.store.PutObject(ctx, obj); err != nil {
		return err
	}
	if err := s.store.SetTaskSync(ctx, task.UserID, task.ID, task.VTODOUID, task.VTODOHref, etag); err != nil {
		return err
	}
	task.VTODOETag = etag
	task.SyncPending = false
	return nil
}

// ---------------------------------------------------------------- import

type parsedVTODO struct {
	UID             string
	RecurrenceID    *time.Time
	Status          string
	Title           string
	Notes           string
	Priority        int
	Start           *time.Time
	Due             *time.Time
	AllDay          bool
	Recurrence      string
	ReminderOffsets []int
	Completed       bool
	CompletedAt     *time.Time
	CreatedAt       *time.Time
	Tags            []string
	Checklist       string
	ListName        string
}

func parseVTODO(cal *store.Calendar, obj *store.Object) (*parsedVTODO, error) {
	parsed, err := ical.Load(obj.Data, cal.Timezone)
	if err != nil {
		return nil, err
	}
	comp := parsed.Root.Child("VTODO")
	if comp == nil {
		return nil, fmt.Errorf("object %s has no VTODO component", obj.Href)
	}
	out := &parsedVTODO{
		UID:             strings.TrimSpace(comp.Value("UID")),
		Title:           strings.TrimSpace(ical.UnescapeText(comp.Value("SUMMARY"))),
		Notes:           ical.UnescapeText(comp.Value("DESCRIPTION")),
		Recurrence:      strings.TrimSpace(comp.Value("RRULE")),
		Status:          strings.ToLower(strings.TrimSpace(comp.Value("STATUS"))),
		ReminderOffsets: remindersFromVTODO(comp),
	}
	if out.UID == "" {
		out.UID = obj.UID
	}
	if out.Title == "" {
		out.Title = "未命名任务"
	}
	if p := comp.Get("PRIORITY"); p != nil {
		if value, err := strconv.Atoi(strings.TrimSpace(p.Value)); err == nil {
			out.Priority = priorityFromICS(value)
		}
	}
	var startValue *time.Time
	if p := comp.Get("DTSTART"); p != nil {
		if tv, err := parsed.ParseTimeProp(p); err == nil {
			start := tv.Time.UTC()
			startValue = &start
			out.AllDay = tv.Date
		}
	}
	if p := comp.Get("DUE"); p != nil {
		if tv, err := parsed.ParseTimeProp(p); err == nil {
			due := tv.Time.UTC()
			out.Due = &due
			out.AllDay = tv.Date
		}
	}
	if p := comp.Get("RECURRENCE-ID"); p != nil {
		if tv, err := parsed.ParseTimeProp(p); err == nil {
			recurrenceID := tv.Time.UTC()
			out.RecurrenceID = &recurrenceID
		}
	}
	if startValue != nil && (out.Due == nil || !startValue.Equal(*out.Due)) {
		out.Start = startValue
	}
	if strings.EqualFold(strings.TrimSpace(comp.Value("STATUS")), "COMPLETED") || comp.Value("COMPLETED") != "" {
		out.Completed = true
		if p := comp.Get("COMPLETED"); p != nil {
			if tv, err := parsed.ParseTimeProp(p); err == nil {
				completed := tv.Time.UTC()
				out.CompletedAt = &completed
			}
		}
		if out.CompletedAt == nil {
			if p := comp.Get("LAST-MODIFIED"); p != nil {
				if tv, err := parsed.ParseTimeProp(p); err == nil {
					completed := tv.Time.UTC()
					out.CompletedAt = &completed
				}
			}
		}
		if out.CompletedAt == nil {
			now := time.Now().UTC()
			out.CompletedAt = &now
		}
	}
	if p := comp.Get("CREATED"); p != nil {
		if tv, err := parsed.ParseTimeProp(p); err == nil {
			created := tv.Time.UTC()
			out.CreatedAt = &created
		}
	}
	for _, p := range comp.All("CATEGORIES") {
		for _, raw := range strings.Split(p.Value, ",") {
			tag := strings.TrimSpace(ical.UnescapeText(raw))
			if tag != "" {
				out.Tags = append(out.Tags, tag)
			}
		}
	}
	if value := comp.Value("X-CALDDAV-CHECKLIST"); value != "" {
		candidate := ical.UnescapeText(value)
		if json.Valid([]byte(candidate)) {
			out.Checklist = candidate
		}
	}
	out.ListName = strings.TrimSpace(ical.UnescapeText(comp.Value("X-CALDDAV-LIST")))
	return out, nil
}

func sanitizeTags(tags []string) store.StringList {
	seen := make(map[string]bool, len(tags))
	out := make([]string, 0, len(tags))
	for _, raw := range tags {
		tag := strings.TrimSpace(strings.ReplaceAll(raw, ",", ""))
		if tag == "" || seen[tag] {
			continue
		}
		seen[tag] = true
		out = append(out, tag)
		if len(out) >= 20 {
			break
		}
	}
	return store.StringList(out)
}

func isRecurrenceExceptionObject(obj *store.Object) bool {
	if obj == nil {
		return false
	}
	if strings.Contains(obj.Href, "-rid-") {
		return true
	}
	return strings.Contains(strings.ToUpper(string(obj.Data)), "RECURRENCE-ID")
}

func sameTaskOccurrence(left, right time.Time) bool {
	return left.UTC().Unix() == right.UTC().Unix()
}

func (s *Syncer) nextOpenOccurrence(ctx context.Context, task *store.Task, after time.Time) (time.Time, bool) {
	if task == nil || task.Recurrence == "" {
		return time.Time{}, false
	}
	anchor := after
	if task.RecurrenceAnchor != nil {
		anchor = *task.RecurrenceAnchor
	}
	current := after
	for index := 0; index < 1000; index++ {
		next, ok := taskparse.NextOccurrenceAfter(task.Recurrence, anchor, current)
		if !ok {
			return time.Time{}, false
		}
		instance, err := s.store.GetRecurrenceInstance(ctx, task.UserID, task.ID, next)
		if err != nil || instance == nil {
			return next, true
		}
		current = next
	}
	return time.Time{}, false
}

func (s *Syncer) importRecurrenceException(ctx context.Context, cal *store.Calendar, userID int64, obj *store.Object) error {
	parsed, err := parseVTODO(cal, obj)
	if err != nil {
		return err
	}
	if parsed.RecurrenceID == nil || parsed.UID == "" {
		return nil
	}
	task, err := s.store.GetTaskByVTODOUID(ctx, userID, parsed.UID)
	if err != nil || task == nil {
		return nil
	}
	status := ""
	postponedTo := parsed.Due
	switch {
	case parsed.Completed || parsed.Status == "completed":
		status = "completed"
	case parsed.Status == "cancelled":
		status = "skipped"
		postponedTo = nil
	case parsed.Due != nil && !sameTaskOccurrence(*parsed.Due, *parsed.RecurrenceID):
		status = "postponed"
	default:
		return nil
	}
	if status == "completed" && postponedTo != nil && sameTaskOccurrence(*postponedTo, *parsed.RecurrenceID) {
		postponedTo = nil
	}
	if err := s.store.RecordRecurrenceInstance(ctx, &store.TaskRecurrenceInstance{
		UserID: task.UserID, TaskID: task.ID, OccurrenceAt: parsed.RecurrenceID.UTC(),
		Status: status, PostponedTo: postponedTo, Title: task.Title,
	}); err != nil {
		return err
	}
	if task.Recurrence == "" || task.DueAt == nil || !sameTaskOccurrence(*task.DueAt, *parsed.RecurrenceID) {
		return nil
	}
	if next, ok := s.nextOpenOccurrence(ctx, task, *task.DueAt); ok {
		task.DueAt = &next
		task.Completed = false
		task.CompletedAt = nil
	} else if status == "postponed" && postponedTo != nil {
		task.DueAt = postponedTo
		task.Completed = false
		task.CompletedAt = nil
	} else {
		now := time.Now().UTC()
		task.Completed = true
		task.CompletedAt = &now
	}
	task.SyncPending = true
	if err := s.store.UpdateTask(ctx, task); err != nil {
		return err
	}
	return s.push(ctx, cal, task)
}

func (s *Syncer) importNew(ctx context.Context, cal *store.Calendar, obj *store.Object, listByName map[string]*store.TaskList, inbox *store.TaskList) error {
	parsed, err := parseVTODO(cal, obj)
	if err != nil {
		return err
	}
	list := inbox
	if parsed.ListName != "" {
		if found, ok := listByName[parsed.ListName]; ok {
			list = found
		}
	}
	task := &store.Task{
		UserID:      inbox.UserID,
		ListID:      list.ID,
		Title:       parsed.Title,
		Notes:       parsed.Notes,
		Kind:        "TASK",
		Priority:    parsed.Priority,
		StartAt:     parsed.Start,
		DueAt:       parsed.Due,
		AllDay:      parsed.AllDay,
		Completed:   parsed.Completed,
		CompletedAt: parsed.CompletedAt,
		Tags:        sanitizeTags(parsed.Tags),
		Checklist:   parsed.Checklist,
		Recurrence:  parsed.Recurrence,
		VTODOUID:    parsed.UID,
		VTODOHref:   obj.Href,
		VTODOETag:   obj.ETag,
	}
	task.SetReminderValues(parsed.ReminderOffsets)
	if parsed.CreatedAt != nil {
		task.CreatedAt = *parsed.CreatedAt
	}
	created, err := s.store.CreateTask(ctx, task)
	if err != nil {
		return err
	}
	return s.store.SetTaskSync(ctx, created.UserID, created.ID, parsed.UID, obj.Href, obj.ETag)
}

func (s *Syncer) importInto(ctx context.Context, cal *store.Calendar, task *store.Task, obj *store.Object) error {
	parsed, err := parseVTODO(cal, obj)
	if err != nil {
		return err
	}
	previousDue := task.DueAt
	task.Title = parsed.Title
	task.Notes = parsed.Notes
	task.Priority = parsed.Priority
	task.StartAt = parsed.Start
	task.DueAt = parsed.Due
	task.AllDay = parsed.AllDay
	task.Completed = parsed.Completed
	task.CompletedAt = parsed.CompletedAt
	task.Tags = sanitizeTags(parsed.Tags)
	task.Checklist = parsed.Checklist
	task.Recurrence = parsed.Recurrence
	if task.Recurrence != "" && (previousDue == nil || parsed.Due == nil || !sameTaskOccurrence(*previousDue, *parsed.Due)) {
		task.RecurrenceAnchor = parsed.Due
	}
	task.SetReminderValues(parsed.ReminderOffsets)
	task.VTODOUID = parsed.UID
	task.VTODOHref = obj.Href
	if err := s.store.UpdateTask(ctx, task); err != nil {
		return err
	}
	return s.store.SetTaskSync(ctx, task.UserID, task.ID, task.VTODOUID, task.VTODOHref, obj.ETag)
}

func reminderTrigger(minutes int) string {
	if minutes <= 0 {
		return "PT0M"
	}
	if minutes%1440 == 0 {
		return fmt.Sprintf("-P%dD", minutes/1440)
	}
	if minutes%60 == 0 {
		return fmt.Sprintf("-PT%dH", minutes/60)
	}
	return fmt.Sprintf("-PT%dM", minutes)
}

func remindersFromVTODO(comp *ical.Component) []int {
	alarms := comp.ChildrenNamed("VALARM")
	offsets := make([]int, 0, len(alarms))
	for _, alarm := range alarms {
		raw := strings.TrimSpace(alarm.Value("TRIGGER"))
		if raw == "" {
			continue
		}
		negative := strings.HasPrefix(raw, "-")
		raw = strings.TrimPrefix(raw, "-")
		if raw == "" || (raw[0] >= '0' && raw[0] <= '9') {
			// Absolute DATE-TIME triggers are not represented by our relative model.
			continue
		}
		duration, err := ical.ParseDuration(raw)
		if err != nil {
			continue
		}
		if duration < 0 {
			duration = -duration
		}
		minutes := int(duration.Minutes())
		if minutes < 0 || (!negative && minutes > 0) {
			continue
		}
		if minutes > 10080 {
			minutes = 10080
		}
		offsets = append(offsets, minutes)
	}
	normalized, _ := store.NormalizeReminderOffsets(offsets)
	return normalized
}
