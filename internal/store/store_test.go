package store

import (
	"context"
	"errors"
	"testing"
	"time"

	"caldav-free/internal/auth"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	s, err := Open(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { s.Close() })
	return s
}

func TestUserLifecycle(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	hash, err := auth.HashPassword("password123")
	if err != nil {
		t.Fatal(err)
	}
	u, err := s.CreateUser(ctx, "Alice", "Alice A", "alice@example.com", hash, true)
	if err != nil {
		t.Fatal(err)
	}
	if u.Username != "alice" {
		t.Fatalf("username not normalized: %q", u.Username)
	}
	if _, err := s.CreateUser(ctx, "alice", "Other", "", hash, false); !errors.Is(err, ErrConflict) {
		t.Fatalf("expected conflict, got %v", err)
	}
	byName, err := s.GetUserByUsername(ctx, "ALICE")
	if err != nil || byName.ID != u.ID {
		t.Fatalf("case-insensitive lookup failed: %v", err)
	}
	users, err := s.ListUsers(ctx)
	if err != nil || len(users) != 1 {
		t.Fatalf("list users: %v %d", err, len(users))
	}
	if err := s.UpdateUser(ctx, u.ID, "Alice B", "a@b.c", true, ""); err != nil {
		t.Fatal(err)
	}
	updated, _ := s.GetUser(ctx, u.ID)
	if updated.DisplayName != "Alice B" || updated.Email != "a@b.c" || updated.PasswordHash != hash {
		t.Fatalf("unexpected update: %+v", updated)
	}
	newHash, _ := auth.HashPassword("newpassword")
	if err := s.UpdateUser(ctx, u.ID, "Alice B", "a@b.c", false, newHash); err != nil {
		t.Fatal(err)
	}
	updated, _ = s.GetUser(ctx, u.ID)
	if updated.IsAdmin || updated.PasswordHash != newHash {
		t.Fatalf("password/admin update failed: %+v", updated)
	}
	if err := s.DeleteUser(ctx, u.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetUser(ctx, u.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("expected not found, got %v", err)
	}
}

func TestDefaultCalendarTimezone(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	hash, _ := auth.HashPassword("password123")
	u, err := s.CreateUser(ctx, "alice", "", "", hash, false)
	if err != nil {
		t.Fatal(err)
	}
	cal, err := s.CreateCalendar(ctx, u.ID, "work", "Work", "", "", "", 0, nil)
	if err != nil {
		t.Fatal(err)
	}
	if cal.Timezone != DefaultTimezone {
		t.Fatalf("default timezone = %q, want %q", cal.Timezone, DefaultTimezone)
	}
	if err := s.UpdateCalendar(ctx, cal.ID, "Work", "", "", "", 0, nil); err != nil {
		t.Fatal(err)
	}
	updated, err := s.GetCalendar(ctx, cal.ID)
	if err != nil {
		t.Fatal(err)
	}
	if updated.Timezone != DefaultTimezone {
		t.Fatalf("updated default timezone = %q, want %q", updated.Timezone, DefaultTimezone)
	}
}

func TestCalendarAndObjectLifecycle(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	hash, _ := auth.HashPassword("password123")
	u, err := s.CreateUser(ctx, "alice", "", "", hash, false)
	if err != nil {
		t.Fatal(err)
	}
	cal, err := s.CreateCalendar(ctx, u.ID, "work", "Work", "desc", "#3366CC", "Asia/Shanghai", 2, []string{"VEVENT"})
	if err != nil {
		t.Fatal(err)
	}
	if len(cal.Components) != 1 || cal.Components[0] != "VEVENT" {
		t.Fatalf("components = %#v", cal.Components)
	}
	if !cal.SupportsComponent("VEVENT") || cal.SupportsComponent("VTODO") {
		t.Fatal("component support wrong")
	}
	if _, err := s.CreateCalendar(ctx, u.ID, "work", "", "", "", "", 0, nil); !errors.Is(err, ErrConflict) {
		t.Fatalf("expected duplicate conflict, got %v", err)
	}

	start := time.Date(2026, 10, 21, 9, 0, 0, 0, time.UTC)
	obj := &Object{
		CalendarID:    cal.ID,
		Href:          "a.ics",
		UID:           "uid-a",
		ETag:          "etag-a",
		ContentType:   "text/calendar; charset=utf-8",
		Data:          []byte("BEGIN:VCALENDAR\nEND:VCALENDAR\n"),
		ComponentType: "VEVENT",
		FirstStart:    start.Unix(),
		LastEnd:       start.Add(time.Hour).Unix(),
		Size:          37,
	}
	seq, created, prev, err := s.PutObject(ctx, obj)
	if err != nil || !created || prev != nil || seq != 1 {
		t.Fatalf("put: seq=%d created=%v prev=%v err=%v", seq, created, prev, err)
	}
	got, err := s.GetObject(ctx, cal.ID, "a.ics")
	if err != nil || got.UID != "uid-a" {
		t.Fatalf("get object: %v", err)
	}
	if byUID, err := s.GetObjectByUID(ctx, cal.ID, "uid-a"); err != nil || byUID.Href != "a.ics" {
		t.Fatalf("get by uid: %v", err)
	}
	list, _ := s.ListObjects(ctx, cal.ID)
	if len(list) != 1 {
		t.Fatalf("list objects = %d", len(list))
	}
	count, _ := s.CountObjects(ctx, cal.ID)
	if count != 1 {
		t.Fatalf("count = %d", count)
	}

	// Update in place.
	obj.ETag = "etag-b"
	obj.Data = []byte("BEGIN:VCALENDAR\nEND:VCALENDAR\n")
	seq, created, prev, err = s.PutObject(ctx, obj)
	if err != nil || created || prev == nil || seq != 2 {
		t.Fatalf("update: seq=%d created=%v prev=%v err=%v", seq, created, prev, err)
	}
	if prev.ETag != "etag-a" {
		t.Fatalf("previous etag = %q", prev.ETag)
	}

	// A second object, then delete it.
	second := &Object{
		CalendarID: cal.ID, Href: "b.ics", UID: "uid-b", ETag: "etag-c",
		ContentType: "text/calendar", Data: []byte("x"), ComponentType: "VEVENT",
		FirstStart: start.Add(2 * time.Hour).Unix(), LastEnd: start.Add(3 * time.Hour).Unix(), Size: 1,
	}
	if _, _, _, err := s.PutObject(ctx, second); err != nil {
		t.Fatal(err)
	}
	seq, removed, err := s.DeleteObject(ctx, cal.ID, "b.ics")
	if err != nil || !removed || seq != 4 {
		t.Fatalf("delete: seq=%d removed=%v err=%v", seq, removed, err)
	}
	if _, err := s.GetObject(ctx, cal.ID, "b.ics"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("deleted object still visible: %v", err)
	}

	changes, err := s.ChangesSince(ctx, cal.ID, 0)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes) != 2 {
		t.Fatalf("changes = %+v", changes)
	}
	byHref := map[string]Change{}
	for _, c := range changes {
		byHref[c.Href] = c
	}
	if byHref["a.ics"].Op != "put" || byHref["a.ics"].Seq != 2 {
		t.Fatalf("a.ics change = %+v", byHref["a.ics"])
	}
	if byHref["b.ics"].Op != "delete" || byHref["b.ics"].Seq != 4 {
		t.Fatalf("b.ics change = %+v", byHref["b.ics"])
	}

	// Range pre-filter includes non-recurring overlap and excludes others.
	rangeObjs, err := s.ObjectRange(ctx, cal.ID, start.Add(-time.Hour), start.Add(30*time.Minute))
	if err != nil || len(rangeObjs) != 1 {
		t.Fatalf("range = %d err=%v", len(rangeObjs), err)
	}
	rangeObjs, _ = s.ObjectRange(ctx, cal.ID, start.Add(10*time.Hour), start.Add(11*time.Hour))
	if len(rangeObjs) != 0 {
		t.Fatalf("range should be empty: %+v", rangeObjs)
	}

	// Recurring objects are always candidates.
	rec := &Object{
		CalendarID: cal.ID, Href: "c.ics", UID: "uid-c", ETag: "etag-d",
		ContentType: "text/calendar", Data: []byte("x"), ComponentType: "VEVENT",
		FirstStart: start.Unix(), LastEnd: 0, Recurring: true, Size: 1,
	}
	if _, _, _, err := s.PutObject(ctx, rec); err != nil {
		t.Fatal(err)
	}
	rangeObjs, _ = s.ObjectRange(ctx, cal.ID, start.Add(100*24*time.Hour), start.Add(101*24*time.Hour))
	if len(rangeObjs) != 1 || rangeObjs[0].Href != "c.ics" {
		t.Fatalf("recurring not returned: %+v", rangeObjs)
	}

	if err := s.DeleteCalendar(ctx, cal.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetCalendar(ctx, cal.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("calendar still exists: %v", err)
	}
	if _, err := s.GetObject(ctx, cal.ID, "a.ics"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("object survived calendar delete: %v", err)
	}
	if changes, _ := s.ChangesSince(ctx, cal.ID, 0); len(changes) != 0 {
		t.Fatalf("sync journal survived: %+v", changes)
	}
}

func TestSettingsAndListing(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if v, err := s.GetSetting(ctx, "missing"); err != nil || v != "" {
		t.Fatalf("missing setting = %q err=%v", v, err)
	}
	if err := s.SetSetting(ctx, "session_secret", "abc"); err != nil {
		t.Fatal(err)
	}
	if err := s.SetSetting(ctx, "session_secret", "def"); err != nil {
		t.Fatal(err)
	}
	if v, _ := s.GetSetting(ctx, "session_secret"); v != "def" {
		t.Fatalf("setting = %q", v)
	}

	hash, _ := auth.HashPassword("password123")
	u, _ := s.CreateUser(ctx, "alice", "", "", hash, false)
	for i, slug := range []string{"zebra", "alpha"} {
		if _, err := s.CreateCalendar(ctx, u.ID, slug, slug, "", "", "UTC", i, nil); err != nil {
			t.Fatal(err)
		}
	}
	cals, err := s.ListCalendars(ctx, u.ID)
	if err != nil || len(cals) != 2 {
		t.Fatalf("list calendars: %v %d", err, len(cals))
	}
	if cals[0].Slug != "zebra" {
		t.Fatalf("order wrong: %s, %s", cals[0].Slug, cals[1].Slug)
	}
	if n, _ := s.CountCalendars(ctx, u.ID); n != 2 {
		t.Fatalf("count calendars = %d", n)
	}
	if n, _ := s.CountUsers(ctx); n != 1 {
		t.Fatalf("count users = %d", n)
	}
}
