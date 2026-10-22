<template>
  <article
    class="tw-row"
    :class="{ selected, done: task.completed, overdue: overdue }"
    @click="$emit('open', task)"
  >
    <button
      class="tw-check"
      :class="{ checked: task.completed }"
      :aria-label="task.completed ? '标记为未完成' : '标记为完成'"
      @click.stop="$emit('toggle', task)"
    >
      <svg v-if="task.completed" viewBox="0 0 20 20" width="13" height="13" aria-hidden="true">
        <path d="m4.5 10.2 3.6 3.7 7.4-8" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </button>

    <span v-if="task.priority" class="tw-priority-dot" :style="{ background: priorityColor }" />

    <div class="tw-row-body">
      <div class="tw-row-title">
        <span class="tw-title-text">{{ task.title }}</span>
        <span v-for="tag in task.tags.slice(0, 3)" :key="tag" class="tw-mini-tag">#{{ tag }}</span>
      </div>
      <div v-if="hasDetails" class="tw-row-detail">
        <span v-if="task.checklist.length" class="tw-row-sub">
          {{ doneCount }}/{{ task.checklist.length }} 子任务
        </span>
        <span v-if="task.notes" class="tw-row-sub">
          <TaskIcon name="note" :size="12" />
          {{ notesPreview }}
        </span>
      </div>
    </div>

    <div class="tw-row-meta">
      <span v-if="showList" class="tw-row-list">
        <i :style="{ background: task.listColor || '#4772fa' }" />
        {{ task.listName }}
      </span>
      <span v-if="dueLabel" class="tw-row-due">{{ dueLabel }}</span>
    </div>

    <button class="tw-row-remove" title="删除任务" @click.stop="$emit('remove', task)">
      <TaskIcon name="trash" :size="15" />
    </button>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { TaskItem } from '../../types'
import { PRIORITIES, formatDue, isOverdue } from '../../tasks-utils'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ task: TaskItem; selected: boolean; showList?: boolean }>()
defineEmits<{
  (event: 'toggle', task: TaskItem): void
  (event: 'open', task: TaskItem): void
  (event: 'remove', task: TaskItem): void
}>()

const overdue = computed(() => isOverdue(props.task))
const dueLabel = computed(() => formatDue(props.task))
const priorityColor = computed(() => PRIORITIES.find((item) => item.value === props.task.priority)?.color || '#4772fa')
const doneCount = computed(() => props.task.checklist.filter((item) => item.done).length)
const notesPreview = computed(() => {
  const text = props.task.notes.replace(/\s+/g, ' ').trim()
  return text.length > 32 ? `${text.slice(0, 32)}…` : text
})
const hasDetails = computed(() => props.task.checklist.length > 0 || props.task.notes.trim().length > 0)
</script>
