package web

import (
	"net/http"
	"net/url"
	"testing"
	"time"
)

func TestTaskAPISummary(t *testing.T) {
	env := newAPIEnv(t)
	now := time.Now()
	loc := time.FixedZone("CST", 8*3600)
	from := time.Date(now.In(loc).Year(), now.In(loc).Month(), now.In(loc).Day(), 0, 0, 0, 0, loc)
	to := from.AddDate(0, 0, 1)

	payloads := []map[string]any{
		{"title": "已完成任务", "completed": true, "tags": []string{"工作"}, "priority": 3},
		{"title": "今天到期", "due": now.Format(time.RFC3339), "tags": []string{"工作"}, "priority": 2},
		{"title": "无日期任务", "tags": []string{"生活"}},
	}
	for _, payload := range payloads {
		status, body := env.request(t, "POST", "/api/admin/tasks", payload, env.csrf)
		if status != http.StatusCreated {
			t.Fatalf("create = %d: %s", status, body)
		}
	}
	query := "?from=" + url.QueryEscape(from.Format(time.RFC3339)) + "&to=" + url.QueryEscape(to.Format(time.RFC3339))
	status, body := env.request(t, "GET", "/api/admin/tasks/summary"+query, nil, "")
	if status != http.StatusOK {
		t.Fatalf("summary = %d: %s", status, body)
	}
	result := decode[struct {
		Title string `json:"title"`
		Tasks []struct {
			Title     string `json:"title"`
			Completed bool   `json:"completed"`
		} `json:"tasks"`
		Counts map[string]int `json:"counts"`
	}](t, body)
	if len(result.Tasks) != 3 || result.Counts["completed"] != 1 || result.Counts["open"] != 2 {
		t.Fatalf("unexpected summary: %+v", result)
	}
	if !result.Tasks[0].Completed {
		t.Fatal("completed tasks should sort first")
	}

	status, body = env.request(t, "GET", "/api/admin/tasks/summary"+query+"&status=completed", nil, "")
	if status != http.StatusOK {
		t.Fatalf("summary = %d: %s", status, body)
	}
	filtered := decode[struct {
		Tasks []struct {
			Title string `json:"title"`
		} `json:"tasks"`
	}](t, body)
	if len(filtered.Tasks) != 1 || filtered.Tasks[0].Title != "已完成任务" {
		t.Fatalf("status filter: %+v", filtered.Tasks)
	}

	status, body = env.request(t, "GET", "/api/admin/tasks/summary"+query+"&status=open&tag=%E7%94%9F%E6%B4%BB", nil, "")
	if status != http.StatusOK {
		t.Fatalf("summary = %d: %s", status, body)
	}
	tagged := decode[struct {
		Tasks []struct {
			Title string `json:"title"`
		} `json:"tasks"`
	}](t, body)
	if len(tagged.Tasks) != 1 || tagged.Tasks[0].Title != "无日期任务" {
		t.Fatalf("tag filter: %+v", tagged.Tasks)
	}
}

func TestTaskAPISummaryNextCycle(t *testing.T) {
	env := newAPIEnv(t)
	loc := time.FixedZone("CST", 8*3600)
	from := time.Date(2026, 10, 22, 0, 0, 0, 0, loc)
	to := from.AddDate(0, 0, 1)
	tomorrow := from.AddDate(0, 0, 1).Add(10 * time.Hour)
	status, body := env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "下一周期", "due": tomorrow.Format(time.RFC3339),
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create = %d: %s", status, body)
	}
	query := "?from=" + url.QueryEscape(from.Format(time.RFC3339)) + "&to=" + url.QueryEscape(to.Format(time.RFC3339)) + "&includeNext=1"
	status, body = env.request(t, "GET", "/api/admin/tasks/summary"+query, nil, "")
	if status != http.StatusOK {
		t.Fatalf("summary = %d: %s", status, body)
	}
	result := decode[struct {
		NextTasks []struct {
			Title string `json:"title"`
		} `json:"nextTasks"`
	}](t, body)
	if len(result.NextTasks) != 1 || result.NextTasks[0].Title != "下一周期" {
		t.Fatalf("next tasks: %+v", result.NextTasks)
	}
}
