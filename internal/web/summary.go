package web

import (
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/store"
)

type apiSummaryTask struct {
	ID          int64              `json:"id"`
	Title       string             `json:"title"`
	ListID      int64              `json:"listId"`
	ListName    string             `json:"listName"`
	ListColor   string             `json:"listColor"`
	Completed   bool               `json:"completed"`
	CompletedAt string             `json:"completedAt,omitempty"`
	Due         string             `json:"due,omitempty"`
	AllDay      bool               `json:"allDay"`
	Priority    int                `json:"priority"`
	Tags        []string           `json:"tags"`
	Notes       string             `json:"notes"`
	Checklist   []apiChecklistItem `json:"checklist"`
	CreatedAt   string             `json:"createdAt"`
}

type apiSummary struct {
	Title     string           `json:"title"`
	From      string           `json:"from"`
	To        string           `json:"to"`
	Tasks     []apiSummaryTask `json:"tasks"`
	NextTasks []apiSummaryTask `json:"nextTasks"`
	Counts    map[string]int   `json:"counts"`
}

func (s *Server) apiTaskSummary(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	from, to, ok := parseEventRange(r)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "时间范围无效")
		return
	}
	loc := taskLocation("")
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	switch status {
	case "completed", "open":
	default:
		status = "all"
	}
	listID, _ := strconv.ParseInt(r.URL.Query().Get("listId"), 10, 64)
	priority, _ := strconv.Atoi(r.URL.Query().Get("priority"))
	if priority < 1 || priority > 3 {
		priority = 0
	}
	tag := strings.TrimSpace(r.URL.Query().Get("tag"))
	includeNext := strings.TrimSpace(r.URL.Query().Get("includeNext")) == "1"

	ctx := r.Context()
	tasks, err := s.store.ListAllTasks(ctx, current.ID, 10000)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	lists, err := s.store.ListTaskLists(ctx, current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	listByID := make(map[int64]*store.TaskList, len(lists))
	for _, list := range lists {
		listByID[list.ID] = list
	}
	nextFrom := to
	nextTo := to.Add(to.Sub(from))
	rows := make([]apiSummaryTask, 0, 32)
	nextRows := make([]apiSummaryTask, 0, 16)
	completedCount, openCount := 0, 0
	for _, task := range tasks {
		if listID > 0 && task.ListID != listID {
			continue
		}
		if priority > 0 && task.Priority != priority {
			continue
		}
		if tag != "" && !hasTag(task.Tags, tag) {
			continue
		}
		if task.Completed {
			if status == "open" || task.CompletedAt == nil {
				continue
			}
			if task.CompletedAt.Before(from) || !task.CompletedAt.Before(to) {
				continue
			}
			rows = append(rows, summaryTaskDTO(task, listByID[task.ListID]))
			completedCount++
			continue
		}
		if status == "completed" {
			continue
		}
		include := false
		if task.DueAt != nil {
			include = !task.DueAt.Before(from) && task.DueAt.Before(to)
		} else {
			include = !task.CreatedAt.Before(from) && task.CreatedAt.Before(to)
		}
		if include {
			rows = append(rows, summaryTaskDTO(task, listByID[task.ListID]))
			openCount++
		}
		if includeNext && task.DueAt != nil && !task.DueAt.Before(nextFrom) && task.DueAt.Before(nextTo) {
			nextRows = append(nextRows, summaryTaskDTO(task, listByID[task.ListID]))
		}
	}
	sort.SliceStable(rows, func(i, j int) bool {
		left, right := rows[i], rows[j]
		if left.Completed != right.Completed {
			return left.Completed
		}
		if left.Completed {
			return left.CompletedAt > right.CompletedAt
		}
		if left.Due == "" {
			return false
		}
		if right.Due == "" {
			return true
		}
		return left.Due < right.Due
	})
	sort.SliceStable(nextRows, func(i, j int) bool { return nextRows[i].Due < nextRows[j].Due })
	writeAPIJSON(w, http.StatusOK, apiSummary{
		Title:     summaryRangeTitle(from, to, loc),
		From:      from.Format(time.RFC3339),
		To:        to.Format(time.RFC3339),
		Tasks:     rows,
		NextTasks: nextRows,
		Counts:    map[string]int{"completed": completedCount, "open": openCount},
	})
}

func summaryTaskDTO(task *store.Task, list *store.TaskList) apiSummaryTask {
	dto := apiSummaryTask{
		ID:        task.ID,
		Title:     task.Title,
		ListID:    task.ListID,
		Priority:  task.Priority,
		AllDay:    task.AllDay,
		Completed: task.Completed,
		Tags:      append([]string(nil), task.Tags...),
		Notes:     task.Notes,
		Checklist: decodeChecklist(task.Checklist),
		CreatedAt: task.CreatedAt.Format(time.RFC3339),
	}
	if task.CompletedAt != nil {
		dto.CompletedAt = task.CompletedAt.Format(time.RFC3339)
	}
	if task.DueAt != nil {
		dto.Due = task.DueAt.Format(time.RFC3339)
	}
	if list != nil {
		dto.ListName = list.Name
		dto.ListColor = list.Color
	}
	if dto.Tags == nil {
		dto.Tags = []string{}
	}
	return dto
}

func summaryRangeTitle(from, to time.Time, loc *time.Location) string {
	start := from.In(loc)
	end := to.Add(-time.Second).In(loc)
	if start.Year() == end.Year() {
		if start.Year() == time.Now().In(loc).Year() {
			return start.Format("1月2日") + "-" + end.Format("1月2日")
		}
		return start.Format("2006年1月2日") + "-" + end.Format("1月2日")
	}
	return start.Format("2006年1月2日") + "-" + end.Format("2006年1月2日")
}

func hasTag(tags []string, want string) bool {
	for _, tag := range tags {
		if tag == want {
			return true
		}
	}
	return false
}
