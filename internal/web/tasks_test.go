package web

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"

	"caldav-free/internal/ical"
	"caldav-free/internal/store"
	"caldav-free/internal/tasksync"
)

type taskResponse struct {
	Task struct {
		ID              int64    `json:"id"`
		ListID          int64    `json:"listId"`
		Title           string   `json:"title"`
		Notes           string   `json:"notes"`
		NotesFormat     string   `json:"notesFormat"`
		NotesText       string   `json:"notesText"`
		Kind            string   `json:"kind"`
		SectionID       int64    `json:"sectionId"`
		ParentID        int64    `json:"parentId"`
		Priority        int      `json:"priority"`
		Start           string   `json:"start"`
		Due             string   `json:"due"`
		AllDay          bool     `json:"allDay"`
		Tags            []string `json:"tags"`
		Completed       bool     `json:"completed"`
		Recurrence      string   `json:"recurrence"`
		ReminderOffset  int      `json:"reminderOffset"`
		ReminderOffsets []int    `json:"reminderOffsets"`
		Order           int      `json:"order"`
		Pinned          bool     `json:"pinned"`
	} `json:"task"`
}

type workspaceResponse struct {
	Lists []struct {
		ID       int64  `json:"id"`
		Name     string `json:"name"`
		IsInbox  bool   `json:"isInbox"`
		FolderID int64  `json:"folderId"`
		Count    int64  `json:"count"`
	} `json:"lists"`
	Folders []struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
	} `json:"folders"`
	Sections []struct {
		ID     int64  `json:"id"`
		ListID int64  `json:"listId"`
		Name   string `json:"name"`
		Order  int    `json:"order"`
	} `json:"sections"`
	Tasks []struct {
		ID        int64    `json:"id"`
		Title     string   `json:"title"`
		Completed bool     `json:"completed"`
		ListName  string   `json:"listName"`
		Order     int      `json:"order"`
		Tags      []string `json:"tags"`
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
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+itoa(created.Task.ID), map[string]any{
		"reminderOffsets": []int{0, 15, 60},
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("update reminders = %d: %s", status, body)
	}
	updated := decode[taskResponse](t, body)
	if len(updated.Task.ReminderOffsets) != 3 || updated.Task.ReminderOffset != 60 {
		t.Fatalf("multiple reminders not stored: %+v", updated.Task)
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
	if len(reminders.Tasks) != 1 || reminders.Tasks[0].Reminder != 60 {
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

func TestTaskAPIFoldersTagsAndFilters(t *testing.T) {
	env := newAPIEnv(t)

	status, body := env.request(t, "POST", "/api/admin/task-folders", map[string]any{"name": "项目"}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create folder = %d: %s", status, body)
	}
	folder := decode[struct {
		Folder struct {
			ID int64 `json:"id"`
		} `json:"folder"`
	}](t, body)

	status, body = env.request(t, "POST", "/api/admin/task-lists", map[string]any{
		"name": "项目 A", "folderId": folder.Folder.ID,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create list = %d: %s", status, body)
	}
	list := decode[struct {
		List struct {
			ID       int64 `json:"id"`
			FolderID int64 `json:"folderId"`
		} `json:"list"`
	}](t, body)
	if list.List.FolderID != folder.Folder.ID {
		t.Fatalf("list folder = %d", list.List.FolderID)
	}

	for _, payload := range []map[string]any{
		{"title": "高优工作", "listId": list.List.ID, "priority": 3, "tags": []string{"工作"}},
		{"title": "低优生活", "listId": list.List.ID, "priority": 1, "tags": []string{"生活"}},
	} {
		status, body = env.request(t, "POST", "/api/admin/tasks", payload, env.csrf)
		if status != http.StatusCreated {
			t.Fatalf("create task = %d: %s", status, body)
		}
	}

	status, body = env.request(t, "POST", "/api/admin/task-filters", map[string]any{
		"name": "高优工作", "conditions": map[string]any{
			"listIds": []int64{list.List.ID}, "tags": []string{"工作"}, "priorities": []int{3},
			"status": "open", "date": "any",
		},
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create filter = %d: %s", status, body)
	}
	filter := decode[struct {
		Filter struct {
			ID int64 `json:"id"`
		} `json:"filter"`
	}](t, body)

	status, body = env.request(t, "GET", "/api/admin/tasks?filterId="+itoa(filter.Filter.ID), nil, "")
	if status != http.StatusOK {
		t.Fatalf("filter workspace = %d: %s", status, body)
	}
	filtered := decode[workspaceResponse](t, body)
	if len(filtered.Tasks) != 1 || filtered.Tasks[0].Title != "高优工作" {
		t.Fatalf("unexpected filtered tasks: %+v", filtered.Tasks)
	}
	if len(filtered.Folders) != 1 || filtered.Folders[0].Name != "项目" {
		t.Fatalf("folders = %+v", filtered.Folders)
	}

	status, body = env.request(t, "GET", "/api/admin/task-tags", nil, "")
	if status != http.StatusOK {
		t.Fatalf("tags = %d: %s", status, body)
	}
	tags := decode[struct {
		Tags []struct {
			Name  string `json:"name"`
			Count int    `json:"count"`
		} `json:"tags"`
	}](t, body)
	if len(tags.Tags) != 2 {
		t.Fatalf("tags = %+v", tags.Tags)
	}

	status, body = env.request(t, "POST", "/api/admin/task-tags/rename", map[string]any{
		"from": "工作", "to": "项目",
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("rename tag = %d: %s", status, body)
	}
	status, body = env.request(t, "GET", "/api/admin/task-filters", nil, "")
	if status != http.StatusOK {
		t.Fatalf("filters = %d: %s", status, body)
	}
	filterRows := decode[struct {
		Filters []struct {
			Conditions struct {
				Tags []string `json:"tags"`
			} `json:"conditions"`
		} `json:"filters"`
	}](t, body)
	if len(filterRows.Filters) != 1 || len(filterRows.Filters[0].Conditions.Tags) != 1 || filterRows.Filters[0].Conditions.Tags[0] != "项目" {
		t.Fatalf("filter tags not updated: %+v", filterRows.Filters)
	}

	status, body = env.request(t, "POST", "/api/admin/task-tags/delete", map[string]any{"tag": "生活"}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("delete tag = %d: %s", status, body)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?view=all", nil, "")
	if status != http.StatusOK {
		t.Fatalf("workspace = %d: %s", status, body)
	}
	workspace := decode[workspaceResponse](t, body)
	for _, task := range workspace.Tasks {
		for _, tag := range task.Tags {
			if tag == "工作" || tag == "生活" {
				t.Fatalf("tag not rewritten: %+v", task)
			}
		}
	}

	status, body = env.request(t, "PATCH", "/api/admin/task-filters/"+itoa(filter.Filter.ID), map[string]any{
		"name": "改名后的过滤器", "conditions": map[string]any{
			"tags": []string{"项目"}, "status": "open", "date": "any",
		},
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("update filter = %d: %s", status, body)
	}
	status, _ = env.request(t, "DELETE", "/api/admin/task-filters/"+itoa(filter.Filter.ID), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete filter = %d", status)
	}

	status, _ = env.request(t, "DELETE", "/api/admin/task-folders/"+itoa(folder.Folder.ID), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete folder = %d", status)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?view=all", nil, "")
	if status != http.StatusOK {
		t.Fatalf("workspace = %d: %s", status, body)
	}
	workspace = decode[workspaceResponse](t, body)
	for _, item := range workspace.Lists {
		if item.FolderID != 0 {
			t.Fatalf("list still in folder: %+v", item)
		}
	}
}

func TestTaskStartAndSubtaskHierarchy(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, http.MethodPost, "/api/admin/tasks", map[string]any{
		"title": "父任务", "start": "2026-10-28T09:00:00+08:00", "due": "2026-10-28T11:30:00+08:00", "allDay": false,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create parent = %d: %s", status, body)
	}
	parent := decode[taskResponse](t, body)
	if parent.Task.Start == "" || parent.Task.Due == "" {
		t.Fatalf("missing start/due: %+v", parent.Task)
	}
	status, body = env.request(t, http.MethodPost, "/api/admin/tasks", map[string]any{
		"title": "子任务", "parentId": parent.Task.ID,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create child = %d: %s", status, body)
	}
	child := decode[taskResponse](t, body)
	if child.Task.ParentID != parent.Task.ID || child.Task.ListID != parent.Task.ListID {
		t.Fatalf("child = %+v", child.Task)
	}
	status, _ = env.request(t, http.MethodPatch, "/api/admin/tasks/"+itoa(parent.Task.ID), map[string]any{
		"parentId": child.Task.ID,
	}, env.csrf)
	if status != http.StatusBadRequest {
		t.Fatalf("cycle parent update = %d, want 400", status)
	}
	status, _ = env.request(t, http.MethodPatch, "/api/admin/tasks/"+itoa(parent.Task.ID), map[string]any{
		"start": "2026-10-28T12:00:00+08:00",
	}, env.csrf)
	if status != http.StatusBadRequest {
		t.Fatalf("start after due = %d, want 400", status)
	}
}

func TestTaskAttachmentsAPI(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, http.MethodPost, "/api/admin/tasks", map[string]any{"title": "带附件任务"}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create task = %d: %s", status, body)
	}
	task := decode[taskResponse](t, body)
	var payload bytes.Buffer
	writer := multipart.NewWriter(&payload)
	part, _ := writer.CreateFormFile("file", "note.txt")
	_, _ = part.Write([]byte("hello attachment"))
	_ = writer.Close()
	req, _ := http.NewRequest(http.MethodPost, env.server.URL+"/api/admin/tasks/"+itoa(task.Task.ID)+"/attachments", &payload)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("X-CSRF-Token", env.csrf)
	resp, err := env.client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	createdBody, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("upload attachment = %d: %s", resp.StatusCode, createdBody)
	}
	created := decode[struct {
		Attachment struct {
			ID int64 `json:"id"`
		} `json:"attachment"`
	}](t, createdBody)
	status, body = env.request(t, http.MethodGet, "/api/admin/tasks/"+itoa(task.Task.ID)+"/attachments", nil, "")
	if status != http.StatusOK || !strings.Contains(string(body), "note.txt") {
		t.Fatalf("list attachments = %d: %s", status, body)
	}
	status, body = env.request(t, http.MethodGet, "/api/admin/tasks/"+itoa(task.Task.ID)+"/attachments/"+itoa(created.Attachment.ID), nil, "")
	if status != http.StatusOK || string(body) != "hello attachment" {
		t.Fatalf("download attachment = %d: %s", status, body)
	}
	status, _ = env.request(t, http.MethodDelete, "/api/admin/tasks/"+itoa(task.Task.ID)+"/attachments/"+itoa(created.Attachment.ID), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete attachment = %d", status)
	}
}

func TestTaskPinAndFilterRangeAPI(t *testing.T) {
	env := newAPIEnv(t)
	now := time.Now().In(time.Local)
	today := time.Date(now.Year(), now.Month(), now.Day(), 9, 0, 0, 0, time.Local)
	from := today.AddDate(0, 0, -1).Format("2006-01-02")
	to := today.AddDate(0, 0, 1).Format("2006-01-02")

	status, body := env.request(t, "POST", "/api/admin/task-lists", map[string]any{"name": "置顶测试"}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create list = %d: %s", status, body)
	}
	list := decode[struct {
		List struct {
			ID int64 `json:"id"`
		} `json:"list"`
	}](t, body)

	status, body = env.request(t, "PATCH", "/api/admin/task-lists/"+itoa(list.List.ID), map[string]any{"pinned": true}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("pin list = %d: %s", status, body)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?view=all", nil, "")
	if status != http.StatusOK {
		t.Fatalf("workspace = %d: %s", status, body)
	}
	ws := decode[workspaceResponse](t, body)
	if len(ws.Lists) == 0 || ws.Lists[0].ID != list.List.ID {
		t.Fatalf("pinned list should be first: %+v", ws.Lists)
	}

	var taskIDs []int64
	for _, day := range []time.Time{today, today.AddDate(0, 0, 1)} {
		status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
			"title": day.Format("01-02"), "listId": list.List.ID, "due": day.Format(time.RFC3339), "allDay": false,
		}, env.csrf)
		if status != http.StatusCreated {
			t.Fatalf("create task = %d: %s", status, body)
		}
		created := decode[taskResponse](t, body)
		taskIDs = append(taskIDs, created.Task.ID)
	}
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+itoa(taskIDs[1]), map[string]any{"pinned": true}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("pin task = %d: %s", status, body)
	}
	pinned := decode[taskResponse](t, body)
	if !pinned.Task.Pinned {
		t.Fatalf("task not pinned: %+v", pinned.Task)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?view=list&listId="+itoa(list.List.ID), nil, "")
	if status != http.StatusOK {
		t.Fatalf("list workspace = %d: %s", status, body)
	}
	ws = decode[workspaceResponse](t, body)
	if len(ws.Tasks) != 2 || ws.Tasks[0].ID != taskIDs[1] {
		t.Fatalf("pinned task should sort first: %+v", ws.Tasks)
	}

	status, body = env.request(t, "POST", "/api/admin/task-filters", map[string]any{
		"name": "时间段", "conditions": map[string]any{
			"status": "open", "date": "range", "dateFrom": from, "dateTo": to,
		},
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create filter = %d: %s", status, body)
	}
	filter := decode[struct {
		Filter struct {
			ID int64 `json:"id"`
		} `json:"filter"`
	}](t, body)
	status, body = env.request(t, "GET", "/api/admin/tasks?filterId="+itoa(filter.Filter.ID), nil, "")
	if status != http.StatusOK {
		t.Fatalf("filter workspace = %d: %s", status, body)
	}
	filtered := decode[workspaceResponse](t, body)
	if len(filtered.Tasks) != 2 {
		t.Fatalf("range filter tasks = %d, want 2", len(filtered.Tasks))
	}
	status, body = env.request(t, "PATCH", "/api/admin/task-filters/"+itoa(filter.Filter.ID), map[string]any{"pinned": true}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("pin filter = %d: %s", status, body)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?filterId="+itoa(filter.Filter.ID), nil, "")
	if status != http.StatusOK {
		t.Fatalf("filter workspace after pin = %d: %s", status, body)
	}
	filtered = decode[workspaceResponse](t, body)
	if len(filtered.Tasks) != 2 {
		t.Fatalf("pinning a filter must preserve its conditions, got %d tasks", len(filtered.Tasks))
	}
}

func TestNoteListAndNoteKind(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/task-lists", map[string]any{
		"name": "笔记", "kind": "NOTE",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create note list = %d: %s", status, body)
	}
	list := decode[struct {
		List struct {
			ID   int64  `json:"id"`
			Kind string `json:"kind"`
		} `json:"list"`
	}](t, body)
	if list.List.Kind != "NOTE" {
		t.Fatalf("note list kind = %q", list.List.Kind)
	}

	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "灵感", "listId": list.List.ID,
		"due": "2026-10-30T09:00:00Z", "reminderOffset": 10,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create note = %d: %s", status, body)
	}
	note := decode[taskResponse](t, body)
	if note.Task.Kind != "NOTE" || note.Task.Due != "" || note.Task.ReminderOffset != -1 || len(note.Task.ReminderOffsets) != 0 {
		t.Fatalf("note should not keep schedule: %+v", note.Task)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks?view=list&listId="+itoa(list.List.ID), nil, "")
	if status != http.StatusOK {
		t.Fatalf("note workspace = %d: %s", status, body)
	}
	ws := decode[workspaceResponse](t, body)
	if len(ws.Tasks) != 1 || ws.Tasks[0].ID != note.Task.ID {
		t.Fatalf("note workspace tasks = %+v", ws.Tasks)
	}

	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "普通任务", "due": "2026-10-30T09:00:00Z",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create task = %d: %s", status, body)
	}
	task := decode[taskResponse](t, body)
	if task.Task.Kind != "TASK" {
		t.Fatalf("task kind = %q", task.Task.Kind)
	}
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+itoa(task.Task.ID), map[string]any{"kind": "NOTE"}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("convert to note = %d: %s", status, body)
	}
	converted := decode[taskResponse](t, body)
	if converted.Task.Kind != "NOTE" || converted.Task.Due != "" {
		t.Fatalf("converted note = %+v", converted.Task)
	}
}

func TestTaskSectionsAndCopyListAPI(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/task-lists", map[string]any{"name": "分栏"}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create list = %d: %s", status, body)
	}
	list := decode[struct {
		List struct {
			ID int64 `json:"id"`
		} `json:"list"`
	}](t, body)

	status, body = env.request(t, "POST", "/api/admin/task-sections", map[string]any{
		"listId": list.List.ID, "name": "进行中",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create section = %d: %s", status, body)
	}
	section := decode[struct {
		Section struct {
			ID int64 `json:"id"`
		} `json:"section"`
	}](t, body)

	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "放进行中", "listId": list.List.ID, "sectionId": section.Section.ID,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create task = %d: %s", status, body)
	}
	task := decode[taskResponse](t, body)
	if task.Task.SectionID != section.Section.ID {
		t.Fatalf("task section = %d, want %d", task.Task.SectionID, section.Section.ID)
	}

	status, body = env.request(t, "GET", "/api/admin/tasks?view=list&listId="+itoa(list.List.ID), nil, "")
	if status != http.StatusOK {
		t.Fatalf("workspace = %d: %s", status, body)
	}
	ws := decode[workspaceResponse](t, body)
	found := 0
	for _, item := range ws.Sections {
		if item.ListID == list.List.ID {
			found++
			if item.Name != "进行中" {
				t.Fatalf("section name = %q", item.Name)
			}
		}
	}
	if found != 1 {
		t.Fatalf("sections = %+v", ws.Sections)
	}

	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+itoa(task.Task.ID), map[string]any{"sectionId": 0}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("ungroup task = %d: %s", status, body)
	}
	if moved := decode[taskResponse](t, body); moved.Task.SectionID != 0 {
		t.Fatalf("task not ungrouped: %+v", moved.Task)
	}

	// Copy only opens: the new list keeps the section but not completed tasks.
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+itoa(task.Task.ID), map[string]any{"completed": true}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("complete task = %d: %s", status, body)
	}
	status, body = env.request(t, "POST", "/api/admin/task-lists/"+itoa(list.List.ID)+"/copy", map[string]any{
		"name": "分栏副本", "mode": "open",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("copy list = %d: %s", status, body)
	}
	copied := decode[struct {
		List struct {
			ID int64 `json:"id"`
		} `json:"list"`
	}](t, body)
	status, body = env.request(t, "GET", "/api/admin/tasks?view=list&listId="+itoa(copied.List.ID), nil, "")
	if status != http.StatusOK {
		t.Fatalf("copied workspace = %d: %s", status, body)
	}
	copiedWS := decode[workspaceResponse](t, body)
	if len(copiedWS.Tasks) != 0 {
		t.Fatalf("open copy should not include completed task: %+v", copiedWS.Tasks)
	}
	copiedSections := 0
	for _, item := range copiedWS.Sections {
		if item.ListID == copied.List.ID {
			copiedSections++
		}
	}
	if copiedSections != 1 {
		t.Fatalf("copied sections = %+v", copiedWS.Sections)
	}

	for _, testCase := range []struct {
		mode      string
		completed bool
	}{
		{mode: "keep", completed: true},
		{mode: "all", completed: false},
	} {
		status, body = env.request(t, "POST", "/api/admin/task-lists/"+itoa(list.List.ID)+"/copy", map[string]any{
			"name": "副本-" + testCase.mode, "mode": testCase.mode,
		}, env.csrf)
		if status != http.StatusCreated {
			t.Fatalf("copy %s = %d: %s", testCase.mode, status, body)
		}
		row := decode[struct {
			List struct {
				ID int64 `json:"id"`
			} `json:"list"`
		}](t, body)
		status, body = env.request(t, "GET", "/api/admin/tasks?view=list&listId="+itoa(row.List.ID), nil, "")
		if status != http.StatusOK {
			t.Fatalf("copy %s workspace = %d: %s", testCase.mode, status, body)
		}
		copiedData := decode[workspaceResponse](t, body)
		if len(copiedData.Tasks) != 1 || copiedData.Tasks[0].Completed != testCase.completed {
			t.Fatalf("copy %s tasks = %+v", testCase.mode, copiedData.Tasks)
		}
	}

	status, body = env.request(t, "DELETE", "/api/admin/task-sections/"+itoa(section.Section.ID)+"?strategy=move&moveTo=0", nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete section = %d: %s", status, body)
	}
}

func TestRichNoteSanitizeAndSearch(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/task-lists", map[string]any{
		"name": "富文本笔记", "kind": "NOTE",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create note list = %d: %s", status, body)
	}
	list := decode[struct {
		List struct {
			ID int64 `json:"id"`
		} `json:"list"`
	}](t, body)

	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "会议纪要", "listId": list.List.ID, "kind": "NOTE", "notesFormat": "html",
		"notes": `<p>Hello <strong>World</strong><script>alert(1)</script>` +
			`<a href="javascript:alert(1)">bad</a></p>`,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create rich note = %d: %s", status, body)
	}
	note := decode[taskResponse](t, body)
	if note.Task.NotesFormat != "html" {
		t.Fatalf("notes format = %q", note.Task.NotesFormat)
	}
	if strings.Contains(note.Task.Notes, "script") || strings.Contains(note.Task.Notes, "javascript:") {
		t.Fatalf("unsafe note HTML = %s", note.Task.Notes)
	}
	if note.Task.NotesText != "Hello Worldbad" {
		t.Fatalf("notes text = %q", note.Task.NotesText)
	}
	if !strings.Contains(note.Task.Notes, "<strong>World</strong>") {
		t.Fatalf("formatting lost: %s", note.Task.Notes)
	}

	status, body = env.request(t, "GET", "/api/admin/tasks?view=list&listId="+itoa(list.List.ID)+"&q=World", nil, "")
	if status != http.StatusOK {
		t.Fatalf("search note = %d: %s", status, body)
	}
	ws := decode[workspaceResponse](t, body)
	if len(ws.Tasks) != 1 || ws.Tasks[0].ID != note.Task.ID {
		t.Fatalf("note search results = %+v", ws.Tasks)
	}
}

