package web

import (
	"net/http"
	"strings"

	"caldav-free/internal/mailer"
	"caldav-free/internal/store"
)

type emailSettingsPayload struct {
	Enabled        bool   `json:"enabled"`
	Host           string `json:"host"`
	Port           int    `json:"port"`
	Username       string `json:"username"`
	From           string `json:"from"`
	Security       string `json:"security"`
	PasswordSet    bool   `json:"passwordSet"`
	RecipientEmail string `json:"recipientEmail"`
}

func (s *Server) apiEmailSettings(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	ctx := r.Context()
	if r.Method == http.MethodGet {
		cfg, err := mailer.Load(ctx, s.store)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		writeAPIJSON(w, http.StatusOK, emailPayload(cfg, current.Email))
		return
	}
	var body struct {
		Enabled       bool   `json:"enabled"`
		Host          string `json:"host"`
		Port          int    `json:"port"`
		Username      string `json:"username"`
		Password      string `json:"password"`
		From          string `json:"from"`
		Security      string `json:"security"`
		ClearPassword bool   `json:"clearPassword"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	port := body.Port
	if port == 0 {
		port = 587
	}
	cfg := mailer.Config{
		Enabled:  body.Enabled,
		Host:     strings.TrimSpace(body.Host),
		Port:     port,
		Username: strings.TrimSpace(body.Username),
		From:     strings.TrimSpace(body.From),
		Security: strings.ToLower(strings.TrimSpace(body.Security)),
	}
	if err := mailer.Save(ctx, s.store, cfg, body.Password, body.ClearPassword); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	saved, err := mailer.Load(ctx, s.store)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, emailPayload(saved, current.Email))
}

func (s *Server) apiTestEmail(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	ctx := r.Context()
	cfg, err := mailer.Load(ctx, s.store)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	if !cfg.Enabled {
		writeAPIError(w, http.StatusBadRequest, "请先开启邮件提醒并保存设置")
		return
	}
	recipient := strings.TrimSpace(current.Email)
	if recipient == "" {
		writeAPIError(w, http.StatusBadRequest, "当前账号没有邮箱，请先在管理后台用户资料中填写")
		return
	}
	body := "这是一封 caldav-free 测试邮件。\n\n如果你收到它，说明 SMTP 配置可用，任务到期提醒会发送到这个地址。\n"
	if err := cfg.Send(ctx, recipient, "caldav-free 邮件提醒测试", body); err != nil {
		writeAPIError(w, http.StatusBadGateway, "发送失败："+err.Error())
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"sent": true, "to": recipient})
}

func emailPayload(cfg mailer.Config, recipient string) emailSettingsPayload {
	return emailSettingsPayload{
		Enabled:        cfg.Enabled,
		Host:           cfg.Host,
		Port:           cfg.Port,
		Username:       cfg.Username,
		From:           cfg.From,
		Security:       cfg.Security,
		PasswordSet:    cfg.Password != "",
		RecipientEmail: strings.TrimSpace(recipient),
	}
}
