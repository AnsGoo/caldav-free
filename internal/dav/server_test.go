package dav

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"testing"

	"caldav-free/internal/auth"
	"caldav-free/internal/store"
)

type testEnv struct {
	server *httptest.Server
	store  *store.Store
	user   *store.User
	pass   string
}

func newTestEnv(t *testing.T) *testEnv {
	t.Helper()
	st, err := store.Open(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	password := "secret123"
	hash, err := auth.HashPassword(password)
	if err != nil {
		t.Fatal(err)
	}
	u, err := st.CreateUser(context.Background(), "alice", "Alice", "alice@example.com", hash, false)
	if err != nil {
		t.Fatal(err)
	}
	h := New(st, nil)
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	return &testEnv{server: srv, store: st, user: u, pass: password}
}

func (e *testEnv) request(t *testing.T, method, path, body string, headers map[string]string) *http.Response {
	t.Helper()
	var reader io.Reader
	if body != "" {
		reader = strings.NewReader(body)
	}
	req, err := http.NewRequest(method, e.server.URL+path, reader)
	if err != nil {
		t.Fatal(err)
	}
	req.SetBasicAuth("alice", e.pass)
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	return resp
}

func readAll(t *testing.T, resp *http.Response) string {
	t.Helper()
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

const eventOne = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//test//EN
BEGIN:VEVENT
UID:event-one@example.com
DTSTAMP:20261001T000000Z
DTSTART;TZID=Asia/Shanghai:20261021T090000
DTEND;TZID=Asia/Shanghai:20261021T100000
SUMMARY:Team Meeting
END:VEVENT
END:VCALENDAR
`

const eventTwo = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//test//EN
BEGIN:VEVENT
UID:event-two@example.com
DTSTAMP:20261001T000000Z
DTSTART;TZID=Asia/Shanghai:20261022T140000
DTEND;TZID=Asia/Shanghai:20261022T150000
SUMMARY:Design Review
END:VEVENT
END:VCALENDAR
`

func TestDiscoveryAndCalendarLifecycle(t *testing.T) {
	env := newTestEnv(t)

	resp := env.request(t, "OPTIONS", "/", "", nil)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("OPTIONS status = %d", resp.StatusCode)
	}
	if dav := resp.Header.Get("DAV"); !strings.Contains(dav, "calendar-access") {
		t.Fatalf("DAV header = %q", dav)
	}
	resp.Body.Close()

	// Unauthenticated requests are rejected.
	req, _ := http.NewRequest("PROPFIND", env.server.URL+"/", nil)
	req.Header.Set("Depth", "0")
	unauth, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	if unauth.StatusCode != http.StatusUnauthorized {
		t.Fatalf("unauthenticated status = %d", unauth.StatusCode)
	}
	unauth.Body.Close()

	body := readAll(t, env.request(t, "PROPFIND", "/", "", map[string]string{"Depth": "0"}))
	if !strings.Contains(body, "current-user-principal") || !strings.Contains(body, "/principals/alice/") {
		t.Fatalf("root PROPFIND missing principal: %s", body)
	}

	body = readAll(t, env.request(t, "PROPFIND", "/principals/alice/", "", map[string]string{"Depth": "0"}))
	if !strings.Contains(body, "calendar-home-set") || !strings.Contains(body, "/calendars/alice/") {
		t.Fatalf("principal PROPFIND missing home: %s", body)
	}

	// propname returns names without values.
	propname := `<D:propfind xmlns:D="DAV:"><D:propname/></D:propfind>`
	body = readAll(t, env.request(t, "PROPFIND", "/", propname, map[string]string{"Depth": "0"}))
	if !strings.Contains(body, "current-user-principal") || strings.Contains(body, "caldav-free</displayname>") {
		t.Fatalf("propname response wrong: %s", body)
	}

	mk := `<C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
	  <D:set><D:prop>
	    <D:displayname>Work</D:displayname>
	    <C:calendar-description>Work calendar</C:calendar-description>
	    <A:calendar-color xmlns:A="http://apple.com/ns/ical/">#3366CC</A:calendar-color>
	  </D:prop></D:set>
	</C:mkcalendar>`
	resp = env.request(t, "MKCALENDAR", "/calendars/alice/work/", mk, map[string]string{"Content-Type": "application/xml"})
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("MKCALENDAR status = %d: %s", resp.StatusCode, readAll(t, resp))
	}
	resp.Body.Close()

	resp = env.request(t, "PUT", "/calendars/alice/work/event1.ics", eventOne, map[string]string{"Content-Type": "text/calendar"})
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("PUT status = %d: %s", resp.StatusCode, readAll(t, resp))
	}
	etagOne := resp.Header.Get("ETag")
	if etagOne == "" {
		t.Fatal("PUT response has no ETag")
	}
	resp.Body.Close()

	resp = env.request(t, "GET", "/calendars/alice/work/event1.ics", "", nil)
	got := readAll(t, resp)
	if resp.StatusCode != http.StatusOK || !strings.Contains(got, "UID:event-one@example.com") {
		t.Fatalf("GET status = %d body=%s", resp.StatusCode, got)
	}
	if resp.Header.Get("ETag") != etagOne {
		t.Fatalf("GET etag mismatch: %q vs %q", resp.Header.Get("ETag"), etagOne)
	}

	// Conditional update with a stale ETag must fail.
	resp = env.request(t, "PUT", "/calendars/alice/work/event1.ics", eventOne,
		map[string]string{"Content-Type": "text/calendar", "If-Match": `"deadbeef"`})
	if resp.StatusCode != http.StatusPreconditionFailed {
		t.Fatalf("stale PUT status = %d", resp.StatusCode)
	}
	resp.Body.Close()

	// Invalid calendar data is rejected.
	resp = env.request(t, "PUT", "/calendars/alice/work/bad.ics", "not a calendar",
		map[string]string{"Content-Type": "text/calendar"})
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("invalid PUT status = %d", resp.StatusCode)
	}
	resp.Body.Close()

	// Duplicate UID in another object is rejected.
	resp = env.request(t, "PUT", "/calendars/alice/work/dup.ics", eventOne,
		map[string]string{"Content-Type": "text/calendar"})
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("duplicate UID PUT status = %d: %s", resp.StatusCode, readAll(t, resp))
	}
	resp.Body.Close()

	// Home listing.
	body = readAll(t, env.request(t, "PROPFIND", "/calendars/alice/", "", map[string]string{"Depth": "1"}))
	if !strings.Contains(body, "/calendars/alice/work/") || !strings.Contains(body, "calendar") {
		t.Fatalf("home PROPFIND missing calendar: %s", body)
	}

	// Collection listing includes the object.
	body = readAll(t, env.request(t, "PROPFIND", "/calendars/alice/work/", "", map[string]string{"Depth": "1"}))
	if !strings.Contains(body, "event1.ics") || !strings.Contains(body, strings.Trim(etagOne, `"`)) {
		t.Fatalf("calendar PROPFIND missing object: %s", body)
	}

	// GET on the collection returns an aggregated calendar.
	resp = env.request(t, "GET", "/calendars/alice/work/", "", nil)
	agg := readAll(t, resp)
	if resp.StatusCode != http.StatusOK || !strings.Contains(agg, "event-one@example.com") {
		t.Fatalf("aggregate GET status = %d body=%s", resp.StatusCode, agg)
	}
}

