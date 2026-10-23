package reminders

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	webpush "github.com/SherClockHolmes/webpush-go"

	"caldav-free/internal/store"
)

// PushMessage is a one-off notification payload.
type PushMessage struct {
	Title  string `json:"title"`
	Body   string `json:"body"`
	Tag    string `json:"tag,omitempty"`
	TaskID int64  `json:"taskId,omitempty"`
	URL    string `json:"url,omitempty"`
}

// NotifyUser sends one-off Web Push messages to all subscriptions of a user.
// It is used for collaboration events such as task assignment.
func NotifyUser(ctx context.Context, st *store.Store, logger *slog.Logger, userID int64, message PushMessage) (int, error) {
	if logger == nil {
		logger = slog.Default()
	}
	subscriptions, err := st.ListPushSubscriptions(ctx, userID)
	if err != nil || len(subscriptions) == 0 {
		return 0, err
	}
	keys, err := EnsureVAPID(ctx, st)
	if err != nil {
		return 0, err
	}
	subject := strings.TrimSpace(os.Getenv("CALDAV_PUSH_SUBJECT"))
	if subject == "" {
		subject = "mailto:admin@example.com"
	}
	if message.Title == "" {
		message.Title = "任务提醒"
	}
	payload, _ := json.Marshal(message)
	client := &http.Client{Timeout: 10 * time.Second}
	sent := 0
	var lastErr error
	for _, subscription := range subscriptions {
		response, err := webpush.SendNotificationWithContext(ctx, payload, &webpush.Subscription{
			Endpoint: subscription.Endpoint,
			Keys:     webpush.Keys{Auth: subscription.Auth, P256dh: subscription.P256dh},
		}, &webpush.Options{
			Subscriber:      subject,
			TTL:             86400,
			Urgency:         webpush.UrgencyNormal,
			VAPIDPublicKey:  keys.Public,
			VAPIDPrivateKey: keys.Private,
			HTTPClient:      client,
		})
		if err != nil {
			lastErr = err
			logger.Warn("collaboration push", "user", userID, "error", err)
			continue
		}
		if response == nil {
			continue
		}
		status := response.StatusCode
		_ = response.Body.Close()
		if status == http.StatusNotFound || status == http.StatusGone {
			_ = st.DeletePushSubscriptionEndpoint(ctx, subscription.Endpoint)
		}
		if status < 200 || status >= 300 {
			lastErr = fmt.Errorf("push service returned %d", status)
			continue
		}
		sent++
	}
	return sent, lastErr
}
