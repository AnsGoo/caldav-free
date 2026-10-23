package web

import (
	"bufio"
	"encoding/json"
	"net"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"
)

func TestEmailNotificationSettingsAPI(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, http.MethodGet, "/api/admin/tasks/notifications/email", nil, "")
	if status != http.StatusOK {
		t.Fatalf("get email settings = %d: %s", status, body)
	}
	var settings emailSettingsPayload
	if err := json.Unmarshal(body, &settings); err != nil {
		t.Fatal(err)
	}
	if settings.Enabled || settings.RecipientEmail != "admin@example.com" || settings.Port != 587 {
		t.Fatalf("unexpected default settings: %+v", settings)
	}

	update := map[string]any{
		"enabled": true, "host": "smtp.example.test", "port": 587,
		"username": "caldav", "password": "secret-value",
		"from": "CalDAV <caldav@example.test>", "security": "starttls",
	}
	status, body = env.request(t, http.MethodPut, "/api/admin/tasks/notifications/email", update, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("save email settings = %d: %s", status, body)
	}
	if strings.Contains(string(body), "secret-value") {
		t.Fatal("SMTP password leaked in API response")
	}
	if err := json.Unmarshal(body, &settings); err != nil {
		t.Fatal(err)
	}
	if !settings.Enabled || !settings.PasswordSet || settings.Host != "smtp.example.test" {
		t.Fatalf("unexpected saved settings: %+v", settings)
	}

	invalid := map[string]any{
		"enabled": true, "host": "smtp.example.test", "port": 587,
		"from": "not-an-email", "security": "starttls",
	}
	status, _ = env.request(t, http.MethodPut, "/api/admin/tasks/notifications/email", invalid, env.csrf)
	if status != http.StatusBadRequest {
		t.Fatalf("invalid sender = %d, want 400", status)
	}
}

func TestTestEmailAPI(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	done := make(chan struct{})
	go func() {
		defer close(done)
		conn, err := listener.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		_ = conn.SetDeadline(time.Now().Add(10 * time.Second))
		reader := bufio.NewReader(conn)
		writer := bufio.NewWriter(conn)
		write := func(line string) {
			_, _ = writer.WriteString(line + "\r\n")
			_ = writer.Flush()
		}
		write("220 localhost ESMTP")
		inData := false
		for {
			line, err := reader.ReadString('\n')
			if err != nil {
				return
			}
			line = strings.TrimRight(line, "\r\n")
			if inData {
				if line == "." {
					inData = false
					write("250 queued")
				}
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
	}()

	env := newAPIEnv(t)
	host, portText, _ := net.SplitHostPort(listener.Addr().String())
	port, _ := strconv.Atoi(portText)
	update := map[string]any{
		"enabled": true, "host": host, "port": port,
		"from": "CalDAV <caldav@example.test>", "security": "none",
	}
	status, body := env.request(t, http.MethodPut, "/api/admin/tasks/notifications/email", update, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("save settings = %d: %s", status, body)
	}
	status, body = env.request(t, http.MethodPost, "/api/admin/tasks/notifications/email/test", nil, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("test email = %d: %s", status, body)
	}
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("test email did not reach SMTP server")
	}
}
