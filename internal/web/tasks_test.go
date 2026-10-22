package web

import (
	"net/http"
	"testing"
)

type taskResponse struct {
	Task struct {
		ID        int64    `json:"id"`
		ListID    int64    `json:"listId"`
		Title     string   `json:"title"`
		Priority  int      `json:"priority"`
		Due       string   `json:"due"`
		AllDay    bool     `json:"allDay"`
		Tags      []string `json:"tags"`
		Completed bool     `json:"completed"`
	} `json:"task"`
}

type workspaceResponse struct {
	Lists []struct {
		ID      int64  `json:"id"`
		Name    string `json:"name"`
		IsInbox bool   `json:"isInbox"`
		Count   int64  `json:"count"`
	} `json:"lists"`
	Tasks []struct {
		ID        int64  `json:"id"`
		Title     string `json:"title"`
		Completed bool   `json:"completed"`
		ListName  string `json:"listName"`
	} `json:"tasks"`
	Counts struct {
		All       int64 `json:"all"`
		Today     int64 `json:"today"`
		Next7     int64 `json:"next7"`
		Inbox     int64 `json:"inbox"`
		Completed int64 `json:"completed"`
	} `json:"counts"`
	Tags  []string `json:"tags"`
	Inbox int64    `json:"inbox"`
}

func TestTaskAPIWorkspaceAndQuickAdd(t *testing.T) {
	env := newAPIEnv(t)

	status, body := env.request(t, "GET", "/api/admin/tasks", nil, "")
	if status != http.StatusOK {
		t.Fatalf("workspace = %d: %s", status, body)
	}
	workspace := decode[workspaceResponse](t, body)
	if len(workspace.Lists) != 1 || !workspace.Lists[0].IsInbox || workspace.Lists[0].Name != "收集箱" {
		t.Fatalf("unexpected lists: %+v", workspace.Lists)
	}

	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"text": "明天下午3点和张三开会 #工作 !!", "timezone": "Asia/Shanghai",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create task = %d: %s", status, body)
	}
	created := decode[taskResponse](t, body)
	if created.Task.Title != "和张三开会" {
		t.Fatalf("title not parsed: %q", created.Task.Title)
	}
	if created.Task.Priority != 2 {
		t.Fatalf("priority = %d, want 2", created.Task.Priority)
	}
	if len(created.Task.Tags) != 1 || created.Task.Tags[0] != "工作" {
		t.Fatalf("tags = %v", created.Task.Tags)
	}
	if created.Task.Due == "" || created.Task.AllDay {
		t.Fatalf("due = %q allDay=%v", created.Task.Due, created.Task.AllDay)
	}
	if created.Task.ListID != workspace.Inbox {
		t.Fatalf("task list = %d, want inbox %d", created.Task.ListID, workspace.Inbox)
	}

	// completed can be supplied at creation time.
	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "已经做完的事", "completed": true,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create completed task = %d: %s", status, body)
	}
	if done := decode[taskResponse](t, body); !done.Task.Completed {
		t.Fatal("completed was not persisted on create")
	}

	status, body = env.request(t, "GET", "/api/admin/tasks?view=all", nil, "")
	if status != http.StatusOK {
		t.Fatalf("workspace = %d: %s", status, body)
	}
	workspace = decode[workspaceResponse](t, body)
	if len(workspace.Tasks) != 2 || workspace.Counts.All != 1 || workspace.Counts.Completed != 1 || workspace.Counts.Inbox != 1 {
		t.Fatalf("unexpected workspace: %+v", workspace)
	}
	if len(workspace.Tags) != 1 || workspace.Tags[0] != "工作" {
		t.Fatalf("tags = %v", workspace.Tags)
	}
}

func TestTaskAPIListLifecycle(t *testing.T) {
	env := newAPIEnv(t)

	status, body := env.request(t, "POST", "/api/admin/task-lists", map[string]any{
		"name": "工作", "color": "#f59e0b",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create list = %d: %s", status, body)
	}
	var list struct {
		List struct {
			ID   int64  `json:"id"`
			Name string `json:"name"`
		} `json:"list"`
	}
	list = decode[struct {
		List struct {
			ID   int64  `json:"id"`
			Name string `json:"name"`
		} `json:"list"`
	}](t, body)
	if list.List.ID == 0 {
		t.Fatalf("missing list id: %s", body)
	}

	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "提交周报", "listId": list.List.ID, "priority": 3,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create task = %d: %s", status, body)
	}
	created := decode[taskResponse](t, body)
	if created.Task.ListID != list.List.ID {
		t.Fatalf("task list = %d", created.Task.ListID)
	}

	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+itoa(created.Task.ID), map[string]any{
		"completed": true,
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("complete task = %d: %s", status, body)
	}
	completed := decode[taskResponse](t, body)
	if !completed.Task.Completed {
		t.Fatal("task not completed")
	}

	status, body = env.request(t, "GET", "/api/admin/tasks?view=completed", nil, "")
	if status != http.StatusOK {
		t.Fatalf("workspace = %d: %s", status, body)
	}
	workspace := decode[workspaceResponse](t, body)
	if workspace.Counts.Completed != 1 || len(workspace.Tasks) != 1 {
		t.Fatalf("completed view: %+v", workspace)
	}

	status, body = env.request(t, "DELETE", "/api/admin/task-lists/"+itoa(list.List.ID), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete list = %d: %s", status, body)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?view=all", nil, "")
	if status != http.StatusOK {
		t.Fatalf("workspace = %d: %s", status, body)
	}
	workspace = decode[workspaceResponse](t, body)
	if len(workspace.Lists) != 1 {
		t.Fatalf("lists after delete: %+v", workspace.Lists)
	}
}

func TestTaskAPIValidation(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/tasks", map[string]any{"title": "  "}, env.csrf)
	if status != http.StatusBadRequest {
		t.Fatalf("empty title = %d: %s", status, body)
	}
	status, body = env.request(t, "POST", "/api/admin/task-lists", map[string]any{"name": "收集箱"}, env.csrf)
	if status != http.StatusConflict {
		t.Fatalf("duplicate inbox = %d: %s", status, body)
	}
	status, _ = env.request(t, "POST", "/api/admin/tasks", map[string]any{"title": "没有 CSRF"}, "")
	if status != http.StatusForbidden {
		t.Fatalf("csrf = %d, want 403", status)
	}
}
