<template>
  <article
    class="tw-row"
    :class="{ selected, done: task.completed, overdue, 'is-trash': trashMode, 'is-note': task.kind === 'NOTE', 'is-subtask': !!task.parentId, 'drag-target': dragTarget }"
    :draggable="draggable"
    @click="handleClick"
  >
    <button
      v-if="selectable"
      class="tw-select-check"
      :class="{ checked: selected }"
      :aria-label="selected ? '取消选择' : '选择任务'"
      @click.stop="$emit('select', task)"
    >
      <TaskIcon v-if="selected" name="check" :size="11" />
    </button>
    <span v-else-if="task.kind === 'NOTE'" class="tw-note-mark"><TaskIcon name="note" :size="15" /></span>
    <button
      v-else-if="!trashMode"
      class="tw-check"
      :class="{ checked: task.completed }"
      :aria-label="task.completed ? '标记为未完成' : '标记为完成'"
      @click.stop="$emit('toggle', task)"
    >
      <svg v-if="task.completed" viewBox="0 0 20 20" width="13" height="13" aria-hidden="true">
        <path d="m4.5 10.2 3.6 3.7 7.4-8" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </button>
    <span v-else class="tw-trash-mark"><TaskIcon name="trash" :size="15" /></span>

    <span v-if="task.priority && !trashMode && task.kind !== 'NOTE'" class="tw-priority-dot" :style="{ background: priorityColor }" />

    <div class="tw-row-body">
      <div class="tw-row-title">
        <span v-if="task.pinned && !trashMode" class="tw-row-pinned" title="已置顶">
          <TaskIcon name="pin" :size="12" />
        </span>
        <span class="tw-title-text">{{ task.title }}</span>
        <span
          v-for="tag in task.tags.slice(0, 3)"
          :key="tag"
          class="tw-mini-tag"
          :style="{ color: tagColor(tag, tagColors?.[tag]), background: tagTint(tagColor(tag, tagColors?.[tag])) }"
        >#{{ tag }}</span>
        <span v-if="task.recurrence && !trashMode" class="tw-row-flag" :title="recurrenceLabel(task.recurrence)">
          <TaskIcon name="repeat" :size="12" />
        </span>
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
      <div v-if="trashMode" class="tw-row-detail">
        <span class="tw-row-sub">{{ formatDeleted(task.deletedAt) }}</span>
      </div>
    </div>

    <div class="tw-row-meta">
      <span v-if="showList" class="tw-row-list">
        <i :style="{ background: task.listColor || '#4772fa' }" />
        {{ task.listName }}
      </span>
      <span v-if="task.assignee && task.kind !== 'NOTE'" class="tw-row-assignee" :title="`指派给 @${task.assignee}`">@{{ task.assignee }}</span>
      <span v-if="taskReminderOffsets(task).length && !trashMode && task.kind !== 'NOTE'" class="tw-row-bell" :title="taskReminderOffsets(task).map(reminderLabel).join('、')">
        <TaskIcon name="bell" :size="12" />
      </span>
      <span v-if="task.kind === 'NOTE'" class="tw-row-due">{{ noteDate }}</span>
      <span v-else-if="dueLabel && !trashMode" class="tw-row-due">{{ dueLabel }}</span>
    </div>

    <div v-if="trashMode" class="tw-trash-actions">
      <button class="tw-icon-button" title="恢复任务" @click.stop="$emit('restore', task)">
        <TaskIcon name="restore" :size="15" />
      </button>
      <button class="tw-icon-button" title="彻底删除" @click.stop="$emit('purge', task)">
        <TaskIcon name="trash" :size="15" />
      </button>
    </div>
    <button
      v-if="!trashMode && !selectable"
      class="tw-row-pin-toggle"
      :class="{ active: task.pinned }"
      :title="task.pinned ? '取消置顶' : '置顶任务'"
      @click.stop="$emit('pin', task)"
    >
      <TaskIcon name="pin" :size="14" />
    </button>
    <button v-if="!trashMode && !selectable" class="tw-row-remove" title="删除任务" @click.stop="$emit('remove', task)">
      <TaskIcon name="trash" :size="15" />
    </button>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { TaskItem } from '../../types'
import { PRIORITIES, formatDeleted, formatDue, isOverdue, recurrenceLabel, reminderLabel, taskReminderOffsets } from '../../tasks-utils'
import { tagColor, tagTint } from '../../tag-colors'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  task: TaskItem
  tagColors?: Record<string, string>
  selected: boolean
  showList?: boolean
  selectable?: boolean
  trashMode?: boolean
  draggable?: boolean
  dragTarget?: boolean
}>()

const emit = defineEmits<{
  (event: 'toggle', task: TaskItem): void
  (event: 'open', task: TaskItem): void
  (event: 'remove', task: TaskItem): void
  (event: 'pin', task: TaskItem): void
  (event: 'select', task: TaskItem): void
  (event: 'restore', task: TaskItem): void
  (event: 'purge', task: TaskItem): void
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
const noteDate = computed(() => {
  const date = new Date(props.task.modifiedAt)
  if (Number.isNaN(date.getTime())) return ''
  return `${date.getMonth() + 1}月${date.getDate()}日`
})

function handleClick() {
  if (props.trashMode) return
  if (props.selectable) {
    emit('select', props.task)
    return
  }
  emit('open', props.task)
}
</script>
