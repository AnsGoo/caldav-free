package web

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"testing"
	"time"

	"caldav-free/internal/store"
	"caldav-free/internal/syncapi"
)

func (e *apiEnv) syncRequest(t *testing.T, method, path string, payload any) (int, []byte) {
	t.Helper()
	var reader io.Reader
	if payload != nil {
		data, err := json.Marshal(payload)
		if err != nil {
			t.Fatal(err)
		}
		reader = bytes.NewReader(data)
	}
	req, err := http.NewRequest(method, e.server.URL+path, reader)
	if err != nil {
		t.Fatal(err)
	}
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	req.SetBasicAuth("admin", "adminpass123")
	resp, err := e.server.Client().Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, body
}

func (e *apiEnv) pull(t *testing.T, since string) syncapi.PullResponse {
	t.Helper()
	path := "/api/sync/pull"
	if since != "" {
		path += "?since=" + since
	}
	status, body := e.syncRequest(t, "GET", path, nil)
	if status != http.StatusOK {
		t.Fatalf("pull = %d: %s", status, body)
	}
	return decode[syncapi.PullResponse](t, body)
}

func (e *apiEnv) push(t *testing.T, ops ...syncapi.PushOp) syncapi.PushResponse {
	t.Helper()
	status, body := e.syncRequest(t, "POST", "/api/sync/push", syncapi.PushRequest{
		DeviceID: "test-device", Ops: ops,
	})
	if status != http.StatusOK {
		t.Fatalf("push = %d: %s", status, body)
	}
	return decode[syncapi.PushResponse](t, body)
}

func snapshotAs[T any](t *testing.T, result syncapi.PushResult) T {
	t.Helper()
	data, err := json.Marshal(result.Snapshot)
	if err != nil {
		t.Fatal(err)
	}
	return decode[T](t, data)
}

func findTask(tasks []syncapi.TaskDTO, id string) *syncapi.TaskDTO {
	for i := range tasks {
		if tasks[i].ID == id {
			return &tasks[i]
		}
	}
	return nil
}

