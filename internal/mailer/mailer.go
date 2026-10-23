// Package mailer loads SMTP settings and sends reminder emails.
package mailer

import (
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/hex"
	"errors"
	"fmt"
	"mime"
	"net"
	"net/mail"
	"net/smtp"
	"os"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/store"
)

const (
	SettingEnabled  = "smtp.enabled"
	SettingHost     = "smtp.host"
	SettingPort     = "smtp.port"
	SettingUsername = "smtp.username"
	SettingPassword = "smtp.password"
	SettingFrom     = "smtp.from"
	SettingSecurity = "smtp.security"
)

// Config is the persisted SMTP configuration. Password is never returned by
// the HTTP API, but is kept here for the scheduler.
type Config struct {
	Enabled  bool
	Host     string
	Port     int
	Username string
	Password string
	From     string
	Security string
}

// Load reads SMTP settings, falling back to CALDAV_SMTP_* environment
// variables when a setting is empty.
func Load(ctx context.Context, st *store.Store) (Config, error) {
	host := value(ctx, st, SettingHost, "CALDAV_SMTP_HOST")
	port := 587
	if raw := value(ctx, st, SettingPort, "CALDAV_SMTP_PORT"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil {
			return Config{}, fmt.Errorf("smtp port: %w", err)
		}
		port = parsed
	}
	security := strings.ToLower(value(ctx, st, SettingSecurity, "CALDAV_SMTP_SECURITY"))
	if security == "" {
		security = "starttls"
	}
	username := value(ctx, st, SettingUsername, "CALDAV_SMTP_USER")
	from := value(ctx, st, SettingFrom, "CALDAV_SMTP_FROM")
	if from == "" && strings.Contains(username, "@") {
		from = username
	}
	enabled := false
	if raw := value(ctx, st, SettingEnabled, "CALDAV_SMTP_ENABLED"); raw != "" {
		enabled = parseBool(raw)
	}
	return Config{
		Enabled:  enabled,
		Host:     host,
		Port:     port,
		Username: username,
		Password: value(ctx, st, SettingPassword, "CALDAV_SMTP_PASSWORD"),
		From:     from,
		Security: security,
	}, nil
}

// Save persists SMTP settings. An empty password keeps the stored value unless
// clearPassword is true.
func Save(ctx context.Context, st *store.Store, cfg Config, password string, clearPassword bool) error {
	security := strings.ToLower(strings.TrimSpace(cfg.Security))
	if security == "" {
		security = "starttls"
	}
	if security != "starttls" && security != "tls" && security != "none" {
		return errors.New("SMTP 加密方式必须是 starttls、tls 或 none")
	}
	if cfg.Port < 1 || cfg.Port > 65535 {
		return errors.New("SMTP 端口必须在 1-65535 之间")
	}
	from := strings.TrimSpace(cfg.From)
	if from == "" && strings.Contains(cfg.Username, "@") {
		from = cfg.Username
	}
	if cfg.Enabled {
		if strings.TrimSpace(cfg.Host) == "" {
			return errors.New("请填写 SMTP 服务器")
		}
		if from == "" {
			return errors.New("请填写发件人邮箱")
		}
		if _, err := mail.ParseAddress(from); err != nil {
			return errors.New("发件人邮箱格式不正确")
		}
	}
	values := map[string]string{
		SettingEnabled:  "0",
		SettingHost:     strings.TrimSpace(cfg.Host),
		SettingPort:     strconv.Itoa(cfg.Port),
		SettingUsername: strings.TrimSpace(cfg.Username),
		SettingFrom:     from,
		SettingSecurity: security,
	}
	if cfg.Enabled {
		values[SettingEnabled] = "1"
	}
	for key, value := range values {
		if err := st.SetSetting(ctx, key, value); err != nil {
			return err
		}
	}
	if clearPassword {
		return st.SetSetting(ctx, SettingPassword, "")
	}
	if strings.TrimSpace(password) != "" {
		return st.SetSetting(ctx, SettingPassword, password)
	}
	return nil
}

// Validate checks required fields for delivery.
func (c Config) Validate() error {
	if !c.Enabled {
		return errors.New("邮件提醒未开启")
	}
	if strings.TrimSpace(c.Host) == "" {
		return errors.New("缺少 SMTP 服务器")
	}
	if c.Port < 1 || c.Port > 65535 {
		return errors.New("SMTP 端口无效")
	}
	switch strings.ToLower(c.Security) {
	case "", "starttls", "tls", "none":
	default:
		return errors.New("SMTP 加密方式无效")
	}
	if _, err := mail.ParseAddress(strings.TrimSpace(c.From)); err != nil {
		return errors.New("发件人邮箱格式不正确")
	}
	return nil
}

