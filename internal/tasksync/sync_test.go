package tasksync

import (
	"context"
	"strings"
	"testing"
	"time"

	"caldav-free/internal/auth"
	"caldav-free/internal/ical"
	"caldav-free/internal/store"
)

func newSyncEnv(t *testing.T) (*store.Store, *Syncer, int64, *store.TaskList) {
	t.Helper()
	st, err := store.Open(t.TempDir() + "/sync.db")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	hash, _ := auth.HashPassword("password123")
	user, err := st.CreateUser(context.Background(), "alice", "Alice", "", hash, true)
	if err != nil {
		t.Fatal(err)
	}
	inbox, err := st.EnsureInbox(context.Background(), user.ID)
	if err != nil {
		t.Fatal(err)
	}
	return st, New(st), user.ID, inbox
}

func TestPushCreatesVTODO(t *testing.T) {
	st, syncer, userID, inbox := newSyncEnv(t)
	ctx := context.Background()
	due := time.Date(2026, 10, 25, 14, 0, 0, 0, time.UTC)
	task, err := st.CreateTask(ctx, &store.Task{
		UserID: userID, ListID: inbox.ID, Title: "写周报", Notes: "汇总进度",
		DueAt: &due, Priority: 3, Tags: store.StringList{"工作"},
		Checklist:  `[{"id":"a","title":"整理数据","done":false}]`,
		Recurrence: "FREQ=WEEKLY", ReminderOffset: 15,
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := syncer.PushTask(ctx, userID, task); err != nil {
		t.Fatal(err)
	}
	if task.VTODOUID == "" || task.VTODOETag == "" {
		t.Fatalf("missing sync identity: %+v", task)
	}
	cal, err := syncer.EnsureTaskCalendar(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	obj, err := st.GetObject(ctx, cal.ID, task.VTODOHref)
	if err != nil {
		t.Fatal(err)
	}
	body := string(obj.Data)
	for _, want := range []string{"BEGIN:VTODO", "SUMMARY:写周报", "DESCRIPTION:汇总进度", "PRIORITY:1", "CATEGORIES:工作", "X-CALDDAV-CHECKLIST:", "X-CALDDAV-LIST:收集箱", "RRULE:FREQ=WEEKLY", "BEGIN:VALARM", "TRIGGER:-PT15M", "DTSTART:20261025T140000Z"} {
		if !strings.Contains(body, want) {
			t.Errorf("VTODO missing %q:\n%s", want, body)
		}
	}
	reloaded, err := st.GetTask(ctx, userID, task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.SyncPending || reloaded.VTODOETag != obj.ETag {
		t.Fatalf("sync metadata not stored: %+v", reloaded)
	}
}

func TestSyncImportsClientEdit(t *testing.T) {
	st, syncer, userID, inbox := newSyncEnv(t)
	ctx := context.Background()
	task, err := st.CreateTask(ctx, &store.Task{UserID: userID, ListID: inbox.ID, Title: "原标题"})
	if err != nil {
		t.Fatal(err)
	}
	if err := syncer.PushTask(ctx, userID, task); err != nil {
		t.Fatal(err)
	}
	cal, _ := syncer.EnsureTaskCalendar(ctx, userID)
	obj, err := st.GetObject(ctx, cal.ID, task.VTODOHref)
	if err != nil {
		t.Fatal(err)
	}
	edited := strings.Replace(string(obj.Data), "SUMMARY:原标题", "SUMMARY:新标题", 1)
	edited = strings.Replace(edited, "STATUS:NEEDS-ACTION", "STATUS:COMPLETED", 1)
	edited = strings.Replace(edited, "PERCENT-COMPLETE:0", "PERCENT-COMPLETE:100", 1)
	editedObj := *obj
	editedObj.Data = []byte(edited)
	editedObj.ETag = computeETag(editedObj.Data)
	editedObj.Size = int64(len(editedObj.Data))
	if _, _, _, err := st.PutObject(ctx, &editedObj); err != nil {
		t.Fatal(err)
	}

	if err := syncer.Sync(ctx, userID); err != nil {
		t.Fatal(err)
	}
	reloaded, err := st.GetTask(ctx, userID, task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.Title != "新标题" || !reloaded.Completed || reloaded.CompletedAt == nil {
		t.Fatalf("client edit not imported: %+v", reloaded)
	}
	if reloaded.VTODOETag != editedObj.ETag {
		t.Fatalf("etag not updated: %q != %q", reloaded.VTODOETag, editedObj.ETag)
	}
}

func TestSyncImportsExternalTask(t *testing.T) {
	st, syncer, userID, _ := newSyncEnv(t)
	ctx := context.Background()
	cal, err := syncer.EnsureTaskCalendar(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	root := ical.NewComponent("VCALENDAR")
	root.AddProp("VERSION", "2.0", nil)
	root.AddProp("PRODID", "-//test//EN", nil)
	todo := ical.NewComponent("VTODO")
	todo.AddProp("UID", "client-created@example.test", nil)
	todo.AddProp("SUMMARY", "客户端创建的任务", nil)
	todo.AddProp("DESCRIPTION", "来自 DAVx5", nil)
	todo.AddProp("DUE", "20261030T090000Z", nil)
	todo.AddProp("PRIORITY", "5", nil)
	todo.AddProp("CATEGORIES", "外部,测试", nil)
	todo.AddProp("X-CALDDAV-LIST", "工作", nil)
	todo.AddProp("STATUS", "NEEDS-ACTION", nil)
	root.AddChild(todo)
	data := []byte(root.Encode())
	obj := &store.Object{
		CalendarID: cal.ID, Href: "client-created.ics", UID: "client-created@example.test",
		ETag: computeETag(data), ContentType: "text/calendar; charset=utf-8", Data: data,
		ComponentType: "VTODO", Size: int64(len(data)),
	}
	if _, _, _, err := st.PutObject(ctx, obj); err != nil {
		t.Fatal(err)
	}
	if err := syncer.Sync(ctx, userID); err != nil {
		t.Fatal(err)
	}
	tasks, err := st.ListAllTasks(ctx, userID, 100)
	if err != nil || len(tasks) != 1 {
		t.Fatalf("tasks = %+v (%v)", tasks, err)
	}
	got := tasks[0]
	if got.Title != "客户端创建的任务" || got.Notes != "来自 DAVx5" || got.Priority != 2 {
		t.Fatalf("unexpected imported task: %+v", got)
	}
	if got.DueAt == nil || !got.DueAt.Equal(time.Date(2026, 10, 30, 9, 0, 0, 0, time.UTC)) {
		t.Fatalf("due = %v", got.DueAt)
	}
	if len(got.Tags) != 2 || got.Tags[0] != "外部" {
		t.Fatalf("tags = %v", got.Tags)
	}
	if got.VTODOUID != "client-created@example.test" || got.VTODOHref != "client-created.ics" {
		t.Fatalf("identity = %+v", got)
	}
}

func TestSyncHonorsClientDeleteAndLocalDelete(t *testing.T) {
	st, syncer, userID, inbox := newSyncEnv(t)
	ctx := context.Background()
	task, err := st.CreateTask(ctx, &store.Task{UserID: userID, ListID: inbox.ID, Title: "删除我"})
	if err != nil {
		t.Fatal(err)
	}
	if err := syncer.PushTask(ctx, userID, task); err != nil {
		t.Fatal(err)
	}
	cal, _ := syncer.EnsureTaskCalendar(ctx, userID)
	if _, _, err := st.DeleteObject(ctx, cal.ID, task.VTODOHref); err != nil {
		t.Fatal(err)
	}
	if err := syncer.Sync(ctx, userID); err != nil {
		t.Fatal(err)
	}
	if _, err := st.GetTask(ctx, userID, task.ID); err != store.ErrNotFound {
		t.Fatalf("client deletion not applied: %v", err)
	}

	local, err := st.CreateTask(ctx, &store.Task{UserID: userID, ListID: inbox.ID, Title: "本地删除"})
	if err != nil {
		t.Fatal(err)
	}
	if err := syncer.PushTask(ctx, userID, local); err != nil {
		t.Fatal(err)
	}
	if err := syncer.DeleteTask(ctx, userID, local); err != nil {
		t.Fatal(err)
	}
	if _, err := st.GetObject(ctx, cal.ID, local.VTODOHref); err != store.ErrNotFound {
		t.Fatalf("object still present: %v", err)
	}
}

func TestSyncPushesPendingTask(t *testing.T) {
	st, syncer, userID, inbox := newSyncEnv(t)
	ctx := context.Background()
	task, err := st.CreateTask(ctx, &store.Task{UserID: userID, ListID: inbox.ID, Title: "待同步"})
	if err != nil {
		t.Fatal(err)
	}
	if err := syncer.Sync(ctx, userID); err != nil {
		t.Fatal(err)
	}
	reloaded, err := st.GetTask(ctx, userID, task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.VTODOUID == "" || reloaded.VTODOETag == "" || reloaded.SyncPending {
		t.Fatalf("pending task not pushed: %+v", reloaded)
	}
}

func TestSyncImportsRecurrenceAndReminder(t *testing.T) {
	st, syncer, userID, _ := newSyncEnv(t)
	ctx := context.Background()
	cal, err := syncer.EnsureTaskCalendar(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	root := ical.NewComponent("VCALENDAR")
	root.AddProp("VERSION", "2.0", nil)
	root.AddProp("PRODID", "-//test//EN", nil)
	todo := ical.NewComponent("VTODO")
	todo.AddProp("UID", "recurring@example.test", nil)
	todo.AddProp("SUMMARY", "每周复盘", nil)
	todo.AddProp("DUE", "20261030T090000Z", nil)
	todo.AddProp("RRULE", "FREQ=WEEKLY;BYDAY=FR", nil)
	todo.AddProp("STATUS", "NEEDS-ACTION", nil)
	alarm := ical.NewComponent("VALARM")
	alarm.AddProp("ACTION", "DISPLAY", nil)
	alarm.AddProp("TRIGGER", "-PT30M", nil)
	todo.AddChild(alarm)
	root.AddChild(todo)
	data := []byte(root.Encode())
	obj := &store.Object{
		CalendarID: cal.ID, Href: "recurring.ics", UID: "recurring@example.test",
		ETag: computeETag(data), ContentType: "text/calendar; charset=utf-8", Data: data,
		ComponentType: "VTODO", Size: int64(len(data)),
	}
	if _, _, _, err := st.PutObject(ctx, obj); err != nil {
		t.Fatal(err)
	}
	if err := syncer.Sync(ctx, userID); err != nil {
		t.Fatal(err)
	}
	tasks, err := st.ListAllTasks(ctx, userID, 10)
	if err != nil || len(tasks) != 1 {
		t.Fatalf("tasks = %+v (%v)", tasks, err)
	}
	if tasks[0].Recurrence != "FREQ=WEEKLY;BYDAY=FR" || tasks[0].ReminderOffset != 30 {
		t.Fatalf("recurrence/reminder not imported: %+v", tasks[0])
	}

	// Removing the RRULE and VALARM clears the fields on import.
	edited := strings.Replace(string(obj.Data), "RRULE:FREQ=WEEKLY;BYDAY=FR\r\n", "", 1)
	edited = strings.Replace(edited, "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT30M\r\nEND:VALARM\r\n", "", 1)
	editedObj := *obj
	editedObj.Data = []byte(edited)
	editedObj.ETag = computeETag(editedObj.Data)
	editedObj.Size = int64(len(editedObj.Data))
	if _, _, _, err := st.PutObject(ctx, &editedObj); err != nil {
		t.Fatal(err)
	}
	if err := syncer.Sync(ctx, userID); err != nil {
		t.Fatal(err)
	}
	reloaded, err := st.GetTask(ctx, userID, tasks[0].ID)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.Recurrence != "" || reloaded.ReminderOffset != -1 {
		t.Fatalf("recurrence/reminder not cleared: %+v", reloaded)
	}
}

func TestMultipleReminderAlarms(t *testing.T) {
	st, syncer, userID, inbox := newSyncEnv(t)
	ctx := context.Background()
	due := time.Date(2026, 10, 25, 14, 0, 0, 0, time.UTC)
	task, err := st.CreateTask(ctx, &store.Task{
		UserID: userID, ListID: inbox.ID, Title: "多提醒", DueAt: &due,
		ReminderOffsets: store.StringList{"1440", "0", "15"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := syncer.PushTask(ctx, userID, task); err != nil {
		t.Fatal(err)
	}
	cal, err := syncer.EnsureTaskCalendar(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	obj, err := st.GetObject(ctx, cal.ID, task.VTODOHref)
	if err != nil {
		t.Fatal(err)
	}
	body := string(obj.Data)
	for _, want := range []string{"TRIGGER:-P1D", "TRIGGER:-PT15M", "TRIGGER:PT0M"} {
		if !strings.Contains(body, want) {
			t.Errorf("VTODO missing %q:\n%s", want, body)
		}
	}
	if strings.Count(body, "BEGIN:VALARM") != 3 {
		t.Fatalf("VALARM count = %d:\n%s", strings.Count(body, "BEGIN:VALARM"), body)
	}
	parsed, err := parseVTODO(cal, obj)
	if err != nil {
		t.Fatal(err)
	}
	if len(parsed.ReminderOffsets) != 3 || parsed.ReminderOffsets[0] != 0 || parsed.ReminderOffsets[2] != 1440 {
		t.Fatalf("parsed reminders = %v", parsed.ReminderOffsets)
	}
}
