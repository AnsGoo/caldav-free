package web

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"caldav-free/internal/store"
	taskparse "caldav-free/internal/tasks"
)

const (
	settingAIBaseURL      = "ai.base_url"
	settingAIModel        = "ai.model"
	settingAIAPIKey       = "ai.api_key"
	settingAIProvider     = "ai.provider"
	settingAIModels       = "ai.models"
	settingAIModelsBase   = "ai.models_base"
	settingAIRecentModels = "ai.recent_models"
	settingAIModelStats   = "ai.model_stats"
)

type aiConfig struct {
	Provider string
	BaseURL  string
	Model    string
	APIKey   string
}

func (s *Server) loadAIConfig(ctx context.Context) aiConfig {
	get := func(key string) string {
		value, _ := s.store.GetSetting(ctx, key)
		return strings.TrimSpace(value)
	}
	config := aiConfig{
		Provider: get(settingAIProvider),
		BaseURL:  get(settingAIBaseURL),
		Model:    get(settingAIModel),
		APIKey:   get(settingAIAPIKey),
	}
	if config.Provider == "" {
		config.Provider = strings.TrimSpace(os.Getenv("CALDAV_AI_PROVIDER"))
	}
	if config.BaseURL == "" {
		config.BaseURL = strings.TrimSpace(os.Getenv("CALDAV_AI_BASE_URL"))
	}
	if config.Model == "" {
		config.Model = strings.TrimSpace(os.Getenv("CALDAV_AI_MODEL"))
	}
	if config.APIKey == "" {
		config.APIKey = strings.TrimSpace(os.Getenv("CALDAV_AI_API_KEY"))
	}
	return config
}

func (s *Server) aiSettingsPayload(ctx context.Context) map[string]any {
	config := s.loadAIConfig(ctx)
	provider := config.Provider
	if provider == "" {
		provider = "custom"
	}
	models := []string{}
	if raw, _ := s.store.GetSetting(ctx, settingAIModels); strings.TrimSpace(raw) != "" {
		_ = json.Unmarshal([]byte(raw), &models)
	}
	if models == nil {
		models = []string{}
	}
	return map[string]any{
		"provider":     provider,
		"baseUrl":      config.BaseURL,
		"model":        config.Model,
		"models":       models,
		"recentModels": s.aiRecentModels(ctx),
		"modelStats":   s.aiModelStats(ctx),
		"hasKey":       config.APIKey != "",
		"configured":   config.BaseURL != "" && config.Model != "",
	}
}

func (s *Server) apiAISettings(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	ctx := r.Context()
	if r.Method == http.MethodGet {
		writeAPIJSON(w, http.StatusOK, s.aiSettingsPayload(ctx))
		return
	}
	var body struct {
		Provider string `json:"provider"`
		BaseURL  string `json:"baseUrl"`
		Model    string `json:"model"`
		APIKey   string `json:"apiKey"`
		ClearKey bool   `json:"clearKey"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	baseURL := strings.TrimRight(strings.TrimSpace(body.BaseURL), "/")
	parsed, err := url.Parse(baseURL)
	if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") || parsed.Host == "" {
		writeAPIError(w, http.StatusBadRequest, "Base URL 必须是 http/https 地址")
		return
	}
	model := strings.TrimSpace(body.Model)
	if model == "" {
		writeAPIError(w, http.StatusBadRequest, "请填写模型名称")
		return
	}
	provider := strings.TrimSpace(body.Provider)
	if provider == "" {
		provider = "custom"
	}
	previous := s.loadAIConfig(ctx)
	modelsBase, _ := s.store.GetSetting(ctx, settingAIModelsBase)
	if strings.TrimSpace(modelsBase) == "" {
		modelsBase = previous.BaseURL
	}
	if modelsBase != "" && strings.TrimRight(modelsBase, "/") != baseURL {
		if err := s.store.SetSetting(ctx, settingAIModels, ""); err != nil {
			s.apiServerError(w, err)
			return
		}
		if err := s.store.SetSetting(ctx, settingAIModelsBase, ""); err != nil {
			s.apiServerError(w, err)
			return
		}
	}
	if err := s.store.SetSetting(ctx, settingAIProvider, provider); err != nil {
		s.apiServerError(w, err)
		return
	}
	if err := s.store.SetSetting(ctx, settingAIBaseURL, baseURL); err != nil {
		s.apiServerError(w, err)
		return
	}
	if err := s.store.SetSetting(ctx, settingAIModel, model); err != nil {
		s.apiServerError(w, err)
		return
	}
	if body.ClearKey {
		if err := s.store.SetSetting(ctx, settingAIAPIKey, ""); err != nil {
			s.apiServerError(w, err)
			return
		}
	} else if key := strings.TrimSpace(body.APIKey); key != "" {
		if err := s.store.SetSetting(ctx, settingAIAPIKey, key); err != nil {
			s.apiServerError(w, err)
			return
		}
	}
	writeAPIJSON(w, http.StatusOK, s.aiSettingsPayload(ctx))
}

func cleanAIModels(data []byte) ([]string, error) {
	var payload struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
		Models []struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		} `json:"models"`
	}
	if err := json.Unmarshal(data, &payload); err != nil {
		return nil, err
	}
	seen := make(map[string]bool)
	models := make([]string, 0, len(payload.Data)+len(payload.Models))
	for _, item := range payload.Data {
		id := strings.TrimSpace(item.ID)
		if id != "" && !seen[id] {
			seen[id] = true
			models = append(models, id)
		}
	}
	for _, item := range payload.Models {
		id := strings.TrimSpace(item.ID)
		if id == "" {
			id = strings.TrimSpace(item.Name)
		}
		if id != "" && !seen[id] {
			seen[id] = true
			models = append(models, id)
		}
	}
	sort.Strings(models)
	if len(models) > 200 {
		models = models[:200]
	}
	return models, nil
}

func fetchAIModels(ctx context.Context, endpoint, apiKey string) ([]string, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("Accept", "application/json")
	if apiKey != "" {
		request.Header.Set("Authorization", "Bearer "+apiKey)
	}
	client := &http.Client{Timeout: 20 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	data, err := io.ReadAll(io.LimitReader(response.Body, 2<<20))
	if err != nil {
		return nil, err
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		message := strings.TrimSpace(string(data))
		if len(message) > 300 {
			message = message[:300]
		}
		return nil, fmt.Errorf("HTTP %d %s", response.StatusCode, message)
	}
	return cleanAIModels(data)
}

func openAIModelsEndpoint(baseURL string) string {
	endpoint := strings.TrimRight(baseURL, "/")
	if strings.HasSuffix(endpoint, "/chat/completions") {
		endpoint = strings.TrimSuffix(endpoint, "/chat/completions")
	}
	if strings.HasSuffix(endpoint, "/models") {
		return endpoint
	}
	return endpoint + "/models"
}

func ollamaTagsEndpoint(baseURL string) string {
	endpoint := strings.TrimRight(baseURL, "/")
	if strings.HasSuffix(endpoint, "/chat/completions") {
		endpoint = strings.TrimSuffix(endpoint, "/chat/completions")
	}
	if strings.HasSuffix(endpoint, "/v1") {
		endpoint = strings.TrimSuffix(endpoint, "/v1")
	}
	if strings.HasSuffix(endpoint, "/api/tags") {
		return endpoint
	}
	return endpoint + "/api/tags"
}

func (s *Server) apiAIModels(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		Provider string `json:"provider"`
		BaseURL  string `json:"baseUrl"`
		APIKey   string `json:"apiKey"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	config := s.loadAIConfig(r.Context())
	provider := strings.TrimSpace(body.Provider)
	if provider == "" {
		provider = config.Provider
	}
	baseURL := strings.TrimRight(strings.TrimSpace(body.BaseURL), "/")
	if baseURL == "" {
		baseURL = strings.TrimRight(config.BaseURL, "/")
	}
	parsed, err := url.Parse(baseURL)
	if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") || parsed.Host == "" {
		writeAPIError(w, http.StatusBadRequest, "请先填写有效的接口地址")
		return
	}
	apiKey := strings.TrimSpace(body.APIKey)
	if apiKey == "" {
		apiKey = config.APIKey
	}
	endpoints := []string{}
	if provider == "ollama" {
		endpoints = append(endpoints, ollamaTagsEndpoint(baseURL))
	}
	endpoints = append(endpoints, openAIModelsEndpoint(baseURL))
	var models []string
	var lastErr error
	for _, endpoint := range endpoints {
		models, lastErr = fetchAIModels(r.Context(), endpoint, apiKey)
		if lastErr == nil && (len(models) > 0 || endpoint == endpoints[len(endpoints)-1]) {
			break
		}
	}
	if lastErr != nil && len(models) == 0 {
		writeAPIError(w, http.StatusBadGateway, "获取模型失败："+lastErr.Error())
		return
	}
	if models == nil {
		models = []string{}
	}
	if encoded, err := json.Marshal(models); err == nil {
		_ = s.store.SetSetting(r.Context(), settingAIModels, string(encoded))
		_ = s.store.SetSetting(r.Context(), settingAIModelsBase, baseURL)
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"models": models})
}

