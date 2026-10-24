package web

import (
	"encoding/json"
	"net/http"
	"strconv"
	"testing"
	"time"
)

func TestFocusAPI(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "GET", "/api/admin/focus", nil, "")
	if status != http.StatusOK {
		t.Fatalf("focus = %d: %s", status, body)
	}
	var initial struct {
		Preferences struct {
			PomodoroMinutes int `json:"pomodoroMinutes"`
		} `json:"preferences"`
	}
	if err := json.Unmarshal(body, &initial); err != nil {
		t.Fatal(err)
	}
	if initial.Preferences.PomodoroMinutes != 25 {
		t.Fatalf("default pomodoro = %d", initial.Preferences.PomodoroMinutes)
	}

	prefs := map[string]any{
		"pomodoroMinutes": 40, "shortBreakMinutes": 6, "longBreakMinutes": 20,
		"longBreakInterval": 3, "dailyGoal": 5, "autoStartPomodoro": true,
		"autoStartBreak": false, "soundEnabled": false, "tabTitleEnabled": true,
	}
	status, body = env.request(t, "PATCH", "/api/admin/focus/preferences", prefs, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("preferences = %d: %s", status, body)
	}

	now := time.Now()
	status, body = env.request(t, "POST", "/api/admin/focus/sessions", map[string]any{
		"mode": "pomodoro", "startedAt": now.Add(-25 * time.Minute).Format(time.RFC3339Nano),
		"endedAt": now.Format(time.RFC3339Nano), "durationSeconds": 1500,
		"pomodoroCount": 1, "note": "API 测试",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create session = %d: %s", status, body)
	}
	var created struct {
		Session struct {
			ID int64 `json:"id"`
		} `json:"session"`
	}
	if err := json.Unmarshal(body, &created); err != nil {
		t.Fatal(err)
	}
	if created.Session.ID == 0 {
		t.Fatal("session id is empty")
	}

	status, body = env.request(t, "GET", "/api/admin/focus", nil, "")
	if status != http.StatusOK {
		t.Fatalf("dashboard = %d: %s", status, body)
	}
	var dashboard struct {
		Stats struct {
			TodayPomodoroCount int `json:"todayPomodoroCount"`
			TodayFocusMinutes  int `json:"todayFocusMinutes"`
		} `json:"stats"`
	}
	if err := json.Unmarshal(body, &dashboard); err != nil {
		t.Fatal(err)
	}
	if dashboard.Stats.TodayPomodoroCount != 1 || dashboard.Stats.TodayFocusMinutes != 25 {
		t.Fatalf("unexpected stats: %+v", dashboard.Stats)
	}

	status, body = env.request(t, "DELETE", "/api/admin/focus/sessions/"+strconv.FormatInt(created.Session.ID, 10), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete session = %d: %s", status, body)
	}
}
