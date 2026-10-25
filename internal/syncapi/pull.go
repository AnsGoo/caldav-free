package syncapi

import (
	"context"
	"strconv"
	"time"

	"caldav-free/internal/store"
)

// Pull returns one page of changes after since. An empty or zero cursor means
// "from the beginning", which the journal backfill makes equivalent to a full
// snapshot.
func (s *Service) Pull(ctx context.Context, userID, since int64, limit int) (*PullResponse, error) {
	if since < 0 {
		since = 0
	}
	if limit <= 0 || limit > 1000 {
		limit = 500
	}
	s.maybeRefresh(ctx, userID)
	s.maybePrune(ctx)
	changes, hasMore, err := s.store.SyncChangesSince(ctx, userID, since, limit)
	if err != nil {
		return nil, err
	}
	response := &PullResponse{
		Cursor:     strconv.FormatInt(since, 10),
		HasMore:    hasMore,
		ServerTime: time.Now().UTC().Format(time.RFC3339),
		Tasks:      []TaskDTO{},
		Lists:      []ListDTO{},
		Sections:   []SectionDTO{},
		Folders:    []FolderDTO{},
		Filters:    []FilterDTO{},
		Tombstones: []Tombstone{},
	}
	if len(changes) == 0 {
		return response, nil
	}

	idsByEntity := map[string][]string{}
	for _, change := range changes {
		idsByEntity[change.Entity] = append(idsByEntity[change.Entity], change.EntityID)
	}

	tasks, err := s.store.ListTasksBySyncIDs(ctx, userID, idsByEntity[store.SyncEntityTask])
	if err != nil {
		return nil, err
	}
	taskBySyncID := make(map[string]*store.Task, len(tasks))
	parentIDs := make([]int64, 0, 4)
	for _, task := range tasks {
		taskBySyncID[task.SyncID] = task
		if task.ParentID != 0 {
			parentIDs = append(parentIDs, task.ParentID)
		}
	}
	parentSyncIDs, err := s.store.TaskSyncIDMap(ctx, userID, parentIDs)
	if err != nil {
		return nil, err
	}

	lists, err := s.store.ListTaskLists(ctx, userID)
	if err != nil {
		return nil, err
	}
	listSyncByID := make(map[int64]string, len(lists))
	listBySyncID := make(map[string]*store.TaskList, len(lists))
	for _, list := range lists {
		listSyncByID[list.ID] = list.SyncID
		listBySyncID[list.SyncID] = list
	}

	folders, err := s.store.ListTaskFolders(ctx, userID)
	if err != nil {
		return nil, err
	}
	folderSyncByID := make(map[int64]string, len(folders))
	folderBySyncID := make(map[string]*store.TaskFolder, len(folders))
	for _, folder := range folders {
		folderSyncByID[folder.ID] = folder.SyncID
		folderBySyncID[folder.SyncID] = folder
	}

	sections, err := s.store.ListTaskSections(ctx, userID)
	if err != nil {
		return nil, err
	}
	sectionSyncByID := make(map[int64]string, len(sections))
	sectionBySyncID := make(map[string]*store.TaskSection, len(sections))
	for _, section := range sections {
		sectionSyncByID[section.ID] = section.SyncID
		sectionBySyncID[section.SyncID] = section
	}

	filters, err := s.store.ListSavedFiltersBySyncIDs(ctx, userID, idsByEntity[store.SyncEntityFilter])
	if err != nil {
		return nil, err
	}
	filterBySyncID := make(map[string]*store.SavedFilter, len(filters))
	for _, filter := range filters {
		filterBySyncID[filter.SyncID] = filter
	}

	// Load list rows for this batch separately: ListTaskLists omits nothing,
	// but a list deleted earlier in the same page must come from the journal as
	// a tombstone instead of a snapshot.
	changedListBySyncID := make(map[string]*store.TaskList)
	for _, id := range idsByEntity[store.SyncEntityList] {
		if list, ok := listBySyncID[id]; ok {
			changedListBySyncID[id] = list
		}
	}

	for _, change := range changes {
		switch change.Entity {
		case store.SyncEntityTask:
			task, ok := taskBySyncID[change.EntityID]
			if !ok {
				response.Tombstones = append(response.Tombstones, tombstone(change))
				continue
			}
			listID := listSyncByID[task.ListID]
			sectionID := sectionSyncByID[task.SectionID]
			parentID := parentSyncIDs[task.ParentID]
			dto := TaskDTO{
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
				ETag:            formatETag(change.ID),
				Version:         change.ID,
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
			response.Tasks = append(response.Tasks, dto)
		case store.SyncEntityList:
			list, ok := changedListBySyncID[change.EntityID]
			if !ok {
				response.Tombstones = append(response.Tombstones, tombstone(change))
				continue
			}
			response.Lists = append(response.Lists, listSnapshot(list, folderSyncByID[list.FolderID], change.ID))
		case store.SyncEntitySection:
			section, ok := sectionBySyncID[change.EntityID]
			if !ok {
				response.Tombstones = append(response.Tombstones, tombstone(change))
				continue
			}
			response.Sections = append(response.Sections, SectionDTO{
				ID:         section.SyncID,
				ListID:     listSyncByID[section.ListID],
				Name:       section.Name,
				Order:      section.Order,
				CreatedAt:  formatTimeValue(section.CreatedAt),
				ModifiedAt: formatTimeValue(section.ModifiedAt),
				ETag:       formatETag(change.ID),
				Version:    change.ID,
			})
		case store.SyncEntityFolder:
			folder, ok := folderBySyncID[change.EntityID]
			if !ok {
				response.Tombstones = append(response.Tombstones, tombstone(change))
				continue
			}
			response.Folders = append(response.Folders, folderSnapshot(folder, change.ID))
		case store.SyncEntityFilter:
			filter, ok := filterBySyncID[change.EntityID]
			if !ok {
				response.Tombstones = append(response.Tombstones, tombstone(change))
				continue
			}
			response.Filters = append(response.Filters, filterSnapshot(filter, change.ID))
		}
	}
	response.Cursor = strconv.FormatInt(changes[len(changes)-1].ID, 10)
	return response, nil
}

func tombstone(change store.SyncJournalEntry) Tombstone {
	deletedAt := time.Unix(change.CreatedAt, 0).UTC()
	if change.CreatedAt <= 0 {
		deletedAt = time.Now().UTC()
	}
	return Tombstone{Entity: change.Entity, ID: change.EntityID, DeletedAt: deletedAt.Format(time.RFC3339)}
}