func TestMarkdownNote(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/task-lists", map[string]any{
		"name": "Markdown 笔记", "kind": "NOTE",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create note list = %d: %s", status, body)
	}
	list := decode[struct {
		List struct {
			ID int64 `json:"id"`
		} `json:"list"`
	}](t, body)

	content := "## 会议\n\n- [x] 完成\n\n**重点**"
	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "Markdown 笔记", "listId": list.List.ID, "kind": "NOTE", "notesFormat": "markdown", "notes": content,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create markdown note = %d: %s", status, body)
	}
	note := decode[taskResponse](t, body)
	if note.Task.NotesFormat != "markdown" || note.Task.Notes != content || note.Task.NotesText != content {
		t.Fatalf("unexpected markdown note: format=%q notes=%q text=%q", note.Task.NotesFormat, note.Task.Notes, note.Task.NotesText)
	}

	status, body = env.request(t, "GET", "/api/admin/tasks?view=list&listId="+itoa(list.List.ID)+"&q=重点", nil, "")
	if status != http.StatusOK {
		t.Fatalf("search markdown note = %d: %s", status, body)
	}
	ws := decode[workspaceResponse](t, body)
	if len(ws.Tasks) != 1 || ws.Tasks[0].ID != note.Task.ID {
		t.Fatalf("markdown note search results = %+v", ws.Tasks)
	}
}

