<template>
  <section class="tw-ai">
    <header class="tw-ai-head">
      <div class="tw-ai-head-actions">
        <a-select
          v-if="settings.configured && chatModelOptions.length > 1"
          v-model="chatModel"
          class="tw-ai-chat-model"
          size="small"
          title="选择对话模型"
          @change="onChatModelChange"
        >
          <a-optgroup v-if="recentChatModels.length" label="最近使用">
            <a-option v-for="model in recentChatModels" :key="model" :value="model">{{ modelOptionLabel(model) }}</a-option>
          </a-optgroup>
          <a-optgroup v-if="otherChatModels.length" label="全部模型">
            <a-option v-for="model in otherChatModels" :key="model" :value="model">{{ modelOptionLabel(model) }}</a-option>
          </a-optgroup>
        </a-select>
        <span v-else-if="settings.configured" class="tw-ai-model">{{ chatModel || settings.model }}</span>
        <button class="tw-icon-button" title="清空对话" @click="clearChat">
          <TaskIcon name="trash" :size="16" />
        </button>
        <button class="tw-icon-button" title="AI 设置" @click="openSettings">
          <TaskIcon name="settings" :size="16" />
        </button>
      </div>
    </header>

    <div v-if="!settings.configured" class="tw-ai-setup">
      <div>
        <strong>尚未配置 AI 模型</strong>
        <p>支持 OpenAI 兼容接口，例如 OpenAI、DeepSeek、Ollama、vLLM。配置后任务数据只会发送到你填写的服务。</p>
      </div>
      <button class="tw-primary-button" @click="openSettings">配置模型</button>
    </div>

    <div ref="scrollRef" class="tw-ai-scroll">
      <div v-if="!messages.length" class="tw-ai-hero">
        <span class="tw-ai-hero-icon"><TaskIcon name="sparkles" :size="34" /></span>
        <h3>今天想完成什么？</h3>
        <p>我可以读取你的任务和清单，并在你确认后创建、修改或完成它们。</p>
        <div class="tw-ai-prompts">
          <button v-for="prompt in quickPrompts" :key="prompt" @click="send(prompt)">{{ prompt }}</button>
        </div>
      </div>

      <div v-for="(message, index) in messages" :key="index" class="tw-ai-message" :class="message.role">
        <div class="tw-ai-bubble" :class="{ error: message.error }">
          <p>{{ message.content }}</p>
          <div v-if="message.actions?.length" class="tw-ai-actions">
            <span v-for="action in message.actions" :key="action.label">
              <TaskIcon name="check" :size="12" />
              {{ action.label }}
            </span>
          </div>
        </div>
      </div>

      <div v-if="sending && !streaming" class="tw-ai-message assistant">
        <div class="tw-ai-bubble tw-ai-thinking">
          <i /><i /><i />
        </div>
      </div>
    </div>

    <form class="tw-ai-input" @submit.prevent="send()">
      <textarea
        ref="inputRef"
        v-model="input"
        rows="1"
        maxlength="4000"
        placeholder="例如：明天下午 3 点提醒我和张三开会，并创建一个任务"
        @input="growInput"
        @keydown.enter="onEnter"
      />
      <button
        v-if="speechSupported"
        class="tw-icon-button"
        type="button"
        :class="{ active: listening }"
        title="语音输入"
        @click="startVoice"
      >
        <TaskIcon name="mic" :size="17" />
      </button>
      <button class="tw-ai-send" type="submit" :disabled="!input.trim() || sending" title="发送">
        <TaskIcon name="send" :size="16" />
      </button>
    </form>
    <p class="tw-ai-note">AI 可能出错，请核查重要信息。对话内容会发送到你配置的模型服务。</p>

    <div v-if="settingsOpen" class="tw-dialog-scrim" @click.self="settingsOpen = false">
      <div class="tw-dialog" role="dialog" aria-modal="true" aria-label="AI 设置" @keydown.esc="settingsOpen = false">
        <header class="tw-dialog-head">
          <h2>AI 设置</h2>
          <button class="tw-icon-button" title="关闭" @click="settingsOpen = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body tw-ai-settings">
          <div class="tw-modal-label">
            服务商
            <a-select v-model="settingsForm.provider" class="tw-field-select" @change="onProviderChange">
              <a-option v-for="option in providerOptions" :key="option.value" :value="option.value">{{ option.label }}</a-option>
            </a-select>
          </div>
          <div class="tw-modal-label">
            API Key
            <a-input-password
              v-model="settingsForm.apiKey"
              class="tw-dialog-input"
              autocomplete="new-password"
              :placeholder="settings.hasKey ? '已保存，留空表示不修改' : '本地模型可留空'"
              @blur="onKeyBlur"
            />
          </div>
          <div class="tw-modal-label">
            接口地址（Base URL）
            <a-input v-model="settingsForm.baseUrl" class="tw-dialog-input" placeholder="选择服务商后自动填充，也可手动修改" @change="models = []" />
          </div>
          <div class="tw-modal-label">
            模型
            <div class="tw-ai-model-row">
              <a-input
                v-model="settingsForm.model"
                class="tw-dialog-input"
                placeholder="获取模型后选择，或手动填写"
                @keydown.enter.prevent
              />
              <button class="tw-ai-model-fetch" type="button" :disabled="modelsLoading || !settingsForm.baseUrl.trim()" @click="loadModels">
                {{ modelsLoading ? '获取中…' : '获取模型' }}
              </button>
            </div>
            <span v-if="models.length" class="tw-ai-model-count">已获取 {{ models.length }} 个模型，点击下方列表选择或直接手动填写</span>
            <div v-if="models.length" class="tw-ai-model-picker">
              <a-input v-model="modelFilter" class="tw-ai-model-filter" placeholder="筛选模型…" />
              <div class="tw-ai-model-options">
                <button
                  v-for="model in filteredModels"
                  :key="model"
                  type="button"
                  class="tw-ai-model-option"
                  :class="{ active: settingsForm.model === model, warn: modelProfile(model).nonChat }"
                  @click="settingsForm.model = model"
                >
                  <span class="tw-ai-model-option-name">{{ model }}</span>
                  <span class="tw-ai-model-option-tags">
                    <em v-if="modelLatencyLabel(model)" class="latency">{{ modelLatencyLabel(model) }}</em>
                    <em v-if="(settings.recentModels || []).includes(model)" class="recent">最近</em>
                    <em v-if="modelProfile(model).recommended" class="recommended">推荐</em>
                    <em v-for="label in modelCapabilityLabels(model)" :key="label" :class="{ warn: label.includes('不是对话') }">{{ label }}</em>
                  </span>
                </button>
                <p v-if="!filteredModels.length" class="tw-ai-model-empty">没有匹配的模型</p>
              </div>
            </div>
            <p v-if="selectedModelProfile" class="tw-ai-model-caps">
              <span v-for="label in selectedModelCapabilities" :key="label" :class="{ warn: selectedModelProfile.nonChat }">{{ label }}</span>
              <small v-if="!selectedModelCapabilities.length">未识别到能力标签</small>
            </p>
            <div class="tw-ai-model-test">
              <button class="tw-ai-model-test-btn" type="button" :disabled="testBusy || !settingsForm.model.trim() || !settingsForm.baseUrl.trim()" @click="testModel('chat')">
                {{ testBusy ? '测试中…' : '测试连接' }}
              </button>
              <button class="tw-ai-model-test-btn" type="button" :disabled="testBusy || !settingsForm.model.trim() || !settingsForm.baseUrl.trim()" @click="testModel('tools')">
                测试工具调用
              </button>
              <span v-if="testResult" :class="testResult.ok ? (testResult.warn ? 'warn' : 'ok') : 'error'">{{ testResult.text }}</span>
            </div>
          </div>
          <a-checkbox v-if="settings.hasKey" v-model="settingsForm.clearKey" class="tw-check-label">清除已保存的 API Key</a-checkbox>
          <div class="tw-ai-provider-hint">
            <strong>提示</strong>
            <span>选择服务商会自动填充接口地址；填写 API Key 后可获取并选择模型。</span>
            <span>接口需兼容 OpenAI Chat Completions 并支持 tools/function calling。</span>
          </div>
          <p class="tw-modal-note">
            任务数据、清单和对话会发送到该接口。API Key 保存在本地 SQLite 中，仅管理员可读取设置接口。
          </p>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="settingsOpen = false">取消</button>
          <button class="tw-dialog-ok" :disabled="settingsBusy" @click="saveSettings">
            {{ settingsBusy ? '保存中…' : '保存' }}
          </button>
        </footer>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { AIChatMessage, AIChatReply, AISettings } from '../../types'
