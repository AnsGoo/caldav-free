<template>
  <section class="tw-summary">
    <div class="tw-summary-main">
      <header class="tw-summary-top">
        <span class="tw-summary-count">
          已完成 {{ data?.counts.completed || 0 }} · 未完成 {{ data?.counts.open || 0 }}
        </span>
        <div class="tw-summary-top-actions">
          <button class="tw-icon-button" title="历史文档" @click="historyOpen = !historyOpen">
            <TaskIcon name="note" :size="17" />
          </button>
          <button class="tw-icon-button" title="显示设置" @click="asideOpen = !asideOpen">
            <TaskIcon name="settings" :size="17" />
          </button>
        </div>

        <div v-if="historyOpen" class="tw-summary-history" @click.stop>
          <header>
            <span>历史文档</span>
            <button class="tw-icon-button" title="关闭" @click="historyOpen = false">
              <TaskIcon name="close" :size="14" />
            </button>
          </header>
          <div v-if="history.length" class="tw-summary-docs">
            <button v-for="doc in history" :key="doc.id" class="tw-summary-doc" @click="loadDocument(doc)">
              <span>{{ doc.name }}</span>
              <small>{{ formatDocTime(doc.createdAt) }}</small>
              <i class="tw-icon-button" title="删除" @click.stop="removeHistory(doc.id)">
                <TaskIcon name="trash" :size="13" />
              </i>
            </button>
          </div>
          <p v-else class="tw-summary-empty">没有历史文档</p>
        </div>
      </header>

      <div class="tw-summary-toolbar" @mousedown.prevent>
        <button title="标题" @click="exec('formatBlock', 'h3')"><b>H</b></button>
        <button title="加粗" @click="exec('bold')"><b>B</b></button>
        <button title="高亮" class="tw-md-highlight" @click="highlight">A</button>
        <button title="插入复选框" @click="insertChecklist">☑</button>
        <button title="无序列表" @click="exec('insertUnorderedList')">•</button>
        <button title="有序列表" @click="exec('insertOrderedList')">1.</button>
        <button title="减少缩进" @click="exec('outdent')">⇤</button>
        <button title="增加缩进" @click="exec('indent')">⇥</button>
        <span class="tw-md-divider" />
        <button title="斜体" @click="exec('italic')"><i>I</i></button>
        <button title="下划线" @click="exec('underline')"><u>U</u></button>
        <button title="删除线" @click="exec('strikeThrough')"><s>S</s></button>
        <label class="tw-md-color" title="文字颜色">
          <span>A</span>
          <input type="color" value="#4772fa" @input="setColor(($event.target as HTMLInputElement).value)" />
        </label>
        <button title="链接" @click="addLink">🔗</button>
        <button title="行内代码" @click="exec('formatBlock', 'pre')">&lt;/&gt;</button>
        <button title="引用" @click="exec('formatBlock', 'blockquote')">“”</button>
        <span class="tw-md-divider" />
        <button title="刷新摘要" @click="load"><TaskIcon name="refresh" :size="15" /></button>
      </div>

      <div class="tw-summary-editor-wrap">
        <div v-if="loading || optimizing" class="tw-summary-loading">{{ optimizing ? 'AI 优化中…' : '生成摘要中…' }}</div>
        <div ref="editorRef" class="tw-summary-editor" contenteditable="true" spellcheck="false" @input="onEdit" />
      </div>

      <footer class="tw-summary-foot">
        <div class="tw-summary-save">
          <button class="tw-summary-foot-btn" @click="saveMenuOpen = !saveMenuOpen">
            <TaskIcon name="download" :size="15" />
            保存为
          </button>
          <div v-if="saveMenuOpen" class="tw-summary-menu">
            <button @click="saveHistory">保存到历史</button>
            <button @click="exportHtml">导出 HTML</button>
            <button @click="printSummary">打印 / PDF</button>
            <button @click="emailSummary">发送邮件</button>
          </div>
        </div>
        <button class="tw-summary-foot-btn" @click="copySummary">
          <TaskIcon name="copy" :size="15" />
          复制
        </button>
      </footer>
    </div>

    <aside class="tw-summary-aside" :class="{ 'is-open': asideOpen }">
      <section class="tw-summary-panel">
        <header class="tw-summary-panel-head">
          <h3>模板</h3>
          <button class="tw-icon-button" title="保存当前为模板" @click="saveAsTemplate">
            <TaskIcon name="plus" :size="15" />
          </button>
        </header>
        <div v-if="templates.length" class="tw-summary-templates">
          <button v-for="item in templates" :key="item.id" @click="loadTemplate(item)">
            {{ item.name }}
          </button>
        </div>
        <p v-else class="tw-summary-hint">把当前摘要保存为模板，下次可直接套用。</p>
      </section>

      <section class="tw-summary-panel">
        <header class="tw-summary-panel-head"><h3>筛选</h3></header>
        <label class="tw-summary-field">
          <span>日期</span>
          <select v-model="preset">
            <option v-for="option in dateOptions" :key="option.value" :value="option.value">{{ option.label }}</option>
          </select>
        </label>
        <div v-if="preset === 'custom'" class="tw-summary-custom-dates">
          <input v-model="customFrom" type="date" />
          <span>→</span>
          <input v-model="customTo" type="date" />
        </div>
        <label class="tw-summary-field">
          <span>清单</span>
          <select v-model.number="listId">
            <option :value="0">所有清单</option>
            <option v-for="list in lists" :key="list.id" :value="list.id">{{ list.name }}</option>
          </select>
        </label>
        <label class="tw-summary-field">
          <span>状态</span>
          <select v-model="status">
            <option value="all">所有状态</option>
            <option value="completed">已完成</option>
            <option value="open">未完成</option>
          </select>
        </label>
        <label class="tw-summary-field">
          <span>优先级</span>
          <select v-model.number="priority">
            <option :value="0">所有优先级</option>
            <option :value="3">高优先级</option>
            <option :value="2">中优先级</option>
            <option :value="1">低优先级</option>
          </select>
        </label>
        <label class="tw-summary-field">
          <span>标签</span>
          <select v-model="tag">
            <option value="">所有标签</option>
            <option v-for="item in tags" :key="item.name" :value="item.name">#{{ item.name }}</option>
          </select>
        </label>
      </section>

      <section class="tw-summary-panel">
        <header class="tw-summary-panel-head"><h3>显示设置</h3></header>
        <label class="tw-summary-field">
          <span>分组</span>
          <select v-model="groupBy">
            <option value="status">按完成状态</option>
            <option value="list">按清单</option>
            <option value="completedAt">按完成时间</option>
            <option value="due">按任务时间</option>
            <option value="tag">按标签</option>
            <option value="priority">按优先级</option>
          </select>
        </label>
        <div class="tw-summary-fields">
          <div class="tw-summary-fields-head">
            <span>显示内容</span>
            <small>{{ fields.length }} 项</small>
          </div>
          <div class="tw-summary-field-chips">
            <button
              v-for="option in displayOptions"
              :key="option.value"
              class="tw-summary-chip"
              :class="{ active: fields.includes(option.value) }"
              @click="toggleField(option.value)"
            >
              {{ option.label }}
            </button>
          </div>
        </div>
        <label class="tw-summary-toggle">
          <span>下一周期任务</span>
          <input v-model="includeNext" type="checkbox" />
        </label>
        <p class="tw-summary-hint">“下一周期任务”会追加当前范围之后同等长度时间段内到期的未完成任务。</p>
        <label class="tw-summary-toggle">
          <span>内容优化 <em class="tw-ai-badge">AI</em></span>
          <input v-model="optimize" type="checkbox" :disabled="!aiConfigured" />
        </label>
        <p v-if="aiConfigured" class="tw-summary-hint">开启后会调用 AI 重写当前摘要，内容会发送到配置的模型服务。</p>
        <p v-else class="tw-summary-hint">需先在 AI 助手中配置模型才能启用内容优化。</p>
      </section>

      <button class="tw-summary-aside-close" @click="asideOpen = false">收起设置</button>
    </aside>
  </section>
