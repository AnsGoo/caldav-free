package store

import (
	"context"
	"testing"

	"caldav-free/internal/auth"
)

func TestTaskCommentsAndAccess(t *testing.T) {
	s, aliceID := newTaskUser(t)
	ctx := context.Background()
	hash, _ := auth.HashPassword("password123")
	bob, err := s.CreateUser(ctx, "bob", "Bob", "", hash, true)
	if err != nil {
		t.Fatal(err)
	}
	inbox, _ := s.EnsureInbox(ctx, aliceID)
	list, _ := s.CreateTaskList(ctx, aliceID, "共享", "#123456")
	task, err := s.CreateTask(ctx, &Task{UserID: aliceID, ListID: list.ID, Title: "评论任务"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.ShareTaskList(ctx, aliceID, list.ID, "bob", "editor"); err != nil {
		t.Fatal(err)
	}
	access, err := s.GetTaskAccess(ctx, bob.ID, task.ID)
	if err != nil || access.Role != "editor" || access.Task.ID != task.ID {
		t.Fatalf("shared access = %+v (%v)", access, err)
	}
	if _, err := s.CreateTaskComment(ctx, task.ID, bob.ID, "@alice 你好"); err != nil {
		t.Fatal(err)
	}
	comments, err := s.ListTaskComments(ctx, task.ID)
	if err != nil || len(comments) != 1 || comments[0].Username != "bob" {
		t.Fatalf("comments = %+v (%v)", comments, err)
	}
	if err := s.DeleteTaskComment(ctx, task.ID, comments[0].ID); err != nil {
		t.Fatal(err)
	}
	if comments, _ := s.ListTaskComments(ctx, task.ID); len(comments) != 0 {
		t.Fatalf("comments not deleted: %+v", comments)
	}
	_ = inbox
}
