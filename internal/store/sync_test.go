package store

import (
	"context"
	"testing"
)

func newSyncTestStore(t *testing.T) (*Store, int64) {
	t.Helper()
	st, err := Open(t.TempDir() + "/sync.db")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	user, err := st.CreateUser(context.Background(), "sync-user", "", "", "hash", false)
	if err != nil {
		t.Fatal(err)
	}
	return st, user.ID
}

func TestSyncJournalTracksWrites(t *testing.T) {
	st, userID := newSyncTestStore(t)
	ctx := context.Background()

	inbox, err := st.EnsureInbox(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if inbox.SyncID == "" {
		t.Fatal("inbox has no sync id")
	}

	changes, _, err := st.SyncChangesSince(ctx, userID, 0, 100)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes) != 1 || changes[0].Entity != SyncEntityList || changes[0].EntityID != inbox.SyncID {
		t.Fatalf("unexpected initial changes: %+v", changes)
	}
	cursor := changes[0].ID

	task, err := st.CreateTask(ctx, &Task{UserID: userID, ListID: inbox.ID, Title: "first"})
	if err != nil {
		t.Fatal(err)
	}
	if task.SyncID == "" {
		t.Fatal("task has no sync id")
	}
	changes, _, err = st.SyncChangesSince(ctx, userID, cursor, 100)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes) != 1 || changes[0].Entity != SyncEntityTask || changes[0].Op != "put" {
		t.Fatalf("unexpected create changes: %+v", changes)
	}
	cursor = changes[0].ID

	// Simulating a CalDAV reconciliation updates bookkeeping fields only. That
	// must not wake clients up.
	if err := st.SetTaskSync(ctx, userID, task.ID, "uid", "href.ics", "etag"); err != nil {
		t.Fatal(err)
	}
	changes, _, err = st.SyncChangesSince(ctx, userID, cursor, 100)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes) != 0 {
		t.Fatalf("bookkeeping update should not journal: %+v", changes)
	}

	task.Title = "renamed"
	if err := st.UpdateTask(ctx, task); err != nil {
		t.Fatal(err)
	}
	changes, _, err = st.SyncChangesSince(ctx, userID, cursor, 100)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes) != 1 || changes[0].ID <= cursor {
		t.Fatalf("update not journaled: %+v", changes)
	}
	cursor = changes[0].ID

	// SyncPending alone is not user-visible state.
	if err := st.DB().Model(&Task{}).Where("id = ?", task.ID).Update("sync_pending", true).Error; err != nil {
		t.Fatal(err)
	}
	changes, _, _ = st.SyncChangesSince(ctx, userID, cursor, 100)
	if len(changes) != 0 {
		t.Fatalf("sync_pending should not journal: %+v", changes)
	}

	if err := st.DeleteTask(ctx, userID, task.ID); err != nil {
		t.Fatal(err)
	}
	changes, _, err = st.SyncChangesSince(ctx, userID, cursor, 100)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes) != 1 || changes[0].Op != "delete" {
		t.Fatalf("delete not journaled: %+v", changes)
	}
}

func TestSyncJournalSurvivesRestart(t *testing.T) {
	path := t.TempDir() + "/restart.db"
	st, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	user, err := st.CreateUser(context.Background(), "restart", "", "", "hash", false)
	if err != nil {
		t.Fatal(err)
	}
	inbox, err := st.EnsureInbox(context.Background(), user.ID)
	if err != nil {
		t.Fatal(err)
	}
	task, err := st.CreateTask(context.Background(), &Task{UserID: user.ID, ListID: inbox.ID, Title: "before restart"})
	if err != nil {
		t.Fatal(err)
	}
	cursor, err := st.SyncUserSeq(context.Background(), user.ID)
	if err != nil {
		t.Fatal(err)
	}
	if err := st.Close(); err != nil {
		t.Fatal(err)
	}

	// Reopening runs AutoMigrate with the journal triggers present. That must
	// not fail and must not duplicate journal rows.
	st, err = Open(path)
	if err != nil {
		t.Fatalf("reopen: %v", err)
	}
	defer st.Close()
	after, err := st.SyncUserSeq(context.Background(), user.ID)
	if err != nil {
		t.Fatal(err)
	}
	if after != cursor {
		t.Fatalf("restart changed journal cursor: %d -> %d", cursor, after)
	}
	task.Title = "after restart"
	if err := st.UpdateTask(context.Background(), task); err != nil {
		t.Fatal(err)
	}
	changes, _, err := st.SyncChangesSince(context.Background(), user.ID, after, 10)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes) != 1 || changes[0].Entity != SyncEntityTask || changes[0].Op != "put" {
		t.Fatalf("triggers not reinstalled after restart: %+v", changes)
	}
}

func TestSyncJournalBackfillsLegacyRows(t *testing.T) {
	st, userID := newSyncTestStore(t)
	ctx := context.Background()
	inbox, err := st.EnsureInbox(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	task, err := st.CreateTask(ctx, &Task{UserID: userID, ListID: inbox.ID, Title: "legacy"})
	if err != nil {
		t.Fatal(err)
	}
	// Emulate a database created before the journal existed.
	if err := st.DB().Exec("DELETE FROM sync_logs").Error; err != nil {
		t.Fatal(err)
	}
	if err := installSyncJournal(st.DB()); err != nil {
		t.Fatal(err)
	}
	changes, _, err := st.SyncChangesSince(ctx, userID, 0, 100)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes) != 2 {
		t.Fatalf("expected 2 backfilled rows, got %+v", changes)
	}
	seq, err := st.SyncEntitySeq(ctx, userID, SyncEntityTask, task.SyncID)
	if err != nil || seq == 0 {
		t.Fatalf("task sequence = %d, %v", seq, err)
	}
}