</template>

<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { SummaryDocument, SummaryTask, TaskList, TaskSummaryData, TaskTagCount } from '../../types'
import { createSummaryDocument, deleteSummaryDocument, fetchAISettings, fetchSummaryDocuments, fetchTaskSummary, optimizeSummary } from '../../tasks-api'
import { PRIORITIES } from '../../tasks-utils'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ lists: TaskList[]; tags: TaskTagCount[] }>()

type Preset = 'today' | 'tomorrow' | 'yesterday' | 'week' | 'nextWeek' | 'lastWeek' | 'month' | 'lastMonth' | 'custom'
type GroupBy = 'status' | 'list' | 'completedAt' | 'due' | 'tag' | 'priority'

const dateOptions: Array<{ value: Preset; label: string }> = [
  { value: 'today', label: '今天' },
  { value: 'tomorrow', label: '明天' },
  { value: 'yesterday', label: '昨天' },
  { value: 'week', label: '本周' },
  { value: 'nextWeek', label: '下周' },
  { value: 'lastWeek', label: '上周' },
  { value: 'month', label: '本月' },
  { value: 'lastMonth', label: '上月' },
  { value: 'custom', label: '自定义' },
]

const displayOptions = [
  { value: 'completedAt', label: '完成时间' },
  { value: 'due', label: '任务时间' },
  { value: 'tags', label: '标签' },
  { value: 'list', label: '所属清单' },
  { value: 'priority', label: '优先级' },
  { value: 'details', label: '详细内容' },
]

