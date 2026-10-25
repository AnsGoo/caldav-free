<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-share-dialog" role="dialog" aria-modal="true" aria-label="共享笔记">
      <header class="tw-dialog-head">
        <h2>共享「{{ task.title || '无标题笔记' }}」</h2>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="16" />
        </button>
      </header>
      <div class="tw-dialog-body tw-share-body">
        <p class="tw-share-hint">输入管理后台用户名，对方会在“共享给我”中看到这篇笔记。可选择只读或可编辑权限。</p>
        <form class="tw-share-form" @submit.prevent="addShare">
          <a-input v-model="username" class="tw-share-name" placeholder="用户名" autocomplete="off" />
          <a-select v-model="role" class="tw-share-role">
            <a-option value="viewer">只读</a-option>
            <a-option value="editor">可编辑</a-option>
          </a-select>
          <button class="tw-dialog-ok" :disabled="busy || !username.trim()">添加</button>
        </form>
        <div v-if="loading" class="tw-share-empty">加载中…</div>
        <div v-else-if="shares.length" class="tw-share-list">
          <div v-for="share in shares" :key="share.userId" class="tw-share-row">
            <span class="tw-avatar tw-avatar-sm">{{ (share.displayName || share.username).slice(0, 1).toUpperCase() }}</span>
            <span class="tw-share-person">
              <strong>{{ share.displayName || share.username }}</strong>
              <small>@{{ share.username }}</small>
            </span>
            <a-select
              class="tw-share-role-select"
              :model-value="share.role"
              :disabled="busy"
              @change="(value) => updateShareRole(share, value)"
            >
              <a-option value="viewer">只读</a-option>
              <a-option value="editor">可编辑</a-option>
            </a-select>
            <button class="tw-icon-button" title="移除共享" :disabled="busy" @click="removeShare(share)">
              <TaskIcon name="close" :size="14" />
            </button>
          </div>
        </div>
        <p v-else class="tw-share-empty">还没有共享给任何人。</p>
        <p v-if="error" class="tw-reminder-warning">{{ error }}</p>
      </div>
      <footer class="tw-dialog-foot">
        <button class="tw-dialog-ok" @click="$emit('close')">完成</button>
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { TaskItem, TaskShare } from '../../types'
import { createTaskShare, deleteTaskShare, fetchTaskShares } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ task: TaskItem }>()
const emit = defineEmits<{
  (event: 'close'): void
  (event: 'changed'): void
}>()

const shares = ref<TaskShare[]>([])
const username = ref('')
const role = ref<'viewer' | 'editor'>('viewer')
const loading = ref(true)
const busy = ref(false)
const error = ref('')

async function load() {
  loading.value = true
  error.value = ''
  try {
    const result = await fetchTaskShares(props.task.id)
    shares.value = result.shares
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '加载共享失败'
  } finally {
    loading.value = false
  }
}

async function addShare() {
  const name = username.value.trim()
  if (!name || busy.value) return
  busy.value = true
  error.value = ''
  try {
    const { share } = await createTaskShare(props.task.id, { username: name, role: role.value })
    const index = shares.value.findIndex((item) => item.userId === share.userId)
    if (index >= 0) shares.value[index] = share
    else shares.value.push(share)
    username.value = ''
    emit('changed')
    Message.success(`已共享给 ${share.displayName || share.username}`)
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '共享失败'
  } finally {
    busy.value = false
  }
}

async function updateShareRole(share: TaskShare, value: unknown) {
  const nextRole = String(value) as 'viewer' | 'editor'
  if (nextRole === share.role) return
  busy.value = true
  error.value = ''
  try {
    const result = await createTaskShare(props.task.id, { username: share.username, role: nextRole })
    const index = shares.value.findIndex((item) => item.userId === share.userId)
    if (index >= 0) shares.value[index] = { ...shares.value[index], ...result.share }
    emit('changed')
    Message.success(nextRole === 'editor' ? '已改为可编辑' : '已改为只读')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '修改角色失败'
  } finally {
    busy.value = false
  }
}

async function removeShare(share: TaskShare) {
  if (busy.value) return
  busy.value = true
  error.value = ''
  try {
    await deleteTaskShare(props.task.id, share.userId)
    shares.value = shares.value.filter((item) => item.userId !== share.userId)
    emit('changed')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '移除共享失败'
  } finally {
    busy.value = false
  }
}

onMounted(load)
</script>