import { fetchAIModels, fetchAISettings, saveAISettings, streamAIChat, testAIModel } from '../../tasks-api'
import { browserTimezone } from '../../tasks-api'
import { modelCapabilityLabels, modelOptionLabel, modelProfile, sortModels } from '../../ai-models'
import TaskIcon from './TaskIcon.vue'

const emit = defineEmits<{ (event: 'tasks-changed'): void }>()

const STORAGE_KEY = 'caldav-task-ai-messages'
const CHAT_MODEL_KEY = 'caldav-task-ai-model'
const quickPrompts = ['今天有哪些任务？', '创建一个明天下午 3 点的任务', '总结一下当前任务情况', '把逾期任务顺延到今天']

const messages = ref<AIChatMessage[]>([])
const input = ref('')
const sending = ref(false)
const streaming = ref(false)
const settings = ref<AISettings>({ provider: 'custom', baseUrl: '', model: '', models: [], recentModels: [], modelStats: {}, hasKey: false, configured: false })
const settingsOpen = ref(false)
const settingsBusy = ref(false)
const settingsForm = reactive({ provider: 'custom', baseUrl: '', model: '', apiKey: '', clearKey: false })
const models = ref<string[]>([])
const modelsLoading = ref(false)
const modelsFetched = ref(false)
const modelFilter = ref('')
const testBusy = ref(false)
const testResult = ref<{ ok: boolean; warn?: boolean; text: string } | null>(null)
const chatModel = ref('')
try {
  chatModel.value = localStorage.getItem(CHAT_MODEL_KEY) || ''
} catch {
  /* ignore */
}