func TestRejectCrossKindListMoves(t *testing.T) {
	env := newAPIEnv(t)
	createList := func(name, kind string) int64 {
		status, body := env.request(t, "POST", "/api/admin/task-lists", map[string]any{"name": name, "kind": kind}, env.csrf)
		if status != http.StatusCreated {
			t.Fatalf("create list %s = %d: %s", name, status, body)
		}
		return decode[struct {
			List struct {
				ID int64 `json:"id"`
			} `json:"list"`
		}](t, body).List.ID
	}
	taskListID := createList("任务区", "TASK")
	noteListID := createList("笔记区", "NOTE")

	createTask := func(title string, listID int64, kind string) int64 {
		payload := map[string]any{"title": title, "listId": listID}
		if kind != "" {
			payload["kind"] = kind
		}
		status, body := env.request(t, "POST", "/api/admin/tasks", payload, env.csrf)
		if status != http.StatusCreated {
			t.Fatalf("create %s = %d: %s", title, status, body)
		}
		return decode[taskResponse](t, body).Task.ID
	}
	taskID := createTask("普通任务", taskListID, "")
	noteID := createTask("普通笔记", noteListID, "")

	status, body := env.request(t, "PATCH", "/api/admin/tasks/"+itoa(taskID), map[string]any{"listId": noteListID}, env.csrf)
	if status != http.StatusBadRequest {
		t.Fatalf("move task into note list = %d: %s", status, body)
	}
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+itoa(noteID), map[string]any{"listId": taskListID}, env.csrf)
	if status != http.StatusBadRequest {
		t.Fatalf("move note into task list = %d: %s", status, body)
	}
	status, body = env.request(t, "POST", "/api/admin/tasks/batch", map[string]any{
		"ids": []int64{taskID}, "action": "move", "listId": noteListID,
	}, env.csrf)
	if status != http.StatusBadRequest {
		t.Fatalf("batch move task into note list = %d: %s", status, body)
	}
	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "显式错误任务", "listId": noteListID, "kind": "TASK",
	}, env.csrf)
	if status != http.StatusBadRequest {
		t.Fatalf("create task in note list = %d: %s", status, body)
	}

	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "无清单笔记", "kind": "NOTE",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create note without list = %d: %s", status, body)
	}
	created := decode[taskResponse](t, body)
	if created.Task.Kind != "NOTE" || created.Task.ListID != noteListID {
		t.Fatalf("note should be placed in the note list: %+v", created.Task)
	}
}

