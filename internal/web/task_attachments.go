package web

import (
	"io"
	"mime"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"

	"caldav-free/internal/store"
)

const maxTaskAttachmentSize = 10 << 20

type apiTaskAttachment struct {
	ID          int64  `json:"id"`
	TaskID      int64  `json:"taskId"`
	Filename    string `json:"filename"`
	ContentType string `json:"contentType"`
	Size        int64  `json:"size"`
	CanDelete   bool   `json:"canDelete"`
}

func taskAttachmentDTO(info store.TaskAttachmentInfo, canDelete bool) apiTaskAttachment {
	return apiTaskAttachment{ID: info.ID, TaskID: info.TaskID, Filename: info.Filename, ContentType: info.ContentType, Size: info.Size, CanDelete: canDelete}
}

func (s *Server) apiTaskAttachments(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	taskID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || taskID <= 0 {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	access, err := s.store.GetTaskAccess(r.Context(), current.ID, taskID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	if r.Method == http.MethodGet {
		rows, err := s.store.ListTaskAttachments(r.Context(), taskID)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		out := make([]apiTaskAttachment, 0, len(rows))
		for _, row := range rows {
			out = append(out, taskAttachmentDTO(row, row.UserID == current.ID || access.List.UserID == current.ID))
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"attachments": out})
		return
	}
	if access.Role != "owner" && access.Role != "editor" {
		writeAPIError(w, http.StatusForbidden, "该共享清单为只读")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxTaskAttachmentSize+1<<20)
	if err := r.ParseMultipartForm(maxTaskAttachmentSize + 1<<20); err != nil {
		writeAPIError(w, http.StatusBadRequest, "附件过大或格式无效")
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "请选择文件")
		return
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, maxTaskAttachmentSize+1))
	if err != nil || len(data) > maxTaskAttachmentSize {
		writeAPIError(w, http.StatusBadRequest, "单个附件不能超过 10MB")
		return
	}
	filename := filepath.Base(strings.TrimSpace(header.Filename))
	if filename == "" || filename == "." || filename == "/" {
		filename = "attachment"
	}
	if len(filename) > 255 {
		filename = filename[len(filename)-255:]
	}
	contentType := strings.TrimSpace(header.Header.Get("Content-Type"))
	if contentType == "" {
		contentType = mime.TypeByExtension(filepath.Ext(filename))
	}
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	attachment := &store.TaskAttachment{TaskID: taskID, UserID: current.ID, Filename: filename, ContentType: contentType, Size: int64(len(data)), Data: data}
	if err := s.store.CreateTaskAttachment(r.Context(), attachment); err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"attachment": apiTaskAttachment{ID: attachment.ID, TaskID: taskID, Filename: filename, ContentType: contentType, Size: attachment.Size, CanDelete: true}})
}

func (s *Server) apiTaskAttachment(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	taskID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || taskID <= 0 {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	attachmentID, err := strconv.ParseInt(r.PathValue("attachmentId"), 10, 64)
	if err != nil || attachmentID <= 0 {
		writeAPIError(w, http.StatusNotFound, "附件不存在")
		return
	}
	access, err := s.store.GetTaskAccess(r.Context(), current.ID, taskID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	attachment, err := s.store.GetTaskAttachment(r.Context(), taskID, attachmentID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "附件不存在")
		return
	}
	if r.Method == http.MethodDelete {
		if attachment.UserID != current.ID && access.List.UserID != current.ID {
			writeAPIError(w, http.StatusForbidden, "不能删除其他成员的附件")
			return
		}
		if err := s.store.DeleteTaskAttachment(r.Context(), taskID, attachmentID); err != nil {
			s.apiServerError(w, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	w.Header().Set("Content-Type", attachment.ContentType)
	w.Header().Set("Content-Disposition", "inline; filename="+strconv.Quote(attachment.Filename))
	w.Header().Set("Cache-Control", "private, max-age=3600")
	_, _ = w.Write(attachment.Data)
}
