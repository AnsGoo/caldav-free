package web

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
)

func TestAISettingsAndChatTools(t *testing.T) {
	env := newAPIEnv(t)
	ctx := context.Background()
	if err := env.store.SetSetting(ctx, settingAIBaseURL, "https://example.invalid/v1"); err != nil {
		t.Fatal(err)
	}
	if err := env.store.SetSetting(ctx, settingAIModel, "test-model"); err != nil {
		t.Fatal(err)
	}
	if err := env.store.SetSetting(ctx, settingAIAPIKey, "test-key"); err != nil {
		t.Fatal(err)
	}

	var calls int32
	var sawToolResult int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); got != "Bearer test-key" {
			t.Errorf("authorization = %q", got)
		}
		var body struct {
			Messages []struct {
				Role string `json:"role"`
			} `json:"messages"`
			Tools []struct {
				Function struct {
					Name string `json:"name"`
				} `json:"function"`
			} `json:"tools"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatal(err)
		}
		if len(body.Tools) < 6 {
			t.Errorf("tools missing: %d", len(body.Tools))
		}
		for _, message := range body.Messages {
			if message.Role == "tool" {
				atomic.StoreInt32(&sawToolResult, 1)
			}
		}
		call := atomic.AddInt32(&calls, 1)
		w.Header().Set("Content-Type", "application/json")
		if call == 1 {
			_, _ = w.Write([]byte(`{"choices":[{"message":{"role":"assistant","content":null,"tool_calls":[{"id":"call_1","type":"function","function":{"name":"create_task","arguments":"{\"title\":\"AI 创建的任务\",\"due\":\"2026-10-30T10:00:00+08:00\",\"priority\":2}"}}]}}]}`))
			return
		}
		if !strings.Contains(body.Messages[len(body.Messages)-1].Role, "tool") {
			t.Errorf("last message role = %q", body.Messages[len(body.Messages)-1].Role)
		}
		_, _ = w.Write([]byte(`{"choices":[{"message":{"role":"assistant","content":"已为你创建任务「AI 创建的任务」。"}}]}`))
	}))
	defer upstream.Close()
	if err := env.store.SetSetting(ctx, settingAIBaseURL, upstream.URL); err != nil {
		t.Fatal(err)
	}

	status, body := env.request(t, "GET", "/api/admin/tasks/ai/settings", nil, "")
	if status != http.StatusOK {
		t.Fatalf("settings = %d: %s", status, body)
	}
	settings := decode[struct {
		BaseURL    string `json:"baseUrl"`
		Model      string `json:"model"`
		HasKey     bool   `json:"hasKey"`
		Configured bool   `json:"configured"`
	}](t, body)
	if !settings.HasKey || !settings.Configured || settings.BaseURL != upstream.URL {
		t.Fatalf("unexpected settings: %+v", settings)
	}
	if strings.Contains(string(body), "test-key") {
		t.Fatal("api key leaked in settings response")
	}

	status, body = env.request(t, "POST", "/api/admin/tasks/ai/chat", map[string]any{
		"messages": []map[string]string{{"role": "user", "content": "帮我创建一个任务"}},
		"timezone": "Asia/Shanghai",
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("chat = %d: %s", status, body)
	}
	reply := decode[struct {
		Message string `json:"message"`
		Actions []struct {
			Type  string `json:"type"`
			Label string `json:"label"`
		} `json:"actions"`
	}](t, body)
	if !strings.Contains(reply.Message, "已为你创建任务") || len(reply.Actions) != 1 || reply.Actions[0].Type != "create_task" {
		t.Fatalf("unexpected reply: %+v", reply)
	}
	if atomic.LoadInt32(&sawToolResult) != 1 {
		t.Fatal("tool result was not sent back to the model")
	}
	tasks, err := env.store.ListAllTasks(ctx, env.userID, 10)
	if err != nil || len(tasks) != 1 || tasks[0].Title != "AI 创建的任务" || tasks[0].Priority != 2 {
		t.Fatalf("AI task not created: %+v (%v)", tasks, err)
	}
}

func TestAIChatRequiresConfiguration(t *testing.T) {
	t.Setenv("CALDAV_AI_BASE_URL", "")
	t.Setenv("CALDAV_AI_MODEL", "")
	t.Setenv("CALDAV_AI_API_KEY", "")
	env := newAPIEnv(t)
	status, body := env.request(t, "GET", "/api/admin/tasks/ai/settings", nil, "")
	if status != http.StatusOK {
		t.Fatalf("settings = %d: %s", status, body)
	}
	if settings := decode[struct {
		Configured bool `json:"configured"`
	}](t, body); settings.Configured {
		t.Fatal("empty settings should not be configured")
	}
	status, body = env.request(t, "POST", "/api/admin/tasks/ai/chat", map[string]any{
		"messages": []map[string]string{{"role": "user", "content": "你好"}},
	}, env.csrf)
	if status != http.StatusServiceUnavailable {
		t.Fatalf("chat = %d: %s", status, body)
	}
}

func TestAISettingsUpdateMasksKey(t *testing.T) {
	env := newAPIEnv(t)
	status, body := env.request(t, "PUT", "/api/admin/tasks/ai/settings", map[string]any{
		"baseUrl": "http://127.0.0.1:11434/v1", "model": "llama3.1", "apiKey": "secret-value",
	}, env.csrf)
	if status != http.StatusOK {
		t.Fatalf("save settings = %d: %s", status, body)
	}
	if strings.Contains(string(body), "secret-value") {
		t.Fatal("api key leaked in settings update response")
	}
	settings := decode[struct {
		HasKey     bool `json:"hasKey"`
		Configured bool `json:"configured"`
	}](t, body)
	if !settings.HasKey || !settings.Configured {
		t.Fatalf("unexpected settings: %+v", settings)
	}
}

func TestCallAIStream(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		_, _ = w.Write([]byte("data: {\"choices\":[{\"delta\":{\"content\":\"你\"}}]}\n\n"))
		_, _ = w.Write([]byte("data: {\"choices\":[{\"delta\":{\"content\":\"好\"}}]}\n\n"))
		_, _ = w.Write([]byte("data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_1\",\"type\":\"function\",\"function\":{\"name\":\"list_\",\"arguments\":\"{\\\"view\\\":\"}}]}}]}\n\n"))
		_, _ = w.Write([]byte("data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"name\":\"tasks\",\"arguments\":\"\\\"today\\\"}\"}}]}}]}\n\n"))
		_, _ = w.Write([]byte("data: [DONE]\n\n"))
	}))
	defer upstream.Close()
	config := aiConfig{BaseURL: upstream.URL + "/v1", Model: "stream-model"}
	var delta strings.Builder
	reply, err := (&Server{}).callAIStream(context.Background(), config, []aiChatMessage{{Role: "user", Content: "hi"}}, nil, func(text string) {
		delta.WriteString(text)
	})
	if err != nil {
		t.Fatal(err)
	}
	if reply.Content != "你好" || delta.String() != "你好" {
		t.Fatalf("content = %q, delta = %q", reply.Content, delta.String())
	}
	if len(reply.ToolCalls) != 1 || reply.ToolCalls[0].Function.Name != "list_tasks" || reply.ToolCalls[0].Function.Arguments != `{"view":"today"}` {
		t.Fatalf("tool calls = %+v", reply.ToolCalls)
	}
	if reply.ToolCalls[0].ID != "call_1" {
		t.Fatalf("tool call id = %q", reply.ToolCalls[0].ID)
	}
}