const chatModelOptions = computed(() => {
  const list = [settings.value.model, ...(settings.value.models || []), chatModel.value].filter(Boolean)
  return sortModels(list)
})
const recentChatModels = computed(() => {
  const available = new Set(chatModelOptions.value)
  return (settings.value.recentModels || []).filter((model) => available.has(model))
})
const otherChatModels = computed(() => chatModelOptions.value.filter((model) => !recentChatModels.value.includes(model)))
const selectedModelProfile = computed(() => settingsForm.model ? modelProfile(settingsForm.model) : null)
const selectedModelCapabilities = computed(() => settingsForm.model ? modelCapabilityLabels(settingsForm.model) : [])
const filteredModels = computed(() => {
  const keyword = modelFilter.value.trim().toLowerCase()
  return keyword ? models.value.filter((model) => model.toLowerCase().includes(keyword)) : models.value
})

const providerOptions = [
  { value: 'openai', label: 'OpenAI', baseUrl: 'https://api.openai.com/v1', model: 'gpt-4o-mini' },
  { value: 'deepseek', label: 'DeepSeek', baseUrl: 'https://api.deepseek.com/v1', model: 'deepseek-chat' },
  { value: 'moonshot', label: 'Moonshot', baseUrl: 'https://api.moonshot.cn/v1', model: 'moonshot-v1-8k' },
  { value: 'zhipu', label: '智谱 GLM', baseUrl: 'https://open.bigmodel.cn/api/paas/v4', model: 'glm-4-flash' },
  { value: 'qwen', label: '通义千问', baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1', model: 'qwen-plus' },
  { value: 'siliconflow', label: 'SiliconFlow', baseUrl: 'https://api.siliconflow.cn/v1', model: 'Qwen/Qwen2.5-7B-Instruct' },
  { value: 'groq', label: 'Groq', baseUrl: 'https://api.groq.com/openai/v1', model: 'llama-3.1-8b-instant' },
  { value: 'openrouter', label: 'OpenRouter', baseUrl: 'https://openrouter.ai/api/v1', model: '' },
  { value: 'ollama', label: 'Ollama', baseUrl: 'http://127.0.0.1:11434/v1', model: 'llama3.1' },
  { value: 'custom', label: '自定义 / 兼容接口', baseUrl: '', model: '' },
]
const scrollRef = ref<HTMLElement | null>(null)
const inputRef = ref<HTMLTextAreaElement | null>(null)
const speechSupported = ref(false)
const listening = ref(false)
let recognition: any = null

function loadLocal() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return
    const parsed = JSON.parse(raw) as AIChatMessage[]
    if (Array.isArray(parsed)) {
      messages.value = parsed
        .filter((item) => item && (item.role === 'user' || item.role === 'assistant') && typeof item.content === 'string')
        .slice(-40)
    }
  } catch {
    /* ignore */
  }
}

function saveLocal() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(messages.value.slice(-40)))
  } catch {
    /* ignore */
  }
}

