package web

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"caldav-free/internal/ical"
	"caldav-free/internal/store"
)

type eventPatchBody struct {
	Summary      string `json:"summary"`
	Location     string `json:"location"`
	Description  string `json:"description"`
	Start        string `json:"start"`
	End          string `json:"end"`
	AllDay       bool   `json:"allDay"`
	RRule        string `json:"rrule"`
	Count        int    `json:"count"`
	RecurrenceID string `json:"recurrenceId"`
	Scope        string `json:"scope"`
	Reminders    []int  `json:"reminders"`
}

func parseOccurrenceID(raw string, loc *time.Location) (time.Time, bool, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, false, errors.New("缺少重复实例时间")
	}
	allDay := !strings.Contains(raw, "T")
	for _, layout := range []string{time.RFC3339, "2006-01-02T15:04", "2006-01-02 15:04", "2006-01-02"} {
		if parsed, err := time.ParseInLocation(layout, raw, loc); err == nil {
			return parsed.In(loc), allDay, nil
		}
	}
	return time.Time{}, allDay, fmt.Errorf("重复实例时间格式无效")
}

func masterEvent(parsed *ical.Calendar) *ical.Component {
	for _, comp := range parsed.Root.ChildrenNamed("VEVENT") {
		if comp.Get("RECURRENCE-ID") == nil {
			return comp
		}
	}
	return nil
}

func buildOccurrenceUpdate(cal *store.Calendar, obj *store.Object, body eventPatchBody, start, end time.Time, tzid string) ([]byte, error) {
	parsed, err := ical.Load(obj.Data, cal.Timezone)
	if err != nil {
		return nil, fmt.Errorf("事件数据无效：%w", err)
	}
	master := masterEvent(parsed)
	if master == nil {
		return nil, errors.New("事件没有主重复规则")
	}
	uid := strings.TrimSpace(master.Value("UID"))
	if uid == "" {
		uid = obj.UID
	}
	loc, _ := time.LoadLocation(cal.Timezone)
	rid, ridAllDay, err := parseOccurrenceID(body.RecurrenceID, loc)
	if err != nil {
		return nil, err
	}
	data, _, err := buildEventICS(cal, uid, body.Summary, body.Location, body.Description, start, end, body.AllDay, tzid, "", 0, body.Reminders)
	if err != nil {
		return nil, err
	}
	built, err := ical.Load(data, cal.Timezone)
	if err != nil {
		return nil, fmt.Errorf("事件数据无效：%w", err)
	}
	child := built.Root.Child("VEVENT")
	if child == nil {
		return nil, errors.New("无法生成重复实例")
	}
	if ridAllDay {
		child.AddProp("RECURRENCE-ID", rid.Format("20060102"), ical.Params{"VALUE": {"DATE"}})
	} else {
		child.AddProp("RECURRENCE-ID", rid.Format("20060102T150405"), ical.Params{"TZID": {tzid}})
	}
	replaced := false
	for index, comp := range parsed.Root.Children {
		if comp.Name != "VEVENT" || comp.Get("RECURRENCE-ID") == nil {
			continue
		}
		tv, err := parsed.ParseTimeProp(comp.Get("RECURRENCE-ID"))
		if err != nil {
			continue
		}
		if tv.Time.UTC().Equal(rid.UTC()) {
			parsed.Root.Children[index] = child
			replaced = true
			break
		}
	}
	if !replaced {
		parsed.Root.AddChild(child)
	}
	return []byte(parsed.Root.Encode()), nil
}

func buildOccurrenceDelete(cal *store.Calendar, obj *store.Object, recurrenceID string) ([]byte, error) {
	parsed, err := ical.Load(obj.Data, cal.Timezone)
	if err != nil {
		return nil, fmt.Errorf("事件数据无效：%w", err)
	}
	master := masterEvent(parsed)
	if master == nil {
		return nil, errors.New("事件没有主重复规则")
	}
	loc, _ := time.LoadLocation(cal.Timezone)
	rid, ridAllDay, err := parseOccurrenceID(recurrenceID, loc)
	if err != nil {
		return nil, err
	}
	// Remove an existing exception for the same occurrence.
	for index := len(parsed.Root.Children) - 1; index >= 0; index-- {
		comp := parsed.Root.Children[index]
		if comp.Name != "VEVENT" || comp.Get("RECURRENCE-ID") == nil {
			continue
		}
		tv, err := parsed.ParseTimeProp(comp.Get("RECURRENCE-ID"))
		if err == nil && tv.Time.UTC().Equal(rid.UTC()) {
			parsed.Root.Children = append(parsed.Root.Children[:index], parsed.Root.Children[index+1:]...)
		}
	}
	if ridAllDay {
		master.AddProp("EXDATE", rid.Format("20060102"), ical.Params{"VALUE": {"DATE"}})
	} else {
		_, tzid := calendarLocation(cal.Timezone)
		master.AddProp("EXDATE", rid.Format("20060102T150405"), ical.Params{"TZID": {tzid}})
	}
	return []byte(parsed.Root.Encode()), nil
}
