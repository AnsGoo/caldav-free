// Package syncapi implements the client sync protocol (pull/push) on top of
// the task workspace. Clients treat the server as a remote database: pull
// returns everything that changed after a cursor, push applies batched,
// idempotent operations with ETag-based conflict detection.
package syncapi

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"sync"
	"time"

	"caldav-free/internal/store"
	"caldav-free/internal/tasksync"
)

// Service implements the sync protocol for one store.
type Service struct {
	store  *store.Store
	syncer *tasksync.Syncer
	// pushMu serializes pushes in this process. SQLite serializes writes, but
	// the ETag check and the write are separate statements, so a process-local
	// lock closes the read-check-write window for sync clients.
	pushMu sync.Mutex
	// lastReconcile throttles CalDAV reconciliation, which is a full table
	// scan and should not run on every short poll.
	reconcileMu   sync.Mutex
	lastReconcile map[int64]time.Time
	pruneMu       sync.Mutex
	lastPrune     time.Time
}

// New creates a sync service. A nil syncer creates a private one; production
// callers should share the server's reconciler to avoid concurrent VTODO
// writers with separate locks.
func New(st *store.Store, syncer *tasksync.Syncer) *Service {
	if syncer == nil {
		syncer = tasksync.New(st)
	}
	return &Service{
		store:         st,
		syncer:        syncer,
		lastReconcile: map[int64]time.Time{},
	}
}

// Refresh reconciles CalDAV VTODOs into workspace tasks. It is safe to call
// concurrently; the syncer serializes internally.
func (s *Service) Refresh(ctx context.Context, userID int64) error {
	s.reconcileMu.Lock()
	s.lastReconcile[userID] = time.Now()
	s.reconcileMu.Unlock()
	return s.syncer.Sync(ctx, userID)
}

// maybeRefresh throttles reconciliation to once per ten seconds per user.
func (s *Service) maybeRefresh(ctx context.Context, userID int64) {
	s.reconcileMu.Lock()
	last := s.lastReconcile[userID]
	if time.Since(last) < 10*time.Second {
		s.reconcileMu.Unlock()
		return
	}
	s.lastReconcile[userID] = time.Now()
	s.reconcileMu.Unlock()
	if err := s.syncer.Sync(ctx, userID); err != nil {
		slog.Default().Warn("reconcile caldav tasks", "user", userID, "error", err)
	}
}

// maybePrune keeps the journal bounded on long-running servers.
func (s *Service) maybePrune(ctx context.Context) {
	s.pruneMu.Lock()
	if time.Since(s.lastPrune) < time.Hour {
		s.pruneMu.Unlock()
		return
	}
	s.lastPrune = time.Now()
	s.pruneMu.Unlock()
	if err := s.store.PruneSyncState(ctx, 90*24*time.Hour, 7*24*time.Hour); err != nil {
		slog.Default().Warn("prune sync journal", "error", err)
	}
}

// ---------------------------------------------------------------- DTOs

// ChecklistItem mirrors the subtask shape stored on a task.
type ChecklistItem struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Done  bool   `json:"done"`
}

// TaskDTO is the wire representation of a task. IDs are the opaque sync IDs,
// never the internal row IDs.
type TaskDTO struct {
	ID              string          `json:"id"`
	ListID          string          `json:"listId"`
	ParentID        string          `json:"parentId,omitempty"`
	SectionID       string          `json:"sectionId,omitempty"`
	Title           string          `json:"title"`
	Notes           string          `json:"notes"`
	NotesFormat     string          `json:"notesFormat"`
	Kind            string          `json:"kind"`
	Priority        int             `json:"priority"`
	Start           string          `json:"start,omitempty"`
	Due             string          `json:"due,omitempty"`
	AllDay          bool            `json:"allDay"`
	Recurrence      string          `json:"recurrence,omitempty"`
	ReminderOffsets []int           `json:"reminderOffsets"`
	Assignee        string          `json:"assignee,omitempty"`
	Completed       bool            `json:"completed"`
	CompletedAt     string          `json:"completedAt,omitempty"`
	Pinned          bool            `json:"pinned"`
	Tags            []string        `json:"tags"`
	Checklist       []ChecklistItem `json:"checklist"`
	Order           int             `json:"order"`
	Deleted         bool            `json:"deleted"`
	DeletedAt       string          `json:"deletedAt,omitempty"`
	CreatedAt       string          `json:"createdAt"`
	ModifiedAt      string          `json:"modifiedAt"`
	ETag            string          `json:"etag"`
	Version         int64           `json:"version"`
}

