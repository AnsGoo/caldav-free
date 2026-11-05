package reminders

import (
	"bufio"
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"golang.org/x/crypto/hkdf"

	"caldav-free/internal/ical"
	"caldav-free/internal/mailer"
	"caldav-free/internal/store"
)

type notifyEnv struct {
	store  *store.Store
	sched  *Scheduler
	userID int64
}

func newNotifyEnv(t *testing.T) *notifyEnv {
	t.Helper()
	ctx := context.Background()
	st, err := store.Open(t.TempDir() + "/notify.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	user, err := st.CreateUser(ctx, "notif", "Notif", "notif@example.test", "test-hash", true)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	keys, err := EnsureVAPID(ctx, st)
	if err != nil {
		t.Fatalf("vapid keys: %v", err)
	}
	return &notifyEnv{
		store:  st,
		userID: user.ID,
		sched: &Scheduler{
			store:   st,
			logger:  slog.New(slog.NewTextHandler(io.Discard, nil)),
			keys:    keys,
			subject: "mailto:test@example.test",
			baseURL: "https://dav.example.test",
			grace:   6 * time.Hour,
			client:  &http.Client{Timeout: 5 * time.Second},
		},
	}
}

// reminderTask creates a task whose 5-minute reminder is already due.
func (e *notifyEnv) reminderTask(t *testing.T, title string) *store.Task {
	t.Helper()
	ctx := context.Background()
	list, err := e.store.EnsureInbox(ctx, e.userID)
	if err != nil {
		t.Fatalf("ensure inbox: %v", err)
	}
	due := time.Now().UTC().Add(2 * time.Minute)
	task := &store.Task{
		UserID: e.userID, ListID: list.ID, Kind: "TASK", Title: title,
		DueAt: &due, ReminderOffset: 5,
	}
	task.SetReminderValues([]int{5})
	created, err := e.store.CreateTask(ctx, task)
	if err != nil {
		t.Fatalf("create task: %v", err)
	}
	return created
}

func reminderKey(task *store.Task, offset int) string {
	return task.DueAt.UTC().Format(time.RFC3339) + ":" + strconv.Itoa(offset)
}

// ---------------------------------------------------------------- push sink

type pushCall struct {
	Header http.Header
	Body   []byte
}

type pushSink struct {
	mu     sync.Mutex
	status int
	calls  []pushCall
	srv    *httptest.Server
}

func newPushSink(t *testing.T, status int) *pushSink {
	t.Helper()
	sink := &pushSink{status: status}
	sink.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		sink.mu.Lock()
		sink.calls = append(sink.calls, pushCall{Header: r.Header.Clone(), Body: body})
		code := sink.status
		sink.mu.Unlock()
		w.WriteHeader(code)
	}))
	t.Cleanup(sink.srv.Close)
	return sink
}

func (s *pushSink) hits() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.calls)
}

func (s *pushSink) call(index int) pushCall {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.calls[index]
}

func (s *pushSink) setStatus(status int) {
	s.mu.Lock()
	s.status = status
	s.mu.Unlock()
}

// newSubscription returns the p256dh/auth values a browser would register and
// the private key needed to decrypt the payload the server sends.
func newSubscription(t *testing.T) (p256dh, authKey string, privateKey *ecdh.PrivateKey) {
	t.Helper()
	key, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("generate ua key: %v", err)
	}
	secret := make([]byte, 16)
	if _, err := rand.Read(secret); err != nil {
		t.Fatalf("generate auth secret: %v", err)
	}
	return base64.RawURLEncoding.EncodeToString(key.PublicKey().Bytes()),
		base64.RawURLEncoding.EncodeToString(secret), key
}

func hkdfExpand(secret, salt, info []byte, length int) []byte {
	out := make([]byte, length)
	reader := hkdf.New(sha256.New, secret, salt, info)
	if _, err := io.ReadFull(reader, out); err != nil {
		return nil
	}
	return out
}