// Send delivers a plain-text email.
func (c Config) Send(ctx context.Context, to, subject, body string) error {
	if err := c.Validate(); err != nil {
		return err
	}
	to = strings.TrimSpace(to)
	recipient, err := mail.ParseAddress(to)
	if err != nil {
		return fmt.Errorf("收件人邮箱格式不正确: %w", err)
	}
	sender, err := mail.ParseAddress(strings.TrimSpace(c.From))
	if err != nil {
		return fmt.Errorf("发件人邮箱格式不正确: %w", err)
	}
	message := buildMessage(c, sender, recipient, subject, body)
	address := net.JoinHostPort(c.Host, strconv.Itoa(c.Port))
	dialer := &net.Dialer{Timeout: 10 * time.Second}
	var conn net.Conn
	security := strings.ToLower(c.Security)
	if security == "tls" {
		conn, err = tls.DialWithDialer(dialer, "tcp", address, &tls.Config{
			ServerName: c.Host,
			MinVersion: tls.VersionTLS12,
		})
	} else {
		conn, err = dialer.DialContext(ctx, "tcp", address)
	}
	if err != nil {
		return fmt.Errorf("连接 SMTP 服务器失败: %w", err)
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(30 * time.Second))
	client, err := smtp.NewClient(conn, c.Host)
	if err != nil {
		return fmt.Errorf("SMTP 握手失败: %w", err)
	}
	defer client.Close()
	if security == "starttls" {
		if ok, _ := client.Extension("STARTTLS"); !ok {
			return errors.New("SMTP 服务器不支持 STARTTLS")
		}
		if err := client.StartTLS(&tls.Config{ServerName: c.Host, MinVersion: tls.VersionTLS12}); err != nil {
			return fmt.Errorf("STARTTLS 失败: %w", err)
		}
	}
	if strings.TrimSpace(c.Username) != "" {
		auth := smtp.PlainAuth("", c.Username, c.Password, c.Host)
		if err := client.Auth(auth); err != nil {
			return fmt.Errorf("SMTP 认证失败: %w", err)
		}
	}
	if err := client.Mail(sender.Address); err != nil {
		return fmt.Errorf("SMTP MAIL FROM 失败: %w", err)
	}
	if err := client.Rcpt(recipient.Address); err != nil {
		return fmt.Errorf("SMTP RCPT TO 失败: %w", err)
	}
	writer, err := client.Data()
	if err != nil {
		return fmt.Errorf("SMTP DATA 失败: %w", err)
	}
	if _, err := writer.Write([]byte(message)); err != nil {
		_ = writer.Close()
		return fmt.Errorf("写入邮件失败: %w", err)
	}
	if err := writer.Close(); err != nil {
		return fmt.Errorf("提交邮件失败: %w", err)
	}
	_ = client.Quit()
	return nil
}

func buildMessage(c Config, sender, recipient *mail.Address, subject, body string) string {
	host := "localhost"
	if at := strings.LastIndex(sender.Address, "@"); at >= 0 {
		host = sender.Address[at+1:]
	}
	random := make([]byte, 8)
	_, _ = rand.Read(random)
	body = strings.ReplaceAll(body, "\r\n", "\n")
	body = strings.ReplaceAll(body, "\n", "\r\n")
	if !strings.HasSuffix(body, "\r\n") {
		body += "\r\n"
	}
	return "From: " + sender.String() + "\r\n" +
		"To: " + recipient.String() + "\r\n" +
		"Subject: " + mime.QEncoding.Encode("utf-8", subject) + "\r\n" +
		"Date: " + time.Now().Format(time.RFC1123Z) + "\r\n" +
		"MIME-Version: 1.0\r\n" +
		"Content-Type: text/plain; charset=UTF-8\r\n" +
		"Content-Transfer-Encoding: 8bit\r\n" +
		"Message-ID: <" + strconv.FormatInt(time.Now().UnixNano(), 10) + "." + hex.EncodeToString(random) + "@" + host + ">\r\n" +
		"\r\n" + body
}

func value(ctx context.Context, st *store.Store, key, env string) string {
	if stored, err := st.GetSetting(ctx, key); err == nil && strings.TrimSpace(stored) != "" {
		return strings.TrimSpace(stored)
	}
	return strings.TrimSpace(os.Getenv(env))
}

func parseBool(raw string) bool {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "1", "true", "on", "yes":
		return true
	default:
		return false
	}
}
