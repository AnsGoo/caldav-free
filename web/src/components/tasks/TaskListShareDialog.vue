<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-share-dialog" role="dialog" aria-modal="true" aria-label="共享清单">
      <header class="tw-dialog-head">
        <h2>共享「{{ list.name }}」</h2>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="16" />
        </button>
      </header>
      <div class="tw-dialog-body tw-share-body">
        <p class="tw-share-hint">输入管理后台用户名，对方会在“共享给我”中看到这个清单。当前版本仅支持只读共享。</p>
        <form class="tw-share-form" @submit.prevent="addShare">
          <input v-model="username" class="tw-dialog-input" placeholder="用户名" autocomplete="off" />
          <select v-model="role" class="tw-dialog-input tw-share-role">
            <option value="viewer">只读</option>
            <option value="editor">可编辑</option>
          </select>
          <button class="tw-dialog-ok" :disabled="busy || !username.trim()">添加</button>
        </form>
        <div v-if="loading" class="tw-share-empty">加载中…</div>
        <div v-else-if="shares.length" class="tw-share-list">
          <div v-for="share in shares" :key="share.userId" class="tw-share-row">
            <span class="tw-avatar tw-avatar-sm">{{ (share.displayName || share.username).slice(0, 1).toUpperCase() }}</span>
            <span class="tw-share-person">
              <strong>{{ share.displayName || share.username }}</strong>
              <small>@{{ share.username }} · {{ share.role === 'editor' ? '可编辑' : '只读' }}</small>
            </span>
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
import type { TaskList, TaskListShare } from '../../types'
import { createTaskListShare, deleteTaskListShare, fetchTaskListShares } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ list: TaskList }>()
const emit = defineEmits<{
  (event: 'close'): void
  (event: 'changed'): void
}>()

const shares = ref<TaskListShare[]>([])
const username = ref('')
const role = ref<'viewer' | 'editor'>('viewer')
const loading = ref(true)
const busy = ref(false)
const error = ref('')

async function load() {
  loading.value = true
  error.value = ''
  try {
    const result = await fetchTaskListShares(props.list.id)
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
    const { share } = await createTaskListShare(props.list.id, name, role.value)
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

async function removeShare(share: TaskListShare) {
  if (busy.value) return
  busy.value = true
  error.value = ''
  try {
    await deleteTaskListShare(props.list.id, share.userId)
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
