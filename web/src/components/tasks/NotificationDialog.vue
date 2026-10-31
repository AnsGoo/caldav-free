<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-notification-dialog" role="dialog" aria-modal="true" aria-label="通知">
      <header class="tw-dialog-head">
        <h2>通知</h2>
        <div class="tw-notification-head-actions">
          <button v-if="unread" class="tw-notification-readall" :disabled="busy" @click="readAll">全部已读</button>
          <button class="tw-icon-button" title="关闭" @click="$emit('close')">
            <TaskIcon name="close" :size="16" />
          </button>
        </div>
      </header>
      <div class="tw-dialog-body tw-notification-body">
        <div class="tw-notification-tabs">
          <button :class="{ active: filter === 'all' }" @click="filter = 'all'">全部</button>
          <button :class="{ active: filter === 'unread' }" @click="filter = 'unread'">未读</button>
          <button :class="{ active: filter === 'task' }" @click="filter = 'task'">任务</button>
          <button :class="{ active: filter === 'event' }" @click="filter = 'event'">日程</button>
        </div>
        <div v-if="loading" class="tw-share-empty">加载中…</div>
        <div
          v-for="item in visibleNotifications"
          v-else
          :key="item.id"
          class="tw-notification-row"
          :class="{ unread: !item.read }"
          role="button"
          tabindex="0"
          @click="open(item)"
          @keydown.enter="open(item)"
        >
          <span class="tw-notification-dot" />
          <span class="tw-notification-copy">
            <strong>{{ item.title }}</strong>
            <span>{{ item.body }}</span>
            <small>{{ formatTime(item.createdAt) }}</small>
          </span>
          <span v-if="item.type === 'event' || item.type === 'task'" class="tw-notification-actions" @click.stop>
            <button
              v-if="item.type === 'task'"
              class="tw-notification-snooze"
              :disabled="completing === item.id || completedTaskIds.has(item.id)"
              @click="completeTask(item)"
            >
              {{
                completing === item.id
                  ? '处理中…'
                  : completedTaskIds.has(item.id)
                    ? '已完成'
                    : '完成'
              }}
            </button>
            <a-select
              class="tw-notification-snooze-select"
              :model-value="snoozeMinutes[item.id] || 10"
              size="small"
              @change="(value) => setSnoozeMinutes(item.id, value)"
            >
              <a-option :value="10">10 分钟</a-option>
              <a-option :value="30">30 分钟</a-option>
              <a-option :value="60">1 小时</a-option>
              <a-option :value="1440">1 天</a-option>
            </a-select>
            <button
              class="tw-notification-snooze"
              :disabled="snoozing === item.id"
              @click="snooze(item)"
            >
              {{ snoozing === item.id ? '处理中…' : '稍后' }}
            </button>
          </span>
        </div>
        <div v-if="!loading && !notifications.length" class="tw-notification-empty">
          <TaskIcon name="bell" :size="24" />
          <p>暂时没有新通知</p>
        </div>
        <p v-if="error" class="tw-reminder-warning">{{ error }}</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { AppNotification } from '../../types'
import { deleteNotification, fetchNotifications, markAllNotificationsRead, markNotificationRead, snoozeEventNotification, updateTask } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const emit = defineEmits<{
  (event: 'close'): void
  (event: 'changed', unread: number): void
  (event: 'open', url: string): void
  (event: 'task-completed', taskId: number): void
}>()

const notifications = ref<AppNotification[]>([])
const unread = ref(0)
const loading = ref(true)
const busy = ref(false)
const snoozing = ref(0)
const snoozeMinutes = ref<Record<number, number>>({})
const completing = ref(0)
const completedTaskIds = ref<Set<number>>(new Set())
const filter = ref<'all' | 'unread' | 'task' | 'event'>('all')
const error = ref('')
const visibleNotifications = computed(() => {
  if (filter.value === 'all') return notifications.value
  if (filter.value === 'unread') return notifications.value.filter((item) => !item.read)
  return notifications.value.filter((item) => item.type === filter.value)
})

function formatTime(value: string) {
  const time = new Date(value).getTime()
  const diff = Date.now() - time
  if (diff < 60000) return '刚刚'
  if (diff < 3600000) return `${Math.floor(diff / 60000)} 分钟前`
  if (diff < 86400000) return `${Math.floor(diff / 3600000)} 小时前`
  return new Date(value).toLocaleDateString('zh-CN')
}

async function load() {
  loading.value = true
  try {
    const data = await fetchNotifications()
    notifications.value = data.notifications
    unread.value = data.unread
    emit('changed', data.unread)
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '加载通知失败'
  } finally {
    loading.value = false
  }
}

async function open(item: AppNotification) {
  if (!item.read) {
    try {
      const result = await markNotificationRead(item.id)
      item.read = true
      unread.value = result.unread
      emit('changed', result.unread)
    } catch {
      /* opening the task is more important than the read marker */
    }
  }
  if (item.url) emit('open', item.url)
  else emit('close')
}

function setSnoozeMinutes(id: number, next: unknown) {
  const value = Number(next)
  snoozeMinutes.value = { ...snoozeMinutes.value, [id]: value }
}

async function completeTask(item: AppNotification) {
  if (
    completing.value ||
    completedTaskIds.value.has(item.id) ||
    item.type !== 'task' ||
    !item.taskId
  ) return
  completing.value = item.id
  try {
    const { task: updated } = await updateTask(item.taskId, { completed: true })
    completedTaskIds.value = new Set([...completedTaskIds.value, item.id])
    try {
      const result = await deleteNotification(item.id)
      notifications.value = notifications.value.filter(
        (notification) => notification.id !== item.id,
      )
      unread.value = result.unread
      emit('changed', result.unread)
    } catch {
      // Deleting is best-effort; at least keep the row marked as handled.
      const wasUnread = !item.read
      item.read = true
      await markNotificationRead(item.id).catch(() => {})
      if (wasUnread) unread.value = Math.max(0, unread.value - 1)
      emit('changed', unread.value)
    }
    emit('task-completed', item.taskId)
    // Recurring tasks advance to the next occurrence instead of completing.
    Message.success(updated.recurrence ? '已完成本次' : '任务已完成')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '完成任务失败'
  } finally {
    completing.value = 0
  }
}

async function snooze(item: AppNotification) {
  if (snoozing.value || (item.type !== 'event' && item.type !== 'task')) return
  const minutes = snoozeMinutes.value[item.id] || 10
  snoozing.value = item.id
  try {
    const result = await snoozeEventNotification(item.id, minutes)
    item.read = true
    unread.value = result.unread
    emit('changed', result.unread)
    const label = minutes >= 1440 ? '1 天' : minutes >= 60 ? `${minutes / 60} 小时` : `${minutes} 分钟`
    Message.success(`已安排 ${label}后提醒`)
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '稍后提醒失败'
  } finally {
    snoozing.value = 0
  }
}

async function readAll() {
  busy.value = true
  try {
    const result = await markAllNotificationsRead()
    notifications.value = notifications.value.map((item) => ({ ...item, read: true }))
    unread.value = result.unread
    emit('changed', result.unread)
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '操作失败'
  } finally {
    busy.value = false
  }
}

onMounted(load)
</script>
