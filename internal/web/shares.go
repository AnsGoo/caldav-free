package web

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/store"
)

type apiTaskListShare struct {
	UserID      int64  `json:"userId"`
	Username    string `json:"username"`
	DisplayName string `json:"displayName"`
	Role        string `json:"role"`
	CreatedAt   string `json:"createdAt"`
}

type apiSharedTaskList struct {
	ListID        int64  `json:"listId"`
	Name          string `json:"name"`
	Color         string `json:"color"`
	Kind          string `json:"kind"`
	OwnerID       int64  `json:"ownerId"`
	OwnerUsername string `json:"ownerUsername"`
	OwnerDisplay  string `json:"ownerDisplay"`
	Role          string `json:"role"`
	Count         int64  `json:"count"`
}

func (s *Server) apiTaskListShares(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	listID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "清单不存在")
		return
	}
	if r.Method == http.MethodGet {
		shares, err := s.store.ListTaskListShares(r.Context(), current.ID, listID)
		if err != nil {
			if err == store.ErrNotFound {
				writeAPIError(w, http.StatusNotFound, "清单不存在")
				return
			}
			s.apiServerError(w, err)
			return
		}
		rows := make([]apiTaskListShare, 0, len(shares))
		for _, share := range shares {
			rows = append(rows, apiTaskListShare{
				UserID: share.UserID, Username: share.Username, DisplayName: share.DisplayName,
				Role: share.Role, CreatedAt: share.CreatedAt.Format(time.RFC3339),
			})
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"shares": rows})
		return
	}
	var body struct {
		Username string `json:"username"`
		Role     string `json:"role"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	username := strings.ToLower(strings.TrimSpace(body.Username))
	if username == "" {
		writeAPIError(w, http.StatusBadRequest, "请填写用户名")
		return
	}
	share, err := s.store.ShareTaskList(r.Context(), current.ID, listID, username, body.Role)
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "清单不存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"share": apiTaskListShare{
		UserID: share.UserID, Username: share.Username, DisplayName: share.DisplayName,
		Role: share.Role, CreatedAt: share.CreatedAt.Format(time.RFC3339),
	}})
}

func (s *Server) apiTaskListShare(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	listID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "清单不存在")
		return
	}
	userID, err := strconv.ParseInt(r.PathValue("userId"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "共享用户不存在")
		return
	}
	if err := s.store.DeleteTaskListShare(r.Context(), current.ID, listID, userID); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "共享记录不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) apiSharedTasks(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	listID, err := strconv.ParseInt(r.URL.Query().Get("listId"), 10, 64)
	if err != nil || listID <= 0 {
		writeAPIError(w, http.StatusBadRequest, "清单参数无效")
		return
	}
	list, role, err := s.store.GetSharedTaskList(r.Context(), current.ID, listID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "共享清单不存在")
		return
	}
	tasks, err := s.store.ListSharedTasks(r.Context(), current.ID, listID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	rows := make([]apiTask, 0, len(tasks))
	for _, task := range tasks {
		rows = append(rows, apiTaskDTO(task, list))
	}
	owner, _ := s.store.GetUser(r.Context(), list.UserID)
	ownerName := ""
	ownerDisplay := ""
	if owner != nil {
		ownerName = owner.Username
		ownerDisplay = owner.DisplayName
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{
		"list": apiSharedTaskList{
			ListID: list.ID, Name: list.Name, Color: list.Color, Kind: list.Kind,
			OwnerID: list.UserID, OwnerUsername: ownerName, OwnerDisplay: ownerDisplay,
			Role: role, Count: int64(len(rows)),
		},
		"tasks": rows,
	})
}

func sharedTaskListDTO(item store.SharedTaskList) apiSharedTaskList {
	return apiSharedTaskList{
		ListID: item.ListID, Name: item.Name, Color: item.Color, Kind: item.Kind,
		OwnerID: item.OwnerID, OwnerUsername: item.OwnerUsername,
		OwnerDisplay: item.OwnerDisplay, Role: item.Role, Count: item.Count,
	}
}

type apiTaskListMember struct {
	Username    string `json:"username"`
	DisplayName string `json:"displayName"`
	Role        string `json:"role"`
}

func (s *Server) apiTaskListMembers(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	listID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "清单不存在")
		return
	}
	members, err := s.store.ListTaskListMembers(r.Context(), current.ID, listID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "清单不存在")
		return
	}
	rows := make([]apiTaskListMember, 0, len(members))
	for _, member := range members {
		rows = append(rows, apiTaskListMember{
			Username: member.Username, DisplayName: member.DisplayName, Role: member.Role,
		})
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"members": rows})
}

type apiTaskShare struct {
	UserID      int64  `json:"userId"`
	Username    string `json:"username"`
	DisplayName string `json:"displayName"`
	Role        string `json:"role"`
	CreatedAt   string `json:"createdAt"`
}

type apiSharedNote struct {
	Task          apiTask `json:"task"`
	Role          string  `json:"role"`
	OwnerID       int64   `json:"ownerId"`
	OwnerUsername string  `json:"ownerUsername"`
	OwnerDisplay  string  `json:"ownerDisplay"`
}

func (s *Server) apiTaskShares(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	taskID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "笔记不存在")
		return
	}
	if r.Method == http.MethodGet {
		shares, err := s.store.ListTaskShares(r.Context(), current.ID, taskID)
		if err != nil {
			writeAPIError(w, http.StatusNotFound, "笔记不存在")
			return
		}
		rows := make([]apiTaskShare, 0, len(shares))
		for _, share := range shares {
			rows = append(rows, apiTaskShare{
				UserID: share.UserID, Username: share.Username, DisplayName: share.DisplayName,
				Role: share.Role, CreatedAt: share.CreatedAt.Format(time.RFC3339),
			})
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"shares": rows})
		return
	}
	var body struct {
		Username string `json:"username"`
		Role     string `json:"role"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	username := strings.ToLower(strings.TrimSpace(body.Username))
	if username == "" {
		writeAPIError(w, http.StatusBadRequest, "请填写用户名")
		return
	}
	share, err := s.store.ShareTask(r.Context(), current.ID, taskID, username, body.Role)
	if err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "笔记不存在")
			return
		}
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"share": apiTaskShare{
		UserID: share.UserID, Username: share.Username, DisplayName: share.DisplayName,
		Role: share.Role, CreatedAt: share.CreatedAt.Format(time.RFC3339),
	}})
}

func (s *Server) apiTaskShare(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	taskID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "笔记不存在")
		return
	}
	userID, err := strconv.ParseInt(r.PathValue("userId"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "共享用户不存在")
		return
	}
	if err := s.store.DeleteTaskShare(r.Context(), current.ID, taskID, userID); err != nil {
		if err == store.ErrNotFound {
			writeAPIError(w, http.StatusNotFound, "共享记录不存在")
			return
		}
		s.apiServerError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