async function loadSettings() {
  try {
    settings.value = await fetchAISettings()
    settings.value.models = settings.value.models || []
    settings.value.recentModels = settings.value.recentModels || []
    settings.value.modelStats = settings.value.modelStats || {}
    settingsForm.provider = normalizeProvider(settings.value.provider, settings.value.baseUrl)
    settingsForm.baseUrl = settings.value.baseUrl
    settingsForm.model = settings.value.model
    const availableModels = [settings.value.model, ...(settings.value.models || [])]
    if (!chatModel.value || !availableModels.includes(chatModel.value)) {
      chatModel.value = settings.value.model
      onChatModelChange()
    }
  } catch {
    /* ignore */
  }
}

function scrollBottom() {
  void nextTick(() => {
    if (scrollRef.value) scrollRef.value.scrollTop = scrollRef.value.scrollHeight
  })
}

function growInput() {
  const element = inputRef.value
  if (!element) return
  element.style.height = 'auto'
  element.style.height = `${Math.min(element.scrollHeight, 120)}px`
}

function onEnter(event: KeyboardEvent) {
  if (event.isComposing) return
  if (event.shiftKey) return
  event.preventDefault()
  void send()
}

async function send(text?: string) {
  const content = (text ?? input.value).trim()
  if (!content || sending.value) return
  if (!settings.value.configured) {
    Message.warning('请先配置 AI 模型')
    openSettings()
    return
  }
  messages.value.push({ role: 'user', content })
  input.value = ''
  await nextTick()
  growInput()
  sending.value = true
  streaming.value = false
  scrollBottom()
  let assistantIndex = -1
  const ensureAssistant = () => {
    if (assistantIndex < 0) {
      messages.value.push({ role: 'assistant', content: '', actions: [] })
      assistantIndex = messages.value.length - 1
    }
    return messages.value[assistantIndex]
  }
  const applyReply = (reply: AIChatReply) => {
    if (reply.recentModels) settings.value.recentModels = reply.recentModels
    if (reply.modelStats) settings.value.modelStats = reply.modelStats
    if (reply.fallbackFrom) {
      chatModel.value = reply.model
      onChatModelChange()
      Message.warning(`模型 ${reply.fallbackFrom} 调用失败，已自动切换到 ${reply.model}`)
    }
    const message = ensureAssistant()
    if (!message.content.trim() && reply.message) message.content = reply.message
    const actions = reply.actions.filter((action) => !message.content.includes(action.label))
    if (actions.length) message.actions = actions
    if (reply.actions.length) emit('tasks-changed')
  }
  const history = messages.value
    .filter((item) => !item.error && item.content.trim())
    .slice(-20)
    .map((item) => ({ role: item.role, content: item.content }))
  try {
    await streamAIChat(
      history,
      browserTimezone(),
      chatModel.value || settings.value.model,
      (text) => {
        streaming.value = true
        const message = ensureAssistant()
        message.content += text
        scrollBottom()
      },
      applyReply,
    )
  } catch (error) {
    messages.value.push({
      role: 'assistant',
      content: error instanceof Error ? error.message : (streaming.value ? 'AI 流式响应中断' : 'AI 请求失败'),
      error: true,
    })
  } finally {
    sending.value = false
    streaming.value = false
    scrollBottom()
  }
}

function clearChat() {
  messages.value = []
  try {
    localStorage.removeItem(STORAGE_KEY)
  } catch {
    /* ignore */
  }
}

function detectProvider(baseUrl: string) {
  return providerOptions.find((option) => option.value !== 'custom' && option.baseUrl && baseUrl.startsWith(option.baseUrl))?.value || 'custom'
}

function normalizeProvider(provider: string, baseUrl: string) {
  return providerOptions.some((option) => option.value === provider) ? provider : detectProvider(baseUrl)
}

function openSettings() {
  settingsForm.provider = normalizeProvider(settings.value.provider, settings.value.baseUrl)
  settingsForm.baseUrl = settings.value.baseUrl
  settingsForm.model = settings.value.model
  settingsForm.apiKey = ''
  settingsForm.clearKey = false
  models.value = sortModels(settings.value.models || [])
  modelsFetched.value = models.value.length > 0
  modelFilter.value = ''
  testResult.value = null
  settingsOpen.value = true
}

function onProviderChange() {
  const preset = providerOptions.find((option) => option.value === settingsForm.provider)
  if (!preset) return
  if (preset.baseUrl) settingsForm.baseUrl = preset.baseUrl
  if (preset.model) settingsForm.model = preset.model
  models.value = []
  modelsFetched.value = false
  testResult.value = null
}

