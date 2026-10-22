package web

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"caldav-free/internal/ical"
	"caldav-free/internal/store"
	"caldav-free/internal/tasksync"
)

type taskResponse struct {
	Task struct {
		ID             int64    `json:"id"`
		ListID         int64    `json:"listId"`
		Title          string   `json:"title"`
		Priority       int      `json:"priority"`
		Due            string   `json:"due"`
		AllDay         bool     `json:"allDay"`
		Tags           []string `json:"tags"`
		Completed      bool     `json:"completed"`
		Recurrence     string   `json:"recurrence"`
		ReminderOffset int      `json:"reminderOffset"`
		Order          int      `json:"order"`
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
		Order     int    `json:"order"`
	} `json:"tasks"`
	Counts struct {
		All       int64 `json:"all"`
		Today     int64 `json:"today"`
		Next7     int64 `json:"next7"`
		Inbox     int64 `json:"inbox"`
		Completed int64 `json:"completed"`
		Trash     int64 `json:"trash"`
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

func TestTaskAPICalDAVSync(t *testing.T) {
	env := newAPIEnv(t)
	ctx := context.Background()

	status, body := env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "本地任务", "priority": 2,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create task = %d: %s", status, body)
	}
	created := decode[taskResponse](t, body)

	cal, err := env.store.GetCalendarBySlug(ctx, env.userID, tasksync.CalendarSlug)
	if err != nil {
		t.Fatalf("task calendar: %v", err)
	}
	stored, err := env.store.GetTask(ctx, env.userID, created.Task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if stored.VTODOUID == "" || stored.VTODOHref == "" {
		t.Fatalf("task has no caldav identity: %+v", stored)
	}
	obj, err := env.store.GetObject(ctx, cal.ID, stored.VTODOHref)
	if err != nil {
		t.Fatalf("VTODO object missing: %v", err)
	}
	if !strings.Contains(string(obj.Data), "SUMMARY:本地任务") {
		t.Fatalf("unexpected VTODO: %s", obj.Data)
	}

	// A VTODO written by a CalDAV client is imported on the next workspace load.
	root := ical.NewComponent("VCALENDAR")
	root.AddProp("VERSION", "2.0", nil)
	root.AddProp("PRODID", "-//test//EN", nil)
	todo := ical.NewComponent("VTODO")
	todo.AddProp("UID", "dav-client@example.test", nil)
	todo.AddProp("SUMMARY", "来自客户端的任务", nil)
	todo.AddProp("STATUS", "NEEDS-ACTION", nil)
	root.AddChild(todo)
	data := []byte(root.Encode())
	external := &store.Object{
		CalendarID: cal.ID, Href: "dav-client.ics", UID: "dav-client@example.test",
		ETag: "external-etag", ContentType: "text/calendar; charset=utf-8", Data: data,
		ComponentType: "VTODO", Size: int64(len(data)),
	}
	if _, _, _, err := env.store.PutObject(ctx, external); err != nil {
		t.Fatal(err)
	}

	status, body = env.request(t, "GET", "/api/admin/tasks?view=all", nil, "")
	if status != http.StatusOK {
		t.Fatalf("workspace = %d: %s", status, body)
	}
	workspace := decode[workspaceResponse](t, body)
	found := false
	for _, task := range workspace.Tasks {
		if task.Title == "来自客户端的任务" {
			found = true
		}
	}
	if !found {
		t.Fatalf("external task not imported: %+v", workspace.Tasks)
	}

	// Deleting locally removes the VTODO so it cannot be re-imported.
	status, body = env.request(t, "DELETE", "/api/admin/tasks/"+itoa(created.Task.ID), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete task = %d: %s", status, body)
	}
	if _, err := env.store.GetObject(ctx, cal.ID, stored.VTODOHref); err != store.ErrNotFound {
		t.Fatalf("object still present after delete: %v", err)
	}
}

func TestTaskAPIRecurrenceReminderAndTrash(t *testing.T) {
	env := newAPIEnv(t)
	ctx := context.Background()

	// A recurring task advances instead of completing.
	status, body := env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "每日站会", "due": time.Date(2026, 10, 26, 9, 0, 0, 0, time.UTC).Format(time.RFC3339),
		"recurrence": "FREQ=DAILY", "reminderOffset": 15,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create recurring = %d: %s", status, body)
	}
	created := decode[taskResponse](t, body)
	if created.Task.Recurrence != "FREQ=DAILY" || created.Task.ReminderOffset != 15 {
		t.Fatalf("recurrence/reminder not stored: %+v", created.Task)
	}
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+itoa(created.Task.ID), map[string]any{"completed": true}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("complete recurring = %d: %s", status, body)
	}
	advanced := decode[taskResponse](t, body)
	if advanced.Task.Completed {
		t.Fatal("recurring task should stay open")
	}
	if advanced.Task.Due != time.Date(2026, 10, 27, 9, 0, 0, 0, time.UTC).Format(time.RFC3339) {
		t.Fatalf("due not advanced: %s", advanced.Task.Due)
	}

	// The reminder endpoint returns it.
	status, body = env.request(t, "GET", "/api/admin/tasks/reminders", nil, "")
	if status != http.StatusOK {
		t.Fatalf("reminders = %d: %s", status, body)
	}
	reminders := decode[struct {
		Tasks []struct {
			ID       int64 `json:"id"`
			Reminder int   `json:"reminderOffset"`
		} `json:"tasks"`
	}](t, body)
	if len(reminders.Tasks) != 1 || reminders.Tasks[0].Reminder != 15 {
		t.Fatalf("unexpected reminders: %+v", reminders)
	}

	// Complete a normal task, delete it, restore it, then purge it.
	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{"title": "扔掉再捡回来"}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create = %d: %s", status, body)
	}
	normal := decode[taskResponse](t, body)
	status, _ = env.request(t, "DELETE", "/api/admin/tasks/"+itoa(normal.Task.ID), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete = %d", status)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?view=trash", nil, "")
	if status != http.StatusOK {
		t.Fatalf("trash = %d: %s", status, body)
	}
	trash := decode[workspaceResponse](t, body)
	if trash.Counts.Trash != 1 || len(trash.Tasks) != 1 {
		t.Fatalf("unexpected trash: %+v", trash)
	}
	status, body = env.request(t, "POST", "/api/admin/tasks/"+itoa(normal.Task.ID)+"/restore", nil, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("restore = %d: %s", status, body)
	}
	restored := decode[taskResponse](t, body)
	if restored.Task.ID != normal.Task.ID {
		t.Fatalf("restored wrong task: %+v", restored)
	}
	stored, err := env.store.GetTask(ctx, env.userID, normal.Task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if stored.VTODOUID == "" {
		t.Fatal("restored task was not re-pushed")
	}
	status, _ = env.request(t, "DELETE", "/api/admin/tasks/"+itoa(normal.Task.ID), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete again = %d", status)
	}
	status, _ = env.request(t, "DELETE", "/api/admin/tasks/"+itoa(normal.Task.ID)+"/purge", nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("purge = %d", status)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?view=trash", nil, "")
	if status != http.StatusOK {
		t.Fatalf("trash = %d: %s", status, body)
	}
	if trash = decode[workspaceResponse](t, body); trash.Counts.Trash != 0 {
		t.Fatalf("trash not purged: %+v", trash)
	}
}

func TestTaskAPIBatchAndReorder(t *testing.T) {
	env := newAPIEnv(t)
	var ids []int64
	for _, title := range []string{"第一", "第二", "第三"} {
		status, body := env.request(t, "POST", "/api/admin/tasks", map[string]any{"title": title}, env.csrf)
		if status != http.StatusCreated {
			t.Fatalf("create = %d: %s", status, body)
		}
		ids = append(ids, decode[taskResponse](t, body).Task.ID)
	}
	status, body := env.request(t, "POST", "/api/admin/tasks/batch", map[string]any{
		"ids": ids[:2], "action": "complete",
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("batch complete = %d: %s", status, body)
	}
	if result := decode[struct {
		Updated int `json:"updated"`
	}](t, body); result.Updated != 2 {
		t.Fatalf("updated = %d", result.Updated)
	}

	status, body = env.request(t, "POST", "/api/admin/tasks/batch", map[string]any{
		"ids": ids[:2], "action": "delete",
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("batch delete = %d: %s", status, body)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?view=trash", nil, "")
	if status != http.StatusOK {
		t.Fatalf("trash = %d: %s", status, body)
	}
	if trash := decode[workspaceResponse](t, body); trash.Counts.Trash != 2 {
		t.Fatalf("trash count = %d", trash.Counts.Trash)
	}

	status, _ = env.request(t, "POST", "/api/admin/tasks/reorder", map[string]any{"ids": []int64{ids[2]}}, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("reorder = %d", status)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?view=all", nil, "")
	if status != http.StatusOK {
		t.Fatalf("workspace = %d: %s", status, body)
	}
	workspace := decode[workspaceResponse](t, body)
	if len(workspace.Tasks) != 1 || workspace.Tasks[0].Order != 1 {
		t.Fatalf("unexpected order: %+v", workspace.Tasks)
	}
}
