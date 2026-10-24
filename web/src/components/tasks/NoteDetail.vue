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
      <textarea
        v-model="notes"
        class="tw-note-body-input"
        placeholder="记录你的想法…"
        :readonly="readonly"
        @input="scheduleSave"
        @blur="flush"
      />
    </div>

    <footer class="tw-note-foot">
      <span>{{ wordCount }} 字</span>
      <span>{{ modifiedLabel }}</span>
    </footer>
  </aside>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
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
const notes = ref(props.task.notes)
const saving = ref(false)
let timer: ReturnType<typeof setTimeout> | undefined
let lastSaved = { title: props.task.title, notes: props.task.notes }

watch(
  () => props.task.id,
  () => {
    title.value = props.task.title
    notes.value = props.task.notes
    lastSaved = { title: props.task.title, notes: props.task.notes }
    saving.value = false
  },
)

const listName = computed(() => props.lists.find((list) => list.id === props.task.listId)?.name || props.task.listName || '笔记')
const wordCount = computed(() => (notes.value.match(/[\u4e00-\u9fa5]|[A-Za-z0-9]+/g) || []).length)
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

async function flush() {
  if (props.readonly) return
  if (timer) {
    clearTimeout(timer)
    timer = undefined
  }
  const nextTitle = title.value.trim() || '无标题笔记'
  if (nextTitle === lastSaved.title && notes.value === lastSaved.notes) {
    saving.value = false
    return
  }
  saving.value = true
  try {
    const { task } = await updateTask(props.task.id, { title: nextTitle, notes: notes.value })
    lastSaved = { title: task.title, notes: task.notes }
    title.value = task.title
    emit('changed', task)
  } finally {
    saving.value = false
  }
}

onBeforeUnmount(() => {
  if (timer) clearTimeout(timer)
  void flush()
})
</script>
