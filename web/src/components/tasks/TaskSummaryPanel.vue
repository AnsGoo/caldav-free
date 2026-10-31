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

      <div class="tw-summary-toolbar tw-summary-md-head">
        <span class="tw-summary-format">Markdown 预览</span>
        <button title="刷新摘要" @click="load"><TaskIcon name="refresh" :size="15" /></button>
      </div>

      <div class="tw-summary-editor-wrap">
        <div v-if="loading || optimizing" class="tw-summary-loading">{{ optimizing ? 'AI 优化中…' : '生成摘要中…' }}</div>
        <div
          v-else
          class="tw-md-wysiwyg tw-summary-preview"
          v-html="renderedSummary"
        />
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
            <button @click="exportImage">导出图片</button>
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
        <div class="tw-summary-field">
          <span>日期</span>
          <a-select v-model="preset" size="small">
            <a-option v-for="option in dateOptions" :key="option.value" :value="option.value">{{ option.label }}</a-option>
          </a-select>
        </div>
        <div v-if="preset === 'custom'" class="tw-summary-custom-dates">
          <a-date-picker v-model="customFrom" class="tw-date-control" value-format="YYYY-MM-DD" format="YYYY-MM-DD" size="small" />
          <span>→</span>
          <a-date-picker v-model="customTo" class="tw-date-control" value-format="YYYY-MM-DD" format="YYYY-MM-DD" size="small" />
        </div>
        <div class="tw-summary-field">
          <span>清单</span>
          <a-select v-model.number="listId" size="small">
            <a-option :value="0">所有清单</a-option>
            <a-option v-for="list in lists" :key="list.id" :value="list.id">{{ list.name }}</a-option>
          </a-select>
        </div>
        <div class="tw-summary-field">
          <span>状态</span>
          <a-select v-model="status" size="small">
            <a-option value="all">所有状态</a-option>
            <a-option value="completed">已完成</a-option>
            <a-option value="open">未完成</a-option>
          </a-select>
        </div>
        <div class="tw-summary-field">
          <span>优先级</span>
          <a-select v-model.number="priority" size="small">
            <a-option :value="0">所有优先级</a-option>
            <a-option :value="3">高优先级</a-option>
            <a-option :value="2">中优先级</a-option>
            <a-option :value="1">低优先级</a-option>
          </a-select>
        </div>
        <div class="tw-summary-field">
          <span>标签</span>
          <a-select v-model="tag" size="small">
            <a-option value="">所有标签</a-option>
            <a-option v-for="item in tags" :key="item.name" :value="item.name">#{{ item.name }}</a-option>
          </a-select>
        </div>
      </section>

      <section class="tw-summary-panel">
        <header class="tw-summary-panel-head"><h3>显示设置</h3></header>
        <div class="tw-summary-field">
          <span>分组</span>
          <a-select v-model="groupBy" size="small">
            <a-option value="status">按完成状态</a-option>
            <a-option value="list">按清单</a-option>
            <a-option value="completedAt">按完成时间</a-option>
            <a-option value="due">按任务时间</a-option>
            <a-option value="tag">按标签</a-option>
            <a-option value="priority">按优先级</a-option>
          </a-select>
        </div>
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
        <div class="tw-summary-toggle">
          <span>下一周期任务</span>
          <a-switch v-model="includeNext" size="small" />
        </div>
        <p class="tw-summary-hint">“下一周期任务”会追加当前范围之后同等长度时间段内到期的未完成任务。</p>
        <div class="tw-summary-toggle">
          <span>内容优化 <em class="tw-ai-badge">AI</em></span>
          <a-switch v-model="optimize" size="small" :disabled="!aiConfigured" />
        </div>
        <p v-if="aiConfigured" class="tw-summary-hint">开启后会调用 AI 重写当前摘要，内容会发送到配置的模型服务。</p>
        <p v-else class="tw-summary-hint">需先在 AI 助手中配置模型才能启用内容优化。</p>
      </section>

      <button class="tw-summary-aside-close" @click="asideOpen = false">收起设置</button>
    </aside>

    <div v-if="templateDialogOpen" class="tw-dialog-scrim" @click.self="templateDialogOpen = false">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true" aria-label="保存为模板" @keydown.esc="templateDialogOpen = false">
        <header class="tw-dialog-head">
          <h2>保存为模板</h2>
          <button class="tw-icon-button" title="关闭" @click="templateDialogOpen = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body">
          <div class="tw-modal-label">
            模板名称
            <a-input
              ref="templateNameInput"
              v-model="templateName"
              class="tw-dialog-input"
              :max-length="80"
              placeholder="例如：本周工作摘要"
              @keydown.enter="confirmSaveTemplate"
            />
          </div>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="templateDialogOpen = false">取消</button>
          <button class="tw-dialog-ok" :disabled="templateBusy" @click="confirmSaveTemplate">
            {{ templateBusy ? '保存中…' : '保存' }}
          </button>
        </footer>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { SummaryDocument, SummaryTask, TaskList, TaskSummaryData, TaskTagCount } from '../../types'
