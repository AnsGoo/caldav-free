package store

import (
	"context"
	"testing"
	"time"
)

func TestTaskAndListPinning(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()

	inbox, err := s.EnsureInbox(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	alpha, err := s.CreateTaskList(ctx, userID, "Alpha", "#ff0000")
	if err != nil {
		t.Fatal(err)
	}
	beta, err := s.CreateTaskList(ctx, userID, "Beta", "#00ff00")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.SetTaskListPinned(ctx, userID, beta.ID, true); err != nil {
		t.Fatal(err)
	}
	lists, err := s.ListTaskLists(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if len(lists) != 3 || lists[0].ID != beta.ID {
		t.Fatalf("pinned list should sort first: %+v", lists)
	}
	if lists[0].ID == inbox.ID || lists[0].ID == alpha.ID {
		t.Fatalf("unexpected first list: %+v", lists[0])
	}

	first := &Task{UserID: userID, ListID: alpha.ID, Title: "先到期"}
	due := time.Now().UTC().Add(2 * time.Hour)
	first.DueAt = &due
	first, err = s.CreateTask(ctx, first)
	if err != nil {
		t.Fatal(err)
	}
	second := &Task{UserID: userID, ListID: alpha.ID, Title: "后到期"}
	later := due.Add(24 * time.Hour)
	second.DueAt = &later
	second, err = s.CreateTask(ctx, second)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.SetTaskPinned(ctx, userID, second.ID, true); err != nil {
		t.Fatal(err)
	}
	tasks, err := s.ListTasks(ctx, userID, TaskFilter{View: "list", ListID: alpha.ID})
	if err != nil {
		t.Fatal(err)
	}
	if len(tasks) != 2 || tasks[0].ID != second.ID {
		t.Fatalf("pinned task should sort first: %+v", tasks)
	}
	unpinned, err := s.SetTaskPinned(ctx, userID, second.ID, false)
	if err != nil {
		t.Fatal(err)
	}
	if unpinned.PinnedAt != nil {
		t.Fatalf("unpin should clear pinned time: %+v", unpinned.PinnedAt)
	}
}

func TestFilterDateRanges(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	inbox, err := s.EnsureInbox(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	today := taskTodayStart(time.Now())
	dates := []time.Time{
		today.AddDate(0, 0, -1).Add(2 * time.Hour),
		today.Add(2 * time.Hour),
		today.AddDate(0, 0, 1).Add(2 * time.Hour),
		today.AddDate(0, 0, 10).Add(2 * time.Hour),
	}
	for index, due := range dates {
		d := due
		task := &Task{UserID: userID, ListID: inbox.ID, Title: "range", DueAt: &d}
		if _, err := s.CreateTask(ctx, task); err != nil {
			t.Fatalf("create task %d: %v", index, err)
		}
	}

	run := func(cond TaskFilterConditions) []*Task {
		t.Helper()
		rows, err := s.ListFilteredTasks(ctx, userID, cond, 100)
		if err != nil {
			t.Fatal(err)
		}
		return rows
	}
	// "today" keeps the existing smart-list semantics: everything due before
	// the end of today, including overdue work.
	if rows := run(TaskFilterConditions{Date: "today"}); len(rows) != 2 {
		t.Fatalf("today filter = %d rows, want 2", len(rows))
	}
	if rows := run(TaskFilterConditions{Date: "yesterday"}); len(rows) != 1 {
		t.Fatalf("yesterday filter = %d rows, want 1", len(rows))
	}
	if rows := run(TaskFilterConditions{Date: "tomorrow"}); len(rows) != 1 {
		t.Fatalf("tomorrow filter = %d rows, want 1", len(rows))
	}
	localNow := time.Now().In(filterLocation())
	localToday := time.Date(localNow.Year(), localNow.Month(), localNow.Day(), 0, 0, 0, 0, filterLocation())
	from := localToday.AddDate(0, 0, -1).Format("2006-01-02")
	to := localToday.AddDate(0, 0, 1).Format("2006-01-02")
	if rows := run(TaskFilterConditions{Date: "range", DateFrom: from, DateTo: to}); len(rows) != 3 {
		t.Fatalf("range filter = %d rows, want 3", len(rows))
	}
	if rows := run(TaskFilterConditions{Date: "range", DateFrom: to, DateTo: from}); len(rows) != 0 {
		t.Fatalf("reversed range = %d rows, want 0", len(rows))
	}
}
