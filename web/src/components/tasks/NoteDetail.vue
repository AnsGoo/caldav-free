<template>
  <aside class="tw-detail tw-note-detail" :style="{ '--tw-note-detail-width': `${panelWidth}px` }">
    <div
      class="tw-note-resizer"
      role="separator"
      aria-orientation="vertical"
      aria-label="调整笔记编辑器宽度"
      title="拖动调整宽度"
      tabindex="0"
      @pointerdown="startResize"
      @keydown.left.prevent="resizeBy(24)"
      @keydown.right.prevent="resizeBy(-24)"
    />
    <header class="tw-detail-head">
      <div class="tw-detail-title">
        <span class="tw-note-status">{{ saving ? '保存中…' : '已保存' }}</span>
      </div>
      <div class="tw-detail-actions">
        <button v-if="!readonly && shareable !== false" class="tw-icon-button" title="共享笔记" @click="$emit('share', task)">
          <TaskIcon name="share" :size="16" />
        </button>
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
      <MarkdownEditor
        v-model="notes"
        class="tw-note-md"
        placeholder="用 Markdown 记录你的想法…"
        :readonly="readonly"
        @update:model-value="scheduleSave"
      />
      <section class="tw-note-config">
        <span class="tw-note-config-title">笔记配置</span>
        <div class="tw-note-config-row">
          <span>所在清单</span>
          <a-select
            v-model.number="listId"
            class="tw-field-select tw-note-config-select"
            :disabled="readonly || moveLocked"
            @change="moveToList"
          >
            <template #prefix>
              <i class="tw-list-picker-dot" :style="{ background: currentList?.color || task.listColor || '#4772fa' }" />
            </template>
            <a-option v-for="list in noteListOptions" :key="list.id" :value="list.id">{{ list.name }}</a-option>
          </a-select>
        </div>
        <div class="tw-note-config-row tw-note-config-tags">
          <span>标签</span>
          <div class="tw-detail-tags">
            <span
              v-for="tag in tags"
              :key="tag"
              class="tw-detail-tag"
              :style="{ color: tagColor(tag, tagColors?.[tag]), background: tagTint(tagColor(tag, tagColors?.[tag])) }"
              @click="removeTag(tag)"
            >
              #{{ tag }}
              <TaskIcon name="close" :size="11" />
            </span>
            <input
              v-model="tagInput"
              class="tw-tag-input"
              placeholder="+ 添加标签"
              maxlength="30"
              :disabled="readonly"
              @keydown.enter="onTagEnter"
              @blur="addTag"
            />
          </div>
        </div>
      </section>
    </div>

    <div class="tw-note-discussion">
      <NoteDiscussion :task-id="task.id" :list-id="task.listId" :readonly="readonly" />
    </div>

    <footer class="tw-note-foot">
      <span>{{ wordCount }} 字 · Markdown</span>
      <span>{{ modifiedLabel }}</span>
    </footer>
  </aside>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { TaskItem, TaskList } from '../../types'
import { updateTask } from '../../tasks-api'
import { htmlToMarkdown, markdownToPlain } from '../../markdown'
import { tagColor, tagTint } from '../../tag-colors'
import MarkdownEditor from './MarkdownEditor.vue'
import NoteDiscussion from './NoteDiscussion.vue'
import TaskIcon from './TaskIcon.vue'

const props = withDefaults(
  defineProps<{
    task: TaskItem
    lists: TaskList[]
    readonly?: boolean
    shareable?: boolean
    moveLocked?: boolean
    tagColors?: Record<string, string>
  }>(),
  { tagColors: () => ({}) },
)

const emit = defineEmits<{
  (event: 'close'): void
  (event: 'changed', task: TaskItem): void
  (event: 'pin', task: TaskItem): void
  (event: 'remove', task: TaskItem): void
  (event: 'share', task: TaskItem): void
}>()

const title = ref(props.task.title)
const notes = ref(props.task.notesFormat === 'html' ? htmlToMarkdown(props.task.notes) : props.task.notes)
const saving = ref(false)
let timer: ReturnType<typeof setTimeout> | undefined
let lastSaved = { title: props.task.title, notes: notes.value }

const NOTE_MIN_WIDTH = 320
const NOTE_MAX_WIDTH = 760

function clampPanelWidth(value: number) {
  const max = Math.min(NOTE_MAX_WIDTH, Math.max(NOTE_MIN_WIDTH, window.innerWidth - 320))
  return Math.min(max, Math.max(NOTE_MIN_WIDTH, value))
}

