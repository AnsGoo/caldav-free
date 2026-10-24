package web

import (
	"net/http"
	"strconv"
	"testing"
)

func TestTaskTemplatesAPI(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, http.MethodPost, "/api/admin/task-templates", map[string]any{
		"name": "周报模板", "payload": `{"title":"写周报","priority":2,"tags":["工作"]}`,
	}, env.csrf)
	if status != http.StatusCreated {
		t.Fatalf("create template = %d: %s", status, body)
	}
	var created struct {
		Template struct {
			ID   int64  `json:"id"`
			Name string `json:"name"`
		} `json:"template"`
	}
	created = decode[struct {
		Template struct {
			ID   int64  `json:"id"`
			Name string `json:"name"`
		} `json:"template"`
	}](t, body)
	if created.Template.ID == 0 || created.Template.Name != "周报模板" {
		t.Fatalf("unexpected template: %+v", created.Template)
	}
	status, body = env.request(t, http.MethodGet, "/api/admin/task-templates", nil, "")
	if status != http.StatusOK {
		t.Fatalf("list templates = %d: %s", status, body)
	}
	status, _ = env.request(t, http.MethodPost, "/api/admin/task-templates", map[string]any{"name": "坏模板", "payload": "not-json"}, env.csrf)
	if status != http.StatusBadRequest {
		t.Fatalf("invalid payload = %d, want 400", status)
	}
	status, body = env.request(t, http.MethodDelete, "/api/admin/task-templates/"+strconv.FormatInt(created.Template.ID, 10), nil, env.csrf)
	if status != http.StatusNoContent {
		t.Fatalf("delete template = %d: %s", status, body)
	}
	status, _ = env.request(t, http.MethodDelete, "/api/admin/task-templates/"+strconv.FormatInt(created.Template.ID, 10), nil, env.csrf)
	if status != http.StatusNotFound {
		t.Fatalf("second delete = %d, want 404", status)
	}
}
