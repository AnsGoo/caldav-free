<template>
  <AdminLayout title="用户与日历" subtitle="管理 principal、日历集合与访问凭据">
    <template #actions>
      <a-button @click="load" :loading="loading">
        <template #icon><IconRefresh /></template>
        刷新
      </a-button>
      <a-button type="primary" @click="openCreate">
        <template #icon><IconPlus /></template>
        新建用户
      </a-button>
    </template>

    <a-card :bordered="false" class="panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Directory</p>
          <h2>全部用户</h2>
        </div>
        <a-tag>{{ users.length }} 个账号</a-tag>
      </div>

      <a-spin :loading="loading">
        <a-table
          v-if="!isMobile && users.length"
          :data="users"
          :columns="columns"
          :pagination="false"
          row-key="id"
          :bordered="false"
          style="width: 100%"
        >
          <template #user="{ record }">
            <div class="user-cell">
              <span class="avatar avatar-sm">{{ initials(record.username) }}</span>
              <div>
                <strong>{{ record.username }}</strong>
                <small>{{ record.email || '未设置邮箱' }}</small>
              </div>
            </div>
          </template>
          <template #role="{ record }">
            <a-tag v-if="record.isAdmin" color="green">管理员</a-tag>
            <a-tag v-else>成员</a-tag>
          </template>
          <template #created="{ record }">
            {{ formatDate(record.createdAt) }}
          </template>
          <template #actions="{ record }">
            <a-space>
              <a-button type="text" size="small" @click="router.push(`/users/${record.id}`)">管理</a-button>
              <a-button
                v-if="record.id !== auth.user?.id"
                type="text"
                status="danger"
                size="small"
                @click="removeUser(record)"
              >
                删除
              </a-button>
            </a-space>
          </template>
        </a-table>

        <div v-if="isMobile && users.length" class="mobile-list">
          <article v-for="user in users" :key="user.id" class="mobile-card">
            <div class="mobile-card-head">
              <div class="user-cell">
                <span class="avatar">{{ initials(user.username) }}</span>
                <div>
                  <strong>{{ user.username }}</strong>
                  <small>{{ user.displayName || user.email || '未设置资料' }}</small>
                </div>
              </div>
              <a-tag v-if="user.isAdmin" color="green">管理员</a-tag>
              <a-tag v-else>成员</a-tag>
            </div>
            <div class="mobile-card-meta">
              <span>日历 {{ user.calendars || 0 }}</span>
              <span>事件 {{ user.objects || 0 }}</span>
              <span>创建于 {{ formatDate(user.createdAt) }}</span>
            </div>
            <div class="mobile-card-actions">
              <a-button size="small" @click="router.push(`/users/${user.id}`)">管理</a-button>
              <a-button
                v-if="user.id !== auth.user?.id"
                size="small"
                status="danger"
                @click="removeUser(user)"
              >
                删除
              </a-button>
            </div>
          </article>
        </div>

        <a-empty v-if="!users.length" description="还没有用户，先创建一个账号" />
      </a-spin>
    </a-card>

    <a-modal
      v-model:visible="createVisible"
      title="创建用户"
      :ok-loading="creating"
      ok-text="创建"
      cancel-text="取消"
      @ok="createUser"
      @cancel="resetCreate"
    >
      <a-form :model="createForm" layout="vertical">
        <a-form-item label="用户名" required>
          <a-input v-model="createForm.username" placeholder="例如 alice" allow-clear />
          <template #extra>小写字母、数字、点、下划线或连字符</template>
        </a-form-item>
        <a-form-item label="显示名称">
          <a-input v-model="createForm.displayName" placeholder="Alice" allow-clear />
        </a-form-item>
        <a-form-item label="邮箱">
          <a-input v-model="createForm.email" placeholder="alice@example.com" allow-clear />
        </a-form-item>
        <a-form-item label="初始密码" required>
          <a-input-password v-model="createForm.password" placeholder="至少 8 位" allow-clear />
        </a-form-item>
        <a-form-item>
          <a-checkbox v-model="createForm.isAdmin">管理员权限</a-checkbox>
        </a-form-item>
      </a-form>
    </a-modal>
  </AdminLayout>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import dayjs from 'dayjs'
import { Message, Modal } from '@arco-design/web-vue'
import type { TableColumnData } from '@arco-design/web-vue'
import { IconPlus, IconRefresh } from '@arco-design/web-vue/es/icon'
import AdminLayout from '../layouts/AdminLayout.vue'
import { api } from '../api'
import { useIsMobile } from '../useMobile'
import { auth, initials } from '../auth'
import type { User } from '../types'

const router = useRouter()
const loading = ref(true)
const users = ref<User[]>([])
const createVisible = ref(false)
const creating = ref(false)
const createForm = reactive({
  username: '',
  displayName: '',
  email: '',
  password: '',
  isAdmin: false,
})

const isMobile = useIsMobile()
const columns = computed<TableColumnData[]>(() => [
  { title: '用户', dataIndex: 'username', slotName: 'user' },
  { title: '角色', slotName: 'role', width: 80 },
  { title: '日历', dataIndex: 'calendars', width: 60 },
  ...(isMobile.value ? [] : [
    { title: '事件', dataIndex: 'objects', width: 60 },
    { title: '创建时间', slotName: 'created', width: 120 },
  ]),
  { title: '', slotName: 'actions', width: 110, align: 'right' },
])

async function load() {
  loading.value = true
  try {
    const data = await api<{ users: User[] }>('/users')
    users.value = data.users
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载失败')
  } finally {
    loading.value = false
  }
}

function openCreate() {
  resetCreate()
  createVisible.value = true
}

function resetCreate() {
  createForm.username = ''
  createForm.displayName = ''
  createForm.email = ''
  createForm.password = ''
  createForm.isAdmin = false
}

async function createUser() {
  if (!createForm.username || !createForm.password) {
    Message.warning('请填写用户名和密码')
    return
  }
  creating.value = true
  try {
    await api('/users', {
      method: 'POST',
      body: JSON.stringify(createForm),
    })
    Message.success('用户已创建')
    createVisible.value = false
    resetCreate()
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建失败')
  } finally {
    creating.value = false
  }
}

function removeUser(user: User) {
  Modal.confirm({
    title: '删除用户',
    content: `确定删除 ${user.username} 及其全部日历和事件吗？该操作不可撤销。`,
    okText: '删除',
    cancelText: '取消',
    okButtonProps: { status: 'danger' },
    async onOk() {
      await api(`/users/${user.id}`, { method: 'DELETE' })
      Message.success('用户已删除')
      await load()
    },
  })
}

function formatDate(value: string) {
  return value ? dayjs(value).format('YYYY-MM-DD') : '—'
}

onMounted(load)
</script>