function storedPanelWidth() {
  try {
    const value = Number(localStorage.getItem('caldav-note-detail-width'))
    if (Number.isFinite(value) && value >= NOTE_MIN_WIDTH) return clampPanelWidth(value)
  } catch {
    /* ignore */
  }
  return 380
}

const panelWidth = ref(storedPanelWidth())

function savePanelWidth() {
  try {
    localStorage.setItem('caldav-note-detail-width', String(panelWidth.value))
  } catch {
    /* ignore */
  }
}

function resizeBy(delta: number) {
  panelWidth.value = clampPanelWidth(panelWidth.value + delta)
  savePanelWidth()
}

function startResize(event: PointerEvent) {
  if (event.button !== 0) return
  event.preventDefault()
  const startX = event.clientX
  const startWidth = panelWidth.value
  document.body.classList.add('tw-resizing')
  const move = (moveEvent: PointerEvent) => {
    panelWidth.value = clampPanelWidth(startWidth - (moveEvent.clientX - startX))
  }
  const stop = () => {
    window.removeEventListener('pointermove', move)
    window.removeEventListener('pointerup', stop)
    document.body.classList.remove('tw-resizing')
    savePanelWidth()
  }
  window.addEventListener('pointermove', move)
  window.addEventListener('pointerup', stop, { once: true })
}

const listId = ref(props.task.listId)
const tags = ref<string[]>([...(props.task.tags || [])])
const tagInput = ref('')
const currentList = computed(() => props.lists.find((list) => list.id === listId.value))
const noteListOptions = computed(() => {
  const noteLists = props.lists.filter((list) => list.kind === 'NOTE')
  const active = props.lists.find((list) => list.id === props.task.listId)
  if (active && !noteLists.some((list) => list.id === active.id)) return [active, ...noteLists]
  return noteLists
})
const wordCount = computed(() => (markdownToPlain(notes.value).match(/[\u4e00-\u9fa5]|[A-Za-z0-9]+/g) || []).length)
const modifiedLabel = computed(() => {
  const date = new Date(props.task.modifiedAt)
  if (Number.isNaN(date.getTime())) return ''
  return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
})

function scheduleSave() {
  if (props.readonly) return
  if (timer) clearTimeout(timer)
  saving.value = true
  timer = setTimeout(() => void flush(), 600)
}

watch(
  () => props.task.tags,
  (next) => {
    tags.value = [...(next || [])]
  },
)

function onTagEnter(event: KeyboardEvent) {
  if (event.isComposing) return
  event.preventDefault()
  addTag()
}

function addTag() {
  const tag = tagInput.value.replace(/^#/, '').trim()
  if (!tag) return
  tagInput.value = ''
  if (tags.value.includes(tag)) return
  void persistTags([...tags.value, tag].slice(0, 20))
}

function removeTag(tag: string) {
  void persistTags(tags.value.filter((item) => item !== tag))
}

async function persistTags(next: string[]) {
  if (props.readonly) return
  const previous = tags.value
  tags.value = next
  saving.value = true
  try {
    const { task } = await updateTask(props.task.id, { tags: next })
    tags.value = [...(task.tags || [])]
    emit('changed', task)
  } catch (error) {
    tags.value = previous
    Message.error(error instanceof Error ? error.message : '保存标签失败')
  } finally {
    saving.value = false
  }
}

async function flush() {
  if (props.readonly) return
  if (timer) {
    clearTimeout(timer)
    timer = undefined
  }
  const nextTitle = title.value.trim() || '无标题笔记'
  const nextNotes = notes.value
  if (nextTitle === lastSaved.title && nextNotes === lastSaved.notes) {
    saving.value = false
    return
  }
  saving.value = true
  try {
    const { task } = await updateTask(props.task.id, { title: nextTitle, notes: nextNotes, notesFormat: 'markdown' })
    lastSaved = { title: task.title, notes: task.notes }
    title.value = task.title
    notes.value = task.notes
    emit('changed', task)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存笔记失败')
  } finally {
    saving.value = false
  }
}

async function moveToList() {  if (props.readonly || listId.value === props.task.listId) return
  const target = props.lists.find((list) => list.id === listId.value)
  if (!target) {
    listId.value = props.task.listId
    return
  }
  await flush()
  saving.value = true
  try {
    const { task } = await updateTask(props.task.id, { listId: listId.value })
    listId.value = task.listId
    emit('changed', task)
    Message.success(`已移动到「${target.name}」`)
  } catch (error) {
    listId.value = props.task.listId
    Message.error(error instanceof Error ? error.message : '移动笔记失败')
  } finally {
    saving.value = false
  }
}

onBeforeUnmount(() => {
  if (timer) clearTimeout(timer)
  document.body.classList.remove('tw-resizing')
  void flush()
})
</script>