func (s *Server) aiRecentModels(ctx context.Context) []string {
	list := []string{}
	if raw, _ := s.store.GetSetting(ctx, settingAIRecentModels); strings.TrimSpace(raw) != "" {
		_ = json.Unmarshal([]byte(raw), &list)
	}
	cleaned := make([]string, 0, len(list))
	seen := make(map[string]bool)
	for _, model := range list {
		model = strings.TrimSpace(model)
		if model == "" || seen[model] {
			continue
		}
		seen[model] = true
		cleaned = append(cleaned, model)
		if len(cleaned) == 8 {
			break
		}
	}
	return cleaned
}

func (s *Server) rememberAIModel(ctx context.Context, model string) []string {
	model = strings.TrimSpace(model)
	if model == "" {
		return s.aiRecentModels(ctx)
	}
	list := s.aiRecentModels(ctx)
	next := []string{model}
	for _, item := range list {
		if item != model {
			next = append(next, item)
		}
	}
	if len(next) > 8 {
		next = next[:8]
	}
	if encoded, err := json.Marshal(next); err == nil {
		_ = s.store.SetSetting(ctx, settingAIRecentModels, string(encoded))
	}
	return next
}

type aiModelStat struct {
	Calls   int    `json:"calls"`
	TotalMs int64  `json:"totalMs"`
	LastMs  int64  `json:"lastMs"`
	LastAt  string `json:"lastAt"`
}

func (s *Server) aiModelStats(ctx context.Context) map[string]aiModelStat {
	stats := map[string]aiModelStat{}
	if raw, _ := s.store.GetSetting(ctx, settingAIModelStats); strings.TrimSpace(raw) != "" {
		_ = json.Unmarshal([]byte(raw), &stats)
	}
	if stats == nil {
		stats = map[string]aiModelStat{}
	}
	return stats
}

func (s *Server) recordAIModelStat(ctx context.Context, model string, latency time.Duration) map[string]aiModelStat {
	model = strings.TrimSpace(model)
	stats := s.aiModelStats(ctx)
	if model == "" {
		return stats
	}
	entry := stats[model]
	elapsed := latency.Milliseconds()
	entry.Calls++
	entry.TotalMs += elapsed
	entry.LastMs = elapsed
	entry.LastAt = time.Now().UTC().Format(time.RFC3339)
	stats[model] = entry
	if len(stats) > 20 {
		oldestKey := ""
		oldest := ""
		for key, item := range stats {
			if oldestKey == "" || item.LastAt < oldest {
				oldestKey = key
				oldest = item.LastAt
			}
		}
		if oldestKey != "" {
			delete(stats, oldestKey)
		}
	}
	if encoded, err := json.Marshal(stats); err == nil {
		_ = s.store.SetSetting(ctx, settingAIModelStats, string(encoded))
	}
	return stats
}

