package web

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"caldav-free/internal/ical"
	"caldav-free/internal/store"
	lunarcalendar "github.com/6tail/lunar-go/calendar"
)

const maxCalendarSubscriptionBytes = 10 << 20

func (s *Server) loadCalendarSubscriptions(ctx context.Context, userID int64) []*store.CalendarSubscription {
	subscriptions, err := s.store.ListCalendarSubscriptions(ctx, userID)
	if err != nil {
		return nil
	}
	for _, subscription := range subscriptions {
		if subscription.LastSynced != nil && time.Since(*subscription.LastSynced) < 15*time.Minute {
			continue
		}
		client := &http.Client{Timeout: 12 * time.Second}
		request, err := http.NewRequestWithContext(ctx, http.MethodGet, subscription.URL, nil)
		if err != nil {
			_ = s.store.UpdateCalendarSubscriptionCache(ctx, subscription.ID, subscription.Data, err.Error())
			continue
		}
		response, err := client.Do(request)
		if err != nil {
			_ = s.store.UpdateCalendarSubscriptionCache(ctx, subscription.ID, subscription.Data, err.Error())
			continue
		}
		data, readErr := io.ReadAll(io.LimitReader(response.Body, maxCalendarSubscriptionBytes+1))
		response.Body.Close()
		if readErr != nil || response.StatusCode < 200 || response.StatusCode >= 300 || len(data) > maxCalendarSubscriptionBytes {
			message := fmt.Sprintf("HTTP %d", response.StatusCode)
			if readErr != nil {
				message = readErr.Error()
			} else if len(data) > maxCalendarSubscriptionBytes {
				message = "订阅文件超过 10MB"
			}
			_ = s.store.UpdateCalendarSubscriptionCache(ctx, subscription.ID, subscription.Data, message)
			continue
		}
		subscription.Data = data
		_ = s.store.UpdateCalendarSubscriptionCache(ctx, subscription.ID, data, "")
	}
	return subscriptions
}

func appendSubscriptionEvents(events []apiCalendarEvent, subscriptions []*store.CalendarSubscription, from, to time.Time) []apiCalendarEvent {
	for _, subscription := range subscriptions {
		if len(subscription.Data) == 0 {
			continue
		}
		parsed, err := ical.Load(subscription.Data, "UTC")
		if err != nil {
			continue
		}
		instances, err := parsed.ExpandObject(from, to, 500)
		if err != nil {
			continue
		}
		for _, instance := range instances {
			comp := instance.Component
			if comp == nil || comp.Name != "VEVENT" {
				continue
			}
			summary := strings.TrimSpace(ical.UnescapeText(comp.Value("SUMMARY")))
			if summary == "" {
				summary = "未命名事件"
			}
			key := fmt.Sprintf("subscription-%d-%s-%d", subscription.ID, comp.Value("UID"), instance.Start.Unix())
			events = append(events, apiCalendarEvent{
				ID: key, UID: strings.TrimSpace(comp.Value("UID")), Href: subscription.URL,
				CalendarID: -subscription.ID, CalendarName: subscription.Name, Color: subscription.Color,
				Summary: summary, Location: strings.TrimSpace(ical.UnescapeText(comp.Value("LOCATION"))),
				Description: strings.TrimSpace(ical.UnescapeText(comp.Value("DESCRIPTION"))),
				Start:       instance.Start.Format(time.RFC3339), End: instance.End.Format(time.RFC3339),
				AllDay: instance.AllDay, Recurring: strings.TrimSpace(comp.Value("RRULE")) != "",
				ReadOnly: true,
			})
		}
	}
	return events
}

func appendHolidayEvents(events []apiCalendarEvent, from, to time.Time) []apiCalendarEvent {
	loc := taskLocation("")
	type holiday struct {
		name string
		date time.Time
	}
	holidays := make([]holiday, 0, 48)
	for year := from.In(loc).Year() - 1; year <= to.In(loc).Year()+1; year++ {
		holidays = append(holidays,
			holiday{"元旦", time.Date(year, 1, 1, 0, 0, 0, 0, loc)},
			holiday{"劳动节", time.Date(year, 5, 1, 0, 0, 0, 0, loc)},
			holiday{"国庆节", time.Date(year, 10, 1, 0, 0, 0, 0, loc)},
			holiday{"圣诞节", time.Date(year, 12, 25, 0, 0, 0, 0, loc)},
		)
		for _, lunar := range []struct {
			name  string
			month int
			day   int
		}{
			{"春节", 1, 1}, {"元宵节", 1, 15}, {"端午节", 5, 5}, {"中秋节", 8, 15},
		} {
			solar := lunarcalendar.NewLunarFromYmd(year, lunar.month, lunar.day).GetSolar()
			holidays = append(holidays, holiday{lunar.name, time.Date(solar.GetYear(), time.Month(solar.GetMonth()), solar.GetDay(), 0, 0, 0, 0, loc)})
		}
	}
	for _, item := range holidays {
		if item.date.Before(from.In(loc)) || !item.date.Before(to.In(loc)) {
			continue
		}
		start := item.date
		end := start.AddDate(0, 0, 1)
		events = append(events, apiCalendarEvent{
			ID: "holiday-" + start.Format("20060102") + "-" + item.name, UID: "holiday-" + start.Format("20060102") + "-" + item.name,
			CalendarID: 0, CalendarName: "节假日", Color: "#f0a020", Summary: item.name,
			Start: start.Format(time.RFC3339), End: end.Format(time.RFC3339), AllDay: true, ReadOnly: true,
		})
	}
	return events
}

func subscriptionSources(subscriptions []*store.CalendarSubscription) []apiCalendarSource {
	out := make([]apiCalendarSource, 0, len(subscriptions))
	for _, subscription := range subscriptions {
		out = append(out, apiCalendarSource{ID: -subscription.ID, Name: subscription.Name, Color: subscription.Color})
	}
	return out
}
