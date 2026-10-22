<template>
  <section class="tw-ai">
    <header class="tw-ai-head">
      <div class="tw-ai-head-actions">
        <span v-if="settings.configured" class="tw-ai-model">{{ settings.model }}</span>
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

      <div v-if="sending" class="tw-ai-message assistant">
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
          <label class="tw-modal-label">
            Base URL
            <input v-model="settingsForm.baseUrl" class="tw-dialog-input" placeholder="https://api.openai.com/v1" />
          </label>
          <label class="tw-modal-label">
            模型
            <input v-model="settingsForm.model" class="tw-dialog-input" placeholder="gpt-4o-mini / deepseek-chat / llama3.1" />
          </label>
          <label class="tw-modal-label">
            API Key
            <input
              v-model="settingsForm.apiKey"
              class="tw-dialog-input"
              type="password"
              autocomplete="new-password"
              :placeholder="settings.hasKey ? '已保存，留空表示不修改' : '本地模型可留空'"
            />
          </label>
          <label v-if="settings.hasKey" class="tw-check-label">
            <input v-model="settingsForm.clearKey" type="checkbox" />
            清除已保存的 API Key
          </label>
          <div class="tw-ai-provider-hint">
            <strong>常用配置</strong>
            <span>OpenAI：https://api.openai.com/v1 · gpt-4o-mini</span>
            <span>DeepSeek：https://api.deepseek.com/v1 · deepseek-chat</span>
            <span>Ollama：http://127.0.0.1:11434/v1 · 本地模型名</span>
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
import { nextTick, onMounted, reactive, ref, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { AIChatMessage, AISettings } from '../../types'
import { fetchAISettings, saveAISettings, sendAIChat } from '../../tasks-api'
import { browserTimezone } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const emit = defineEmits<{ (event: 'tasks-changed'): void }>()

const STORAGE_KEY = 'caldav-task-ai-messages'
const quickPrompts = ['今天有哪些任务？', '创建一个明天下午 3 点的任务', '总结一下当前任务情况', '把逾期任务顺延到今天']

const messages = ref<AIChatMessage[]>([])
const input = ref('')
const sending = ref(false)
const settings = ref<AISettings>({ baseUrl: '', model: '', hasKey: false, configured: false })
const settingsOpen = ref(false)
const settingsBusy = ref(false)
const settingsForm = reactive({ baseUrl: '', model: '', apiKey: '', clearKey: false })
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
    settingsForm.baseUrl = settings.value.baseUrl
    settingsForm.model = settings.value.model
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
  scrollBottom()
  try {
    const history = messages.value
      .filter((item) => !item.error)
      .slice(-20)
      .map((item) => ({ role: item.role, content: item.content }))
    const reply = await sendAIChat(history, browserTimezone())
    const actions = reply.actions.filter((action) => !reply.message.includes(action.label))
    messages.value.push({ role: 'assistant', content: reply.message, actions })
    if (reply.actions.length) emit('tasks-changed')
  } catch (error) {
    messages.value.push({
      role: 'assistant',
      content: error instanceof Error ? error.message : 'AI 请求失败',
      error: true,
    })
  } finally {
    sending.value = false
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

function openSettings() {
  settingsForm.baseUrl = settings.value.baseUrl
  settingsForm.model = settings.value.model
  settingsForm.apiKey = ''
  settingsForm.clearKey = false
  settingsOpen.value = true
}

async function saveSettings() {
  if (!settingsForm.baseUrl.trim() || !settingsForm.model.trim()) {
    Message.warning('请填写 Base URL 和模型名称')
    return
  }
  settingsBusy.value = true
  try {
    settings.value = await saveAISettings({
      baseUrl: settingsForm.baseUrl.trim(),
      model: settingsForm.model.trim(),
      apiKey: settingsForm.apiKey.trim() || undefined,
      clearKey: settingsForm.clearKey,
    })
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

onMounted(() => {
  loadLocal()
  void loadSettings()
  initSpeech()
  scrollBottom()
})
</script>