const today = new Date()
const defaultFrom = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-01`
const defaultTo = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

const preset = ref<Preset>('week')
const customFrom = ref(defaultFrom)
const customTo = ref(defaultTo)
const listId = ref(0)
const status = ref('all')
const priority = ref(0)
const tag = ref('')
const includeNext = ref(false)
const groupBy = ref<GroupBy>('status')
const fields = ref<string[]>(['completedAt'])

const data = ref<TaskSummaryData | null>(null)
const loading = ref(false)
const editorRef = ref<HTMLElement | null>(null)
const asideOpen = ref(false)
const historyOpen = ref(false)
const saveMenuOpen = ref(false)

const history = ref<SummaryDocument[]>([])
const templates = ref<SummaryDocument[]>([])
const aiConfigured = ref(false)
const optimize = ref(false)
const optimizing = ref(false)

let loadTimer: ReturnType<typeof setTimeout> | undefined

function startOfDay(value: Date) {
  return new Date(value.getFullYear(), value.getMonth(), value.getDate())
}

function addDays(value: Date, days: number) {
  const copy = new Date(value)
  copy.setDate(copy.getDate() + days)
  return copy
}

function parseDateInput(value: string, fallback: Date) {
  const [year, month, day] = value.split('-').map(Number)
  if (!year || !month || !day) return fallback
  return new Date(year, month - 1, day)
}

function computeRange() {
  const now = new Date()
  const day = startOfDay(now)
  switch (preset.value) {
    case 'today':
      return { from: day, to: addDays(day, 1) }
    case 'tomorrow':
      return { from: addDays(day, 1), to: addDays(day, 2) }
    case 'yesterday':
      return { from: addDays(day, -1), to: day }
    case 'week': {
      const from = addDays(day, -day.getDay())
      return { from, to: addDays(from, 7) }
    }
    case 'nextWeek': {
      const from = addDays(day, -day.getDay() + 7)
      return { from, to: addDays(from, 7) }
    }
    case 'lastWeek': {
      const from = addDays(day, -day.getDay() - 7)
      return { from, to: addDays(from, 7) }
    }
    case 'month': {
      const from = new Date(day.getFullYear(), day.getMonth(), 1)
      return { from, to: new Date(day.getFullYear(), day.getMonth() + 1, 1) }
    }
    case 'lastMonth': {
      const from = new Date(day.getFullYear(), day.getMonth() - 1, 1)
      return { from, to: new Date(day.getFullYear(), day.getMonth(), 1) }
    }
    default: {
      const from = parseDateInput(customFrom.value, day)
      let to = parseDateInput(customTo.value, day)
      if (to.getTime() <= from.getTime()) to = addDays(from, 1)
      else to = addDays(to, 1)
      return { from, to }
    }
  }
}

function formatDocTime(value: string) {
  const date = new Date(value)
  const pad = (item: number) => String(item).padStart(2, '0')
  return `${date.getFullYear()}/${pad(date.getMonth() + 1)}/${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`
}

function formatDate(value?: string) {
  if (!value) return ''
  const date = new Date(value)
  return `${date.getMonth() + 1}月${date.getDate()}日`
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function priorityLabel(value: number) {
  return PRIORITIES.find((item) => item.value === value)?.label || ''
}

function taskDate(task: SummaryTask) {
  if (task.completed && fields.value.includes('completedAt') && task.completedAt) return task.completedAt
  if (fields.value.includes('due') && task.due) return task.due
  if (task.completed && task.completedAt) return task.completedAt
  return task.due || ''
}

function groupTasks(tasks: SummaryTask[]): Array<{ key: string; label: string; tasks: SummaryTask[] }> {
  const groups = new Map<string, { key: string; label: string; tasks: SummaryTask[] }>()
  const push = (key: string, label: string, task: SummaryTask) => {
    if (!groups.has(key)) groups.set(key, { key, label, tasks: [] })
    groups.get(key)!.tasks.push(task)
  }
  for (const task of tasks) {
    if (groupBy.value === 'list') push(`list-${task.listId}`, task.listName || '未分组', task)
    else if (groupBy.value === 'completedAt') {
      if (task.completed && task.completedAt) push(`date-${hourKey(task.completedAt)}`, formatDate(task.completedAt), task)
      else push('date-open', '未完成', task)
    } else if (groupBy.value === 'due') {
      if (task.due) push(`due-${hourKey(task.due)}`, formatDate(task.due), task)
      else push('due-none', '无日期', task)
    } else if (groupBy.value === 'tag') push(`tag-${task.tags[0] || 'none'}`, task.tags[0] ? `#${task.tags[0]}` : '无标签', task)
    else if (groupBy.value === 'priority') push(`priority-${task.priority}`, priorityLabel(task.priority) || '无优先级', task)
    else push(task.completed ? 'completed' : 'open', task.completed ? '已完成' : '未完成', task)
  }
  const list: Array<{ key: string; label: string; tasks: SummaryTask[] }> = []
  const order = (key: string) => {
    if (groupBy.value === 'status') return key === 'completed' ? 0 : 1
    if (groupBy.value === 'list') {
      const id = Number(key.replace('list-', ''))
      return props.lists.findIndex((item) => item.id === id)
    }
    if (groupBy.value === 'priority') return 3 - Number(key.replace('priority-', ''))
    if (groupBy.value === 'due' || groupBy.value === 'completedAt') {
      if (key.endsWith('open') || key.endsWith('none')) return 999999
      return -Date.parse(key.replace(/^due-|^date-/, ''))
    }
    return 0
  }
  const keys = [...groups.keys()].sort((a, b) => {
    if (groupBy.value === 'due' || groupBy.value === 'completedAt') {
      if (a.endsWith('open') || a.endsWith('none')) return 1
      if (b.endsWith('open') || b.endsWith('none')) return -1
      return keyTime(b) - keyTime(a)
    }
    return order(a) - order(b)
  })
  if (groupBy.value === 'status' || groupBy.value === 'priority') {
    keys.sort((a, b) => order(a) - order(b))
  }
  for (const key of keys) {
    const group = groups.get(key)!
    group.tasks.sort((a, b) => {
      if (a.completed !== b.completed) return a.completed ? -1 : 1
      if (a.completed) return (b.completedAt || '').localeCompare(a.completedAt || '')
      return (a.due || '9999').localeCompare(b.due || '9999')
    })
    list.push(group)
  }
  return list
}