func TestNoteCommentsAndActivities(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/task-lists", map[string]any{
		"name": "分享笔记", "kind": "NOTE",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create note list = %d: %s", status, body)
	}
	list := decode[struct {
		List struct {
			ID int64 `json:"id"`
		} `json:"list"`
	}](t, body)
	status, body = env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "共享笔记", "listId": list.List.ID, "kind": "NOTE",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create note = %d: %s", status, body)
	}
	note := decode[taskResponse](t, body)

	status, body = env.request(t, "GET", "/api/admin/tasks/"+itoa(note.Task.ID)+"/activities", nil, "")
	if status != http.StatusOK {
		t.Fatalf("note activities = %d: %s", status, body)
	}
	activities := decode[struct {
		Activities []struct {
			Detail string `json:"detail"`
		} `json:"activities"`
	}](t, body)
	if len(activities.Activities) == 0 || activities.Activities[0].Detail != "创建了笔记" {
		t.Fatalf("unexpected note activities: %+v", activities.Activities)
	}

	status, body = env.request(t, "POST", "/api/admin/tasks/"+itoa(note.Task.ID)+"/comments", map[string]any{
		"body": "笔记评论",
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create note comment = %d: %s", status, body)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks/"+itoa(note.Task.ID)+"/comments", nil, "")
	if status != http.StatusOK {
		t.Fatalf("note comments = %d: %s", status, body)
	}
	comments := decode[struct {
		Comments []struct {
			Body string `json:"body"`
		} `json:"comments"`
	}](t, body)
	if len(comments.Comments) != 1 || comments.Comments[0].Body != "笔记评论" {
		t.Fatalf("unexpected note comments: %+v", comments.Comments)
	}
}

