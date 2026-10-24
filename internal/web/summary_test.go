package web

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
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

func TestSummaryDocumentsAPI(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/task-summary-documents", map[string]any{
		"kind": "template", "name": "周报模板", "content": "## 周报", "format": "markdown",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create doc = %d: %s", status, body)
	}
	created := decode[struct {
		Document struct {
			ID     int64  `json:"id"`
			Kind   string `json:"kind"`
			Format string `json:"format"`
		} `json:"document"`
	}](t, body)
	if created.Document.ID == 0 || created.Document.Kind != "template" || created.Document.Format != "markdown" {
		t.Fatalf("unexpected doc: %+v", created.Document)
	}
	status, body = env.request(t, "GET", "/api/admin/task-summary-documents?kind=template", nil, "")
	if status != http.StatusOK {
		t.Fatalf("list docs = %d: %s", status, body)
	}
	list := decode[struct {
		Documents []struct {
			ID     int64  `json:"id"`
			Name   string `json:"name"`
			Format string `json:"format"`
		} `json:"documents"`
	}](t, body)
	if len(list.Documents) != 1 || list.Documents[0].Name != "周报模板" || list.Documents[0].Format != "markdown" {
		t.Fatalf("unexpected docs: %+v", list.Documents)
	}
	status, body = env.request(t, "PATCH", "/api/admin/task-summary-documents/"+itoa(created.Document.ID), map[string]any{
		"name": "周报模板 2", "content": "## 新周报", "format": "markdown",
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("update doc = %d: %s", status, body)
	}
	status, _ = env.request(t, "DELETE", "/api/admin/task-summary-documents/"+itoa(created.Document.ID), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete doc = %d", status)
	}

	status, body = env.request(t, "POST", "/api/admin/task-summary-documents", map[string]any{
		"kind": "template", "name": "旧模板", "content": "<h2>旧</h2>",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create legacy doc = %d: %s", status, body)
	}
	legacy := decode[struct {
		Document struct {
			ID     int64  `json:"id"`
			Format string `json:"format"`
		} `json:"document"`
	}](t, body)
	if legacy.Document.Format != "html" {
		t.Fatalf("legacy format = %q", legacy.Document.Format)
	}
}

func TestSummaryOptimizeAPI(t *testing.T) {
	env := newAPIEnv(t)
	ctx := context.Background()
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"choices":[{"message":{"role":"assistant","content":"## 优化后的摘要\n- 已完成：研发日报"}}]}`))
	}))
	defer upstream.Close()
	if err := env.store.SetSetting(ctx, settingAIBaseURL, upstream.URL); err != nil {
		t.Fatal(err)
	}
	if err := env.store.SetSetting(ctx, settingAIModel, "mock-model"); err != nil {
		t.Fatal(err)
	}
	status, body := env.request(t, "POST", "/api/admin/tasks/summary/optimize", map[string]any{
		"title": "9月摘要", "text": "已完成\n- 研发日报",
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("optimize = %d: %s", status, body)
	}
	result := decode[struct {
		Markdown string `json:"markdown"`
	}](t, body)
	if !strings.Contains(result.Markdown, "优化后的摘要") {
		t.Fatalf("unexpected markdown: %q", result.Markdown)
	}
}
