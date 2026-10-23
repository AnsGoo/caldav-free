package mailer

import (
	"bufio"
	"context"
	"net"
	"strconv"
	"strings"
	"testing"
	"time"
)

func TestSendPlainSMTP(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	messages := make(chan string, 1)
	go func() {
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
		var message strings.Builder
		for {
			line, err := reader.ReadString('\n')
			if err != nil {
				return
			}
			line = strings.TrimRight(line, "\r\n")
			if inData {
				if line == "." {
					inData = false
					messages <- message.String()
					write("250 queued")
					continue
				}
				message.WriteString(line)
				message.WriteString("\r\n")
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

	host, portText, _ := net.SplitHostPort(listener.Addr().String())
	port, _ := strconv.Atoi(portText)
	cfg := Config{
		Enabled: true, Host: host, Port: port,
		From: "CalDAV <caldav@example.test>", Security: "none",
	}
	if err := cfg.Send(context.Background(), "user@example.test", "任务提醒：写周报", "第一行\n第二行"); err != nil {
		t.Fatalf("send: %v", err)
	}
	select {
	case message := <-messages:
		if !strings.Contains(message, "To: <user@example.test>") {
			t.Fatalf("missing recipient: %s", message)
		}
		if !strings.Contains(message, "Subject: =?utf-8?") {
			t.Fatalf("subject is not encoded: %s", message)
		}
		if !strings.Contains(message, "第一行\r\n第二行") {
			t.Fatalf("body missing: %s", message)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("SMTP server received no message")
	}
}

func TestValidateDisabled(t *testing.T) {
	if err := (Config{}).Validate(); err == nil {
		t.Fatal("disabled config should reject delivery")
	}
}