func TestRecurringTaskInstanceHistoryAndSkip(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "每日站会", "recurrence": "FREQ=DAILY", "due": "2026-11-01T09:00:00Z", "allDay": false,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create recurring task = %d: %s", status, body)
	}
	task := decode[taskResponse](t, body)
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+itoa(task.Task.ID), map[string]any{"completed": true}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("complete recurrence = %d: %s", status, body)
	}
	completed := decode[taskResponse](t, body)
	if completed.Task.Completed || completed.Task.Due == task.Task.Due {
		t.Fatalf("recurring task did not roll: %+v", completed.Task)
	}
	status, body = env.request(t, "GET", "/api/admin/tasks/"+itoa(task.Task.ID)+"/recurrence", nil, "")
	if status != http.StatusOK {
		t.Fatalf("recurrence history = %d: %s", status, body)
	}
	history := decode[struct {
		Instances []struct {
			Status string `json:"status"`
		} `json:"instances"`
	}](t, body)
	if len(history.Instances) != 1 || history.Instances[0].Status != "completed" {
		t.Fatalf("unexpected completed history: %+v", history.Instances)
	}

	status, body = env.request(t, "POST", "/api/admin/tasks/"+itoa(task.Task.ID)+"/recurrence/skip", nil, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("skip recurrence = %d: %s", status, body)
	}
	skipped := decode[struct {
		Task      any `json:"task"`
		Instances []struct {
			Status string `json:"status"`
		} `json:"instances"`
	}](t, body)
	if len(skipped.Instances) != 2 {
		t.Fatalf("unexpected skip history: %+v", skipped.Instances)
	}
	foundSkip := false
	for _, item := range skipped.Instances {
		if item.Status == "skipped" {
			foundSkip = true
		}
	}
	if !foundSkip {
		t.Fatalf("skip not recorded: %+v", skipped.Instances)
	}
	cal, err := tasksync.New(env.store).EnsureTaskCalendar(context.Background(), env.userID)
	if err != nil {
		t.Fatal(err)
	}
	objects, err := env.store.ListObjects(context.Background(), cal.ID)
	if err != nil {
		t.Fatal(err)
	}
	completedExceptions, skippedExceptions := 0, 0
	for _, obj := range objects {
		body := string(obj.Data)
		if !strings.Contains(obj.Href, "-rid-") {
			continue
		}
		if strings.Contains(body, "STATUS:COMPLETED") {
			completedExceptions++
		}
		if strings.Contains(body, "STATUS:CANCELLED") {
			skippedExceptions++
		}
	}
	if completedExceptions != 1 || skippedExceptions != 1 {
		t.Fatalf("recurrence exceptions = completed %d, skipped %d; objects %d", completedExceptions, skippedExceptions, len(objects))
	}
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+itoa(task.Task.ID), map[string]any{"recurrence": ""}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("clear recurrence = %d: %s", status, body)
	}
	objects, err = env.store.ListObjects(context.Background(), cal.ID)
	if err != nil {
		t.Fatal(err)
	}
	for _, obj := range objects {
		if strings.Contains(obj.Href, "-rid-") {
			t.Fatalf("recurrence exceptions were not removed after clearing recurrence: %s", obj.Href)
		}
	}
}

