<template>
  <aside class="tw-detail tw-note-detail">
    <header class="tw-detail-head">
      <div class="tw-detail-title">
        <span class="tw-detail-list">
          <i :style="{ background: task.listColor || '#4772fa' }" />
          {{ listName }}
        </span>
        <span class="tw-note-status">{{ saving ? '保存中…' : '已保存' }}</span>
      </div>
      <div class="tw-detail-actions">
        <button
          class="tw-icon-button"
          :class="{ active: task.pinned }"
          :title="task.pinned ? '取消置顶' : '置顶笔记'"
          :disabled="readonly"
          @click="$emit('pin', task)"
        >
          <TaskIcon name="pin" :size="16" />
        </button>
        <button v-if="!readonly" class="tw-icon-button" title="删除笔记" @click="$emit('remove', task)">
          <TaskIcon name="trash" :size="16" />
        </button>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="17" />
        </button>
      </div>
    </header>

    <div class="tw-note-editor">
      <input
        v-model="title"
        class="tw-note-title-input"
        maxlength="500"
        placeholder="笔记标题"
        :readonly="readonly"
        @input="scheduleSave"
        @blur="flush"
      />
      <div v-if="!readonly" class="tw-note-toolbar" role="toolbar" aria-label="笔记格式">
        <button title="加粗" @mousedown.prevent="exec('bold')"><b>B</b></button>
        <button title="斜体" @mousedown.prevent="exec('italic')"><i>I</i></button>
        <button title="下划线" @mousedown.prevent="exec('underline')"><u>U</u></button>
        <button title="删除线" @mousedown.prevent="exec('strikeThrough')"><s>S</s></button>
        <span class="tw-note-toolbar-sep" />
        <button title="标题" @mousedown.prevent="exec('formatBlock', 'h2')">H</button>
        <button title="引用" @mousedown.prevent="exec('formatBlock', 'blockquote')">❝</button>
        <button title="代码块" @mousedown.prevent="exec('formatBlock', 'pre')">&lt;/&gt;</button>
        <span class="tw-note-toolbar-sep" />
        <button title="无序列表" @mousedown.prevent="exec('insertUnorderedList')">•</button>
        <button title="有序列表" @mousedown.prevent="exec('insertOrderedList')">1.</button>
        <button title="高亮" @mousedown.prevent="exec('hiliteColor', '#fff3a3')"><span class="tw-note-hl">A</span></button>
        <button title="链接" @mousedown.prevent="insertLink"><TaskIcon name="link" :size="14" /></button>
        <span class="tw-note-toolbar-sep" />
        <button title="清除格式" @mousedown.prevent="exec('removeFormat')">Tx</button>
        <button title="撤销" @mousedown.prevent="exec('undo')">↶</button>
        <button title="重做" @mousedown.prevent="exec('redo')">↷</button>
      </div>
      <div
        ref="editorRef"
        class="tw-note-body-input tw-note-rich"
        spellcheck="false"
        data-placeholder="记录你的想法…"
        :contenteditable="readonly ? 'false' : 'true'"
        @input="onInput"
        @blur="flush"
        @paste.prevent="onPaste"
        @drop.prevent
      />
    </div>

    <footer class="tw-note-foot">
      <span>{{ wordCount }} 字</span>
      <span>{{ modifiedLabel }}</span>
    </footer>
  </aside>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { TaskItem, TaskList } from '../../types'
import { updateTask } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  task: TaskItem
  lists: TaskList[]
  readonly?: boolean
}>()

const emit = defineEmits<{
  (event: 'close'): void
  (event: 'changed', task: TaskItem): void
  (event: 'pin', task: TaskItem): void
  (event: 'remove', task: TaskItem): void
}>()

const title = ref(props.task.title)
const editorRef = ref<HTMLElement | null>(null)
const saving = ref(false)
const wordCount = ref(0)
let timer: ReturnType<typeof setTimeout> | undefined
let lastSaved = { title: props.task.title, notes: props.task.notes }

const listName = computed(() => props.lists.find((list) => list.id === props.task.listId)?.name || props.task.listName || '笔记')
const modifiedLabel = computed(() => {
  const date = new Date(props.task.modifiedAt)
  if (Number.isNaN(date.getTime())) return ''
  return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
})

function escapeHtml(value: string) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function plainToHtml(value: string) {
  const text = value.replace(/\r\n/g, '\n').trim()
  if (!text) return ''
  return text
    .split('\n')
    .filter((line) => line.trim() !== '')
    .map((line) => `<p>${escapeHtml(line)}</p>`)
    .join('')
}

function syncFromEditor() {
  const editor = editorRef.value
  if (!editor) return
  wordCount.value = (editor.innerText.match(/[\u4e00-\u9fa5]|[A-Za-z0-9]+/g) || []).length
}

function onInput() {
  syncFromEditor()
  scheduleSave()
}

function scheduleSave() {
  if (props.readonly) return
  if (timer) clearTimeout(timer)
  saving.value = true
  timer = setTimeout(() => void flush(), 600)
}

async function flush() {
  if (props.readonly) return
  if (timer) {
    clearTimeout(timer)
    timer = undefined
  }
  const editor = editorRef.value
  if (!editor) return
  const nextTitle = title.value.trim() || '无标题笔记'
  const notes = editor.innerHTML.trim()
  if (nextTitle === lastSaved.title && notes === lastSaved.notes) {
    saving.value = false
    return
  }
  saving.value = true
  try {
    const { task } = await updateTask(props.task.id, { title: nextTitle, notes, notesFormat: 'html' })
    lastSaved = { title: task.title, notes: task.notes }
    title.value = task.title
    if (editor.innerHTML !== task.notes) editor.innerHTML = task.notes
    syncFromEditor()
    emit('changed', task)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存笔记失败')
  } finally {
    saving.value = false
  }
}

function exec(command: string, value?: string) {
  if (props.readonly) return
  document.execCommand('styleWithCSS', false, 'true')
  document.execCommand(command, false, value)
  syncFromEditor()
  scheduleSave()
}

function safeLink(value: string) {
  const url = value.trim()
  if (!url) return ''
  const lower = url.toLowerCase()
  if (lower.startsWith('javascript:') || lower.startsWith('data:') || lower.startsWith('vbscript:')) return ''
  if (url.startsWith('#') || url.startsWith('/') || lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('mailto:') || lower.startsWith('tel:')) {
    return url
  }
  return ''
}

function insertLink() {
  const raw = window.prompt('链接地址')
  if (!raw) return
  const url = safeLink(raw)
  if (!url) {
    Message.warning('链接必须以 http(s)://、mailto:、/ 或 # 开头')
    return
  }
  const selection = window.getSelection()
  if (selection && !selection.isCollapsed) {
    document.execCommand('createLink', false, url)
  } else {
    document.execCommand('insertHTML', false, `<a href="${escapeHtml(url)}">${escapeHtml(url)}</a>`)
  }
  syncFromEditor()
  scheduleSave()
}

function onPaste(event: ClipboardEvent) {
  if (props.readonly) return
  const text = event.clipboardData?.getData('text/plain') ?? ''
  document.execCommand('insertText', false, text)
  syncFromEditor()
  scheduleSave()
}

onMounted(() => {
  const editor = editorRef.value
  if (!editor) return
  editor.innerHTML = props.task.notesFormat === 'html' ? props.task.notes : plainToHtml(props.task.notes)
  lastSaved = { title: props.task.title, notes: editor.innerHTML }
  syncFromEditor()
})

onBeforeUnmount(() => {
  if (timer) clearTimeout(timer)
  void flush()
})
</script>
