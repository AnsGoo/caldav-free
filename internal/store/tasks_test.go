package store

import (
	"context"
	"testing"
	"time"

	"caldav-free/internal/auth"
)

func newTaskUser(t *testing.T) (*Store, int64) {
	t.Helper()
	s := newStore(t)
	hash, _ := auth.HashPassword("password123")
	user, err := s.CreateUser(context.Background(), "alice", "Alice", "", hash, true)
	if err != nil {
		t.Fatal(err)
	}
	return s, user.ID
}

func TestTaskListsAndInbox(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()

	inbox, err := s.EnsureInbox(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if !inbox.IsInbox || inbox.Name != "收集箱" {
		t.Fatalf("unexpected inbox: %+v", inbox)
	}
	again, err := s.EnsureInbox(ctx, userID)
	if err != nil || again.ID != inbox.ID {
		t.Fatalf("inbox is not stable: %v %+v", err, again)
	}

	work, err := s.CreateTaskList(ctx, userID, "工作", "#ff0000")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.CreateTaskList(ctx, userID, "工作", "#00ff00"); err != ErrConflict {
		t.Fatalf("duplicate list = %v, want ErrConflict", err)
	}
	if err := s.UpdateTaskList(ctx, userID, work.ID, "工作台", "#00ff00", 3); err != nil {
		t.Fatal(err)
	}
	lists, err := s.ListTaskLists(ctx, userID)
	if err != nil || len(lists) != 2 {
		t.Fatalf("lists = %+v (%v)", lists, err)
	}
	if lists[0].IsInbox != true {
		t.Fatalf("inbox should sort first: %+v", lists)
	}

	task, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: work.ID, Title: "写周报"})
	if err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteTaskList(ctx, userID, work.ID); err != nil {
		t.Fatal(err)
	}
	moved, err := s.GetTask(ctx, userID, task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if moved.ListID != inbox.ID {
		t.Fatalf("task not moved to inbox: %+v", moved)
	}
	if err := s.DeleteTaskList(ctx, userID, inbox.ID); err == nil {
		t.Fatal("inbox deletion should fail")
	}
}

func TestTaskFiltersAndCounts(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	inbox, _ := s.EnsureInbox(ctx, userID)
	work, _ := s.CreateTaskList(ctx, userID, "工作", "#ff0000")

	today := taskTodayStart(time.Now()).Add(15 * time.Hour)
	overdue := today.AddDate(0, 0, -2)
	next := today.AddDate(0, 0, 3)
	far := today.AddDate(0, 0, 30)

	seed := []*Task{
		{UserID: userID, ListID: inbox.ID, Title: "今天的事", DueAt: &today},
		{UserID: userID, ListID: inbox.ID, Title: "过期的事", DueAt: &overdue},
		{UserID: userID, ListID: work.ID, Title: "三天后", DueAt: &next},
		{UserID: userID, ListID: work.ID, Title: "很久以后", DueAt: &far},
		{UserID: userID, ListID: work.ID, Title: "没有日期"},
	}
	for _, task := range seed {
		if _, err := s.CreateTask(ctx, task); err != nil {
			t.Fatal(err)
		}
	}
	done := &Task{UserID: userID, ListID: inbox.ID, Title: "做完了", Completed: true}
	if _, err := s.CreateTask(ctx, done); err != nil {
		t.Fatal(err)
	}

	counts, err := s.TaskCounts(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if counts.All != 5 || counts.Today != 2 || counts.Next7 != 2 || counts.Inbox != 2 || counts.Completed != 1 {
		t.Fatalf("unexpected counts: %+v", counts)
	}

	todayTasks, err := s.ListTasks(ctx, userID, TaskFilter{View: "today"})
	if err != nil || len(todayTasks) != 2 {
		t.Fatalf("today = %d (%v)", len(todayTasks), err)
	}
	inboxTasks, err := s.ListTasks(ctx, userID, TaskFilter{View: "inbox", ListID: inbox.ID})
	if err != nil || len(inboxTasks) != 3 {
		t.Fatalf("inbox = %d (%v), want 2 open + 1 completed", len(inboxTasks), err)
	}
	search, err := s.ListTasks(ctx, userID, TaskFilter{View: "all", Query: "周报"})
	if err != nil || len(search) != 0 {
		t.Fatalf("search = %d (%v)", len(search), err)
	}
	completedView, err := s.ListTasks(ctx, userID, TaskFilter{View: "completed"})
	if err != nil || len(completedView) != 1 || !completedView[0].Completed {
		t.Fatalf("completed view = %+v (%v)", completedView, err)
	}
}

func TestTaskDueOrderingAcrossOffsets(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	inbox, _ := s.EnsureInbox(ctx, userID)
	zone := time.FixedZone("CST", 8*3600)
	// 14:00 in +08 is 06:00 UTC, so it must sort before 08:30 UTC.
	first := time.Date(2026, 10, 22, 14, 0, 0, 0, zone)
	second := time.Date(2026, 10, 22, 8, 30, 0, 0, time.UTC)
	for _, due := range []time.Time{second, first} {
		value := due
		if _, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: inbox.ID, Title: "排序", DueAt: &value}); err != nil {
			t.Fatal(err)
		}
	}
	tasks, err := s.ListTasks(ctx, userID, TaskFilter{View: "all"})
	if err != nil || len(tasks) != 2 {
		t.Fatalf("tasks = %d (%v)", len(tasks), err)
	}
	if !tasks[0].DueAt.Before(*tasks[1].DueAt) {
		t.Fatalf("tasks not ordered by instant: %v, %v", tasks[0].DueAt, tasks[1].DueAt)
	}
	if loc := tasks[0].DueAt.Location(); loc != time.UTC {
		t.Fatalf("due not normalized to UTC: %v", loc)
	}
}

