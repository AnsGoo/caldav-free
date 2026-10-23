package web

import (
	"net/http"
	"net/url"
	"strings"

	"caldav-free/internal/reminders"
	"caldav-free/internal/store"
)

type pushSubscriptionBody struct {
	Endpoint string `json:"endpoint"`
	Keys     struct {
		P256dh string `json:"p256dh"`
		Auth   string `json:"auth"`
	} `json:"keys"`
}

// apiPushPublicKey returns the VAPID public key used by browser push managers.
func (s *Server) apiPushPublicKey(w http.ResponseWriter, r *http.Request, _ *store.User, _ *session) {
	keys, err := reminders.EnsureVAPID(r.Context(), s.store)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]string{"publicKey": keys.Public})
}

// apiPushSubscriptions returns how many devices the current user registered.
func (s *Server) apiPushSubscriptions(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	subscriptions, err := s.store.ListPushSubscriptions(r.Context(), current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"count":      len(subscriptions),
		"subscribed": len(subscriptions) > 0,
	})
}

// apiPushSubscribe saves a browser push subscription.
func (s *Server) apiPushSubscribe(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body pushSubscriptionBody
	if !readAPIJSON(w, r, &body) {
		return
	}
	endpoint := strings.TrimSpace(body.Endpoint)
	parsed, err := url.Parse(endpoint)
	if err != nil || (parsed.Scheme != "https" && parsed.Scheme != "http") || parsed.Host == "" {
		writeAPIError(w, http.StatusBadRequest, "无效的推送订阅地址")
		return
	}
	p256dh := strings.TrimSpace(body.Keys.P256dh)
	auth := strings.TrimSpace(body.Keys.Auth)
	if p256dh == "" || auth == "" || len(p256dh) > 255 || len(auth) > 255 || len(endpoint) > 1024 {
		writeAPIError(w, http.StatusBadRequest, "推送订阅数据不完整")
		return
	}
	if err := s.store.SavePushSubscription(r.Context(), current.ID, endpoint, p256dh, auth); err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"subscribed": true})
}

// apiUnsubscribePush removes a browser push subscription.
func (s *Server) apiUnsubscribePush(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		Endpoint string `json:"endpoint"`
	}
	if r.ContentLength != 0 {
		if !readAPIJSON(w, r, &body) {
			return
		}
	}
	if body.Endpoint == "" {
		body.Endpoint = r.URL.Query().Get("endpoint")
	}
	endpoint := strings.TrimSpace(body.Endpoint)
	if endpoint == "" {
		writeAPIError(w, http.StatusBadRequest, "缺少推送订阅地址")
		return
	}
	if err := s.store.DeletePushSubscription(r.Context(), current.ID, endpoint); err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"subscribed": false})
}