func TestSyncProtocolConvergesTwoClients(t *testing.T) {
	env := newAPIEnv(t)

	// Unauthenticated requests must be rejected.
	req, _ := http.NewRequest("GET", env.server.URL+"/api/sync/pull", nil)
	resp, err := env.server.Client().Do(req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("unauthenticated pull = %d", resp.StatusCode)
	}

	initial := env.pull(t, "0")
	if len(initial.Tasks) != 0 {
		t.Fatalf("unexpected initial tasks: %+v", initial.Tasks)
	}

	listID := "01list0000000000000000001"
	listPush := env.push(t, syncapi.PushOp{
		OpID: "op-list-1", Entity: "list", EntityID: listID, Action: "create",
		Patch: map[string]json.RawMessage{
			"name":  json.RawMessage(`"客户端清单"`),
			"color": json.RawMessage(`"#123456"`),
		},
	})
	if len(listPush.Results) != 1 || listPush.Results[0].Status != "ok" {
		t.Fatalf("list push failed: %+v", listPush.Results)
	}
	list := snapshotAs[syncapi.ListDTO](t, listPush.Results[0])
	if list.ID != listID || list.Name != "客户端清单" || list.ETag == "" {
		t.Fatalf("bad list snapshot: %+v", list)
	}

	taskID := "01task0000000000000000001"
	taskPush := env.push(t, syncapi.PushOp{
		OpID: "op-task-1", Entity: "task", EntityID: taskID, Action: "create",
		Patch: map[string]json.RawMessage{
			"listId":          json.RawMessage(`"` + listID + `"`),
			"title":           json.RawMessage(`"写协议"`),
			"notes":           json.RawMessage(`"第一版"`),
			"due":             json.RawMessage(`"2026-10-26T09:00:00Z"`),
			"priority":        json.RawMessage(`2`),
			"tags":            json.RawMessage(`["sync","p0"]`),
			"allDay":          json.RawMessage(`false`),
			"reminderOffsets": json.RawMessage(`[30]`),
		},
	})
	if len(taskPush.Results) != 1 || taskPush.Results[0].Status != "ok" {
		t.Fatalf("task push failed: %+v", taskPush.Results)
	}
	created := snapshotAs[syncapi.TaskDTO](t, taskPush.Results[0])
	if created.ID != taskID || created.ListID != listID || created.Title != "写协议" || created.ETag == "" {
		t.Fatalf("bad task snapshot: %+v", created)
	}
	if created.Priority != 2 || len(created.Tags) != 2 || created.Due == "" || len(created.ReminderOffsets) != 1 {
		t.Fatalf("task fields lost: %+v", created)
	}

	// A second device starts from zero and sees both entities.
	deviceB := env.pull(t, "0")
	if findTask(deviceB.Tasks, taskID) == nil {
		t.Fatalf("device B did not receive the task: %+v", deviceB.Tasks)
	}
	foundList := false
	for _, item := range deviceB.Lists {
		if item.ID == listID {
			foundList = true
		}
	}
	if !foundList {
		t.Fatalf("device B did not receive the list: %+v", deviceB.Lists)
	}
	bCursor := deviceB.Cursor

	// Both devices edit the same revision: the first wins, the second gets a
	// conflict carrying the current server snapshot.
	baseETag := created.ETag
	first := env.push(t, syncapi.PushOp{
		OpID: "op-a-title", Entity: "task", EntityID: taskID, Action: "update",
		BaseETag: baseETag,
		Patch:    map[string]json.RawMessage{"title": json.RawMessage(`"A 改的标题"`)},
	})
	if first.Results[0].Status != "ok" || first.Results[0].ETag == baseETag {
		t.Fatalf("A update failed: %+v", first.Results[0])
	}
	etagA := first.Results[0].ETag

	second := env.push(t, syncapi.PushOp{
		OpID: "op-b-notes", Entity: "task", EntityID: taskID, Action: "update",
		BaseETag: baseETag,
		Patch:    map[string]json.RawMessage{"notes": json.RawMessage(`"B 改的备注"`)},
	})
	if second.Results[0].Status != "conflict" {
		t.Fatalf("B update should conflict: %+v", second.Results[0])
	}
	conflictSnapshot := snapshotAs[syncapi.TaskDTO](t, second.Results[0])
	if conflictSnapshot.Title != "A 改的标题" || conflictSnapshot.ETag != etagA {
		t.Fatalf("conflict snapshot is stale: %+v", conflictSnapshot)
	}

	// B retries on top of A's revision. Both fields survive (field-level merge
	// is done by the client using the returned snapshot).
	retry := env.push(t, syncapi.PushOp{
		OpID: "op-b-notes-retry", Entity: "task", EntityID: taskID, Action: "update",
		BaseETag: etagA,
		Patch:    map[string]json.RawMessage{"notes": json.RawMessage(`"B 改的备注"`)},
	})
	if retry.Results[0].Status != "ok" {
		t.Fatalf("B retry failed: %+v", retry.Results[0])
	}
	etagB := retry.Results[0].ETag

	// Replaying an acknowledged op returns the stored result and writes nothing.
	cursorBefore := retry.Cursor
	replay := env.push(t, syncapi.PushOp{
		OpID: "op-a-title", Entity: "task", EntityID: taskID, Action: "update",
		BaseETag: baseETag,
		Patch:    map[string]json.RawMessage{"title": json.RawMessage(`"A 改的标题"`)},
	})
	if replay.Results[0].Status != "ok" || replay.Results[0].ETag != etagA {
		t.Fatalf("replay did not return stored result: %+v", replay.Results[0])
	}
	if replay.Cursor != cursorBefore {
		t.Fatalf("replay advanced cursor: %s -> %s", cursorBefore, replay.Cursor)
	}

	// A third device sees the merged state.
	third := env.pull(t, bCursor)
	merged := findTask(third.Tasks, taskID)
	if merged == nil || merged.Title != "A 改的标题" || merged.Notes != "B 改的备注" {
		t.Fatalf("merged state not visible: %+v", merged)
	}

	// A stale delete is rejected, then succeeds against the current revision.
	staleDelete := env.push(t, syncapi.PushOp{
		OpID: "op-delete-stale", Entity: "task", EntityID: taskID, Action: "delete",
		BaseETag: baseETag,
	})
	if staleDelete.Results[0].Status != "conflict" {
		t.Fatalf("stale delete should conflict: %+v", staleDelete.Results[0])
	}
	deletePush := env.push(t, syncapi.PushOp{
		OpID: "op-delete", Entity: "task", EntityID: taskID, Action: "delete",
		BaseETag: etagB,
	})
	if deletePush.Results[0].Status != "ok" {
		t.Fatalf("delete failed: %+v", deletePush.Results[0])
	}

	afterDelete := env.pull(t, third.Cursor)
	deleted := findTask(afterDelete.Tasks, taskID)
	if deleted == nil || !deleted.Deleted || deleted.DeletedAt == "" {
		t.Fatalf("soft delete not visible: %+v", deleted)
	}
	gone := env.push(t, syncapi.PushOp{
		OpID: "op-update-deleted", Entity: "task", EntityID: taskID, Action: "update",
		BaseETag: deletePush.Results[0].ETag,
		Patch:    map[string]json.RawMessage{"title": json.RawMessage(`"复活"`)},
	})
	if gone.Results[0].Status != "gone" {
		t.Fatalf("updating a trashed task should report gone: %+v", gone.Results[0])
	}

	// A permanent purge becomes a tombstone.
	task, err := env.store.GetTaskBySyncID(context.Background(), env.userID, taskID)
	if err != nil {
		t.Fatal(err)
	}
	if err := env.store.PurgeTask(context.Background(), env.userID, task.ID); err != nil {
		t.Fatal(err)
	}
	afterPurge := env.pull(t, afterDelete.Cursor)
	foundTombstone := false
	for _, item := range afterPurge.Tombstones {
		if item.Entity == "task" && item.ID == taskID {
			foundTombstone = true
		}
	}
	if !foundTombstone {
		t.Fatalf("purge did not produce a tombstone: %+v", afterPurge)
	}
}