func TestReportsAndSync(t *testing.T) {
	env := newTestEnv(t)
	resp := env.request(t, "MKCALENDAR", "/calendars/alice/work/", "", nil)
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("MKCALENDAR = %d", resp.StatusCode)
	}
	resp.Body.Close()

	put := func(name, data string) string {
		t.Helper()
		r := env.request(t, "PUT", "/calendars/alice/work/"+name, data, map[string]string{"Content-Type": "text/calendar"})
		if r.StatusCode != http.StatusCreated && r.StatusCode != http.StatusNoContent {
			t.Fatalf("PUT %s = %d: %s", name, r.StatusCode, readAll(t, r))
		}
		tag := r.Header.Get("ETag")
		r.Body.Close()
		return tag
	}
	put("event1.ics", eventOne)

	query := `<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
	  <D:prop><D:getetag/><C:calendar-data/></D:prop>
	  <C:filter><C:comp-filter name="VCALENDAR"><C:comp-filter name="VEVENT">
	    <C:time-range start="20261021T000000Z" end="20261022T000000Z"/>
	  </C:comp-filter></C:comp-filter></C:filter>
	</C:calendar-query>`
	body := readAll(t, env.request(t, "REPORT", "/calendars/alice/work/", query, map[string]string{"Depth": "1"}))
	if !strings.Contains(body, "event-one@example.com") || !strings.Contains(body, "calendar-data") {
		t.Fatalf("calendar-query missing event: %s", body)
	}

	outside := strings.ReplaceAll(query, "20261021T000000Z", "20261025T000000Z")
	outside = strings.ReplaceAll(outside, "20261022T000000Z", "20261026T000000Z")
	body = readAll(t, env.request(t, "REPORT", "/calendars/alice/work/", outside, map[string]string{"Depth": "1"}))
	if strings.Contains(body, "event-one@example.com") {
		t.Fatalf("calendar-query returned event outside range: %s", body)
	}

	multiget := `<C:calendar-multiget xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
	  <D:prop><D:getetag/><C:calendar-data/></D:prop>
	  <D:href>/calendars/alice/work/event1.ics</D:href>
	  <D:href>/calendars/alice/work/missing.ics</D:href>
	</C:calendar-multiget>`
	body = readAll(t, env.request(t, "REPORT", "/calendars/alice/work/", multiget, map[string]string{"Depth": "1"}))
	if !strings.Contains(body, "event-one@example.com") || !strings.Contains(body, "404 Not Found") {
		t.Fatalf("multiget response wrong: %s", body)
	}

	syncInitial := `<D:sync-collection xmlns:D="DAV:"><D:sync-token/><D:sync-level>1</D:sync-level>
	  <D:prop><D:getetag/></D:prop></D:sync-collection>`
	body = readAll(t, env.request(t, "REPORT", "/calendars/alice/work/", syncInitial, map[string]string{"Depth": "1"}))
	token := extractTag(body, "sync-token")
	if token == "" || !strings.Contains(body, "event1.ics") {
		t.Fatalf("initial sync missing token/object: %s", body)
	}

	put("event2.ics", eventTwo)
	syncIncremental := fmt.Sprintf(`<D:sync-collection xmlns:D="DAV:"><D:sync-token>%s</D:sync-token>
	  <D:sync-level>1</D:sync-level><D:prop><D:getetag/></D:prop></D:sync-collection>`, token)
	body = readAll(t, env.request(t, "REPORT", "/calendars/alice/work/", syncIncremental, map[string]string{"Depth": "1"}))
	token2 := extractTag(body, "sync-token")
	if !strings.Contains(body, "event2.ics") || strings.Contains(body, "event1.ics") {
		t.Fatalf("incremental sync wrong: %s", body)
	}
	if token2 == "" || token2 == token {
		t.Fatalf("sync token did not advance: %q -> %q", token, token2)
	}

	resp = env.request(t, "DELETE", "/calendars/alice/work/event2.ics", "", nil)
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("DELETE = %d", resp.StatusCode)
	}
	resp.Body.Close()

	syncIncremental = fmt.Sprintf(`<D:sync-collection xmlns:D="DAV:"><D:sync-token>%s</D:sync-token>
	  <D:sync-level>1</D:sync-level><D:prop><D:getetag/></D:prop></D:sync-collection>`, token2)
	body = readAll(t, env.request(t, "REPORT", "/calendars/alice/work/", syncIncremental, map[string]string{"Depth": "1"}))
	if !strings.Contains(body, "event2.ics") || !strings.Contains(body, "404 Not Found") {
		t.Fatalf("delete sync wrong: %s", body)
	}

	syncBad := `<D:sync-collection xmlns:D="DAV:"><D:sync-token>http://caldav-free/sync/1/99999</D:sync-token>
	  <D:sync-level>1</D:sync-level><D:prop><D:getetag/></D:prop></D:sync-collection>`
	resp = env.request(t, "REPORT", "/calendars/alice/work/", syncBad, map[string]string{"Depth": "1"})
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("invalid sync token status = %d", resp.StatusCode)
	}
	resp.Body.Close()

	freeBusy := `<C:free-busy-query xmlns:C="urn:ietf:params:xml:ns:caldav">
	  <C:time-range start="20261021T000000Z" end="20261022T000000Z"/>
	</C:free-busy-query>`
	resp = env.request(t, "REPORT", "/calendars/alice/work/", freeBusy, map[string]string{"Depth": "1"})
	fb := readAll(t, resp)
	if resp.StatusCode != http.StatusOK || !strings.Contains(fb, "VFREEBUSY") || !strings.Contains(fb, "FREEBUSY") {
		t.Fatalf("free-busy status = %d body=%s", resp.StatusCode, fb)
	}
}

