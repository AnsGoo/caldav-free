<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-occurrence-dialog" role="dialog" aria-modal="true" aria-label="重复任务实例">
      <header class="tw-dialog-head">
        <h2>{{ task.postponed ? '顺延实例' : '重复实例' }}</h2>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')"><TaskIcon name="close" :size="16" /></button>
      </header>
      <div class="tw-dialog-body">
        <div class="tw-occurrence-title">
          <i :style="{ background: task.listColor || '#4772fa' }" />
          <div>
            <strong>{{ task.title }}</strong>
            <span>{{ task.listName }}</span>
          </div>
        </div>
        <dl class="tw-occurrence-meta">
          <div>
            <dt>{{ task.postponed ? '顺延至' : '实例时间' }}</dt>
            <dd>{{ occurrenceDate(task.due, task.allDay) }}</dd>
          </div>
          <div v-if="task.postponed && task.occurrence">
            <dt>原定时间</dt>
            <dd>{{ occurrenceDate(task.occurrence, task.allDay) }}</dd>
          </div>
          <div>
            <dt>重复规则</dt>
            <dd>{{ recurrenceLabel(task.recurrence) }}</dd>
          </div>
        </dl>
        <div class="tw-occurrence-actions">
          <button class="tw-primary-button" :disabled="busy" @click="$emit('complete')">
            {{ busy ? '处理中…' : '完成本次' }}
          </button>
          <button class="tw-ghost-button" :disabled="busy" @click="$emit('skip')">跳过本次</button>
          <button class="tw-ghost-button" :disabled="busy" @click="$emit('postpone')">顺延一天</button>
          <button class="tw-link-button" :disabled="busy" @click="$emit('open')">打开整个任务</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { TaskItem } from '../../types'
import { recurrenceLabel } from '../../tasks-utils'
import TaskIcon from './TaskIcon.vue'

defineProps<{ task: TaskItem; busy?: boolean }>()

function occurrenceDate(value?: string, allDay = false) {
  if (!value) return '未设置'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  if (allDay) {
    return date.toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'short' })
  }
  return date.toLocaleString('zh-CN', {
    year: 'numeric', month: 'long', day: 'numeric', weekday: 'short',
    hour: '2-digit', minute: '2-digit', hour12: false,
  })
}
defineEmits<{
  (event: 'close'): void
  (event: 'complete'): void
  (event: 'skip'): void
  (event: 'postpone'): void
  (event: 'open'): void
}>()
</script>
