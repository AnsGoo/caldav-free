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
        <div v-if="loading" class="tw-share-empty">加载中…</div>
        <button
          v-for="item in notifications"
          v-else
          :key="item.id"
          class="tw-notification-row"
          :class="{ unread: !item.read }"
          @click="open(item)"
        >
          <span class="tw-notification-dot" />
          <span class="tw-notification-copy">
            <strong>{{ item.title }}</strong>
            <span>{{ item.body }}</span>
            <small>{{ formatTime(item.createdAt) }}</small>
          </span>
        </button>
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
import { onMounted, ref } from 'vue'
import type { AppNotification } from '../../types'
import { fetchNotifications, markAllNotificationsRead, markNotificationRead } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const emit = defineEmits<{
  (event: 'close'): void
  (event: 'changed', unread: number): void
  (event: 'open', url: string): void
}>()

const notifications = ref<AppNotification[]>([])
const unread = ref(0)
const loading = ref(true)
const busy = ref(false)
const error = ref('')

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