func TestProppatchAndDeleteCalendar(t *testing.T) {
	env := newTestEnv(t)
	resp := env.request(t, "MKCALENDAR", "/calendars/alice/work/", "", nil)
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("MKCALENDAR = %d", resp.StatusCode)
	}
	resp.Body.Close()

	update := `<D:propertyupdate xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:A="http://apple.com/ns/ical/">
	  <D:set><D:prop>
	    <D:displayname>Renamed</D:displayname>
	    <C:calendar-description>Updated</C:calendar-description>
	    <A:calendar-color>#FF0000</A:calendar-color>
	    <A:calendar-order>7</A:calendar-order>
	  </D:prop></D:set>
	</D:propertyupdate>`
	body := readAll(t, env.request(t, "PROPPATCH", "/calendars/alice/work/", update, map[string]string{"Content-Type": "application/xml"}))
	if !strings.Contains(body, "200 OK") {
		t.Fatalf("PROPPATCH failed: %s", body)
	}

	body = readAll(t, env.request(t, "PROPFIND", "/calendars/alice/work/", "", map[string]string{"Depth": "0"}))
	if !strings.Contains(body, "Renamed") || !strings.Contains(body, "#FF0000") || !strings.Contains(body, ">7<") {
		t.Fatalf("PROPPATCH not persisted: %s", body)
	}

	// Protected properties must not be modified.
	bad := `<D:propertyupdate xmlns:D="DAV:"><D:set><D:prop><D:getetag>x</D:getetag></D:prop></D:set></D:propertyupdate>`
	resp = env.request(t, "PROPPATCH", "/calendars/alice/work/", bad, map[string]string{"Content-Type": "application/xml"})
	body = readAll(t, resp)
	if resp.StatusCode != http.StatusMultiStatus || !strings.Contains(body, "403 Forbidden") {
		t.Fatalf("protected PROPPATCH = %d %s", resp.StatusCode, body)
	}

	resp = env.request(t, "DELETE", "/calendars/alice/work/", "", nil)
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("DELETE calendar = %d", resp.StatusCode)
	}
	resp.Body.Close()
	body = readAll(t, env.request(t, "PROPFIND", "/calendars/alice/", "", map[string]string{"Depth": "1"}))
	if strings.Contains(body, "/calendars/alice/work/") {
		t.Fatalf("calendar still listed: %s", body)
	}
}