import { createSummaryDocument, deleteSummaryDocument, fetchAISettings, fetchSummaryDocuments, fetchTaskSummary, optimizeSummary } from '../../tasks-api'
import { PRIORITIES } from '../../tasks-utils'
import { htmlToMarkdown, markdownToPlain, renderMarkdown } from '../../markdown'
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
  { value: 'status', label: '状态' },
  { value: 'progress', label: '进度' },
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
const summaryMarkdown = ref('')
const renderedSummary = computed(() => renderMarkdown(summaryMarkdown.value))
const asideOpen = ref(false)
const historyOpen = ref(false)
const saveMenuOpen = ref(false)

const history = ref<SummaryDocument[]>([])
const templates = ref<SummaryDocument[]>([])
const aiConfigured = ref(false)
const optimize = ref(false)
const optimizing = ref(false)

const templateDialogOpen = ref(false)
const templateName = ref('')
const templateBusy = ref(false)
const templateNameInput = ref<{ focus?: () => void } | null>(null)
let optimizeSeq = 0

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

function mdEscape(value: string) {
  return value.replace(/([\\`*_[\]])/g, '\\$1')
}

function taskMarkdown(task: SummaryTask) {
  const date = taskDate(task)
  const parts: string[] = []
  if (date) parts.push(`[${formatDate(date)}]`)
  parts.push(mdEscape(task.title))
  if (fields.value.includes('tags') && task.tags.length) {
    parts.push(task.tags.map((tag) => `#${mdEscape(tag)}`).join(' '))
  }
  if (fields.value.includes('list')) parts.push(`· ${mdEscape(task.listName)}`)
  if (fields.value.includes('priority') && task.priority) parts.push(`· ${priorityLabel(task.priority)}`)
  if (fields.value.includes('status')) parts.push(`· ${task.completed ? '已完成' : '未完成'}`)
  if (fields.value.includes('progress') && task.checklist.length) {
    const done = task.checklist.filter((item) => item.done).length
    parts.push(`· 进度 ${done}/${task.checklist.length}`)
  }
  if (fields.value.includes('details')) {
    if (task.notes.trim()) parts.push(`· ${mdEscape(task.notes.trim().replace(/\n+/g, ' '))}`)
    if (task.checklist.length) parts.push(`· 子任务 ${task.checklist.filter((item) => item.done).length}/${task.checklist.length}`)
  }
  return `${task.completed ? '- [x]' : '- [ ]'} ${parts.join(' ')}`
}

function generateMarkdown() {
  if (!data.value) return '正在生成摘要…'
  const lines: string[] = [`## ${mdEscape(data.value.title)}`, '']
  const groups = groupTasks(data.value.tasks)
  for (const group of groups) {
    lines.push(`### ${mdEscape(group.label)}`, '')
    for (const task of group.tasks) lines.push(taskMarkdown(task))
    lines.push('')
  }
  if (data.value.nextTasks.length) {
    lines.push('### 下一周期', '')
    for (const task of data.value.nextTasks) lines.push(taskMarkdown(task))
    lines.push('')
  }
  if (!groups.length && !data.value.nextTasks.length) {
    lines.push('当前范围内没有符合条件的任务')
  }
  return lines.join('\n').trim() + '\n'
}

function renderEditor() {
  summaryMarkdown.value = generateMarkdown()
  if (optimize.value && aiConfigured.value) void applyOptimization()
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

function toggleField(value: string) {
  const next = new Set(fields.value)
  if (next.has(value)) next.delete(value)
  else next.add(value)
  fields.value = [...next]
}

function readHtml() {
  return renderMarkdown(summaryMarkdown.value)
}

function readText() {
  return markdownToPlain(summaryMarkdown.value)
}

async function applyOptimization() {
  if (!data.value) return
  const text = readText().trim()
  if (!text) return
  const seq = ++optimizeSeq
  optimizing.value = true
  try {
    const result = await optimizeSummary(data.value.title, text)
    if (seq !== optimizeSeq) return
    if (result.markdown) {
      summaryMarkdown.value = result.markdown.trim()
    } else {
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
      content: summaryMarkdown.value,
      format: 'markdown',
    })
    history.value = [document, ...history.value].slice(0, 50)
    saveMenuOpen.value = false
    Message.success('已保存到历史文档')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存失败')
  }
}

function loadDocument(doc: SummaryDocument) {
  summaryMarkdown.value = doc.format === 'markdown' ? doc.content : htmlToMarkdown(doc.content)
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

function saveAsTemplate() {
  templateName.value = data.value?.title || '摘要模板'
  templateDialogOpen.value = true
  void nextTick(() => templateNameInput.value?.focus?.())
}

async function confirmSaveTemplate() {
  const name = templateName.value.trim()
  if (!name) {
    Message.warning('请填写模板名称')
    return
  }
  templateBusy.value = true
  try {
    const { document } = await createSummaryDocument({ kind: 'template', name, content: summaryMarkdown.value, format: 'markdown' })
    templates.value = [document, ...templates.value].slice(0, 50)
    templateDialogOpen.value = false
    Message.success('模板已保存')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存模板失败')
  } finally {
    templateBusy.value = false
  }
}

function loadTemplate(template: SummaryDocument) {
  summaryMarkdown.value = template.format === 'markdown' ? template.content : htmlToMarkdown(template.content)
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

async function exportImage() {
  const content = readHtml()
  const width = 980
  const wrapper = document.createElement('div')
  wrapper.setAttribute('xmlns', 'http://www.w3.org/1999/xhtml')
  wrapper.style.width = '980px'
  wrapper.style.padding = '40px'
  wrapper.style.background = '#ffffff'
  wrapper.style.color = '#1f2329'
  wrapper.style.fontFamily = '-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC",sans-serif'
  wrapper.style.fontSize = '14px'
  wrapper.style.lineHeight = '1.75'
  wrapper.style.boxSizing = 'border-box'
  wrapper.innerHTML = `<style>
    h2{font-size:24px;margin:0 0 16px;color:#111827}h3{font-size:16px;margin:22px 0 8px;color:#111827}
    h4{font-size:15px;margin:18px 0 6px;color:#111827}ul,ol{padding-left:24px;margin:6px 0}li{margin:5px 0}
    blockquote{border-left:3px solid #4772fa;margin:10px 0;padding:4px 12px;color:#5c626b;background:#f3f3f5}
    pre{background:#f3f3f5;border-radius:7px;padding:8px 10px;font-size:12px;overflow-x:auto}
    code{background:#f3f3f5;border-radius:4px;padding:1px 4px;font-size:12px}pre code{padding:0;background:transparent}
    a{color:#4772fa}hr{border:0;border-top:1px solid #e5e7eb;margin:14px 0}
    table{width:100%;border-collapse:collapse;margin:12px 0;font-size:13px}
    th,td{border:1px solid #d9dce3;padding:5px 8px;text-align:left}th{background:#f3f4f6}
  </style>${content}`
  wrapper.style.position = 'fixed'
  wrapper.style.left = '-10000px'
  wrapper.style.top = '0'
  document.body.appendChild(wrapper)
  const height = Math.max(wrapper.getBoundingClientRect().height, 200)
  document.body.removeChild(wrapper)
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${Math.ceil(height)}">
    <foreignObject width="100%" height="100%">${new XMLSerializer().serializeToString(wrapper)}</foreignObject>
  </svg>`
  try {
    const url = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`
    const image = new Image()
    await new Promise<void>((resolve, reject) => {
      image.onload = () => resolve()
      image.onerror = () => reject(new Error('图片渲染失败'))
      image.src = url
    })
    const scale = 2
    const canvas = document.createElement('canvas')
    canvas.width = width * scale
    canvas.height = Math.ceil(height) * scale
    const context = canvas.getContext('2d')
    if (!context) throw new Error('无法创建画布')
    context.scale(scale, scale)
    context.fillStyle = '#ffffff'
    context.fillRect(0, 0, width, height)
    context.drawImage(image, 0, 0)
    const png = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/png'))
    if (!png) throw new Error('图片生成失败')
    const link = document.createElement('a')
    link.href = URL.createObjectURL(png)
    link.download = 'summary.png'
    link.click()
    setTimeout(() => URL.revokeObjectURL(link.href), 1000)
    saveMenuOpen.value = false
    Message.success('图片已导出')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '导出图片失败')
  } finally {
  }
}

function printSummary() {
  const win = window.open('', '_blank')
  if (!win) return
  win.document.write(buildDocument(readHtml()))
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

function buildDocument(content: string) {
  return `<!doctype html><html><head><meta charset="utf-8"><title>${escapeHtml(data.value?.title || '摘要')}</title><style>
    body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC",sans-serif;max-width:760px;margin:40px auto;padding:0 20px;line-height:1.7;color:#1f2329}
    h2{font-size:24px;margin:0 0 16px}h3{font-size:16px;margin:22px 0 8px}ul,ol{padding-left:22px}
    blockquote{margin:10px 0;padding:4px 12px;border-left:3px solid #4772fa;color:#5c626b;background:#f3f3f5}
    pre{background:#f3f3f5;border-radius:7px;padding:8px 10px;font-size:12px;overflow-x:auto}
    code{background:#f3f3f5;border-radius:4px;padding:1px 4px;font-size:12px}pre code{padding:0;background:transparent}
    a{color:#4772fa}hr{border:0;border-top:1px solid #e5e7eb;margin:14px 0}
    table{width:100%;border-collapse:collapse;margin:12px 0;font-size:13px}
    th,td{border:1px solid #d9dce3;padding:5px 8px;text-align:left}th{background:#f3f4f6}
    @media print{body{margin:0;max-width:none}}
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
