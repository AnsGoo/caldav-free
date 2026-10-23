package web

import (
	"net/http"
	"strconv"
	"time"

	"caldav-free/internal/store"
)

type apiTaskActivity struct {
	ID          int64  `json:"id"`
	Type        string `json:"type"`
	Detail      string `json:"detail"`
	Username    string `json:"username"`
	DisplayName string `json:"displayName"`
	CreatedAt   string `json:"createdAt"`
}

func (s *Server) apiTaskActivities(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	taskID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	if _, err := s.store.GetTaskAccess(r.Context(), current.ID, taskID); err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	activities, err := s.store.ListTaskActivities(r.Context(), taskID, 50)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	rows := make([]apiTaskActivity, 0, len(activities))
	for _, activity := range activities {
		rows = append(rows, apiTaskActivity{
			ID: activity.ID, Type: activity.Type, Detail: activity.Detail,
			Username: activity.Username, DisplayName: activity.DisplayName,
			CreatedAt: activity.CreatedAt.Format(time.RFC3339),
		})
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"activities": rows})
}