func aiStoredModels(ctx context.Context, s *Server) []string {
	list := []string{}
	if raw, _ := s.store.GetSetting(ctx, settingAIModels); strings.TrimSpace(raw) != "" {
		_ = json.Unmarshal([]byte(raw), &list)
	}
	return list
}

func (s *Server) apiAITestModel(w http.ResponseWriter, r *http.Request, current *store.User, _ *session) {
	var body struct {
		Provider string `json:"provider"`
		BaseURL  string `json:"baseUrl"`
		APIKey   string `json:"apiKey"`
		Model    string `json:"model"`
		Mode     string `json:"mode"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	config := s.loadAIConfig(r.Context())
	baseURL := strings.TrimRight(strings.TrimSpace(body.BaseURL), "/")
	if baseURL == "" {
		baseURL = strings.TrimRight(config.BaseURL, "/")
	}
	parsed, err := url.Parse(baseURL)
	if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") || parsed.Host == "" {
		writeAPIError(w, http.StatusBadRequest, "请先填写有效的接口地址")
		return
	}
	model := strings.TrimSpace(body.Model)
	if model == "" {
		model = config.Model
	}
	if model == "" {
		writeAPIError(w, http.StatusBadRequest, "请选择要测试的模型")
		return
	}
	apiKey := strings.TrimSpace(body.APIKey)
	if apiKey == "" {
		apiKey = config.APIKey
	}
	endpoint := strings.TrimRight(baseURL, "/")
	if strings.HasSuffix(endpoint, "/chat/completions") {
		// already complete
	} else if strings.HasSuffix(endpoint, "/v1") || strings.HasSuffix(endpoint, "/v4") {
		endpoint += "/chat/completions"
	} else {
		endpoint += "/chat/completions"
	}
	testMode := strings.TrimSpace(body.Mode)
	payload := map[string]any{
		"model": model,
		"messages": []map[string]string{
			{"role": "user", "content": "Reply with OK only."},
		},
		"max_tokens": 8,
	}
	if testMode == "tools" {
		payload["messages"] = []map[string]string{
			{"role": "user", "content": "Call the ping tool once. Do not answer directly."},
		}
		payload["tools"] = []map[string]any{
			{
				"type": "function",
				"function": map[string]any{
					"name":        "ping",
					"description": "Connectivity test tool.",
					"parameters":  map[string]any{"type": "object", "properties": map[string]any{}},
				},
			},
		}
		payload["tool_choice"] = "auto"
	}
	encoded, _ := json.Marshal(payload)
	request, err := http.NewRequestWithContext(r.Context(), http.MethodPost, endpoint, bytes.NewReader(encoded))
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "接口地址无效")
		return
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Accept", "application/json")
	if apiKey != "" {
		request.Header.Set("Authorization", "Bearer "+apiKey)
	}
	start := time.Now()
	client := &http.Client{Timeout: 20 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		writeAPIError(w, http.StatusBadGateway, "连接失败："+err.Error())
		return
	}
	defer response.Body.Close()
	data, err := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if err != nil {
		writeAPIError(w, http.StatusBadGateway, "读取测试结果失败")
		return
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		message := strings.TrimSpace(string(data))
		if len(message) > 300 {
			message = message[:300]
		}
		writeAPIError(w, http.StatusBadGateway, fmt.Sprintf("测试失败：HTTP %d %s", response.StatusCode, message))
		return
	}
	var result struct {
		Choices []struct {
			Message struct {
				Content   string `json:"content"`
				ToolCalls []struct {
					Function struct {
						Name string `json:"name"`
					} `json:"function"`
				} `json:"tool_calls"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		writeAPIError(w, http.StatusBadGateway, "接口返回格式不正确")
		return
	}
	if len(result.Choices) == 0 {
		writeAPIError(w, http.StatusBadGateway, "接口没有返回对话结果")
		return
	}
	sample := strings.TrimSpace(result.Choices[0].Message.Content)
	if len([]rune(sample)) > 120 {
		sample = string([]rune(sample)[:120])
	}
	responsePayload := map[string]any{
		"ok":        true,
		"model":     model,
		"latencyMs": time.Since(start).Milliseconds(),
		"sample":    sample,
	}
	if testMode == "tools" {
		responsePayload["toolsSupported"] = len(result.Choices[0].Message.ToolCalls) > 0
	}
	writeAPIJSON(w, http.StatusOK, responsePayload)
}

// ---------------------------------------------------------------- chat

type aiToolCall struct {
	ID       string `json:"id"`
	Type     string `json:"type"`
	Function struct {
		Name      string `json:"name"`
		Arguments string `json:"arguments"`
	} `json:"function"`
}

type aiChatMessage struct {
	Role       string       `json:"role"`
	Content    string       `json:"content,omitempty"`
	ToolCalls  []aiToolCall `json:"tool_calls,omitempty"`
	ToolCallID string       `json:"tool_call_id,omitempty"`
}

type aiAction struct {
	Type   string `json:"type"`
	Label  string `json:"label"`
	TaskID int64  `json:"taskId,omitempty"`
	ListID int64  `json:"listId,omitempty"`
}

type aiToolDef struct {
	Type     string `json:"type"`
	Function struct {
		Name        string         `json:"name"`
		Description string         `json:"description"`
		Parameters  map[string]any `json:"parameters"`
	} `json:"function"`
}

func tool(name, description string, properties map[string]any, required ...string) aiToolDef {
	var def aiToolDef
	def.Type = "function"
	def.Function.Name = name
	def.Function.Description = description
	def.Function.Parameters = map[string]any{
		"type":       "object",
		"properties": properties,
	}
	if len(required) > 0 {
		def.Function.Parameters["required"] = required
	}
	return def
}

func stringProp(description string) map[string]any {
	return map[string]any{"type": "string", "description": description}
}

func numberProp(description string) map[string]any {
	return map[string]any{"type": "integer", "description": description}
}

