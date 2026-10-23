package store

import (
	"context"
	"testing"

	"caldav-free/internal/auth"
)

func TestTaskListSharing(t *testing.T) {
	s, aliceID := newTaskUser(t)
	ctx := context.Background()
	hash, _ := auth.HashPassword("password123")
	bob, err := s.CreateUser(ctx, "bob", "Bob", "", hash, true)
	if err != nil {
		t.Fatal(err)
	}
	inbox, _ := s.EnsureInbox(ctx, aliceID)
	list, err := s.CreateTaskList(ctx, aliceID, "项目", "#123456")
	if err != nil {
		t.Fatal(err)
	}
	task, err := s.CreateTask(ctx, &Task{UserID: aliceID, ListID: list.ID, Title: "共享任务"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.ShareTaskList(ctx, aliceID, list.ID, "bob", "viewer"); err != nil {
		t.Fatal(err)
	}
	shared, err := s.ListSharedTaskLists(ctx, bob.ID)
	if err != nil || len(shared) != 1 || shared[0].ListID != list.ID || shared[0].Count != 1 {
		t.Fatalf("shared lists = %+v (%v)", shared, err)
	}
	tasks, err := s.ListSharedTasks(ctx, bob.ID, list.ID)
	if err != nil || len(tasks) != 1 || tasks[0].ID != task.ID {
		t.Fatalf("shared tasks = %+v (%v)", tasks, err)
	}
	if _, _, err := s.GetSharedTaskList(ctx, aliceID, list.ID); err == nil {
		t.Fatal("owner should not resolve their own list as a share")
	}
	if err := s.DeleteTaskListShare(ctx, aliceID, list.ID, bob.ID); err != nil {
		t.Fatal(err)
	}
	if shared, _ := s.ListSharedTaskLists(ctx, bob.ID); len(shared) != 0 {
		t.Fatalf("share not deleted: %+v", shared)
	}
	if err := s.DeleteTaskList(ctx, aliceID, inbox.ID); err == nil {
		t.Fatal("inbox cannot be deleted")
	}
}