func TestSyncRestoreAndPurgeTask(t *testing.T) {
	env := newAPIEnv(t)

	created := env.push(t, syncapi.PushOp{
		OpID: "op-restore-create", Entity: "task", Action: "create",
		Patch: map[string]json.RawMessage{
			"title": json.RawMessage(`"回收站任务"`),
		},
	})
	if created.Results[0].Status != "ok" {
		t.Fatalf("create: %+v", created.Results[0])
	}
	taskID := created.Results[0].EntityID
	createETag := created.Results[0].ETag

	deleted := env.push(t, syncapi.PushOp{
		OpID: "op-restore-delete", Entity: "task", EntityID: taskID,
		Action: "delete", BaseETag: createETag,
	})
	if deleted.Results[0].Status != "ok" {
		t.Fatalf("delete: %+v", deleted.Results[0])
	}

	restored := env.push(t, syncapi.PushOp{
		OpID: "op-restore", Entity: "task", EntityID: taskID,
		Action: "restore", BaseETag: deleted.Results[0].ETag,
	})
	if restored.Results[0].Status != "ok" {
		t.Fatalf("restore: %+v", restored.Results[0])
	}
	restoredTask := snapshotAs[syncapi.TaskDTO](t, restored.Results[0])
	if restoredTask.Deleted {
		t.Fatalf("restored task still deleted: %+v", restoredTask)
	}
	if restoredTask.ListID == "" {
		t.Fatalf("restored task has no live list: %+v", restoredTask)
	}

	// Restoring an already-live task is idempotent.
	again := env.push(t, syncapi.PushOp{
		OpID: "op-restore-again", Entity: "task", EntityID: taskID,
		Action: "restore", BaseETag: restored.Results[0].ETag,
	})
	if again.Results[0].Status != "ok" {
		t.Fatalf("idempotent restore: %+v", again.Results[0])
	}

	deletedAgain := env.push(t, syncapi.PushOp{
		OpID: "op-restore-delete-2", Entity: "task", EntityID: taskID,
		Action: "delete", BaseETag: again.Results[0].ETag,
	})
	if deletedAgain.Results[0].Status != "ok" {
		t.Fatalf("delete 2: %+v", deletedAgain.Results[0])
	}

	purged := env.push(t, syncapi.PushOp{
		OpID: "op-purge", Entity: "task", EntityID: taskID,
		Action: "purge", BaseETag: deletedAgain.Results[0].ETag,
	})
	if purged.Results[0].Status != "ok" {
		t.Fatalf("purge: %+v", purged.Results[0])
	}

	after := env.pull(t, deletedAgain.Cursor)
	foundTombstone := false
	for _, item := range after.Tombstones {
		if item.Entity == "task" && item.ID == taskID {
			foundTombstone = true
		}
	}
	if !foundTombstone {
		t.Fatalf("purge did not produce a tombstone: %+v", after)
	}

	// Purge of an already-hard-deleted row is a no-op for the caller.
	gone := env.push(t, syncapi.PushOp{
		OpID: "op-purge-gone", Entity: "task", EntityID: taskID,
		Action: "purge", BaseETag: purged.Results[0].ETag,
	})
	if gone.Results[0].Status != "gone" {
		t.Fatalf("purge gone = %+v", gone.Results[0])
	}
}