func TestRecurringCountUsesOriginalAnchor(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "三次任务", "recurrence": "FREQ=DAILY;COUNT=3", "due": "2026-11-01T09:00:00Z", "allDay": false,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create = %d: %s", status, body)
	}
	created := decode[taskResponse](t, body)
	id := itoa(created.Task.ID)
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+id, map[string]any{"title": "三次任务改名", "due": "2026-11-01T09:00:00Z"}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("unchanged due update = %d: %s", status, body)
	}
	for index, want := range []string{"2026-11-02T09:00:00Z", "2026-11-03T09:00:00Z"} {
		status, body = env.request(t, "PATCH", "/api/admin/tasks/"+id, map[string]any{"completed": true}, env.csrf)
		if status != http.StatusOK {
			t.Fatalf("complete %d = %d: %s", index, status, body)
		}
		updated := decode[taskResponse](t, body)
		if updated.Task.Completed || updated.Task.Due != want {
			t.Fatalf("complete %d = %+v, want due %s", index, updated.Task, want)
		}
	}
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+id, map[string]any{"completed": true}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("final complete = %d: %s", status, body)
	}
	updated := decode[taskResponse](t, body)
	if !updated.Task.Completed {
		t.Fatalf("counted recurrence should be exhausted: %+v", updated.Task)
	}
}