function keyTime(key: string) {
  const raw = key.replace(/^due-|^date-/, '')
  return Date.parse(`${raw}T00:00:00`) || 0
}

function hourKey(value: string) {
  const date = new Date(value)
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

function taskHtml(task: SummaryTask) {
  const date = taskDate(task)
  const prefix = date ? `<span class="tw-summary-date">[${formatDate(date)}]</span> ` : ''
  const extras: string[] = []
  if (fields.value.includes('tags') && task.tags.length) {
    extras.push(task.tags.map((tag) => `<span class="tw-summary-tag">#${escapeHtml(tag)}</span>`).join(' '))
  }
  if (fields.value.includes('list')) extras.push(`<span class="tw-summary-extra">· ${escapeHtml(task.listName)}</span>`)
  if (fields.value.includes('priority') && task.priority) extras.push(`<span class="tw-summary-extra">· ${priorityLabel(task.priority)}</span>`)
  let details = ''
  if (fields.value.includes('details')) {
    const parts: string[] = []
    if (task.notes.trim()) parts.push(escapeHtml(task.notes.trim().replace(/\n+/g, ' ')))
    if (task.checklist.length) parts.push(`子任务 ${task.checklist.filter((item) => item.done).length}/${task.checklist.length}`)
    if (parts.length) details = `<div class="tw-summary-detail">${parts.join(' · ')}</div>`
  }
  return `<li>${prefix}${escapeHtml(task.title)}${extras.length ? ' ' + extras.join(' ') : ''}${details}</li>`
}

function generateHtml() {
  if (!data.value) return '<p>正在生成摘要…</p>'
  let html = `<h2>${escapeHtml(data.value.title)}</h2>`
  const groups = groupTasks(data.value.tasks)
  for (const group of groups) {
    html += `<h3>${escapeHtml(group.label)}</h3><ul>${group.tasks.map(taskHtml).join('')}</ul>`
  }
  if (data.value.nextTasks.length) {
    html += `<h3>下一周期</h3><ul>${data.value.nextTasks.map(taskHtml).join('')}</ul>`
  }
  if (!groups.length && !data.value.nextTasks.length) {
    html += '<p>当前范围内没有符合条件的任务</p>'
  }
  return html
}

function renderEditor() {
  void nextTick(() => {
    if (editorRef.value) {
      editorRef.value.innerHTML = generateHtml()
      if (optimize.value && aiConfigured.value) void applyOptimization()
    }
  })
}

async function load() {
  const currentRange = computeRange()
  loading.value = true
  try {
    data.value = await fetchTaskSummary({
      from: currentRange.from,
      to: currentRange.to,
      listId: listId.value || undefined,
      status: status.value,
      priority: priority.value || undefined,
      tag: tag.value || undefined,
      includeNext: includeNext.value,
    })
    renderEditor()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载摘要失败')
  } finally {
    loading.value = false
  }
}

function scheduleLoad() {
  if (loadTimer) clearTimeout(loadTimer)
  loadTimer = setTimeout(() => void load(), 180)
}

function exec(command: string, value?: string) {
  editorRef.value?.focus()
  document.execCommand(command, false, value)
  onEdit()
}

function highlight() {
  exec('hiliteColor', '#f0a020')
}

function setColor(color: string) {
  exec('foreColor', color)
}

function addLink() {
  const url = window.prompt('链接地址')
  if (url) exec('createLink', url)
}

function insertChecklist() {
  exec('insertHTML', '<div>☐&nbsp;</div>')
}

function toggleField(value: string) {
  const next = new Set(fields.value)
  if (next.has(value)) next.delete(value)
  else next.add(value)
  fields.value = [...next]
}

function onEdit() {
  /* content is read directly from the editor when copying or exporting */
}

function readHtml() {
  return editorRef.value?.innerHTML || generateHtml()
}

function readText() {
  return editorRef.value?.innerText || ''
}

function markdownToHtml(markdown: string) {
  let content = markdown.trim()
  if (content.startsWith('```')) {
    content = content.replace(/^```[a-zA-Z]*\s*/, '').replace(/```\s*$/, '')
  }
  const inline = (value: string) => escapeHtml(value)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
  const lines = content.split(/\r?\n/)
  const out: string[] = []
  let list: 'ul' | 'ol' | '' = ''
  const closeList = () => {
    if (list) {
      out.push(`</${list}>`)
      list = ''
    }
  }
  for (const line of lines) {
    const trimmed = line.trim()
    if (!trimmed) {
      closeList()
      continue
    }
    const heading = trimmed.match(/^(#{1,4})\s+(.*)$/)
    if (heading) {
      closeList()
      const level = Math.min(Math.max(heading[1].length + 1, 2), 4)
      out.push(`<h${level}>${inline(heading[2])}</h${level}>`)
      continue
    }
    const bullet = trimmed.match(/^[-*]\s+(.*)$/)
    if (bullet) {
      if (list !== 'ul') {
        closeList()
        list = 'ul'
        out.push('<ul>')
      }
      out.push(`<li>${inline(bullet[1])}</li>`)
      continue
    }
    const ordered = trimmed.match(/^\d+[.)]\s+(.*)$/)
    if (ordered) {
      if (list !== 'ol') {
        closeList()
        list = 'ol'
        out.push('<ol>')
      }
      out.push(`<li>${inline(ordered[1])}</li>`)
      continue
    }
    closeList()
    out.push(`<p>${inline(trimmed)}</p>`)
  }
  closeList()
  return out.join('')
}

let optimizeSeq = 0

async function applyOptimization() {
  if (!data.value) return
  const text = readText().trim()
  if (!text) return
  const seq = ++optimizeSeq
  optimizing.value = true
  try {
    const result = await optimizeSummary(data.value.title, text)
    if (seq !== optimizeSeq) return
    if (result.markdown && editorRef.value) {
      editorRef.value.innerHTML = markdownToHtml(result.markdown)
    } else if (!result.markdown) {
      Message.warning('AI 没有返回优化内容')
    }
  } catch (error) {
    if (seq === optimizeSeq) {
      Message.warning(error instanceof Error ? error.message : 'AI 优化失败，已保留原摘要')
    }
  } finally {
    if (seq === optimizeSeq) optimizing.value = false
  }
}

async function saveHistory() {
  try {
    const { document } = await createSummaryDocument({
      kind: 'history',
      name: data.value?.title || '摘要',
      content: readHtml(),
    })
    history.value = [document, ...history.value].slice(0, 50)
    saveMenuOpen.value = false
    Message.success('已保存到历史文档')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存失败')
  }
}

function loadDocument(doc: SummaryDocument) {
  if (editorRef.value) editorRef.value.innerHTML = doc.content
  historyOpen.value = false
}

async function removeHistory(id: number) {
  try {
    await deleteSummaryDocument(id)
    history.value = history.value.filter((item) => item.id !== id)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '删除失败')
  }
}

async function saveAsTemplate() {
  const name = window.prompt('模板名称', data.value?.title || '摘要模板')
  if (!name) return
  try {
    const { document } = await createSummaryDocument({ kind: 'template', name, content: readHtml() })
    templates.value = [document, ...templates.value].slice(0, 50)
    Message.success('模板已保存')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存模板失败')
  }
}

function loadTemplate(template: SummaryDocument) {
  if (editorRef.value) editorRef.value.innerHTML = template.content
}

async function copySummary() {
  const html = readHtml()
  const text = readText()
  try {
    if (navigator.clipboard && window.ClipboardItem) {
      await navigator.clipboard.write([
        new ClipboardItem({
          'text/html': new Blob([html], { type: 'text/html' }),
          'text/plain': new Blob([text], { type: 'text/plain' }),
        }),
      ])
    } else if (navigator.clipboard) {
      await navigator.clipboard.writeText(text)
    } else {
      throw new Error('clipboard unavailable')
    }
    Message.success('已复制摘要')
  } catch {
    const area = document.createElement('textarea')
    area.value = text
    document.body.appendChild(area)
    area.select()
    document.execCommand('copy')
    area.remove()
    Message.success('已复制摘要')
  }
}

function exportHtml() {
  const html = buildDocument(readHtml())
  download('summary.html', html, 'text/html;charset=utf-8')
  saveMenuOpen.value = false
}

function printSummary() {
  const win = window.open('', '_blank')
  if (!win) return
  win.document.write(buildDocument(readHtml(), true))
  win.document.close()
  win.focus()
  win.print()
  saveMenuOpen.value = false
}

function emailSummary() {
  const text = readText()
  const subject = encodeURIComponent(data.value?.title || '任务摘要')
  window.location.href = `mailto:?subject=${subject}&body=${encodeURIComponent(text)}`
  saveMenuOpen.value = false
}

function buildDocument(content: string, print = false) {
  return `<!doctype html><html><head><meta charset="utf-8"><title>${escapeHtml(data.value?.title || '摘要')}</title><style>
    body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC",sans-serif;max-width:760px;margin:40px auto;padding:0 20px;line-height:1.7;color:#1f2329}
    h2{font-size:24px;margin:0 0 16px}h3{font-size:16px;margin:22px 0 8px}ul{padding-left:22px}
    .tw-summary-date{color:#6b7280}.tw-summary-tag{color:#4772fa}.tw-summary-extra{color:#6b7280}
    .tw-summary-detail{color:#6b7280;font-size:12px}
    @media print{body{margin:0;max-width:none}${print ? '' : ''}}
  </style></head><body>${content}</body></html>`
}

function download(name: string, content: string, type: string) {
  const blob = new Blob([content], { type })
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  link.download = name
  link.click()
  setTimeout(() => URL.revokeObjectURL(link.href), 1000)
}

watch([preset, customFrom, customTo, listId, status, priority, tag, includeNext], scheduleLoad)
watch([groupBy, fields], renderEditor, { deep: true })

async function loadDocuments() {
  try {
    const [historyData, templateData] = await Promise.all([
      fetchSummaryDocuments('history'),
      fetchSummaryDocuments('template'),
    ])
    history.value = historyData.documents
    templates.value = templateData.documents
  } catch {
    /* ignore documents load failure */
  }
}

async function loadAIConfig() {
  try {
    const settings = await fetchAISettings()
    aiConfigured.value = settings.configured
  } catch {
    aiConfigured.value = false
  }
}

watch(optimize, (value) => {
  if (value) {
    void applyOptimization()
  } else {
    optimizeSeq += 1
    optimizing.value = false
    renderEditor()
  }
})

onMounted(() => {
  void loadDocuments()
  void loadAIConfig()
  void load()
})

onBeforeUnmount(() => {
  if (loadTimer) clearTimeout(loadTimer)
})
</script>