func (s *Server) aiTools() []aiToolDef {
	return []aiToolDef{
		tool("list_lists", "列出当前用户的清单（任务列表）及其 ID。", map[string]any{}),
		tool("list_tasks", "查询任务。view 可选 all/today/next7/inbox/completed；query 搜索标题或备注。", map[string]any{
			"view":  map[string]any{"type": "string", "enum": []string{"all", "today", "next7", "inbox", "completed"}},
			"query": stringProp("搜索关键词"),
			"limit": numberProp("最多返回条数，默认 30"),
		}),
		tool("get_stats", "获取最近 30 天的任务统计。", map[string]any{}),
		tool("create_task", "创建任务。日期使用 RFC3339 或 YYYY-MM-DDTHH:mm；只有日期没有时间时 allDay=true。", map[string]any{
			"title":           stringProp("任务标题"),
			"text":            stringProp("自然语言任务描述，可包含日期、#标签、! 优先级；可替代 title"),
			"listId":          numberProp("清单 ID，缺省为收集箱"),
			"due":             stringProp("到期时间"),
			"allDay":          map[string]any{"type": "boolean"},
			"priority":        numberProp("优先级 0=无, 1=低, 2=中, 3=高"),
			"tags":            map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
			"notes":           stringProp("备注"),
			"recurrence":      stringProp("RRULE，例如 FREQ=DAILY 或 FREQ=WEEKLY;BYDAY=MO,WE"),
			"reminderOffset":  numberProp("单个提前提醒分钟数，-1=不提醒"),
			"reminderOffsets": map[string]any{"type": "array", "items": numberProp("提前分钟数，0=准时"), "description": "多个提醒偏移，优先于 reminderOffset"},
		}, "title"),
		tool("update_task", "修改任务字段。只传需要修改的字段；completed=true 完成（重复任务会推进到下一次）。", map[string]any{
			"id":              numberProp("任务 ID"),
			"title":           stringProp("新标题"),
			"listId":          numberProp("移动到清单 ID"),
			"due":             stringProp("新到期时间；传空字符串清除日期"),
			"allDay":          map[string]any{"type": "boolean"},
			"priority":        numberProp("优先级 0-3"),
			"tags":            map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
			"notes":           stringProp("备注"),
			"recurrence":      stringProp("RRULE；空字符串表示不重复"),
			"reminderOffset":  numberProp("单个提前提醒分钟数，-1=不提醒"),
			"reminderOffsets": map[string]any{"type": "array", "items": numberProp("提前分钟数，0=准时"), "description": "多个提醒偏移，优先于 reminderOffset；空数组清除提醒"},
			"completed":       map[string]any{"type": "boolean"},
		}, "id"),
		tool("complete_task", "完成一个任务；重复任务会推进到下一次。", map[string]any{
			"id": numberProp("任务 ID"),
		}, "id"),
		tool("delete_task", "把任务移到垃圾桶。", map[string]any{
			"id": numberProp("任务 ID"),
		}, "id"),
		tool("create_list", "创建一个新清单。", map[string]any{
			"name":  stringProp("清单名称"),
			"color": stringProp("颜色，例如 #4772fa"),
		}, "name"),
	}
}

func (s *Server) apiAIChat(w http.ResponseWriter, r *http.Request, current *store.User, sess *session) {
	s.aiChat(w, r, current, sess, false)
}

func (s *Server) apiAIChatStream(w http.ResponseWriter, r *http.Request, current *store.User, sess *session) {
	s.aiChat(w, r, current, sess, true)
}

