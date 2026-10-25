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
	if _, err := s.ShareTaskList(ctx, aliceID, list.ID, "bob", "editor"); err != nil {
		t.Fatal(err)
	}
	members, err := s.ListTaskListMembers(ctx, bob.ID, list.ID)
	if err != nil || len(members) != 2 || members[0].Username != "alice" || members[1].Username != "bob" {
		t.Fatalf("members = %+v (%v)", members, err)
	}
	task.Assignee = "bob"
	if err := s.UpdateTask(ctx, task); err != nil {
		t.Fatal(err)
	}
	if assigned, _ := s.GetTask(ctx, aliceID, task.ID); assigned.Assignee != "bob" {
		t.Fatalf("assignee = %q", assigned.Assignee)
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

func TestSharedNoteListKeepsKind(t *testing.T) {
	s, aliceID := newTaskUser(t)
	ctx := context.Background()
	hash, _ := auth.HashPassword("password123")
	bob, err := s.CreateUser(ctx, "bob", "Bob", "", hash, true)
	if err != nil {
		t.Fatal(err)
	}
	noteList, err := s.CreateTaskListKind(ctx, aliceID, "共享笔记", "#4772fa", "NOTE")
	if err != nil {
		t.Fatal(err)
	}
	note, err := s.CreateTask(ctx, &Task{UserID: aliceID, ListID: noteList.ID, Kind: "NOTE", Title: "共享笔记"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.ShareTaskList(ctx, aliceID, noteList.ID, "bob", "editor"); err != nil {
		t.Fatal(err)
	}
	shared, err := s.ListSharedTaskLists(ctx, bob.ID)
	if err != nil || len(shared) != 1 || shared[0].Kind != "NOTE" {
		t.Fatalf("shared note list = %+v (%v)", shared, err)
	}
	tasks, err := s.ListSharedTasks(ctx, bob.ID, noteList.ID)
	if err != nil || len(tasks) != 1 || tasks[0].ID != note.ID || tasks[0].Kind != "NOTE" {
		t.Fatalf("shared notes = %+v (%v)", tasks, err)
	}
}

func TestTaskShareSingleNote(t *testing.T) {
	s, aliceID := newTaskUser(t)
	ctx := context.Background()
	hash, _ := auth.HashPassword("password123")
	bob, err := s.CreateUser(ctx, "bob", "Bob", "", hash, true)
	if err != nil {
		t.Fatal(err)
	}
	noteList, err := s.CreateTaskListKind(ctx, aliceID, "笔记", "#4772fa", "NOTE")
	if err != nil {
		t.Fatal(err)
	}
	note, err := s.CreateTask(ctx, &Task{UserID: aliceID, ListID: noteList.ID, Kind: "NOTE", Title: "单篇共享"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.ShareTask(ctx, aliceID, note.ID, "bob", "editor"); err != nil {
		t.Fatal(err)
	}
	access, err := s.GetTaskAccess(ctx, bob.ID, note.ID)
	if err != nil || access.Role != "editor" || access.Task.ID != note.ID {
		t.Fatalf("task access = %+v (%v)", access, err)
	}
	shared, err := s.ListSharedNotes(ctx, bob.ID)
	if err != nil || len(shared) != 1 || shared[0].Task.ID != note.ID || shared[0].Role != "editor" {
		t.Fatalf("shared notes = %+v (%v)", shared, err)
	}
	if err := s.DeleteTaskShare(ctx, aliceID, note.ID, bob.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetTaskAccess(ctx, bob.ID, note.ID); err == nil {
		t.Fatal("removed task share should not grant access")
	}
}
