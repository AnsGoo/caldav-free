package web

import (
	"net/http"
	"testing"
	"time"
)

func TestTaskAPIStats(t *testing.T) {
	env := newAPIEnv(t)
	past := time.Now().AddDate(0, 0, -1)
	future := time.Now().AddDate(0, 0, 3)

	payloads := []map[string]any{
		{"title": "逾期任务", "due": past.Format(time.RFC3339), "tags": []string{"工作"}, "priority": 3},
		{"title": "今天任务", "due": time.Now().Format(time.RFC3339), "tags": []string{"工作", "生活"}, "priority": 2},
		{"title": "未来完成", "due": future.Format(time.RFC3339), "completed": true, "tags": []string{"生活"}, "priority": 1},
	}
	for _, payload := range payloads {
		status, body := env.request(t, "POST", "/api/admin/tasks", payload, env.csrf)
		if status != http.StatusCreated {
			t.Fatalf("create = %d: %s", status, body)
		}
	}
	status, body := env.request(t, "GET", "/api/admin/tasks/stats?days=30", nil, "")
	if status != http.StatusOK {
		t.Fatalf("stats = %d: %s", status, body)
	}
	result := decode[struct {
		Stats struct {
			Open               int     `json:"open"`
			Completed          int     `json:"completed"`
			Overdue            int     `json:"overdue"`
			Today              int     `json:"today"`
			CompletionRate     float64 `json:"completionRate"`
			CompletedInPeriod  int     `json:"completedInPeriod"`
			OnTimeInPeriod     int     `json:"onTimeInPeriod"`
			AvgCompletionHours float64 `json:"avgCompletionHours"`
			Daily              []struct {
				Date      string `json:"date"`
				Created   int    `json:"created"`
				Completed int    `json:"completed"`
			} `json:"daily"`
			Lists []struct {
				Name      string `json:"name"`
				Open      int    `json:"open"`
				Completed int    `json:"completed"`
				Overdue   int    `json:"overdue"`
			} `json:"lists"`
			Tags []struct {
				Name      string `json:"name"`
				Open      int    `json:"open"`
				Completed int    `json:"completed"`
			} `json:"tags"`
			Priorities []struct {
				Priority  int `json:"priority"`
				Open      int `json:"open"`
				Completed int `json:"completed"`
			} `json:"priorities"`
		} `json:"stats"`
	}](t, body)
	stats := result.Stats
	if stats.Open != 2 || stats.Completed != 1 || stats.Overdue < 1 || stats.Today < 1 {
		t.Fatalf("unexpected totals: %+v", stats)
	}
	if stats.CompletionRate < 33 || stats.CompletionRate > 34 {
		t.Fatalf("completion rate = %v", stats.CompletionRate)
	}
	if stats.CompletedInPeriod != 1 || stats.OnTimeInPeriod != 1 {
		t.Fatalf("period completion = %d ontime=%d", stats.CompletedInPeriod, stats.OnTimeInPeriod)
	}
	if len(stats.Daily) != 30 {
		t.Fatalf("daily length = %d", len(stats.Daily))
	}
	today := stats.Daily[len(stats.Daily)-1]
	if today.Created != 3 || today.Completed != 1 {
		t.Fatalf("today daily = %+v", today)
	}
	if len(stats.Lists) != 1 || stats.Lists[0].Open != 2 || stats.Lists[0].Completed != 1 {
		t.Fatalf("lists = %+v", stats.Lists)
	}
	if len(stats.Tags) != 2 {
		t.Fatalf("tags = %+v", stats.Tags)
	}
	if len(stats.Priorities) != 4 {
		t.Fatalf("priorities = %+v", stats.Priorities)
	}
}