func (s *Server) aiChat(w http.ResponseWriter, r *http.Request, current *store.User, _ *session, stream bool) {
	var body struct {
		Messages []struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"messages"`
		Timezone string `json:"timezone"`
		Model    string `json:"model"`
	}
	if !readAPIJSON(w, r, &body) {
		return
	}
	config := s.loadAIConfig(r.Context())
	defaultModel := config.Model
	requestedModel := strings.TrimSpace(body.Model)
	if requestedModel != "" {
		if len([]rune(requestedModel)) > 200 {
			writeAPIError(w, http.StatusBadRequest, "模型名称过长")
			return
		}
		config.Model = requestedModel
	}
	if config.BaseURL == "" || config.Model == "" {
		writeAPIError(w, http.StatusServiceUnavailable, "尚未配置 AI 模型，请先在 AI 设置中填写 Base URL 与模型")
		return
	}
	fallbackCandidates := []string{config.Model}
	if requestedModel != "" && requestedModel != defaultModel {
		addCandidate := func(model string) {
			model = strings.TrimSpace(model)
			if model == "" {
				return
			}
			for _, existing := range fallbackCandidates {
				if existing == model {
					return
				}
			}
			if len(fallbackCandidates) < 3 {
				fallbackCandidates = append(fallbackCandidates, model)
			}
		}
		addCandidate(defaultModel)
		for _, model := range s.aiRecentModels(r.Context()) {
			addCandidate(model)
		}
		for _, model := range aiStoredModels(r.Context(), s) {
			addCandidate(model)
		}
	}
	if len(body.Messages) == 0 || len(body.Messages) > 40 {
		writeAPIError(w, http.StatusBadRequest, "对话消息数量无效")
		return
	}
	loc := taskLocation(body.Timezone)
	lists, err := s.store.ListTaskLists(r.Context(), current.ID)
	if err != nil {
		s.apiServerError(w, err)
		return
	}
	ctx := r.Context()
	messages := []aiChatMessage{{Role: "system", Content: aiSystemPrompt(loc, lists)}}
	start := len(body.Messages) - 30
	if start < 0 {
		start = 0
	}
	for _, message := range body.Messages[start:] {
		role := message.Role
		if role != "user" && role != "assistant" {
			continue
		}
		content := strings.TrimSpace(message.Content)
		if content == "" {
			continue
		}
		if len([]rune(content)) > 6000 {
			content = string([]rune(content)[:6000])
		}
		messages = append(messages, aiChatMessage{Role: role, Content: content})
	}
	if len(messages) <= 1 {
		writeAPIError(w, http.StatusBadRequest, "请先输入内容")
		return
	}

	var flusher http.Flusher
	sendEvent := func(eventType string, payload map[string]any) {
		if !stream {
			return
		}
		payload["type"] = eventType
		data, err := json.Marshal(payload)
		if err != nil {
			return
		}
		_, _ = fmt.Fprintf(w, "data: %s\n\n", data)
		flusher.Flush()
	}
	fail := func(status int, message string) {
		if stream && flusher != nil {
			sendEvent("error", map[string]any{"error": message})
			return
		}
		writeAPIError(w, status, message)
	}
	if stream {
		var ok bool
		flusher, ok = w.(http.Flusher)
		if !ok {
			writeAPIError(w, http.StatusInternalServerError, "当前服务器不支持流式响应")
			return
		}
		w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
		w.Header().Set("Cache-Control", "no-cache")
		w.Header().Set("Connection", "keep-alive")
		w.Header().Set("X-Accel-Buffering", "no")
		sendEvent("meta", map[string]any{"model": config.Model})
	}
	tools := s.aiTools()
	actions := make([]aiAction, 0, 2)
	var finalText string
	fallbackFrom := ""
	fallbackFromModel := ""
	chatStart := time.Now()
	for round := 0; round < 6; round++ {
		var reply aiChatMessage
		var err error
		attempted := []string{}
		streamed := false
		for index, candidate := range fallbackCandidates {
			config.Model = candidate
			if stream {
				reply, err = s.callAIStream(ctx, config, messages, tools, func(text string) {
					if text == "" {
						return
					}
					streamed = true
					sendEvent("delta", map[string]any{"text": text})
				})
			} else {
				reply, err = s.callAI(ctx, config, messages, tools)
			}
			if err == nil {
				if index > 0 && fallbackFromModel == "" {
					fallbackFromModel = fallbackCandidates[0]
					fallbackFrom = fallbackFromModel
				}
				fallbackCandidates = fallbackCandidates[index:]
				break
			}
			attempted = append(attempted, candidate)
			if streamed || round > 0 || len(actions) > 0 {
				break
			}
		}
		if err != nil {
			if fallbackFromModel != "" {
				fallbackFrom = fallbackFromModel
			}
			prefix := "AI 请求失败："
			if len(attempted) > 1 {
				prefix = "AI 请求失败（已尝试 " + strings.Join(attempted, "、") + "）："
			}
			fail(http.StatusBadGateway, prefix+err.Error())
			return
		}
		if len(reply.ToolCalls) == 0 {
			finalText = strings.TrimSpace(reply.Content)
			break
		}
		messages = append(messages, reply)
		for _, call := range reply.ToolCalls {
			result, action, err := s.runAITool(ctx, current, call, loc)
			if err != nil {
				result = map[string]any{"error": err.Error()}
			} else if action != nil {
				actions = append(actions, *action)
			}
			encoded, _ := json.Marshal(result)
			messages = append(messages, aiChatMessage{
				Role:       "tool",
				ToolCallID: call.ID,
				Content:    string(encoded),
			})
		}
	}
	if finalText == "" {
		if len(actions) > 0 {
			labels := make([]string, 0, len(actions))
			for _, action := range actions {
				labels = append(labels, action.Label)
			}
			finalText = strings.Join(labels, "；")
		} else {
			finalText = "操作已完成。"
		}
	}
	latency := time.Since(chatStart)
	recentModels := s.rememberAIModel(ctx, config.Model)
	modelStats := s.recordAIModelStat(ctx, config.Model, latency)
	payload := map[string]any{
		"message":      finalText,
		"actions":      actions,
		"model":        config.Model,
		"recentModels": recentModels,
		"modelStats":   modelStats,
		"latencyMs":    latency.Milliseconds(),
	}
	if fallbackFrom != "" {
		payload["fallbackFrom"] = fallbackFrom
	}
	if stream {
		sendEvent("done", payload)
		return
	}
	writeAPIJSON(w, http.StatusOK, payload)
}

func (s *Server) callAIStream(ctx context.Context, config aiConfig, messages []aiChatMessage, tools []aiToolDef, onDelta func(string)) (aiChatMessage, error) {
	endpoint := strings.TrimRight(config.BaseURL, "/")
	if !strings.HasSuffix(endpoint, "/chat/completions") {
		endpoint += "/chat/completions"
	}
	payload := map[string]any{
		"model":       config.Model,
		"messages":    messages,
		"temperature": 0.3,
		"stream":      true,
	}
	if len(tools) > 0 {
		payload["tools"] = tools
		payload["tool_choice"] = "auto"
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return aiChatMessage{}, err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(encoded))
	if err != nil {
		return aiChatMessage{}, err
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Accept", "text/event-stream")
	if config.APIKey != "" {
		request.Header.Set("Authorization", "Bearer "+config.APIKey)
	}
	client := &http.Client{Timeout: 90 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return aiChatMessage{}, err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		data, _ := io.ReadAll(io.LimitReader(response.Body, 1<<20))
		message := strings.TrimSpace(string(data))
		if len(message) > 300 {
			message = message[:300]
		}
		return aiChatMessage{}, fmt.Errorf("HTTP %d: %s", response.StatusCode, message)
	}
	type streamTool struct {
		id   string
		name string
		args strings.Builder
	}
	reply := aiChatMessage{Role: "assistant"}
	var content strings.Builder
	toolsByIndex := map[int]*streamTool{}
	scanner := bufio.NewScanner(response.Body)
	scanner.Buffer(make([]byte, 64*1024), 2<<20)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if !strings.HasPrefix(line, "data:") {
			continue
		}
		data := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if data == "" || data == "[DONE]" {
			continue
		}
		var chunk struct {
			Choices []struct {
				Delta struct {
					Content   string `json:"content"`
					ToolCalls []struct {
						Index    int    `json:"index"`
						ID       string `json:"id"`
						Type     string `json:"type"`
						Function struct {
							Name      string `json:"name"`
							Arguments string `json:"arguments"`
						} `json:"function"`
					} `json:"tool_calls"`
				} `json:"delta"`
			} `json:"choices"`
			Error *struct {
				Message string `json:"message"`
			} `json:"error"`
		}
		if err := json.Unmarshal([]byte(data), &chunk); err != nil {
			continue
		}
		if chunk.Error != nil && chunk.Error.Message != "" {
			return aiChatMessage{}, fmt.Errorf("%s", chunk.Error.Message)
		}
		for _, choice := range chunk.Choices {
			if choice.Delta.Content != "" {
				content.WriteString(choice.Delta.Content)
				if onDelta != nil {
					onDelta(choice.Delta.Content)
				}
			}
			for _, call := range choice.Delta.ToolCalls {
				item := toolsByIndex[call.Index]
				if item == nil {
					item = &streamTool{}
					toolsByIndex[call.Index] = item
				}
				if call.ID != "" {
					item.id = call.ID
				}
				if call.Function.Name != "" {
					item.name += call.Function.Name
				}
				item.args.WriteString(call.Function.Arguments)
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return aiChatMessage{}, err
	}
	reply.Content = content.String()
	if len(toolsByIndex) > 0 {
		indexes := make([]int, 0, len(toolsByIndex))
		for index := range toolsByIndex {
			indexes = append(indexes, index)
		}
		sort.Ints(indexes)
		for _, index := range indexes {
			item := toolsByIndex[index]
			call := aiToolCall{ID: item.id, Type: "function"}
			call.Function.Name = item.name
			call.Function.Arguments = item.args.String()
			if call.ID == "" {
				call.ID = fmt.Sprintf("call_%d", index)
			}
			reply.ToolCalls = append(reply.ToolCalls, call)
		}
	}
	return reply, nil
}

func (s *Server) callAI(ctx context.Context, config aiConfig, messages []aiChatMessage, tools []aiToolDef) (aiChatMessage, error) {
	endpoint := strings.TrimRight(config.BaseURL, "/")
	if !strings.HasSuffix(endpoint, "/chat/completions") {
		endpoint += "/chat/completions"
	}
	payload := map[string]any{
		"model":       config.Model,
		"messages":    messages,
		"temperature": 0.3,
	}
	if len(tools) > 0 {
		payload["tools"] = tools
		payload["tool_choice"] = "auto"
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return aiChatMessage{}, err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(encoded))
	if err != nil {
		return aiChatMessage{}, err
	}
	request.Header.Set("Content-Type", "application/json")
	if config.APIKey != "" {
		request.Header.Set("Authorization", "Bearer "+config.APIKey)
	}
	client := &http.Client{Timeout: 90 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return aiChatMessage{}, err
	}
	defer response.Body.Close()
	data, err := io.ReadAll(io.LimitReader(response.Body, 4<<20))
	if err != nil {
		return aiChatMessage{}, err
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		message := strings.TrimSpace(string(data))
		if len(message) > 300 {
			message = message[:300]
		}
		return aiChatMessage{}, fmt.Errorf("HTTP %d: %s", response.StatusCode, message)
	}
	var result struct {
		Choices []struct {
			Message aiChatMessage `json:"message"`
		} `json:"choices"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		return aiChatMessage{}, fmt.Errorf("响应解析失败")
	}
	if result.Error != nil && result.Error.Message != "" {
		return aiChatMessage{}, fmt.Errorf("%s", result.Error.Message)
	}
	if len(result.Choices) == 0 {
		return aiChatMessage{}, fmt.Errorf("模型没有返回内容")
	}
	return result.Choices[0].Message, nil
}