// decryptPushPayload decodes an RFC 8291 aes128gcm body.
func decryptPushPayload(t *testing.T, body []byte, authKey string, key *ecdh.PrivateKey) []byte {
	t.Helper()
	if len(body) < 22 {
		t.Fatalf("push body too short: %d", len(body))
	}
	salt := body[:16]
	idLen := int(body[20])
	if len(body) < 21+idLen {
		t.Fatalf("truncated key id (len=%d)", idLen)
	}
	asPublicBytes := body[21 : 21+idLen]
	ciphertext := body[21+idLen:]
	asPublic, err := ecdh.P256().NewPublicKey(asPublicBytes)
	if err != nil {
		t.Fatalf("parse push key: %v", err)
	}
	shared, err := key.ECDH(asPublic)
	if err != nil {
		t.Fatalf("ecdh: %v", err)
	}
	authSecret, err := base64.RawURLEncoding.DecodeString(authKey)
	if err != nil {
		t.Fatalf("decode auth: %v", err)
	}
	info := append([]byte("WebPush: info\x00"), key.PublicKey().Bytes()...)
	info = append(info, asPublicBytes...)
	prk := hkdfExpand(shared, authSecret, info, 32)
	cek := hkdfExpand(prk, salt, []byte("Content-Encoding: aes128gcm\x00"), 16)
	nonce := hkdfExpand(prk, salt, []byte("Content-Encoding: nonce\x00"), 12)
	block, err := aes.NewCipher(cek)
	if err != nil {
		t.Fatalf("aes: %v", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		t.Fatalf("gcm: %v", err)
	}
	plain, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		t.Fatalf("decrypt push: %v", err)
	}
	// Strip the 0x02 last-record delimiter and zero padding.
	for len(plain) > 0 && plain[len(plain)-1] == 0 {
		plain = plain[:len(plain)-1]
	}
	if len(plain) > 0 && plain[len(plain)-1] == 2 {
		plain = plain[:len(plain)-1]
	}
	return plain
}

// ---------------------------------------------------------------- smtp sink

type smtpSink struct {
	addr     string
	mu       sync.Mutex
	messages []string
}

func newSMTPSink(t *testing.T) *smtpSink {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("smtp listen: %v", err)
	}
	t.Cleanup(func() { _ = listener.Close() })
	sink := &smtpSink{addr: listener.Addr().String()}
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go sink.serve(conn)
		}
	}()
	return sink
}

func (s *smtpSink) serve(conn net.Conn) {
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(20 * time.Second))
	reader := bufio.NewReader(conn)
	writer := bufio.NewWriter(conn)
	write := func(line string) {
		_, _ = writer.WriteString(line + "\r\n")
		_ = writer.Flush()
	}
	write("220 localhost ESMTP")
	inData := false
	var data strings.Builder
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			return
		}
		line = strings.TrimRight(line, "\r\n")
		if inData {
			if line == "." {
				inData = false
				s.mu.Lock()
				s.messages = append(s.messages, data.String())
				s.mu.Unlock()
				data.Reset()
				write("250 queued")
				continue
			}
			data.WriteString(line + "\n")
			continue
		}
		switch {
		case strings.HasPrefix(line, "EHLO"), strings.HasPrefix(line, "HELO"):
			write("250-localhost")
			write("250 8BITMIME")
		case strings.HasPrefix(line, "MAIL FROM:"), strings.HasPrefix(line, "RCPT TO:"):
			write("250 OK")
		case line == "DATA":
			inData = true
			write("354 End data with <CR><LF>.<CR><LF>")
		case line == "QUIT":
			write("221 Bye")
			return
		default:
			write("250 OK")
		}
	}
}

func (s *smtpSink) count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.messages)
}

func (s *smtpSink) message(index int) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.messages[index]
}

func (e *notifyEnv) enableEmail(t *testing.T, sink *smtpSink) {
	t.Helper()
	host, portText, _ := net.SplitHostPort(sink.addr)
	port, _ := strconv.Atoi(portText)
	err := mailer.Save(context.Background(), e.store, mailer.Config{
		Enabled: true, Host: host, Port: port,
		From: "CalFree <caldav@example.test>", Security: "none",
	}, "", false)
	if err != nil {
		t.Fatalf("save mail settings: %v", err)
	}
}

// ---------------------------------------------------------------- tests