// ListDTO is the wire representation of a task list.
type ListDTO struct {
	ID         string `json:"id"`
	FolderID   string `json:"folderId,omitempty"`
	Name       string `json:"name"`
	Color      string `json:"color"`
	Kind       string `json:"kind"`
	Order      int    `json:"order"`
	Pinned     bool   `json:"pinned"`
	IsInbox    bool   `json:"isInbox"`
	CreatedAt  string `json:"createdAt"`
	ModifiedAt string `json:"modifiedAt"`
	ETag       string `json:"etag"`
	Version    int64  `json:"version"`
}

// SectionDTO is the wire representation of a kanban column.
type SectionDTO struct {
	ID         string `json:"id"`
	ListID     string `json:"listId"`
	Name       string `json:"name"`
	Order      int    `json:"order"`
	CreatedAt  string `json:"createdAt"`
	ModifiedAt string `json:"modifiedAt"`
	ETag       string `json:"etag"`
	Version    int64  `json:"version"`
}

// FolderDTO is the wire representation of a list folder.
type FolderDTO struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Order      int    `json:"order"`
	CreatedAt  string `json:"createdAt"`
	ModifiedAt string `json:"modifiedAt"`
	ETag       string `json:"etag"`
	Version    int64  `json:"version"`
}

// FilterDTO is the wire representation of a saved filter.
type FilterDTO struct {
	ID         string          `json:"id"`
	Name       string          `json:"name"`
	Color      string          `json:"color"`
	Conditions json.RawMessage `json:"conditions"`
	Order      int             `json:"order"`
	Pinned     bool            `json:"pinned"`
	CreatedAt  string          `json:"createdAt"`
	ModifiedAt string          `json:"modifiedAt"`
	ETag       string          `json:"etag"`
	Version    int64           `json:"version"`
}

// Tombstone marks a hard-deleted entity.
type Tombstone struct {
	Entity    string `json:"entity"`
	ID        string `json:"id"`
	DeletedAt string `json:"deletedAt"`
}

// PullResponse is one page of the change feed.
type PullResponse struct {
	Cursor     string       `json:"cursor"`
	HasMore    bool         `json:"hasMore"`
	ServerTime string       `json:"serverTime"`
	Tasks      []TaskDTO    `json:"tasks"`
	Lists      []ListDTO    `json:"lists"`
	Sections   []SectionDTO `json:"sections"`
	Folders    []FolderDTO  `json:"folders"`
	Filters    []FilterDTO  `json:"filters"`
	Tombstones []Tombstone  `json:"tombstones"`
}

// PushRequest is a batch of client operations.
type PushRequest struct {
	DeviceID string   `json:"deviceId"`
	Ops      []PushOp `json:"ops"`
}

// PushOp is one create/update/move/reorder/delete operation.
type PushOp struct {
	OpID     string                     `json:"opId"`
	Entity   string                     `json:"entity"`
	EntityID string                     `json:"entityId"`
	Action   string                     `json:"action"`
	BaseETag string                     `json:"baseEtag"`
	Patch    map[string]json.RawMessage `json:"patch"`
}

// PushError explains a rejected operation.
type PushError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// PushResult is the outcome of one operation.
type PushResult struct {
	OpID     string     `json:"opId"`
	Entity   string     `json:"entityType"`
	EntityID string     `json:"entityId"`
	Status   string     `json:"status"` // ok | conflict | gone | error
	ETag     string     `json:"etag,omitempty"`
	Version  int64      `json:"version,omitempty"`
	Snapshot any        `json:"entity,omitempty"`
	Error    *PushError `json:"error,omitempty"`
}

// PushResponse wraps all per-operation results.
type PushResponse struct {
	Cursor  string       `json:"cursor"`
	Results []PushResult `json:"results"`
}

// ---------------------------------------------------------------- ETag helpers

func formatETag(seq int64) string {
	if seq <= 0 {
		return ""
	}
	return "v" + strconv.FormatInt(seq, 10)
}

func parseETag(raw string) (int64, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, nil
	}
	raw = strings.TrimPrefix(strings.ToLower(raw), "v")
	seq, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || seq < 0 {
		return 0, fmt.Errorf("invalid baseEtag %q", raw)
	}
	return seq, nil
}

// ---------------------------------------------------------------- formatting

func formatTime(value *time.Time) string {
	if value == nil {
		return ""
	}
	return value.UTC().Format(time.RFC3339)
}

func formatTimeValue(value time.Time) string {
	if value.IsZero() {
		return ""
	}
	return value.UTC().Format(time.RFC3339)
}

func parseTimePtr(raw string) (*time.Time, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, nil
	}
	loc := time.Local
	if configured, err := time.LoadLocation(store.DefaultTimezone); err == nil {
		loc = configured
	}
	layouts := []string{time.RFC3339Nano, time.RFC3339}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, raw); err == nil {
			utc := parsed.UTC()
			return &utc, nil
		}
	}
	for _, layout := range []string{"2006-01-02T15:04:05", "2006-01-02T15:04", "2006-01-02 15:04", "2006-01-02"} {
		if parsed, err := time.ParseInLocation(layout, raw, loc); err == nil {
			utc := parsed.UTC()
			return &utc, nil
		}
	}
	return nil, fmt.Errorf("invalid time %q", raw)
}