func TestTaskCompletionAndDelete(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	inbox, _ := s.EnsureInbox(ctx, userID)

	task, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: inbox.ID, Title: "买菜", Tags: StringList{"生活"}})
	if err != nil {
		t.Fatal(err)
	}
	updated, err := s.SetTaskCompleted(ctx, userID, task.ID, true)
	if err != nil {
		t.Fatal(err)
	}
	if !updated.Completed || updated.CompletedAt == nil {
		t.Fatalf("completion not stored: %+v", updated)
	}
	updated, err = s.SetTaskCompleted(ctx, userID, task.ID, false)
	if err != nil {
		t.Fatal(err)
	}
	if updated.Completed || updated.CompletedAt != nil {
		t.Fatalf("uncompletion not stored: %+v", updated)
	}

	if err := s.DeleteTask(ctx, userID, task.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetTask(ctx, userID, task.ID); err != ErrNotFound {
		t.Fatalf("deleted task still readable: %v", err)
	}
	other, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: inbox.ID, Title: "另一件事"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.SetTaskCompleted(ctx, userID, other.ID, true); err != nil {
		t.Fatal(err)
	}
	removed, err := s.PurgeCompletedTasks(ctx, userID)
	if err != nil || removed != 1 {
		t.Fatalf("purge = %d (%v)", removed, err)
	}
}

func TestTaskTrashLifecycle(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	inbox, _ := s.EnsureInbox(ctx, userID)
	work, err := s.CreateTaskList(ctx, userID, "临时清单", "#ff0000")
	if err != nil {
		t.Fatal(err)
	}
	task, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: work.ID, Title: "待恢复"})
	if err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteTask(ctx, userID, task.ID); err != nil {
		t.Fatal(err)
	}
	deleted, err := s.ListDeletedTasks(ctx, userID, 20)
	if err != nil || len(deleted) != 1 || deleted[0].DeletedAt == nil {
		t.Fatalf("deleted = %+v (%v)", deleted, err)
	}
	if err := s.DeleteTaskList(ctx, userID, work.ID); err != nil {
		t.Fatal(err)
	}
	restored, err := s.RestoreTask(ctx, userID, task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if restored.Deleted || restored.Completed || restored.VTODOETag != "" {
		t.Fatalf("unexpected restored task: %+v", restored)
	}
	if restored.ListID != inbox.ID {
		t.Fatalf("restored into missing list: %d", restored.ListID)
	}
	if err := s.DeleteTask(ctx, userID, task.ID); err != nil {
		t.Fatal(err)
	}
	if err := s.PurgeTask(ctx, userID, task.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetTask(ctx, userID, task.ID); err != ErrNotFound {
		t.Fatalf("purged task readable: %v", err)
	}
	if count, err := s.TaskCounts(ctx, userID); err != nil || count.Trash != 0 {
		t.Fatalf("trash count = %d (%v)", count.Trash, err)
	}
}

func TestTaskManualOrder(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	inbox, _ := s.EnsureInbox(ctx, userID)
	var ids []int64
	for _, title := range []string{"一", "二", "三"} {
		task, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: inbox.ID, Title: title})
		if err != nil {
			t.Fatal(err)
		}
		ids = append(ids, task.ID)
	}
	if err := s.SetTaskOrder(ctx, userID, []int64{ids[2], ids[0], ids[1]}); err != nil {
		t.Fatal(err)
	}
	tasks, err := s.ListTasks(ctx, userID, TaskFilter{View: "inbox", ListID: inbox.ID})
	if err != nil || len(tasks) != 3 {
		t.Fatalf("tasks = %d (%v)", len(tasks), err)
	}
	want := []int64{ids[2], ids[0], ids[1]}
	for index, id := range want {
		if tasks[index].ID != id {
			t.Fatalf("order[%d] = %d, want %d", index, tasks[index].ID, id)
		}
	}
}

func TestTaskReminderAtDueTime(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	inbox, _ := s.EnsureInbox(ctx, userID)
	due := time.Date(2026, 10, 24, 9, 0, 0, 0, time.UTC)
	task, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: inbox.ID, Title: "准时提醒", DueAt: &due, ReminderOffset: 0})
	if err != nil {
		t.Fatal(err)
	}
	if task.ReminderOffset != 0 {
		t.Fatalf("created reminder offset = %d, want 0", task.ReminderOffset)
	}
	reloaded, err := s.GetTask(ctx, userID, task.ID)
	if err != nil || reloaded.ReminderOffset != 0 {
		t.Fatalf("reloaded reminder offset = %d (%v), want 0", reloaded.ReminderOffset, err)
	}
}