func TestSyncRecurringCompleteAndSkip(t *testing.T) {
	env := newAPIEnv(t)
	due := "2026-11-01T09:00:00Z"

	created := env.push(t, syncapi.PushOp{
		OpID: "op-recur-create", Entity: "task", Action: "create",
		Patch: map[string]json.RawMessage{
			"title":      json.RawMessage(`"每日站会"`),
			"due":        json.RawMessage(`"` + due + `"`),
			"recurrence": json.RawMessage(`"FREQ=DAILY"`),
		},
	})
	if created.Results[0].Status != "ok" {
		t.Fatalf("create recurring: %+v", created.Results[0])
	}
	taskID := created.Results[0].EntityID

	completed := env.push(t, syncapi.PushOp{
		OpID: "op-recur-complete", Entity: "task", EntityID: taskID,
		Action: "update", BaseETag: created.Results[0].ETag,
		Patch: map[string]json.RawMessage{
			"completed":   json.RawMessage(`true`),
			"completedAt": json.RawMessage(`"2026-11-01T10:00:00Z"`),
		},
	})
	if completed.Results[0].Status != "ok" {
		t.Fatalf("complete recurring: %+v", completed.Results[0])
	}
	afterComplete := snapshotAs[syncapi.TaskDTO](t, completed.Results[0])
	if afterComplete.Completed {
		t.Fatalf("recurring completion should advance instead of completing: %+v", afterComplete)
	}
	if afterComplete.Due != "2026-11-02T09:00:00Z" {
		t.Fatalf("next due = %q", afterComplete.Due)
	}

	skipped := env.push(t, syncapi.PushOp{
		OpID: "op-recur-skip", Entity: "task", EntityID: taskID,
		Action: "skip", BaseETag: completed.Results[0].ETag,
	})
	if skipped.Results[0].Status != "ok" {
		t.Fatalf("skip recurring: %+v", skipped.Results[0])
	}
	afterSkip := snapshotAs[syncapi.TaskDTO](t, skipped.Results[0])
	if afterSkip.Due != "2026-11-03T09:00:00Z" {
		t.Fatalf("due after skip = %q", afterSkip.Due)
	}
	if afterSkip.Completed {
		t.Fatalf("skip should leave the task open: %+v", afterSkip)
	}

	task, err := env.store.GetTaskBySyncID(context.Background(), env.userID, taskID)
	if err != nil {
		t.Fatal(err)
	}
	rows, err := env.store.ListRecurrenceInstances(
		context.Background(), env.userID, task.ID, 20,
	)
	if err != nil {
		t.Fatal(err)
	}
	statuses := map[string]string{}
	for _, row := range rows {
		statuses[row.OccurrenceAt.UTC().Format(time.RFC3339)] = row.Status
	}
	if statuses["2026-11-01T09:00:00Z"] != "completed" {
		t.Fatalf("completed instance missing: %+v", statuses)
	}
	if statuses["2026-11-02T09:00:00Z"] != "skipped" {
		t.Fatalf("skipped instance missing: %+v", statuses)
	}
}

