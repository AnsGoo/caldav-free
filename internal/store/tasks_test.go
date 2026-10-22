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
