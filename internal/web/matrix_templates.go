package web

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"caldav-free/internal/store"
)

type apiMatrixRuleTemplate struct {
	ID    int64           `json:"id"`
	Name  string          `json:"name"`
	Rules json.RawMessage `json:"rules,omitempty"`
}

func matrixRuleTemplateDTO(template *store.MatrixRuleTemplate) apiMatrixRuleTemplate {
	dto := apiMatrixRuleTemplate{ID: template.ID, Name: template.Name}
	if json.Valid([]byte(template.Rules)) && strings.TrimSpace(template.Rules) != "" {
		dto.Rules = json.RawMessage(template.Rules)
	}
	return dto
}

func (s *Server) apiMatrixRuleTemplates(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	if r.Method == http.MethodGet {
		templates, err := s.store.ListMatrixRuleTemplates(r.Context(), current.ID)
		if err != nil {
			s.apiServerError(w, err)
			return
		}
		rows := make([]apiMatrixRuleTemplate, 0, len(templates))
		for _, template := range templates {
			rows = append(rows, matrixRuleTemplateDTO(template))
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"templates": rows})
		return
	}
	var body struct {
		Name  string          `json:"name"`
		Rules json.RawMessage `json:"rules"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Name) == "" {
		writeAPIError(w, http.StatusBadRequest, "请填写模板名称")
		return
	}
	if len(body.Rules) == 0 {
		writeAPIError(w, http.StatusBadRequest, "请填写模板规则")
		return
	}
	if !validMatrixRules(body.Rules) {
		writeAPIError(w, http.StatusBadRequest, "模板规则格式不正确")
		return
	}
	template, err := s.store.CreateMatrixRuleTemplate(r.Context(), current.ID, body.Name, string(body.Rules))
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeAPIJSON(w, http.StatusCreated, map[string]any{"template": matrixRuleTemplateDTO(template)})
}

func (s *Server) apiMatrixRuleTemplate(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, "模板不存在")
		return
	}
	switch r.Method {
	case http.MethodDelete:
		if err := s.store.DeleteMatrixRuleTemplate(r.Context(), current.ID, id); err != nil {
			writeAPIError(w, http.StatusNotFound, "模板不存在")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	case http.MethodPatch:
		var body struct {
			Name  string          `json:"name"`
			Rules json.RawMessage `json:"rules"`
		}
		if !readAPIJSON(w, r, &body) {
			return
		}
		if strings.TrimSpace(body.Name) == "" && len(body.Rules) == 0 {
			writeAPIError(w, http.StatusBadRequest, "没有需要更新的内容")
			return
		}
		if !validMatrixRules(body.Rules) {
			writeAPIError(w, http.StatusBadRequest, "模板规则格式不正确")
			return
		}
		template, err := s.store.UpdateMatrixRuleTemplate(r.Context(), current.ID, id, body.Name, string(body.Rules))
		if err != nil {
			writeAPIError(w, http.StatusNotFound, "模板不存在")
			return
		}
		writeAPIJSON(w, http.StatusOK, map[string]any{"template": matrixRuleTemplateDTO(template)})
	default:
		writeAPIError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}
