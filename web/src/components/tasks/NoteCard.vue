<template>
  <article class="tw-note-card" :class="{ selected }" @click="$emit('open', task)">
    <header class="tw-note-card-head">
      <span class="tw-note-badge"><TaskIcon name="note" :size="13" /> 笔记</span>
      <button
        v-if="!readonly"
        class="tw-note-pin"
        :class="{ active: task.pinned }"
        :title="task.pinned ? '取消置顶' : '置顶笔记'"
        @click.stop="$emit('pin', task)"
      >
        <TaskIcon name="pin" :size="13" />
      </button>
    </header>
    <h3 class="tw-note-card-title">{{ task.title || '无标题笔记' }}</h3>
    <p v-if="preview" class="tw-note-card-preview">{{ preview }}</p>
    <footer class="tw-note-card-foot">
      <span v-if="showList" class="tw-note-card-list">
        <i :style="{ background: task.listColor || '#4772fa' }" />
        {{ task.listName }}
      </span>
      <span class="tw-note-card-date">{{ modified }}</span>
      <button v-if="!readonly" class="tw-note-remove" title="删除笔记" @click.stop="$emit('remove', task)">
        <TaskIcon name="trash" :size="13" />
      </button>
    </footer>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { TaskItem } from '../../types'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  task: TaskItem
  selected?: boolean
  showList?: boolean
  readonly?: boolean
}>()

defineEmits<{
  (event: 'open', task: TaskItem): void
  (event: 'pin', task: TaskItem): void
  (event: 'remove', task: TaskItem): void
}>()

const preview = computed(() => {
  const text = props.task.notes.replace(/\s+/g, ' ').trim()
  if (!text) return ''
  return text.length > 120 ? `${text.slice(0, 120)}…` : text
})

const modified = computed(() => {
  const date = new Date(props.task.modifiedAt)
  if (Number.isNaN(date.getTime())) return ''
  return `${date.getMonth() + 1}月${date.getDate()}日`
})
</script>
