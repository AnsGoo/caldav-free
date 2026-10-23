package web

import (
	"bytes"
	"io"
	"mime"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"

	"caldav-free/internal/store"
)

const maxCommentAttachmentSize = 10 << 20

type apiCommentAttachment struct {
	ID          int64  `json:"id"`
	CommentID   int64  `json:"commentId"`
	Filename    string `json:"filename"`
	ContentType string `json:"contentType"`
	Size        int64  `json:"size"`
	CanDelete   bool   `json:"canDelete"`
}

func commentAttachmentDTO(info store.CommentAttachmentInfo, canDelete bool) apiCommentAttachment {
	return apiCommentAttachment{
		ID: info.ID, CommentID: info.CommentID, Filename: info.Filename,
		ContentType: info.ContentType, Size: info.Size, CanDelete: canDelete,
	}
}

func (s *Server) apiCommentAttachments(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	if r.Method != http.MethodPost {
		writeAPIError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	taskID, commentID, ok := commentPath(r)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "附件路径无效")
		return
	}
	access, err := s.store.GetTaskAccess(r.Context(), current.ID, taskID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	comment, err := s.store.GetTaskComment(r.Context(), taskID, commentID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "评论不存在")
		return
	}
	if comment.UserID != current.ID && access.List.UserID != current.ID {
		writeAPIError(w, http.StatusForbidden, "不能给其他成员的评论添加附件")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxCommentAttachmentSize+1<<20)
	if err := r.ParseMultipartForm(maxCommentAttachmentSize + 1<<20); err != nil {
		writeAPIError(w, http.StatusBadRequest, "附件过大或格式无效")
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "请选择文件")
		return
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, maxCommentAttachmentSize+1))
	if err != nil || len(data) > maxCommentAttachmentSize {
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
	attachment := &store.CommentAttachment{
		TaskID: taskID, CommentID: commentID, UserID: current.ID,
		Filename: filename, ContentType: contentType, Size: int64(len(data)), Data: data,
	}
	if err := s.store.CreateCommentAttachment(r.Context(), attachment); err != nil {
		s.apiServerError(w, err)
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"attachment": apiCommentAttachment{
		ID: attachment.ID, CommentID: commentID, Filename: filename,
		ContentType: contentType, Size: attachment.Size, CanDelete: true,
	}})
}

func (s *Server) apiCommentAttachment(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	taskID, commentID, attachmentID, ok := commentAttachmentPath(r)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "附件路径无效")
		return
	}
	access, err := s.store.GetTaskAccess(r.Context(), current.ID, taskID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "任务不存在")
		return
	}
	attachment, err := s.store.GetCommentAttachment(r.Context(), taskID, commentID, attachmentID)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "附件不存在")
		return
	}
	if r.Method == http.MethodDelete {
		if attachment.UserID != current.ID && access.List.UserID != current.ID {
			writeAPIError(w, http.StatusForbidden, "不能删除其他成员的附件")
			return
		}
		if err := s.store.DeleteCommentAttachment(r.Context(), taskID, commentID, attachmentID); err != nil {
			s.apiServerError(w, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	disposition := mime.FormatMediaType("attachment", map[string]string{"filename": attachment.Filename})
	w.Header().Set("Content-Type", attachment.ContentType)
	w.Header().Set("Content-Disposition", disposition)
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Cache-Control", "private, no-store")
	http.ServeContent(w, r, attachment.Filename, attachment.CreatedAt, bytes.NewReader(attachment.Data))
}

func commentPath(r *http.Request) (int64, int64, bool) {
	taskID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		return 0, 0, false
	}
	commentID, err := strconv.ParseInt(r.PathValue("commentId"), 10, 64)
	if err != nil {
		return 0, 0, false
	}
	return taskID, commentID, true
}

func commentAttachmentPath(r *http.Request) (int64, int64, int64, bool) {
	taskID, commentID, ok := commentPath(r)
	if !ok {
		return 0, 0, 0, false
	}
	attachmentID, err := strconv.ParseInt(r.PathValue("attachmentId"), 10, 64)
	if err != nil {
		return 0, 0, 0, false
	}
	return taskID, commentID, attachmentID, true
}