func TestTaskMultipleReminders(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	inbox, _ := s.EnsureInbox(ctx, userID)
	due := time.Date(2026, 10, 24, 9, 0, 0, 0, time.UTC)
	task, err := s.CreateTask(ctx, &Task{
		UserID: userID, ListID: inbox.ID, Title: "多提醒", DueAt: &due,
		ReminderOffsets: StringList{"15", "0", "60", "15"},
	})
	if err != nil {
		t.Fatal(err)
	}
	want := []int{0, 15, 60}
	got := task.ReminderValues()
	if len(got) != len(want) {
		t.Fatalf("reminders = %v, want %v", got, want)
	}
	for index := range want {
		if got[index] != want[index] {
			t.Fatalf("reminders = %v, want %v", got, want)
		}
	}
	if task.ReminderOffset != 60 {
		t.Fatalf("legacy reminder = %d, want earliest 60", task.ReminderOffset)
	}
	reloaded, err := s.GetTask(ctx, userID, task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if values := reloaded.ReminderValues(); len(values) != 3 || values[0] != 0 || values[2] != 60 {
		t.Fatalf("reloaded reminders = %v", values)
	}
}

func TestDeleteNoteListKeepsNotesInNoteList(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	noteList, err := s.CreateTaskListKind(ctx, userID, "临时笔记", "#4772fa", "NOTE")
	if err != nil {
		t.Fatal(err)
	}
	note, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: noteList.ID, Kind: "NOTE", Title: "不要丢"})
	if err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteTaskList(ctx, userID, noteList.ID); err != nil {
		t.Fatal(err)
	}
	moved, err := s.GetTask(ctx, userID, note.ID)
	if err != nil {
		t.Fatal(err)
	}
	fallback, err := s.GetTaskList(ctx, userID, moved.ListID)
	if err != nil {
		t.Fatal(err)
	}
	if fallback.Kind != "NOTE" || fallback.IsInbox {
		t.Fatalf("note moved to non-note list: %+v", fallback)
	}

	trashedList, err := s.CreateTaskListKind(ctx, userID, "待恢复笔记", "#4772fa", "NOTE")
	if err != nil {
		t.Fatal(err)
	}
	trashed, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: trashedList.ID, Kind: "NOTE", Title: "恢复我"})
	if err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteTask(ctx, userID, trashed.ID); err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteTaskList(ctx, userID, trashedList.ID); err != nil {
		t.Fatal(err)
	}
	restored, err := s.RestoreTask(ctx, userID, trashed.ID)
	if err != nil {
		t.Fatal(err)
	}
	restoredList, err := s.GetTaskList(ctx, userID, restored.ListID)
	if err != nil {
		t.Fatal(err)
	}
	if restoredList.Kind != "NOTE" || restoredList.IsInbox {
		t.Fatalf("restored note moved to non-note list: %+v", restoredList)
	}
}

func TestNormalizeCrossKindTaskLists(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	inbox, err := s.EnsureInbox(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	taskList, err := s.CreateTaskListKind(ctx, userID, "任务区", "#ff0000", "TASK")
	if err != nil {
		t.Fatal(err)
	}
	noteList, err := s.CreateTaskListKind(ctx, userID, "笔记区", "#4772fa", "NOTE")
	if err != nil {
		t.Fatal(err)
	}
	task, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: noteList.ID, Kind: "TASK", Title: "误入笔记"})
	if err != nil {
		t.Fatal(err)
	}
	note, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: taskList.ID, Kind: "NOTE", Title: "误入任务"})
	if err != nil {
		t.Fatal(err)
	}
	if err := normalizeTaskListKinds(ctx, s.db.WithContext(ctx)); err != nil {
		t.Fatal(err)
	}
	movedTask, err := s.GetTask(ctx, userID, task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if movedTask.ListID != inbox.ID {
		t.Fatalf("task should return to inbox: %+v", movedTask)
	}
	movedNote, err := s.GetTask(ctx, userID, note.ID)
	if err != nil {
		t.Fatal(err)
	}
	if movedNote.ListID != noteList.ID {
		t.Fatalf("note should return to a note list: %+v", movedNote)
	}
}

func TestTaskWorkspaceRevisionChanges(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	before, err := s.TaskWorkspaceRevision(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	inbox, _ := s.EnsureInbox(ctx, userID)
	task, err := s.CreateTask(ctx, &Task{UserID: userID, ListID: inbox.ID, Title: "revision"})
	if err != nil {
		t.Fatal(err)
	}
	created, err := s.TaskWorkspaceRevision(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if created == before {
		t.Fatalf("revision did not change after create: %q", created)
	}
	task.Title = "revision 2"
	task.SyncPending = true
	if err := s.UpdateTask(ctx, task); err != nil {
		t.Fatal(err)
	}
	updated, err := s.TaskWorkspaceRevision(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if updated == created {
		t.Fatalf("revision did not change after update: %q", updated)
	}
}
