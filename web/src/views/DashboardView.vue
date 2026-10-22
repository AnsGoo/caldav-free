<template>
  <AdminLayout title="控制台" subtitle="服务器概览、用户与日历状态">
    <template #actions>
      <a-button @click="load" :loading="loading">
        <template #icon><IconRefresh /></template>
        刷新
      </a-button>
    </template>

    <a-spin :loading="loading" class="page-spin">
      <template v-if="data">
        <section class="stat-grid">
          <article class="stat-card">
            <span class="stat-icon">U</span>
            <div>
              <strong>{{ data.stats.users }}</strong>
              <span>用户</span>
            </div>
          </article>
          <article class="stat-card">
            <span class="stat-icon">C</span>
            <div>
              <strong>{{ data.stats.calendars }}</strong>
              <span>日历</span>
            </div>
          </article>
          <article class="stat-card">
            <span class="stat-icon">E</span>
            <div>
              <strong>{{ data.stats.objects }}</strong>
              <span>事件对象</span>
            </div>
          </article>
        </section>

        <section class="dashboard-grid">
          <a-card :bordered="false" class="panel hero-panel">
            <p class="eyebrow">CalDAV endpoint</p>
            <h2>服务运行中</h2>
            <p class="muted">
              管理后台由 Vue 3 + Vite+ + Arco Design 构建。CalDAV 客户端使用独立账户密码同步，与管理后台登录互不影响。
            </p>
            <div class="copy-row">
              <div class="copy-field">
                <span class="copy-label">管理入口</span>
                <code>{{ origin }}/admin/</code>
              </div>
              <a-button size="small" @click="copy(`${origin}/admin/`)">
                <template #icon><IconCopy /></template>
                复制
              </a-button>
            </div>
            <div class="copy-row">
              <div class="copy-field">
                <span class="copy-label">健康检查</span>
                <code>{{ origin }}/healthz</code>
              </div>
              <a-button size="small" @click="copy(`${origin}/healthz`)">
                <template #icon><IconCopy /></template>
                复制
              </a-button>
            </div>
            <div class="copy-row">
              <div class="copy-field">
                <span class="copy-label">CalDAV 客户端地址</span>
                <code>{{ caldavBase }}/calendars/{{ auth.user?.username }}/</code>
              </div>
              <a-button size="small" @click="copy(`${caldavBase}/calendars/${auth.user?.username}/`)">
                <template #icon><IconCopy /></template>
                复制
              </a-button>
            </div>
            <p class="endpoint-note">
              手机端 CalDAV 同步地址请使用部署时的公网 HTTPS 地址。管理入口仅用于网页管理。
            </p>
          </a-card>

          <a-card :bordered="false" class="panel">
            <p class="eyebrow">Quick actions</p>
            <h2>快速操作</h2>
            <div class="quick-grid">
              <router-link class="quick-card" to="/users">
                <IconUserGroup :size="22" />
                <strong>用户管理</strong>
                <small>创建账号、重置密码</small>
              </router-link>
              <router-link class="quick-card" to="/users">
                <IconCalendar :size="22" />
                <strong>日历集合</strong>
                <small>时区、颜色与组件</small>
              </router-link>
              <a class="quick-card" :href="`${origin}/healthz`" target="_blank" rel="noreferrer">
                <IconCheckCircle :size="22" />
                <strong>健康检查</strong>
                <small>查看服务状态</small>
              </a>
            </div>
          </a-card>
        </section>

        <a-card :bordered="false" class="panel">
          <div class="panel-head">
            <div>
              <p class="eyebrow">Principals</p>
              <h2>用户概览</h2>
            </div>
            <a-button type="primary" @click="router.push('/users')">
              <template #icon><IconPlus /></template>
              管理用户
            </a-button>
          </div>
          <a-table
            v-if="!isMobile && data.users.length"
            :data="data.users"
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
                  <small>{{ record.displayName || record.email || '未设置资料' }}</small>
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
              <a-link @click="router.push(`/users/${record.id}`)">详情</a-link>
            </template>
          </a-table>

          <div v-if="isMobile && data.users.length" class="mobile-list">
            <article v-for="user in data.users" :key="user.id" class="mobile-card">
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
              </div>
              <div class="mobile-card-actions">
                <a-button size="small" @click="router.push(`/users/${user.id}`)">查看详情</a-button>
              </div>
            </article>
          </div>

          <a-empty v-if="!data.users.length" description="还没有用户" />
        </a-card>
      </template>
    </a-spin>
  </AdminLayout>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import dayjs from 'dayjs'
import { Message } from '@arco-design/web-vue'
import type { TableColumnData } from '@arco-design/web-vue'
import {
  IconCalendar,
  IconCheckCircle,
  IconCopy,
  IconPlus,
  IconRefresh,
  IconUserGroup,
} from '@arco-design/web-vue/es/icon'
import AdminLayout from '../layouts/AdminLayout.vue'
import { api } from '../api'
import { useIsMobile } from '../useMobile'
import { auth, copyText, initials } from '../auth'
import type { DashboardData } from '../types'

const router = useRouter()
const loading = ref(true)
const data = ref<DashboardData | null>(null)
const origin = computed(() => window.location.origin)
const caldavBase = computed(() => auth.caldavUrl || origin.value)

const isMobile = useIsMobile()
const columns = computed<TableColumnData[]>(() => [
  { title: '用户', dataIndex: 'username', slotName: 'user' },
  { title: '角色', slotName: 'role', width: 80 },
  { title: '日历', dataIndex: 'calendars', width: 60 },
  ...(isMobile.value ? [] : [
    { title: '事件', dataIndex: 'objects', width: 60 },
    { title: '创建时间', slotName: 'created', width: 120 },
  ]),
  { title: '', slotName: 'actions', width: 70, align: 'right' },
])

async function load() {
  loading.value = true
  try {
    data.value = await api<DashboardData>('/dashboard')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载失败')
  } finally {
    loading.value = false
  }
}

async function copy(text: string) {
  await copyText(text)
  Message.success('已复制')
}

function formatDate(value: string) {
  return value ? dayjs(value).format('YYYY-MM-DD') : '—'
}

onMounted(load)
</script>
