package store

import (
	"context"
	"fmt"
	"sort"
	"time"
)

// TaskDailyStat is one day in the trend chart.
type TaskDailyStat struct {
	Date      string `json:"date"`
	Created   int    `json:"created"`
	Completed int    `json:"completed"`
	Due       int    `json:"due"`
}

// TaskListStat aggregates tasks per list.
type TaskListStat struct {
	ID        int64  `json:"id"`
	Name      string `json:"name"`
	Color     string `json:"color"`
	Open      int    `json:"open"`
	Completed int    `json:"completed"`
	Overdue   int    `json:"overdue"`
}

// TaskTagStat aggregates tasks per tag.
type TaskTagStat struct {
	Name      string `json:"name"`
	Color     string `json:"color"`
	Open      int    `json:"open"`
	Completed int    `json:"completed"`
	Overdue   int    `json:"overdue"`
}

// TaskPriorityStat aggregates tasks per priority.
type TaskPriorityStat struct {
	Priority  int `json:"priority"`
	Open      int `json:"open"`
	Completed int `json:"completed"`
}

// TaskStats is the workspace statistics payload.
type TaskStats struct {
	Days              int                `json:"days"`
	Open              int                `json:"open"`
	Completed         int                `json:"completed"`
	Overdue           int                `json:"overdue"`
	Today             int                `json:"today"`
	Trash             int                `json:"trash"`
	CompletionRate    float64            `json:"completionRate"`
	CreatedInPeriod   int                `json:"createdInPeriod"`
	CompletedInPeriod int                `json:"completedInPeriod"`
	DueInPeriod       int                `json:"dueInPeriod"`
	OnTimeInPeriod    int                `json:"onTimeInPeriod"`
	AvgCompletionHour float64            `json:"avgCompletionHours"`
	Daily             []TaskDailyStat    `json:"daily"`
	Lists             []TaskListStat     `json:"lists"`
	Tags              []TaskTagStat      `json:"tags"`
	Priorities        []TaskPriorityStat `json:"priorities"`
}