func TestSyncServerSideWritesAppearInPull(t *testing.T) {
	env := newAPIEnv(t)
	ctx := context.Background()
	inbox, err := env.store.EnsureInbox(ctx, env.userID)
	if err != nil {
		t.Fatal(err)
	}
	// Simulate a CalDAV client creating a VTODO that the reconciler imports.
	task, err := env.store.CreateTask(ctx, &store.Task{
		UserID: env.userID, ListID: inbox.ID, Title: "来自 CalDAV",
	})
	if err != nil {
		t.Fatal(err)
	}
	page := env.pull(t, "0")
	imported := findTask(page.Tasks, task.SyncID)
	if imported == nil || imported.Title != "来自 CalDAV" {
		t.Fatalf("server-side task not pulled: %+v", page.Tasks)
	}

	// A sync client can update it using the server-issued ETag.
	result := env.push(t, syncapi.PushOp{
		OpID: "op-edit-imported", Entity: "task", EntityID: task.SyncID, Action: "update",
		BaseETag: imported.ETag,
		Patch:    map[string]json.RawMessage{"title": json.RawMessage(`"客户端改名"`)},
	})
	if result.Results[0].Status != "ok" {
		t.Fatalf("update imported task: %+v", result.Results[0])
	}

	// A CalDAV-side change after the client's pull bumps the ETag, so the next
	// push from that client conflicts.
	importedETag := imported.ETag
	if err := env.store.UpdateTask(ctx, func() *store.Task {
		current, _ := env.store.GetTaskBySyncID(ctx, env.userID, task.SyncID)
		current.Title = "CalDAV 又改了"
		return current
	}()); err != nil {
		t.Fatal(err)
	}
	conflict := env.push(t, syncapi.PushOp{
		OpID: "op-edit-stale", Entity: "task", EntityID: task.SyncID, Action: "update",
		BaseETag: importedETag,
		Patch:    map[string]json.RawMessage{"notes": json.RawMessage(`"旧客户端"`)},
	})
	if conflict.Results[0].Status != "conflict" {
		t.Fatalf("CalDAV change should conflict: %+v", conflict.Results[0])
	}
	current := snapshotAs[syncapi.TaskDTO](t, conflict.Results[0])
	if current.Title != "CalDAV 又改了" {
		t.Fatalf("conflict should expose CalDAV state: %+v", current)
	}
}

func TestSyncInboxAndPagination(t *testing.T) {
	env := newAPIEnv(t)
	inbox, err := env.store.EnsureInbox(context.Background(), env.userID)
	if err != nil {
		t.Fatal(err)
	}
	created := env.push(t, syncapi.PushOp{
		OpID: "op-inbox-task", Entity: "task", EntityID: "01task0000000000000000002", Action: "create",
		Patch: map[string]json.RawMessage{"title": json.RawMessage(`"无清单任务"`)},
	})
	if created.Results[0].Status != "ok" {
		t.Fatalf("inbox task: %+v", created.Results[0])
	}
	snapshot := snapshotAs[syncapi.TaskDTO](t, created.Results[0])
	if snapshot.ListID != inbox.SyncID {
		t.Fatalf("task should land in inbox: %+v", snapshot)
	}

	status, body := env.syncRequest(t, "GET", "/api/sync/pull?since=0&limit=1", nil)
	if status != http.StatusOK {
		t.Fatalf("paged pull = %d: %s", status, body)
	}
	page := decode[syncapi.PullResponse](t, body)
	if !page.HasMore || page.Cursor == "0" {
		t.Fatalf("expected a second page: %+v", page)
	}
	if count := len(page.Tasks) + len(page.Lists); count != 1 {
		t.Fatalf("limit not honored: %d", count)
	}
}