func TestCalendarQueryRecurring(t *testing.T) {
	env := newTestEnv(t)
	resp := env.request(t, "MKCALENDAR", "/calendars/alice/work/", "", nil)
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("MKCALENDAR = %d", resp.StatusCode)
	}
	resp.Body.Close()
	recurring := `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:weekly@example.com
DTSTAMP:20261001T000000Z
DTSTART;TZID=Europe/Paris:20261005T090000
DTEND;TZID=Europe/Paris:20261005T100000
RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=8
SUMMARY:Weekly
END:VEVENT
END:VCALENDAR
`
	req := env.request(t, "PUT", "/calendars/alice/work/weekly.ics", recurring, map[string]string{"Content-Type": "text/calendar"})
	if req.StatusCode != http.StatusCreated {
		t.Fatalf("PUT recurring = %d: %s", req.StatusCode, readAll(t, req))
	}
	req.Body.Close()

	query := `<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
	  <D:prop><C:calendar-data><C:expand start="20261019T000000Z" end="20261027T000000Z"/></C:calendar-data></D:prop>
	  <C:filter><C:comp-filter name="VCALENDAR"><C:comp-filter name="VEVENT">
	    <C:time-range start="20261019T000000Z" end="20261027T000000Z"/>
	  </C:comp-filter></C:comp-filter></C:filter>
	</C:calendar-query>`
	body := readAll(t, env.request(t, "REPORT", "/calendars/alice/work/", query, map[string]string{"Depth": "1"}))
	if !strings.Contains(body, "weekly@example.com") {
		t.Fatalf("recurring query missing: %s", body)
	}
	if strings.Contains(body, "RRULE") {
		t.Fatalf("expand did not remove RRULE: %s", body)
	}
	if !strings.Contains(body, "RECURRENCE-ID") {
		t.Fatalf("expand missing RECURRENCE-ID: %s", body)
	}
}

