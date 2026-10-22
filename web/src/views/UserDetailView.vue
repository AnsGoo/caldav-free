<template>
  <AdminLayout :title="detail ? `用户 · ${detail.user.username}` : '用户'" subtitle="账号资料、日历集合与访问权限">
    <template #actions>
      <a-button @click="router.push('/users')">
        <template #icon><IconLeft /></template>
        返回用户
      </a-button>
    </template>

    <a-spin :loading="loading" class="page-spin">
      <template v-if="detail">
        <nav class="breadcrumb">
          <router-link to="/users">用户</router-link>
          <span>/</span>
          <span>{{ detail.user.username }}</span>
        </nav>

        <section class="detail-grid">
          <a-card :bordered="false" class="panel">
            <div class="panel-head">
              <div>
                <p class="eyebrow">Profile</p>
                <h2>账号资料</h2>
              </div>
              <a-tag v-if="detail.user.isAdmin" color="green">管理员</a-tag>
              <a-tag v-else>成员</a-tag>
            </div>

            <a-form :model="profile" layout="vertical">
              <div class="form-grid">
                <a-form-item label="用户名">
                  <a-input :model-value="detail.user.username" disabled />
                </a-form-item>
                <a-form-item label="显示名称">
                  <a-input v-model="profile.displayName" placeholder="显示名称" allow-clear />
                </a-form-item>
              </div>
              <a-form-item label="邮箱">
                <a-input v-model="profile.email" placeholder="name@example.com" allow-clear />
              </a-form-item>
              <a-form-item label="重置密码">
                <a-input-password v-model="profile.password" placeholder="留空则不修改" allow-clear />
                <template #extra>至少 8 位；修改后客户端需使用新密码重新认证</template>
              </a-form-item>
              <a-form-item>
                <a-checkbox v-model="profile.isAdmin">管理员权限</a-checkbox>
              </a-form-item>
              <div class="form-actions">
                <a-button type="primary" :loading="saving" @click="saveProfile">保存资料</a-button>
              </div>
            </a-form>
          </a-card>

          <aside class="stack">
            <a-card :bordered="false" class="panel">
              <p class="eyebrow">Account</p>
              <h2>概览</h2>
              <dl class="facts">
                <div><dt>用户 ID</dt><dd>#{{ detail.user.id }}</dd></div>
                <div><dt>注册时间</dt><dd>{{ formatDate(detail.user.createdAt) }}</dd></div>
                <div><dt>日历数量</dt><dd>{{ detail.calendars.length }}</dd></div>
                <div><dt>事件数量</dt><dd>{{ detail.user.objects || 0 }}</dd></div>
              </dl>
              <div class="copy-row compact">
                <div class="copy-field">
                  <span class="copy-label">Principal</span>
                  <code>/principals/{{ detail.user.username }}/</code>
                </div>
                <a-button size="small" @click="copy(`${origin}/principals/${detail.user.username}/`)">
                  <template #icon><IconCopy /></template>
                </a-button>
              </div>
            </a-card>

            <a-card v-if="!detail.isSelf" :bordered="false" class="panel danger-panel">
              <p class="eyebrow">Danger zone</p>
              <h2>删除用户</h2>
              <p class="muted">删除账号会同时移除其所有日历和事件，且无法恢复。</p>
              <a-button status="danger" long @click="removeUser">删除用户</a-button>
            </a-card>
          </aside>
        </section>

        <a-card :bordered="false" class="panel">
          <div class="panel-head">
            <div>
              <p class="eyebrow">Calendars</p>
              <h2>日历集合</h2>
            </div>
            <a-button type="primary" @click="openCalendar">
              <template #icon><IconPlus /></template>
              新建日历
            </a-button>
          </div>

          <div v-if="detail.calendars.length" class="calendar-grid">
            <button
              v-for="calendar in detail.calendars"
              :key="calendar.id"
              class="calendar-tile"
              type="button"
              @click="router.push(`/calendars/${calendar.id}`)"
            >
              <span class="color-dot" :style="{ background: calendar.color || '#3366CC' }" />
              <span class="calendar-tile-body">
                <strong>{{ calendar.displayName || calendar.slug }}</strong>
                <small>{{ calendar.slug }} · {{ calendar.eventCount || 0 }} 个事件</small>
              </span>
              <span class="tile-arrow">→</span>
            </button>
          </div>
          <a-empty v-else description="还没有日历" />
        </a-card>
      </template>
    </a-spin>

    <a-modal
      v-model:visible="calendarVisible"
      title="新建日历"
      :ok-loading="creatingCalendar"
      ok-text="创建"
      cancel-text="取消"
      @ok="createCalendar"
      @cancel="resetCalendar"
    >
      <a-form :model="calendarForm" layout="vertical">
        <a-form-item label="标识（URL）" required>
          <a-input v-model="calendarForm.slug" placeholder="work" allow-clear />
        </a-form-item>
        <a-form-item label="名称">
          <a-input v-model="calendarForm.displayName" placeholder="工作" allow-clear />
        </a-form-item>
        <a-form-item label="时区">
          <a-auto-complete v-model="calendarForm.timezone" :data="detail?.timezones || []" placeholder="Asia/Shanghai" />
        </a-form-item>
        <a-form-item label="颜色">
          <input v-model="calendarForm.color" class="color-input" type="color" />
        </a-form-item>
        <a-form-item label="组件">
          <a-checkbox-group v-model="calendarForm.components">
            <a-space direction="vertical">
              <a-checkbox value="VEVENT">事件 VEVENT</a-checkbox>
              <a-checkbox value="VTODO">待办 VTODO</a-checkbox>
              <a-checkbox value="VJOURNAL">日志 VJOURNAL</a-checkbox>
            </a-space>
          </a-checkbox-group>
        </a-form-item>
      </a-form>
    </a-modal>
  </AdminLayout>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import dayjs from 'dayjs'