func aiSystemPrompt(loc *time.Location, lists []*store.TaskList) string {
	now := time.Now().In(loc)
	var builder strings.Builder
	builder.WriteString("你是 caldav-free 的任务助手，帮助用户查看和管理任务。\n")
	builder.WriteString("当前时间：" + now.Format("2006-01-02 15:04 Monday") + "，时区：" + loc.String() + "。\n")
	builder.WriteString("可用清单：\n")
	for _, list := range lists {
		kind := ""
		if list.IsInbox {
			kind = "（收集箱）"
		}
		builder.WriteString(fmt.Sprintf("- id=%d %s%s\n", list.ID, list.Name, kind))
	}
	builder.WriteString("规则：\n")
	builder.WriteString("- 需要任务数据时调用工具，不要编造任务、日期或 ID。\n")
	builder.WriteString("- 用户明确要求创建、修改、完成任务时直接调用工具；意图不明确时先询问。\n")
	builder.WriteString("- 删除任务、清空数据等破坏性操作必须先向用户说明并得到确认，确认后再调用工具。\n")
	builder.WriteString("- 日期使用 RFC3339 或 YYYY-MM-DDTHH:mm；只有日期没有时间时 allDay=true。\n")
	builder.WriteString("- 创建任务时如果没有指定清单，使用收集箱。\n")
	builder.WriteString("- 回复使用简洁中文，说明执行结果；不要输出 JSON 或工具调用内容。\n")
	return builder.String()
}

// ---------------------------------------------------------------- tool execution

func (s *Server) runAITool(ctx context.Context, current *store.User, call aiToolCall, loc *time.Location) (any, *aiAction, error) {
	if len(call.Function.Arguments) > 64<<10 {
		return nil, nil, fmt.Errorf("工具参数过大")
	}
	var args map[string]any
	if strings.TrimSpace(call.Function.Arguments) != "" {
		if err := json.Unmarshal([]byte(call.Function.Arguments), &args); err != nil {
			return nil, nil, fmt.Errorf("工具参数不是有效 JSON")
		}
	}
	switch call.Function.Name {
	case "list_lists":
		return s.aiListLists(ctx, current)
	case "list_tasks":
		return s.aiListTasks(ctx, current, args)
	case "get_stats":
		stats, err := s.store.ComputeTaskStats(ctx, current.ID, 30)
		if err != nil {
			return nil, nil, err
		}
		return stats, nil, nil
	case "create_task":
		return s.aiCreateTask(ctx, current, args, loc)
	case "update_task":
		return s.aiUpdateTask(ctx, current, args, loc)
	case "complete_task":
		id, err := aiInt64(args, "id")
		if err != nil {
			return nil, nil, err
		}
		args = map[string]any{"id": id, "completed": true}
		return s.aiUpdateTask(ctx, current, args, loc)
	case "delete_task":
		return s.aiDeleteTask(ctx, current, args)
	case "create_list":
		name, _ := args["name"].(string)
		color, _ := args["color"].(string)
		if strings.TrimSpace(color) == "" {
			color = "#4772fa"
		}
		list, err := s.store.CreateTaskList(ctx, current.ID, name, color)
		if err != nil {
			return nil, nil, err
		}
		return map[string]any{"id": list.ID, "name": list.Name}, &aiAction{Type: "create_list", Label: "已创建清单「" + list.Name + "」", ListID: list.ID}, nil
	default:
		return nil, nil, fmt.Errorf("未知工具：%s", call.Function.Name)
	}
}

