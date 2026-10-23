package web

import (
	"encoding/json"
	"net/http"
	"testing"
)

func TestPushSubscriptionAPI(t *testing.T) {
	env := newAPIEnv(t)

	status, body := env.request(t, http.MethodGet, "/api/admin/tasks/push/public-key", nil, "")
	if status != http.StatusOK {
		t.Fatalf("public key = %d: %s", status, body)
	}
	var key struct {
		PublicKey string `json:"publicKey"`
	}
	if err := json.Unmarshal(body, &key); err != nil || key.PublicKey == "" {
		t.Fatalf("public key = %q (%v)", key.PublicKey, err)
	}
	_, again := env.request(t, http.MethodGet, "/api/admin/tasks/push/public-key", nil, "")
	var key2 struct {
		PublicKey string `json:"publicKey"`
	}
	_ = json.Unmarshal(again, &key2)
	if key2.PublicKey != key.PublicKey {
		t.Fatal("VAPID public key is not stable")
	}

	subscription := map[string]any{
		"endpoint": "https://push.example.test/abc",
		"keys": map[string]string{
			"p256dh": "BExampleKey",
			"auth":   "example-auth",
		},
	}
	status, body = env.request(t, http.MethodPost, "/api/admin/tasks/push/subscribe", subscription, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("subscribe = %d: %s", status, body)
	}
	status, body = env.request(t, http.MethodGet, "/api/admin/tasks/push/subscriptions", nil, "")
	var list struct {
		Count int `json:"count"`
	}
	if status != http.StatusOK || json.Unmarshal(body, &list) != nil || list.Count != 1 {
		t.Fatalf("subscriptions = %d %s", status, body)
	}
	status, body = env.request(t, http.MethodDelete, "/api/admin/tasks/push/subscribe", map[string]string{
		"endpoint": "https://push.example.test/abc",
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("unsubscribe = %d: %s", status, body)
	}
	_, body = env.request(t, http.MethodGet, "/api/admin/tasks/push/subscriptions", nil, "")
	if json.Unmarshal(body, &list) != nil || list.Count != 0 {
		t.Fatalf("subscriptions after delete = %s", body)
	}
}