async function loadModels() {
  if (modelsLoading.value || !settingsForm.baseUrl.trim()) return
  modelsLoading.value = true
  try {
    const data = await fetchAIModels({
      provider: settingsForm.provider,
      baseUrl: settingsForm.baseUrl.trim(),
      apiKey: settingsForm.apiKey.trim() || undefined,
    })
    models.value = sortModels(data.models)
    settings.value.models = [...models.value]
    modelsFetched.value = true
    if (!settingsForm.model.trim() && models.value.length) settingsForm.model = models.value[0]
    if (!data.models.length) Message.warning('服务商没有返回可用模型，可手动填写模型名称')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '获取模型失败')
  } finally {
    modelsLoading.value = false
  }
}

function onKeyBlur() {
  if (!modelsFetched.value && settingsForm.apiKey.trim() && settingsForm.baseUrl.trim()) {
    void loadModels()
  }
}

async function testModel(mode: 'chat' | 'tools' = 'chat') {
  if (testBusy.value || !settingsForm.model.trim() || !settingsForm.baseUrl.trim()) return
  testBusy.value = true
  testResult.value = null
  try {
    const result = await testAIModel({
      provider: settingsForm.provider,
      baseUrl: settingsForm.baseUrl.trim(),
      apiKey: settingsForm.apiKey.trim() || undefined,
      model: settingsForm.model.trim(),
      mode,
    })
    if (mode === 'tools') {
      testResult.value = result.toolsSupported
        ? { ok: true, text: `工具调用成功 · ${result.latencyMs}ms` }
        : { ok: true, warn: true, text: '模型未发起工具调用（可能不支持）' }
    } else {
      testResult.value = { ok: true, text: `连接成功 · ${result.latencyMs}ms · ${result.model}` }
    }
  } catch (error) {
    testResult.value = { ok: false, text: error instanceof Error ? error.message : '连接测试失败' }
  } finally {
    testBusy.value = false
  }
}

function modelLatencyLabel(model: string) {
  const stat = settings.value.modelStats?.[model]
  if (!stat || !stat.calls) return ''
  return `~${Math.round(stat.totalMs / stat.calls)}ms`
}

function onChatModelChange() {
  try {
    localStorage.setItem(CHAT_MODEL_KEY, chatModel.value)
  } catch {
    /* ignore */
  }
}

async function saveSettings() {
  if (!settingsForm.baseUrl.trim() || !settingsForm.model.trim()) {
    Message.warning('请填写 Base URL 和模型名称')
    return
  }
  settingsBusy.value = true
  try {
    settings.value = await saveAISettings({
      provider: settingsForm.provider,
      baseUrl: settingsForm.baseUrl.trim(),
      model: settingsForm.model.trim(),
      apiKey: settingsForm.apiKey.trim() || undefined,
      clearKey: settingsForm.clearKey,
    })
    settings.value.models = settings.value.models || []
    settings.value.recentModels = settings.value.recentModels || []
    settings.value.modelStats = settings.value.modelStats || {}
    chatModel.value = settings.value.model
    onChatModelChange()
    settingsOpen.value = false
    Message.success('AI 设置已保存')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存失败')
  } finally {
    settingsBusy.value = false
  }
}

function initSpeech() {
  const ctor = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
  if (!ctor) return
  speechSupported.value = true
  recognition = new ctor()
  recognition.lang = 'zh-CN'
  recognition.interimResults = false
  recognition.continuous = false
  recognition.onresult = (event: any) => {
    const transcript = event.results?.[0]?.[0]?.transcript || ''
    if (transcript) {
      input.value = `${input.value}${input.value ? ' ' : ''}${transcript}`
      void nextTick(growInput)
    }
    listening.value = false
  }
  recognition.onerror = (event: any) => {
    listening.value = false
    if (event.error !== 'aborted' && event.error !== 'no-speech') {
      Message.warning('语音识别失败，请检查浏览器权限')
    }
  }
  recognition.onend = () => {
    listening.value = false
  }
}

function startVoice() {
  if (!recognition) return
  if (listening.value) {
    recognition.stop()
    listening.value = false
    return
  }
  try {
    recognition.start()
    listening.value = true
  } catch {
    Message.warning('无法启动语音输入')
  }
}

watch(messages, saveLocal, { deep: true })
watch(() => [settingsForm.provider, settingsForm.baseUrl, settingsForm.model], () => { testResult.value = null })

onMounted(() => {
  loadLocal()
  void loadSettings()
  initSpeech()
  scrollBottom()
})
</script>