func TestRecurrenceOccurrenceActions(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "实例操作", "recurrence": "FREQ=WEEKLY", "due": "2026-11-01T09:00:00Z", "allDay": false,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create = %d: %s", status, body)
	}
	created := decode[taskResponse](t, body)
	id := itoa(created.Task.ID)

	status, body = env.request(t, "POST", "/api/admin/tasks/"+id+"/recurrence/complete", map[string]any{"occurrence": "2026-11-15T09:00:00Z"}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("future complete = %d: %s", status, body)
	}
	future := decode[taskResponse](t, body)
	if future.Task.Due != "2026-11-01T09:00:00Z" {
		t.Fatalf("future completion moved master: %+v", future.Task)
	}

	status, body = env.request(t, "POST", "/api/admin/tasks/"+id+"/recurrence/postpone", map[string]any{"days": 2}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("postpone = %d: %s", status, body)
	}
	postponed := decode[struct {
		Task struct {
			Due string `json:"due"`
		} `json:"task"`
		Instances []struct {
			Status      string `json:"status"`
			PostponedTo string `json:"postponedTo"`
		} `json:"instances"`
	}](t, body)
	if postponed.Task.Due != "2026-11-08T09:00:00Z" {
		t.Fatalf("postpone did not advance series: %+v", postponed.Task)
	}
	foundPostponed := false
	for _, item := range postponed.Instances {
		if item.Status == "postponed" && item.PostponedTo == "2026-11-03T09:00:00Z" {
			foundPostponed = true
		}
	}
	if !foundPostponed {
		t.Fatalf("postpone history = %+v", postponed.Instances)
	}

	status, body = env.request(t, "GET", "/api/admin/tasks/calendar?from="+url.QueryEscape("2026-11-01T00:00:00Z")+"&to="+url.QueryEscape("2026-11-10T00:00:00Z"), nil, "")
	if status != http.StatusOK {
		t.Fatalf("calendar = %d: %s", status, body)
	}
	var cal struct {
		Tasks []struct {
			ID         int64  `json:"id"`
			Due        string `json:"due"`
			Occurrence string `json:"occurrence"`
			Postponed  bool   `json:"postponed"`
			Virtual    bool   `json:"virtual"`
		} `json:"tasks"`
	}
	if err := json.Unmarshal(body, &cal); err != nil {
		t.Fatal(err)
	}
	foundVirtual := false
	for _, task := range cal.Tasks {
		if task.ID == created.Task.ID && task.Postponed && task.Due == "2026-11-03T09:00:00Z" && task.Occurrence == "2026-11-01T09:00:00Z" {
			foundVirtual = true
		}
	}
	if !foundVirtual {
		t.Fatalf("postponed virtual task missing: %+v", cal.Tasks)
	}
}

func TestCompletingCurrentSkipsHandledFutureInstance(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "POST", "/api/admin/tasks", map[string]any{
		"title": "提前完成", "recurrence": "FREQ=DAILY", "due": "2026-11-01T09:00:00Z", "allDay": false,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create = %d: %s", status, body)
	}
	created := decode[taskResponse](t, body)
	id := itoa(created.Task.ID)
	status, body = env.request(t, "POST", "/api/admin/tasks/"+id+"/recurrence/complete", map[string]any{"occurrence": "2026-11-02T09:00:00Z"}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("future complete = %d: %s", status, body)
	}
	status, body = env.request(t, "PATCH", "/api/admin/tasks/"+id, map[string]any{"completed": true}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("current complete = %d: %s", status, body)
	}
	updated := decode[taskResponse](t, body)
	if updated.Task.Completed || updated.Task.Due != "2026-11-03T09:00:00Z" {
		t.Fatalf("handled future instance not skipped: %+v", updated.Task)
	}
}