func TestSyncOrganizationalEntities(t *testing.T) {
	env := newAPIEnv(t)
	folderID := "01folder000000000000000001"
	listID := "01list0000000000000000009"
	sectionID := "01sect00000000000000000009"
	filterID := "01filt00000000000000000009"

	batch := env.push(t,
		syncapi.PushOp{OpID: "op-folder", Entity: "folder", EntityID: folderID, Action: "create",
			Patch: map[string]json.RawMessage{"name": json.RawMessage(`"工作"`), "order": json.RawMessage(`1`)}},
		syncapi.PushOp{OpID: "op-folder-list", Entity: "list", EntityID: listID, Action: "create",
			Patch: map[string]json.RawMessage{
				"name": json.RawMessage(`"项目"`), "folderId": json.RawMessage(`"` + folderID + `"`),
			}},
		syncapi.PushOp{OpID: "op-section", Entity: "section", EntityID: sectionID, Action: "create",
			Patch: map[string]json.RawMessage{"listId": json.RawMessage(`"` + listID + `"`), "name": json.RawMessage(`"待办"`)}},
		syncapi.PushOp{OpID: "op-filter", Entity: "filter", EntityID: filterID, Action: "create",
			Patch: map[string]json.RawMessage{
				"name":       json.RawMessage(`"本周"`),
				"conditions": json.RawMessage(`{"date":"thisWeek","priorities":[2,3]}`),
			}},
	)
	for _, result := range batch.Results {
		if result.Status != "ok" {
			t.Fatalf("create failed: %+v", result)
		}
	}

	page := env.pull(t, "0")
	list := snapshotAs[syncapi.ListDTO](t, batch.Results[1])
	if list.FolderID != folderID {
		t.Fatalf("list folder lost: %+v", list)
	}
	section := snapshotAs[syncapi.SectionDTO](t, batch.Results[2])
	if section.ListID != listID {
		t.Fatalf("section list lost: %+v", section)
	}
	filter := snapshotAs[syncapi.FilterDTO](t, batch.Results[3])
	if !strings.Contains(string(filter.Conditions), "thisWeek") {
		t.Fatalf("filter conditions lost: %s", filter.Conditions)
	}
	if len(page.Folders) == 0 || len(page.Sections) == 0 || len(page.Filters) == 0 {
		t.Fatalf("organizational entities missing from pull: %+v", page)
	}

	// Deleting a folder detaches its lists and tombstones the folder.
	deleted := env.push(t, syncapi.PushOp{
		OpID: "op-folder-delete", Entity: "folder", EntityID: folderID, Action: "delete",
	})
	if deleted.Results[0].Status != "ok" {
		t.Fatalf("folder delete: %+v", deleted.Results[0])
	}
	after := env.pull(t, page.Cursor)
	foundTombstone := false
	for _, item := range after.Tombstones {
		if item.Entity == "folder" && item.ID == folderID {
			foundTombstone = true
		}
	}
	if !foundTombstone {
		t.Fatalf("folder tombstone missing: %+v", after.Tombstones)
	}
	detached := false
	for _, item := range after.Lists {
		if item.ID == listID && item.FolderID == "" {
			detached = true
		}
	}
	if !detached {
		t.Fatalf("list not detached from folder: %+v", after.Lists)
	}
}

func TestSyncCalendarEndpoint(t *testing.T) {
	env := newAPIEnv(t)

	req, _ := http.NewRequest("GET", env.server.URL+"/api/sync/calendar?from=2026-10-01&to=2026-11-01", nil)
	resp, err := env.server.Client().Do(req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("unauthenticated calendar = %d", resp.StatusCode)
	}

	status, body := env.syncRequest(
		t, "GET", "/api/sync/calendar?from=2026-10-01&to=2026-11-01", nil,
	)
	if status != http.StatusOK {
		t.Fatalf("calendar = %d: %s", status, body)
	}
	payload := decode[map[string]json.RawMessage](t, body)
	for _, key := range []string{"calendars", "events", "tasks", "from", "to"} {
		if _, ok := payload[key]; !ok {
			t.Fatalf("calendar response missing %q: %s", key, body)
		}
	}
}

func TestSyncSubscriptions(t *testing.T) {
	env := newAPIEnv(t)

	status, body := env.syncRequest(t, "GET", "/api/sync/subscriptions", nil)
	if status != http.StatusOK {
		t.Fatalf("list subscriptions = %d: %s", status, body)
	}
	if !strings.Contains(string(body), `"subscriptions"`) {
		t.Fatalf("subscriptions payload: %s", body)
	}

	status, body = env.syncRequest(t, "POST", "/api/sync/subscriptions", map[string]any{
		"name": "测试订阅",
		"url":  "https://example.com/feed.ics",
	})
	if status != http.StatusCreated {
		t.Fatalf("create subscription = %d: %s", status, body)
	}
	created := decode[map[string]any](t, body)
	subscription, _ := created["subscription"].(map[string]any)
	id, _ := subscription["id"].(float64)
	if id <= 0 {
		t.Fatalf("subscription id missing: %s", body)
	}

	status, body = env.syncRequest(
		t, "DELETE", "/api/sync/subscriptions/"+strconv.FormatInt(int64(id), 10), nil,
	)
	if status != http.StatusNoContent {
		t.Fatalf("delete subscription = %d: %s", status, body)
	}
}