func decodeChecklist(raw string) []ChecklistItem {
	if strings.TrimSpace(raw) == "" {
		return []ChecklistItem{}
	}
	var items []ChecklistItem
	if err := json.Unmarshal([]byte(raw), &items); err != nil {
		return []ChecklistItem{}
	}
	if items == nil {
		return []ChecklistItem{}
	}
	return items
}

func encodeChecklist(items []ChecklistItem) string {
	if len(items) == 0 {
		return ""
	}
	encoded, err := json.Marshal(items)
	if err != nil {
		return ""
	}
	return string(encoded)
}

func normalizeTags(tags []string) store.StringList {
	seen := map[string]bool{}
	out := make(store.StringList, 0, len(tags))
	for _, tag := range tags {
		tag = strings.TrimSpace(tag)
		if tag == "" || seen[tag] {
			continue
		}
		seen[tag] = true
		out = append(out, tag)
	}
	return out
}

// ---------------------------------------------------------------- patch helpers

func patchRaw(patch map[string]json.RawMessage, key string) (json.RawMessage, bool) {
	raw, ok := patch[key]
	if !ok {
		return nil, false
	}
	return raw, true
}

func patchIsNull(raw json.RawMessage) bool {
	return strings.TrimSpace(string(raw)) == "null"
}

func patchString(patch map[string]json.RawMessage, key string) (value string, set, null bool, err error) {
	raw, ok := patchRaw(patch, key)
	if !ok {
		return "", false, false, nil
	}
	if patchIsNull(raw) {
		return "", true, true, nil
	}
	if err := json.Unmarshal(raw, &value); err != nil {
		return "", true, false, fmt.Errorf("%s: %w", key, err)
	}
	return value, true, false, nil
}

func patchInt(patch map[string]json.RawMessage, key string) (value int, set, null bool, err error) {
	raw, ok := patchRaw(patch, key)
	if !ok {
		return 0, false, false, nil
	}
	if patchIsNull(raw) {
		return 0, true, true, nil
	}
	if err := json.Unmarshal(raw, &value); err != nil {
		return 0, true, false, fmt.Errorf("%s: %w", key, err)
	}
	return value, true, false, nil
}

func patchBool(patch map[string]json.RawMessage, key string) (value bool, set bool, err error) {
	raw, ok := patchRaw(patch, key)
	if !ok {
		return false, false, nil
	}
	if patchIsNull(raw) {
		return false, true, nil
	}
	if err := json.Unmarshal(raw, &value); err != nil {
		return false, true, fmt.Errorf("%s: %w", key, err)
	}
	return value, true, nil
}

func patchStrings(patch map[string]json.RawMessage, key string) (value []string, set bool, err error) {
	raw, ok := patchRaw(patch, key)
	if !ok {
		return nil, false, nil
	}
	if patchIsNull(raw) {
		return nil, true, nil
	}
	if err := json.Unmarshal(raw, &value); err != nil {
		return nil, true, fmt.Errorf("%s: %w", key, err)
	}
	return value, true, nil
}

func patchTime(patch map[string]json.RawMessage, key string) (value *time.Time, set bool, err error) {
	text, set, null, err := patchString(patch, key)
	if err != nil || !set {
		return nil, set, err
	}
	if null {
		return nil, true, nil
	}
	parsed, err := parseTimePtr(text)
	if err != nil {
		return nil, true, fmt.Errorf("%s: %w", key, err)
	}
	return parsed, true, nil
}

func patchChecklist(patch map[string]json.RawMessage, key string) (string, bool, error) {
	raw, ok := patchRaw(patch, key)
	if !ok {
		return "", false, nil
	}
	if patchIsNull(raw) {
		return "", true, nil
	}
	var items []ChecklistItem
	if err := json.Unmarshal(raw, &items); err != nil {
		return "", true, fmt.Errorf("%s: %w", key, err)
	}
	return encodeChecklist(items), true, nil
}

// ---------------------------------------------------------------- snapshots