func TestSchedulerDeliversTaskReminderOnEveryChannel(t *testing.T) {
	env := newNotifyEnv(t)
	ctx := context.Background()

	push := newPushSink(t, http.StatusCreated)
	p256dh, authKey, privateKey := newSubscription(t)
	endpoint := push.srv.URL + "/push/device-1"
	if err := env.store.SavePushSubscription(ctx, env.userID, endpoint, p256dh, authKey); err != nil {
		t.Fatalf("save subscription: %v", err)
	}
	smtp := newSMTPSink(t)
	env.enableEmail(t, smtp)

	task := env.reminderTask(t, "提交季度报告")
	env.sched.tick(ctx)

	// in-app notification center
	items, err := env.store.ListNotifications(ctx, env.userID, 50)
	if err != nil {
		t.Fatalf("list notifications: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("in-app notifications = %d, want 1", len(items))
	}
	if items[0].Type != "task" || items[0].Title != "任务提醒" {
		t.Fatalf("unexpected notification: %+v", items[0])
	}
	if !strings.Contains(items[0].Body, "提交季度报告") {
		t.Fatalf("notification body missing title: %q", items[0].Body)
	}
	if !strings.Contains(items[0].URL, fmt.Sprintf("task=%d", task.ID)) {
		t.Fatalf("notification url missing task: %q", items[0].URL)
	}
	if unread, _ := env.store.CountUnreadNotifications(ctx, env.userID); unread != 1 {
		t.Fatalf("unread = %d, want 1", unread)
	}

	// web push: verify transport headers and the decrypted payload
	if push.hits() != 1 {
		t.Fatalf("push requests = %d, want 1", push.hits())
	}
	delivered := push.call(0)
	if got := delivered.Header.Get("Content-Encoding"); got != "aes128gcm" {
		t.Fatalf("content-encoding = %q", got)
	}
	if got := delivered.Header.Get("TTL"); got != "86400" {
		t.Fatalf("ttl = %q", got)
	}
	if auth := delivered.Header.Get("Authorization"); !strings.HasPrefix(auth, "vapid ") {
		t.Fatalf("authorization = %q", auth)
	}
	plain := decryptPushPayload(t, delivered.Body, authKey, privateKey)
	var payload map[string]any
	if err := json.Unmarshal(plain, &payload); err != nil {
		t.Fatalf("decode push payload %q: %v", plain, err)
	}
	if payload["title"] != "任务提醒" {
		t.Fatalf("push title = %v", payload["title"])
	}
	if body, _ := payload["body"].(string); !strings.Contains(body, "提交季度报告") {
		t.Fatalf("push body = %v", payload["body"])
	}
	if payload["taskId"] != float64(task.ID) {
		t.Fatalf("push taskId = %v, want %d", payload["taskId"], task.ID)
	}
	if tag, _ := payload["tag"].(string); tag != fmt.Sprintf("task-%d", task.ID) {
		t.Fatalf("push tag = %v", payload["tag"])
	}

	// email
	if smtp.count() != 1 {
		t.Fatalf("emails = %d, want 1", smtp.count())
	}
	mail := smtp.message(0)
	for _, want := range []string{"任务提醒", "提交季度报告", "https://dav.example.test/admin/tasks?task="} {
		if !strings.Contains(mail, want) {
			t.Fatalf("email missing %q:\n%s", want, mail)
		}
	}

	// delivery bookkeeping
	key := reminderKey(task, 5)
	for _, channel := range []string{"inapp", "push", "email"} {
		ok, err := env.store.HasReminderDelivery(ctx, task.ID, key, channel)
		if err != nil || !ok {
			t.Fatalf("delivery %s = %v (%v)", channel, ok, err)
		}
	}

	// a second tick must not duplicate any channel
	env.sched.tick(ctx)
	items, _ = env.store.ListNotifications(ctx, env.userID, 50)
	if len(items) != 1 {
		t.Fatalf("duplicate in-app notifications: %d", len(items))
	}
	if push.hits() != 1 {
		t.Fatalf("duplicate pushes: %d", push.hits())
	}
	if smtp.count() != 1 {
		t.Fatalf("duplicate emails: %d", smtp.count())
	}
}

func TestPushFailureBacksOffThenRetries(t *testing.T) {
	env := newNotifyEnv(t)
	ctx := context.Background()

	push := newPushSink(t, http.StatusServiceUnavailable)
	p256dh, authKey, _ := newSubscription(t)
	endpoint := push.srv.URL + "/push/flaky"
	if err := env.store.SavePushSubscription(ctx, env.userID, endpoint, p256dh, authKey); err != nil {
		t.Fatalf("save subscription: %v", err)
	}

	task := env.reminderTask(t, "拨回客户电话")
	key := reminderKey(task, 5)
	env.sched.tick(ctx)

	if push.hits() != 1 {
		t.Fatalf("push attempts = %d, want 1", push.hits())
	}
	if ok, _ := env.store.HasReminderDelivery(ctx, task.ID, key, "push"); ok {
		t.Fatal("failed push must not be recorded as delivered")
	}
	attempt, err := env.store.ReminderAttemptState(ctx, task.ID, key, "push")
	if err != nil || attempt == nil {
		t.Fatalf("retry state = %v (%v)", attempt, err)
	}
	if attempt.Attempts != 1 || !attempt.NextAttemptAt.After(time.Now()) {
		t.Fatalf("retry state = %+v", attempt)
	}

	// Backoff suppresses an immediate retry on the next tick.
	env.sched.tick(ctx)
	if push.hits() != 1 {
		t.Fatalf("backoff did not suppress retry: %d", push.hits())
	}

	// Simulate the backoff window elapsing and the push service recovering.
	push.setStatus(http.StatusCreated)
	if err := env.store.RecordReminderFailure(ctx, task.ID, key, "push", 1, time.Now().Add(-time.Second), "simulated"); err != nil {
		t.Fatal(err)
	}
	env.sched.tick(ctx)
	if push.hits() != 2 {
		t.Fatalf("push retries = %d, want 2", push.hits())
	}
	if ok, _ := env.store.HasReminderDelivery(ctx, task.ID, key, "push"); !ok {
		t.Fatal("successful retry was not recorded")
	}
	if attempt, _ := env.store.ReminderAttemptState(ctx, task.ID, key, "push"); attempt != nil {
		t.Fatalf("retry state not cleared: %+v", attempt)
	}
}

func TestGoneSubscriptionIsPruned(t *testing.T) {
	env := newNotifyEnv(t)
	ctx := context.Background()

	push := newPushSink(t, http.StatusGone)
	p256dh, authKey, _ := newSubscription(t)
	endpoint := push.srv.URL + "/push/expired"
	if err := env.store.SavePushSubscription(ctx, env.userID, endpoint, p256dh, authKey); err != nil {
		t.Fatalf("save subscription: %v", err)
	}

	task := env.reminderTask(t, "已失效设备")
	env.sched.tick(ctx)

	if push.hits() != 1 {
		t.Fatalf("push attempts = %d, want 1", push.hits())
	}
	subs, err := env.store.ListPushSubscriptions(ctx, env.userID)
	if err != nil {
		t.Fatal(err)
	}
	if len(subs) != 0 {
		t.Fatalf("expired subscription kept: %d", len(subs))
	}
	// In-app delivery still succeeded even though push was gone.
	if ok, _ := env.store.HasReminderDelivery(ctx, task.ID, reminderKey(task, 5), "inapp"); !ok {
		t.Fatal("in-app reminder lost when push endpoint was gone")
	}
}

func TestEventReminderCreatesNotification(t *testing.T) {
	env := newNotifyEnv(t)
	ctx := context.Background()

	cal, err := env.store.CreateCalendar(ctx, env.userID, "work", "工作", "", "#4772fa", "Asia/Shanghai", 0, []string{"VEVENT"})
	if err != nil {
		t.Fatalf("create calendar: %v", err)
	}
	loc, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		t.Fatal(err)
	}
	start := time.Now().In(loc).Add(2 * time.Minute).Truncate(time.Second)
	end := start.Add(time.Hour)
	ics := fmt.Sprintf("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//test//EN\r\nBEGIN:VEVENT\r\nUID:weekly@test\r\nDTSTART;TZID=Asia/Shanghai:%s\r\nDTEND;TZID=Asia/Shanghai:%s\r\nSUMMARY:周会\r\nBEGIN:VALARM\r\nACTION:DISPLAY\r\nDESCRIPTION:周会\r\nTRIGGER:-PT5M\r\nEND:VALARM\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n",
		start.Format("20060102T150405"), end.Format("20060102T150405"))
	parsed, err := ical.Load([]byte(ics), cal.Timezone)
	if err != nil {
		t.Fatalf("parse ics: %v", err)
	}
	info, err := parsed.Analyze()
	if err != nil {
		t.Fatalf("analyze ics: %v", err)
	}
	obj := &store.Object{
		CalendarID: cal.ID, Href: "weekly.ics", UID: "weekly@test", ETag: "etag-1",
		ContentType: "text/calendar; charset=utf-8", Data: []byte(ics),
		ComponentType: "VEVENT", FirstStart: info.FirstStart.Unix(), LastEnd: info.LastEnd.Unix(),
		Size: int64(len(ics)),
	}
	if _, _, _, err := env.store.PutObject(ctx, obj); err != nil {
		t.Fatalf("put object: %v", err)
	}

	env.sched.tick(ctx)

	items, err := env.store.ListNotifications(ctx, env.userID, 50)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 {
		t.Fatalf("event notifications = %d, want 1", len(items))
	}
	item := items[0]
	if item.Type != "event" || item.Title != "日程提醒" {
		t.Fatalf("unexpected event notification: %+v", item)
	}
	if !strings.Contains(item.Body, "周会") {
		t.Fatalf("event notification body = %q", item.Body)
	}
	if !strings.Contains(item.URL, fmt.Sprintf("calendar=%d", cal.ID)) || !strings.Contains(item.URL, "event=weekly.ics") {
		t.Fatalf("event notification url = %q", item.URL)
	}

	// The same occurrence must not notify twice.
	env.sched.tick(ctx)
	items, _ = env.store.ListNotifications(ctx, env.userID, 50)
	if len(items) != 1 {
		t.Fatalf("duplicate event notifications: %d", len(items))
	}
}