func TestSyncEventCRUD(t *testing.T) {
	env := newAPIEnv(t)
	ctx := context.Background()
	cal, err := env.store.CreateCalendar(
		ctx, env.userID, "p3-mobile", "移动日历", "", "#3b82f6",
		"Asia/Shanghai", 1, []string{"VEVENT"},
	)
	if err != nil {
		t.Fatal(err)
	}

	status, body := env.syncRequest(t, "POST", "/api/sync/events", map[string]any{
		"calendarId": cal.ID,
		"summary":    "移动端创建",
		"start":      "2026-10-26T10:00:00+08:00",
		"end":        "2026-10-26T11:00:00+08:00",
		"location":   "会议室",
		"reminders":  []int{10},
	})
	if status != http.StatusCreated {
		t.Fatalf("create event = %d: %s", status, body)
	}
	created := decode[map[string]any](t, body)
	href, _ := created["href"].(string)
	if href == "" {
		t.Fatalf("create event href missing: %s", body)
	}

	status, body = env.syncRequest(t, "GET", "/api/sync/calendar?from=2026-10-26&to=2026-10-27", nil)
	if status != http.StatusOK {
		t.Fatalf("calendar = %d: %s", status, body)
	}
	snapshot := decode[struct {
		Events []apiCalendarEvent `json:"events"`
	}](t, body)
	if len(snapshot.Events) != 1 || snapshot.Events[0].Summary != "移动端创建" {
		t.Fatalf("created event not visible: %s", body)
	}

	status, body = env.syncRequest(t, "PUT", "/api/sync/events", map[string]any{
		"calendarId": cal.ID,
		"href":       href,
		"summary":    "移动端改名",
		"start":      "2026-10-26T10:30:00+08:00",
		"end":        "2026-10-26T11:30:00+08:00",
	})
	if status != http.StatusOK {
		t.Fatalf("update event = %d: %s", status, body)
	}
	status, body = env.syncRequest(t, "GET", "/api/sync/calendar?from=2026-10-26&to=2026-10-27", nil)
	if status != http.StatusOK {
		t.Fatalf("calendar after update = %d: %s", status, body)
	}
	snapshot = decode[struct {
		Events []apiCalendarEvent `json:"events"`
	}](t, body)
	if len(snapshot.Events) != 1 || snapshot.Events[0].Summary != "移动端改名" {
		t.Fatalf("updated event not visible: %s", body)
	}

	status, body = env.syncRequest(
		t, "DELETE",
		"/api/sync/events?calendarId="+strconv.FormatInt(cal.ID, 10)+
			"&href="+url.QueryEscape(href),
		nil,
	)
	if status != http.StatusNoContent {
		t.Fatalf("delete event = %d: %s", status, body)
	}
	status, body = env.syncRequest(t, "GET", "/api/sync/calendar?from=2026-10-26&to=2026-10-27", nil)
	if status != http.StatusOK {
		t.Fatalf("calendar after delete = %d: %s", status, body)
	}
	snapshot = decode[struct {
		Events []apiCalendarEvent `json:"events"`
	}](t, body)
	if len(snapshot.Events) != 0 {
		t.Fatalf("deleted event still visible: %s", body)
	}
}