func (s *Server) aiListLists(ctx context.Context, current *store.User) (any, *aiAction, error) {
	lists, err := s.store.ListTaskLists(ctx, current.ID)
	if err != nil {
		return nil, nil, err
	}
	out := make([]map[string]any, 0, len(lists))
	for _, list := range lists {
		out = append(out, map[string]any{"id": list.ID, "name": list.Name, "isInbox": list.IsInbox, "color": list.Color})
	}
	return map[string]any{"lists": out}, nil, nil
}

func (s *Server) aiListTasks(ctx context.Context, current *store.User, args map[string]any) (any, *aiAction, error) {
	view, _ := args["view"].(string)
	switch view {
	case "today", "next7", "completed":
	case "inbox", "all":
	default:
		view = "all"
	}
	query, _ := args["query"].(string)
	limit := 30
	if value, ok := args["limit"].(float64); ok && value > 0 {
		limit = int(value)
	}
	if limit > 100 {
		limit = 100
	}
	inbox, err := s.store.EnsureInbox(ctx, current.ID)
	if err != nil {
		return nil, nil, err
	}
	filter := store.TaskFilter{View: view, Query: strings.TrimSpace(query), Limit: limit}
	if view == "inbox" {
		filter.ListID = inbox.ID
	} else if listID, err := aiInt64(args, "listId"); err == nil && listID > 0 {
		filter.View = "list"
		filter.ListID = listID
	}
	tasks, err := s.store.ListTasks(ctx, current.ID, filter)
	if err != nil {
		return nil, nil, err
	}
	lists, _ := s.store.ListTaskLists(ctx, current.ID)
	names := make(map[int64]string, len(lists))
	for _, list := range lists {
		names[list.ID] = list.Name
	}
	rows := make([]map[string]any, 0, len(tasks))
	for _, task := range tasks {
		row := map[string]any{
			"id": task.ID, "title": task.Title, "list": names[task.ListID], "completed": task.Completed,
			"priority": task.Priority, "tags": []string(task.Tags), "recurrence": task.Recurrence,
			"reminderOffset":  task.ReminderOffset,
			"reminderOffsets": task.ReminderValues(),
		}
		if task.DueAt != nil {
			row["due"] = task.DueAt.Format(time.RFC3339)
			row["allDay"] = task.AllDay
		}
		if task.Notes != "" {
			row["notes"] = task.Notes
		}
		rows = append(rows, row)
	}
	return map[string]any{"tasks": rows, "count": len(rows)}, nil, nil
}

func aiInt64(args map[string]any, key string) (int64, error) {
	value, ok := args[key]
	if !ok {
		return 0, fmt.Errorf("缺少参数 %s", key)
	}
	switch typed := value.(type) {
	case float64:
		return int64(typed), nil
	case int64:
		return typed, nil
	case int:
		return int64(typed), nil
	case string:
		return strconv.ParseInt(typed, 10, 64)
	default:
		return 0, fmt.Errorf("参数 %s 必须是数字", key)
	}
}

func aiStringPointer(args map[string]any, key string) *string {
	if value, ok := args[key]; ok {
		if text, ok := value.(string); ok {
			return &text
		}
	}
	return nil
}

func applyAIReminders(task *store.Task, args map[string]any) error {
	if value, ok := args["reminderOffsets"]; ok {
		raw, ok := value.([]any)
		if !ok {
			return fmt.Errorf("reminderOffsets 必须是数组")
		}
		offsets := make([]int, 0, len(raw))
		for _, item := range raw {
			number, ok := item.(float64)
			if !ok {
				return fmt.Errorf("reminderOffsets 必须是整数数组")
			}
			offsets = append(offsets, int(number))
		}
		normalized, err := store.NormalizeReminderOffsets(offsets)
		if err != nil {
			return err
		}
		task.SetReminderValues(normalized)
		return nil
	}
	if value, ok := args["reminderOffset"].(float64); ok {
		if int(value) < -1 || int(value) > 10080 {
			return fmt.Errorf("提醒偏移必须在 -1 到 10080 分钟之间")
		}
		if int(value) < 0 {
			task.SetReminderValues(nil)
		} else {
			task.SetReminderValues([]int{int(value)})
		}
	}
	return nil
}