func (s *Service) taskSnapshot(ctx context.Context, userID int64, task *store.Task, seq int64) (*TaskDTO, error) {
	listID := ""
	if task.ListID != 0 {
		list, err := s.store.GetTaskList(ctx, userID, task.ListID)
		if err != nil && err != store.ErrNotFound {
			return nil, err
		}
		if list != nil {
			listID = list.SyncID
		}
	}
	parentID := ""
	if task.ParentID != 0 {
		ids, err := s.store.TaskSyncIDMap(ctx, userID, []int64{task.ParentID})
		if err != nil {
			return nil, err
		}
		parentID = ids[task.ParentID]
	}
	sectionID := ""
	if task.SectionID != 0 {
		section, err := s.store.GetTaskSection(ctx, userID, task.SectionID)
		if err != nil && err != store.ErrNotFound {
			return nil, err
		}
		if section != nil {
			sectionID = section.SyncID
		}
	}
	dto := &TaskDTO{
		ID:              task.SyncID,
		ListID:          listID,
		ParentID:        parentID,
		SectionID:       sectionID,
		Title:           task.Title,
		Notes:           task.Notes,
		NotesFormat:     task.NotesFormat,
		Kind:            task.Kind,
		Priority:        task.Priority,
		Start:           formatTime(task.StartAt),
		Due:             formatTime(task.DueAt),
		AllDay:          task.AllDay,
		Recurrence:      task.Recurrence,
		ReminderOffsets: task.ReminderValues(),
		Assignee:        task.Assignee,
		Completed:       task.Completed,
		CompletedAt:     formatTime(task.CompletedAt),
		Pinned:          task.PinnedAt != nil,
		Tags:            append([]string(nil), task.Tags...),
		Checklist:       decodeChecklist(task.Checklist),
		Order:           task.Order,
		Deleted:         task.Deleted,
		DeletedAt:       formatTime(task.DeletedAt),
		CreatedAt:       formatTimeValue(task.CreatedAt),
		ModifiedAt:      formatTimeValue(task.ModifiedAt),
		ETag:            formatETag(seq),
		Version:         seq,
	}
	if dto.Kind == "" {
		dto.Kind = "TASK"
	}
	if dto.Tags == nil {
		dto.Tags = []string{}
	}
	if dto.ReminderOffsets == nil {
		dto.ReminderOffsets = []int{}
	}
	return dto, nil
}

func listSnapshot(list *store.TaskList, folderSyncID string, seq int64) ListDTO {
	kind := list.Kind
	if kind == "" {
		kind = "TASK"
	}
	return ListDTO{
		ID:         list.SyncID,
		FolderID:   folderSyncID,
		Name:       list.Name,
		Color:      list.Color,
		Kind:       kind,
		Order:      list.Order,
		Pinned:     list.Pinned,
		IsInbox:    list.IsInbox,
		CreatedAt:  formatTimeValue(list.CreatedAt),
		ModifiedAt: formatTimeValue(list.ModifiedAt),
		ETag:       formatETag(seq),
		Version:    seq,
	}
}

func (s *Service) listSnapshot(ctx context.Context, userID int64, list *store.TaskList, seq int64) (*ListDTO, error) {
	folderSyncID := ""
	if list.FolderID != 0 {
		folder, err := s.store.GetTaskFolder(ctx, userID, list.FolderID)
		if err != nil && err != store.ErrNotFound {
			return nil, err
		}
		if folder != nil {
			folderSyncID = folder.SyncID
		}
	}
	dto := listSnapshot(list, folderSyncID, seq)
	return &dto, nil
}

func (s *Service) sectionSnapshot(ctx context.Context, userID int64, section *store.TaskSection, seq int64) (*SectionDTO, error) {
	listSyncID := ""
	if list, err := s.store.GetTaskList(ctx, userID, section.ListID); err == nil {
		listSyncID = list.SyncID
	} else if err != store.ErrNotFound {
		return nil, err
	}
	return &SectionDTO{
		ID:         section.SyncID,
		ListID:     listSyncID,
		Name:       section.Name,
		Order:      section.Order,
		CreatedAt:  formatTimeValue(section.CreatedAt),
		ModifiedAt: formatTimeValue(section.ModifiedAt),
		ETag:       formatETag(seq),
		Version:    seq,
	}, nil
}

func folderSnapshot(folder *store.TaskFolder, seq int64) FolderDTO {
	return FolderDTO{
		ID:         folder.SyncID,
		Name:       folder.Name,
		Order:      folder.Order,
		CreatedAt:  formatTimeValue(folder.CreatedAt),
		ModifiedAt: formatTimeValue(folder.ModifiedAt),
		ETag:       formatETag(seq),
		Version:    seq,
	}
}

func filterSnapshot(filter *store.SavedFilter, seq int64) FilterDTO {
	conditions := json.RawMessage("{}")
	if strings.TrimSpace(filter.Conditions) != "" && json.Valid([]byte(filter.Conditions)) {
		conditions = json.RawMessage(filter.Conditions)
	}
	return FilterDTO{
		ID:         filter.SyncID,
		Name:       filter.Name,
		Color:      filter.Color,
		Conditions: conditions,
		Order:      filter.Order,
		Pinned:     filter.Pinned,
		CreatedAt:  formatTimeValue(filter.CreatedAt),
		ModifiedAt: formatTimeValue(filter.ModifiedAt),
		ETag:       formatETag(seq),
		Version:    seq,
	}
}