// ComputeTaskStats aggregates live tasks for the stats view.
func (s *Store) ComputeTaskStats(ctx context.Context, userID int64, days int) (*TaskStats, error) {
	if days <= 0 || days > 365 {
		days = 30
	}
	tasks, err := s.ListAllTasks(ctx, userID, 10000)
	if err != nil {
		return nil, err
	}
	loc, err := time.LoadLocation(DefaultTimezone)
	if err != nil {
		loc = time.UTC
	}
	now := time.Now().In(loc)
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	periodStart := todayStart.AddDate(0, 0, -(days - 1))
	tomorrow := todayStart.AddDate(0, 0, 1)

	stats := &TaskStats{Days: days}
	daily := make(map[string]*TaskDailyStat, days)
	for index := 0; index < days; index++ {
		date := periodStart.AddDate(0, 0, index)
		key := date.Format("2006-01-02")
		stats.Daily = append(stats.Daily, TaskDailyStat{Date: key})
		daily[key] = &stats.Daily[len(stats.Daily)-1]
	}
	lists, err := s.ListTaskLists(ctx, userID)
	if err != nil {
		return nil, err
	}
	listByID := make(map[int64]*TaskList, len(lists))
	listStats := make(map[int64]*TaskListStat, len(lists))
	for _, list := range lists {
		listByID[list.ID] = list
		listStats[list.ID] = &TaskListStat{ID: list.ID, Name: list.Name, Color: list.Color}
	}
	tagStats := make(map[string]*TaskTagStat)
	tagColors, _ := s.ListTaskTagColors(ctx, userID)
	priorityStats := make(map[int]*TaskPriorityStat)
	var completionHours float64
	var completionSamples int

	for _, task := range tasks {
		listStat := listStats[task.ListID]
		overdue := !task.Completed && isTaskOverdue(task, now, todayStart)
		if task.Completed {
			stats.Completed++
			if listStat != nil {
				listStat.Completed++
			}
		} else {
			stats.Open++
			if listStat != nil {
				listStat.Open++
			}
			if overdue {
				stats.Overdue++
				if listStat != nil {
					listStat.Overdue++
				}
			}
			if task.DueAt != nil && sameDayIn(task.DueAt, todayStart, loc) {
				stats.Today++
			}
		}
		if task.CompletedAt != nil && !task.CompletedAt.Before(periodStart) {
			stats.CompletedInPeriod++
			if !task.CreatedAt.IsZero() && task.CompletedAt.After(task.CreatedAt) {
				completionHours += task.CompletedAt.Sub(task.CreatedAt).Hours()
				completionSamples++
			}
			if task.DueAt != nil && isTaskOnTime(task) {
				stats.OnTimeInPeriod++
			}
		}
		if task.CreatedAt.After(periodStart) || task.CreatedAt.Equal(periodStart) {
			stats.CreatedInPeriod++
		}
		if task.DueAt != nil && !task.DueAt.Before(periodStart) && task.DueAt.Before(tomorrow) {
			stats.DueInPeriod++
		}

		if task.CreatedAt.After(periodStart) || task.CreatedAt.Equal(periodStart) {
			if entry := daily[task.CreatedAt.In(loc).Format("2006-01-02")]; entry != nil {
				entry.Created++
			}
		}
		if task.CompletedAt != nil && !task.CompletedAt.Before(periodStart) {
			if entry := daily[task.CompletedAt.In(loc).Format("2006-01-02")]; entry != nil {
				entry.Completed++
			}
		}
		if task.DueAt != nil {
			if entry := daily[task.DueAt.In(loc).Format("2006-01-02")]; entry != nil {
				entry.Due++
			}
		}

		for _, tag := range task.Tags {
			if tag == "" {
				continue
			}
			entry := tagStats[tag]
			if entry == nil {
				entry = &TaskTagStat{Name: tag, Color: tagColors[tag]}
				tagStats[tag] = entry
			}
			if task.Completed {
				entry.Completed++
			} else {
				entry.Open++
				if overdue {
					entry.Overdue++
				}
			}
		}
		priority := task.Priority
		if priority < 0 || priority > 3 {
			priority = 0
		}
		entry := priorityStats[priority]
		if entry == nil {
			entry = &TaskPriorityStat{Priority: priority}
			priorityStats[priority] = entry
		}
		if task.Completed {
			entry.Completed++
		} else {
			entry.Open++
		}
	}

	total := stats.Open + stats.Completed
	if total > 0 {
		stats.CompletionRate = float64(stats.Completed) / float64(total) * 100
	}
	if completionSamples > 0 {
		stats.AvgCompletionHour = completionHours / float64(completionSamples)
	}
	var trash int64
	if err := s.db.WithContext(ctx).Model(&Task{}).
		Where("user_id = ? AND deleted = ?", userID, true).Count(&trash).Error; err != nil {
		return nil, fmt.Errorf("count trash: %w", err)
	}
	stats.Trash = int(trash)

	for _, list := range lists {
		entry := listStats[list.ID]
		stats.Lists = append(stats.Lists, *entry)
	}
	for _, entry := range tagStats {
		stats.Tags = append(stats.Tags, *entry)
	}
	sort.Slice(stats.Tags, func(i, j int) bool {
		left := stats.Tags[i].Open + stats.Tags[i].Completed
		right := stats.Tags[j].Open + stats.Tags[j].Completed
		if left != right {
			return left > right
		}
		return stats.Tags[i].Name < stats.Tags[j].Name
	})
	for priority := 3; priority >= 0; priority-- {
		entry := priorityStats[priority]
		if entry == nil {
			entry = &TaskPriorityStat{Priority: priority}
		}
		stats.Priorities = append(stats.Priorities, *entry)
	}
	return stats, nil
}

func isTaskOverdue(task *Task, now, todayStart time.Time) bool {
	if task.Completed || task.DueAt == nil {
		return false
	}
	if task.AllDay {
		local := task.DueAt.In(todayStart.Location())
		return time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, local.Location()).Before(todayStart)
	}
	return task.DueAt.Before(now)
}

func isTaskOnTime(task *Task) bool {
	if task.DueAt == nil || task.CompletedAt == nil {
		return false
	}
	due := *task.DueAt
	if task.AllDay {
		due = due.Add(24 * time.Hour)
	}
	return !task.CompletedAt.After(due)
}

func sameDayIn(value *time.Time, day time.Time, loc *time.Location) bool {
	if value == nil {
		return false
	}
	local := value.In(loc)
	return local.Year() == day.Year() && local.YearDay() == day.YearDay()
}