func (s *Server) aiCreateTask(ctx context.Context, current *store.User, args map[string]any, loc *time.Location) (any, *aiAction, error) {
	inbox, err := s.store.EnsureInbox(ctx, current.ID)
	if err != nil {
		return nil, nil, err
	}
	task := &store.Task{UserID: current.ID, ListID: inbox.ID, ReminderOffset: -1}
	if id, err := aiInt64(args, "listId"); err == nil && id > 0 {
		task.ListID = id
	}
	title, _ := args["title"].(string)
	text, _ := args["text"].(string)
	if strings.TrimSpace(title) == "" && strings.TrimSpace(text) != "" {
		parsed := taskparse.Parse(text, time.Now(), loc)
		task.Title = parsed.Title
		if task.DueAt == nil && parsed.Due != nil {
			utc := parsed.Due.UTC()
			task.DueAt = &utc
			task.AllDay = parsed.AllDay
		}
		task.Priority = parsed.Priority
		task.Tags = store.StringList(parsed.Tags)
	} else {
		task.Title = strings.TrimSpace(title)
	}
	if value, ok := args["due"].(string); ok && strings.TrimSpace(value) != "" {
		due, allDay, ok := parseTaskDue(value, loc.String(), task.AllDay)
		if !ok {
			return nil, nil, fmt.Errorf("到期时间格式无效")
		}
		task.DueAt = due
		task.AllDay = allDay
	}
	if value, ok := args["allDay"].(bool); ok {
		task.AllDay = value
	}
	if value, ok := args["priority"].(float64); ok {
		task.Priority = int(value)
	}
	if value, ok := args["notes"].(string); ok {
		task.Notes = value
	}
	if err := applyAIReminders(task, args); err != nil {
		return nil, nil, err
	}
	if value, ok := args["tags"].([]any); ok {
		tags := make([]string, 0, len(value))
		for _, tag := range value {
			if text, ok := tag.(string); ok {
				tags = append(tags, text)
			}
		}
		task.Tags = normalizeTaskTags(tags)
	}
	if value, ok := args["recurrence"].(string); ok {
		rule := strings.TrimSpace(strings.TrimPrefix(value, "RRULE:"))
		if rule != "" && !taskparse.ValidRule(rule) {
			return nil, nil, fmt.Errorf("重复规则无效")
		}
		task.Recurrence = rule
	}
	created, err := s.store.CreateTask(ctx, task)
	if err != nil {
		return nil, nil, err
	}
	if err := s.taskSync.PushTask(ctx, current.ID, created); err != nil {
		s.logger.Warn("push AI task", "task", created.ID, "error", err)
	}
	return map[string]any{"id": created.ID, "title": created.Title, "listId": created.ListID, "due": aiDue(created), "priority": created.Priority},
		&aiAction{Type: "create_task", Label: "已创建任务「" + created.Title + "」", TaskID: created.ID}, nil
}

func (s *Server) aiUpdateTask(ctx context.Context, current *store.User, args map[string]any, loc *time.Location) (any, *aiAction, error) {
	id, err := aiInt64(args, "id")
	if err != nil {
		return nil, nil, err
	}
	task, err := s.store.GetTask(ctx, current.ID, id)
	if err != nil {
		return nil, nil, fmt.Errorf("任务不存在")
	}
	previousRecurrence := task.Recurrence
	if value := aiStringPointer(args, "title"); value != nil {
		task.Title = strings.TrimSpace(*value)
	}
	if value, ok := args["listId"].(float64); ok && int64(value) > 0 {
		task.ListID = int64(value)
	}
	if value, ok := args["priority"].(float64); ok {
		task.Priority = int(value)
	}
	if value, ok := args["notes"].(string); ok {
		task.Notes = value
	}
	if err := applyAIReminders(task, args); err != nil {
		return nil, nil, err
	}
	if value, ok := args["allDay"].(bool); ok {
		task.AllDay = value
	}
	if value, ok := args["due"].(string); ok {
		due, allDay, ok := parseTaskDue(value, loc.String(), task.AllDay)
		if !ok {
			return nil, nil, fmt.Errorf("到期时间格式无效")
		}
		task.DueAt = due
		if strings.TrimSpace(value) != "" {
			task.AllDay = allDay
		} else {
			task.AllDay = false
		}
	}
	if value, ok := args["tags"].([]any); ok {
		tags := make([]string, 0, len(value))
		for _, tag := range value {
			if text, ok := tag.(string); ok {
				tags = append(tags, text)
			}
		}
		task.Tags = normalizeTaskTags(tags)
	}
	if value, ok := args["recurrence"].(string); ok {
		rule := strings.TrimSpace(strings.TrimPrefix(value, "RRULE:"))
		if rule != "" && !taskparse.ValidRule(rule) {
			return nil, nil, fmt.Errorf("重复规则无效")
		}
		task.Recurrence = rule
	}
	completed := false
	var completedOccurrence *time.Time
	if value, ok := args["completed"].(bool); ok {
		completed = value
		if value && task.Recurrence != "" && task.DueAt != nil {
			occurrence := *task.DueAt
			completedOccurrence = &occurrence
		}
		applyTaskCompletion(task, value)
	}
	if err := s.store.UpdateTask(ctx, task); err != nil {
		return nil, nil, err
	}
	if err := s.taskSync.PushTask(ctx, current.ID, task); err != nil {
		s.logger.Warn("push AI task", "task", task.ID, "error", err)
	}
	if previousRecurrence != "" && previousRecurrence != task.Recurrence {
		if err := s.taskSync.DeleteRecurrenceExceptions(ctx, current.ID, task); err != nil {
			s.logger.Warn("clear AI recurrence exceptions", "task", task.ID, "error", err)
		}
	}
	if completedOccurrence != nil {
		s.recordCompletedOccurrence(ctx, task, completedOccurrence)
	}
	label := "已更新任务「" + task.Title + "」"
	if completed {
		if !task.Completed && task.Recurrence != "" {
			label = "已完成「" + task.Title + "」本次，下次 " + aiDue(task)
		} else {
			label = "已完成任务「" + task.Title + "」"
		}
	}
	return map[string]any{"id": task.ID, "title": task.Title, "completed": task.Completed, "due": aiDue(task)},
		&aiAction{Type: "update_task", Label: label, TaskID: task.ID}, nil
}

func (s *Server) aiDeleteTask(ctx context.Context, current *store.User, args map[string]any) (any, *aiAction, error) {
	id, err := aiInt64(args, "id")
	if err != nil {
		return nil, nil, err
	}
	task, err := s.store.GetTask(ctx, current.ID, id)
	if err != nil {
		return nil, nil, fmt.Errorf("任务不存在")
	}
	if err := s.taskSync.DeleteTask(ctx, current.ID, task); err != nil {
		return nil, nil, err
	}
	if err := s.store.DeleteTask(ctx, current.ID, id); err != nil {
		return nil, nil, err
	}
	return map[string]any{"id": id, "deleted": true},
		&aiAction{Type: "delete_task", Label: "已删除任务「" + task.Title + "」", TaskID: id}, nil
}

func aiDue(task *store.Task) string {
	if task == nil || task.DueAt == nil {
		return ""
	}
	return task.DueAt.Format(time.RFC3339)
}