import { Message, Modal } from '@arco-design/web-vue'
import { IconCopy, IconLeft, IconPlus } from '@arco-design/web-vue/es/icon'
import AdminLayout from '../layouts/AdminLayout.vue'
import { api } from '../api'
import { copyText } from '../auth'
import type { UserDetailData } from '../types'

const route = useRoute()
const router = useRouter()
const loading = ref(true)
const saving = ref(false)
const detail = ref<UserDetailData | null>(null)
const origin = computed(() => window.location.origin)

const profile = reactive({
  displayName: '',
  email: '',
  password: '',
  isAdmin: false,
})

const calendarVisible = ref(false)
const creatingCalendar = ref(false)
const calendarForm = reactive({
  slug: '',
  displayName: '',
  timezone: 'Asia/Shanghai',
  color: '#3366CC',
  components: ['VEVENT', 'VTODO', 'VJOURNAL'] as string[],
})

async function load() {
  loading.value = true
  try {
    detail.value = await api<UserDetailData>(`/users/${route.params.id}`)
    profile.displayName = detail.value.user.displayName
    profile.email = detail.value.user.email
    profile.isAdmin = detail.value.user.isAdmin
    profile.password = ''
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载失败')
  } finally {
    loading.value = false
  }
}

async function saveProfile() {
  saving.value = true
  try {
    await api(`/users/${route.params.id}`, {
      method: 'PATCH',
      body: JSON.stringify(profile),
    })
    Message.success('资料已更新')
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存失败')
  } finally {
    saving.value = false
  }
}

function openCalendar() {
  calendarForm.slug = ''
  calendarForm.displayName = ''
  calendarForm.timezone = 'Asia/Shanghai'
  calendarForm.color = '#3366CC'
  calendarForm.components = ['VEVENT', 'VTODO', 'VJOURNAL']
  calendarVisible.value = true
}

function resetCalendar() {
  calendarForm.slug = ''
  calendarForm.displayName = ''
}

async function createCalendar() {
  if (!calendarForm.slug) {
    Message.warning('请填写日历标识')
    return
  }
  if (!calendarForm.components.length) {
    Message.warning('至少选择一种组件')
    return
  }
  creatingCalendar.value = true
  try {
    await api(`/users/${route.params.id}/calendars`, {
      method: 'POST',
      body: JSON.stringify(calendarForm),
    })
    Message.success('日历已创建')
    calendarVisible.value = false
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建失败')
  } finally {
    creatingCalendar.value = false
  }
}

function removeUser() {
  if (!detail.value) return
  Modal.confirm({
    title: '删除用户',
    content: `确定删除 ${detail.value.user.username} 及其全部数据吗？`,
    okText: '删除',
    cancelText: '取消',
    okButtonProps: { status: 'danger' },
    async onOk() {
      await api(`/users/${detail.value!.user.id}`, { method: 'DELETE' })
      Message.success('用户已删除')
      router.push('/users')
    },
  })
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