func TestMkcalendarPropertiesAndExtendedMKCOL(t *testing.T) {
	env := newTestEnv(t)
	timezone := `BEGIN:VTIMEZONE
TZID:Asia/Shanghai
BEGIN:STANDARD
DTSTART:19700101T000000
TZOFFSETFROM:+0800
TZOFFSETTO:+0800
TZNAME:CST
END:STANDARD
END:VTIMEZONE`
	body := fmt.Sprintf(`<C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
	  <D:set><D:prop>
	    <D:displayname>China</D:displayname>
	    <C:calendar-timezone>%s</C:calendar-timezone>
	    <C:supported-calendar-component-set><C:comp name="VEVENT"/></C:supported-calendar-component-set>
	  </D:prop></D:set>
	</C:mkcalendar>`, timezone)
	resp := env.request(t, "MKCALENDAR", "/calendars/alice/china/", body, map[string]string{"Content-Type": "application/xml"})
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("MKCALENDAR = %d: %s", resp.StatusCode, readAll(t, resp))
	}
	resp.Body.Close()
	body = readAll(t, env.request(t, "PROPFIND", "/calendars/alice/china/", "", map[string]string{"Depth": "0"}))
	if !strings.Contains(body, "Asia/Shanghai") || !strings.Contains(body, `name="VEVENT"`) {
		t.Fatalf("properties missing: %s", body)
	}

	// VTODO is not supported by this calendar.
	todo := `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VTODO
UID:todo1
DTSTAMP:20261001T000000Z
SUMMARY:Buy milk
END:VTODO
END:VCALENDAR
`
	resp = env.request(t, "PUT", "/calendars/alice/china/todo.ics", todo, map[string]string{"Content-Type": "text/calendar"})
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("unsupported component PUT = %d: %s", resp.StatusCode, readAll(t, resp))
	}
	resp.Body.Close()

	// Extended MKCOL creates a calendar collection.
	mkcol := `<D:mkcol xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
	  <D:set><D:prop>
	    <D:resourcetype><D:collection/><C:calendar/></D:resourcetype>
	    <D:displayname>Via MKCOL</D:displayname>
	  </D:prop></D:set>
	</D:mkcol>`
	resp = env.request(t, "MKCOL", "/calendars/alice/viamkcol/", mkcol, map[string]string{"Content-Type": "application/xml"})
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("extended MKCOL = %d: %s", resp.StatusCode, readAll(t, resp))
	}
	resp.Body.Close()
	body = readAll(t, env.request(t, "PROPFIND", "/calendars/alice/viamkcol/", "", map[string]string{"Depth": "0"}))
	if !strings.Contains(body, "Via MKCOL") {
		t.Fatalf("MKCOL properties missing: %s", body)
	}
}

func TestPasswordChangeInvalidatesAuthCache(t *testing.T) {
	env := newTestEnv(t)
	resp := env.request(t, "PROPFIND", "/", "", map[string]string{"Depth": "0"})
	if resp.StatusCode != http.StatusMultiStatus {
		t.Fatalf("initial PROPFIND = %d", resp.StatusCode)
	}
	resp.Body.Close()

	newHash, _ := auth.HashPassword("changed-password")
	if err := env.store.UpdateUser(context.Background(), env.user.ID, "", "", false, newHash); err != nil {
		t.Fatal(err)
	}
	resp = env.request(t, "PROPFIND", "/", "", map[string]string{"Depth": "0"})
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("old password still accepted: %d", resp.StatusCode)
	}
	resp.Body.Close()
}

func TestAdminCanAccessOtherUser(t *testing.T) {
	env := newTestEnv(t)
	hash, _ := auth.HashPassword("adminpass")
	if _, err := env.store.CreateUser(context.Background(), "root", "", "", hash, true); err != nil {
		t.Fatal(err)
	}
	if _, err := env.store.CreateCalendar(context.Background(), env.user.ID, "shared", "Shared", "", "", "UTC", 0, nil); err != nil {
		t.Fatal(err)
	}
	req, _ := http.NewRequest("PROPFIND", env.server.URL+"/calendars/alice/shared/", nil)
	req.Header.Set("Depth", "0")
	req.SetBasicAuth("root", "adminpass")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusMultiStatus {
		t.Fatalf("admin cross-user PROPFIND = %d: %s", resp.StatusCode, readAll(t, resp))
	}
	resp.Body.Close()

	// A normal user may not access another user's calendar.
	resp = env.request(t, "PROPFIND", "/calendars/root/", "", map[string]string{"Depth": "0"})
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("alice accessed root home: %d", resp.StatusCode)
	}
	resp.Body.Close()
}

func extractTag(body, local string) string {
	re := regexp.MustCompile(`<` + regexp.QuoteMeta(local) + `(?:\s[^>]*)?>([^<]*)</` + regexp.QuoteMeta(local) + `>`)
	match := re.FindStringSubmatch(body)
	if len(match) != 2 {
		return ""
	}
	return strings.TrimSpace(match[1])
}
