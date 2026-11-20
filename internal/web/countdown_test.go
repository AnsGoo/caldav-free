package web

import (
	"encoding/json"
	"net/http"
	"strconv"
	"testing"
	"time"
)

func TestCountdownAPI(t *testing.T) {
	env := newAPIEnv(t)
	// 日期必须用 time.Time 递推。早先这里把 yyyymmdd 当整数做 +1/+2，
	// 落在月末时会拼出 20261131 这种不存在的日期（今天+10 = 11-30，
	// 于是 +1 直接 400），测试结果随运行日期漂移。
	base := time.Now().AddDate(0, 0, 10)
	date := countdownDay(base)
	status, body := env.request(t, "POST", "/api/admin/countdowns", map[string]any{
		"name": "发布日", "type": "countdown", "date": date, "repeat": "none", "reminders": "[0,3]", "reminderTime": "08:30",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create countdown = %d: %s", status, body)
	}
	var created struct {
		Countdown struct {
			ID    int64  `json:"id"`
			Days  int    `json:"days"`
			State string `json:"state"`
		} `json:"countdown"`
	}
	if err := json.Unmarshal(body, &created); err != nil {
		t.Fatal(err)
	}
	if created.Countdown.ID == 0 || created.Countdown.State != "future" {
		t.Fatalf("unexpected countdown: %+v", created.Countdown)
	}
	status, body = env.request(t, "PATCH", "/api/admin/countdowns/"+strconv.FormatInt(created.Countdown.ID, 10), map[string]any{
		"pinned": true, "status": 1,
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("update countdown = %d: %s", status, body)
	}
	status, body = env.request(t, "POST", "/api/admin/countdowns", map[string]any{
		"name": "第二项", "type": "countdown", "date": countdownDay(base.AddDate(0, 0, 1)), "repeat": "none",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("second countdown = %d: %s", status, body)
	}
	var second struct {
		Countdown struct {
			ID int64 `json:"id"`
		} `json:"countdown"`
	}
	if err := json.Unmarshal(body, &second); err != nil {
		t.Fatal(err)
	}
	status, body = env.request(t, "POST", "/api/admin/countdowns", map[string]any{
		"name": "第三项", "type": "countdown", "date": countdownDay(base.AddDate(0, 0, 2)), "repeat": "none",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("third countdown = %d: %s", status, body)
	}
	var third struct {
		Countdown struct {
			ID int64 `json:"id"`
		} `json:"countdown"`
	}
	if err := json.Unmarshal(body, &third); err != nil {
		t.Fatal(err)
	}
	status, body = env.request(t, "POST", "/api/admin/countdowns/reorder", map[string]any{
		"ids": []int64{third.Countdown.ID, second.Countdown.ID},
	}, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("reorder countdowns = %d: %s", status, body)
	}
	status, body = env.request(t, "GET", "/api/admin/countdowns", nil, "")
	if status != http.StatusOK {
		t.Fatalf("list reordered = %d: %s", status, body)
	}
	var reordered struct {
		Countdowns []struct {
			ID int64 `json:"id"`
		} `json:"countdowns"`
	}
	if err := json.Unmarshal(body, &reordered); err != nil {
		t.Fatal(err)
	}
	if len(reordered.Countdowns) < 2 || reordered.Countdowns[0].ID != third.Countdown.ID {
		t.Fatalf("unexpected reorder: %+v", reordered.Countdowns)
	}

	status, body = env.request(t, "GET", "/api/admin/countdowns?archived=1", nil, "")
	if status != http.StatusOK {
		t.Fatalf("list countdowns = %d: %s", status, body)
	}
	var list struct {
		Countdowns []map[string]any `json:"countdowns"`
	}
	if err := json.Unmarshal(body, &list); err != nil {
		t.Fatal(err)
	}
	if len(list.Countdowns) != 1 {
		t.Fatalf("countdown list = %d", len(list.Countdowns))
	}
	status, _ = env.request(t, "DELETE", "/api/admin/countdowns/"+strconv.FormatInt(created.Countdown.ID, 10), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete countdown = %d", status)
	}
}

// countdownDay 把时间转成接口要求的 yyyymmdd 整数。
func countdownDay(t time.Time) int {
	day, _ := strconv.Atoi(t.Format("20060102"))
	return day
}