func TestSyncRecurringEventOccurrence(t *testing.T) {
	env := newAPIEnv(t)
	ctx := context.Background()
	cal, err := env.store.CreateCalendar(
		ctx, env.userID, "p3-recur", "重复日历", "", "#22c55e",
		"Asia/Shanghai", 1, []string{"VEVENT"},
	)
	if err != nil {
		t.Fatal(err)
	}
	status, body := env.syncRequest(t, "POST", "/api/sync/events", map[string]any{
		"calendarId": cal.ID,
		"summary":    "每日站会",
		"start":      "2026-10-26T10:00:00+08:00",
		"end":        "2026-10-26T10:30:00+08:00",
		"rrule":      "FREQ=DAILY;COUNT=3",
	})
	if status != http.StatusCreated {
		t.Fatalf("create recurring = %d: %s", status, body)
	}
	created := decode[map[string]any](t, body)
	href, _ := created["href"].(string)

	read := func() []apiCalendarEvent {
		status, body := env.syncRequest(
			t, "GET", "/api/sync/calendar?from=2026-10-26&to=2026-10-30", nil,
		)
		if status != http.StatusOK {
			t.Fatalf("calendar = %d: %s", status, body)
		}
		snapshot := decode[struct {
			Events []apiCalendarEvent `json:"events"`
		}](t, body)
		return snapshot.Events
	}

	occurrences := read()
	if len(occurrences) != 3 {
		t.Fatalf("occurrences = %d: %+v", len(occurrences), occurrences)
	}
	occurrence := occurrences[0]
	if occurrence.RecurrenceID == "" {
		t.Fatalf("missing recurrence id: %+v", occurrence)
	}

	status, body = env.syncRequest(t, "PUT", "/api/sync/events", map[string]any{
		"calendarId":   cal.ID,
		"href":         href,
		"scope":        "single",
		"recurrenceId": occurrence.RecurrenceID,
		"summary":      "单次改",
		"start":        occurrence.Start,
		"end":          occurrence.End,
	})
	if status != http.StatusOK {
		t.Fatalf("single update = %d: %s", status, body)
	}
	occurrences = read()
	if len(occurrences) != 3 {
		t.Fatalf("occurrences after single update = %d", len(occurrences))
	}
	changed := false
	for _, item := range occurrences {
		if item.Summary == "单次改" {
			changed = true
		}
	}
	if !changed {
		t.Fatalf("single update not visible: %+v", occurrences)
	}

	status, body = env.syncRequest(
		t, "DELETE",
		"/api/sync/events?calendarId="+strconv.FormatInt(cal.ID, 10)+
			"&href="+url.QueryEscape(href)+
			"&recurrenceId="+url.QueryEscape(occurrence.RecurrenceID),
		nil,
	)
	if status != http.StatusNoContent {
		t.Fatalf("single delete = %d: %s", status, body)
	}
	if items := read(); len(items) != 2 {
		t.Fatalf("occurrences after single delete = %d: %+v", len(items), items)
	}
}

func TestSyncRejectsCrossKindAndBadBaseEtag(t *testing.T) {
	env := newAPIEnv(t)
	listPush := env.push(t, syncapi.PushOp{
		OpID: "op-note-list", Entity: "list", EntityID: "01list0000000000000000002", Action: "create",
		Patch: map[string]json.RawMessage{
			"name": json.RawMessage(`"笔记"`),
			"kind": json.RawMessage(`"NOTE"`),
		},
	})
	if listPush.Results[0].Status != "ok" {
		t.Fatalf("note list: %+v", listPush.Results[0])
	}
	bad := env.push(t, syncapi.PushOp{
		OpID: "op-cross-kind", Entity: "task", EntityID: "01task0000000000000000003", Action: "create",
		Patch: map[string]json.RawMessage{
			"title":  json.RawMessage(`"错放"`),
			"listId": json.RawMessage(`"01list0000000000000000002"`),
		},
	})
	if bad.Results[0].Status != "error" || bad.Results[0].Error == nil {
		t.Fatalf("cross-kind create should fail: %+v", bad.Results[0])
	}

	invalid := env.push(t, syncapi.PushOp{
		OpID: "op-bad-etag", Entity: "task", EntityID: "missing", Action: "update",
		BaseETag: "not-a-version",
		Patch:    map[string]json.RawMessage{"title": json.RawMessage(`"x"`)},
	})
	if invalid.Results[0].Status != "error" || !strings.Contains(invalid.Results[0].Error.Message, "baseEtag") {
		t.Fatalf("invalid etag should fail: %+v", invalid.Results[0])
	}
}
