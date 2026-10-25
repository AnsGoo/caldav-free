<template>
  <div class="app-shell">
    <aside class="sidebar">
      <router-link class="brand" to="/">
        <span class="brand-mark">
          <svg viewBox="0 0 32 32" width="30" height="30" aria-hidden="true">
            <path d="M8 10.5h16M8 16h11M8 21.5h13" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" />
            <circle cx="24" cy="23" r="2.2" fill="currentColor" />
          </svg>
        </span>
        <span class="brand-name">caldav<em>free</em></span>
      </router-link>

      <nav class="nav">
        <router-link class="nav-item" :class="{ active: String(route.name || '').startsWith('tasks') }" to="/tasks">
          <IconCheckSquare :size="18" />
          <span>任务工作台</span>
        </router-link>
        <router-link class="nav-item" :class="{ active: route.name === 'dashboard' }" to="/dashboard">
          <IconDashboard :size="18" />
          <span>控制台</span>
        </router-link>
        <router-link class="nav-item" :class="{ active: route.name === 'users' || route.name === 'user' || route.name === 'calendar' || route.name === 'event-edit' }" to="/users">
          <IconUserGroup :size="18" />
          <span>用户与日历</span>
        </router-link>
      </nav>

      <div class="sidebar-foot">
        <div class="account">
          <span class="avatar">{{ initials(auth.user?.username || '') }}</span>
          <span class="account-meta">
            <strong>{{ auth.user?.username }}</strong>
            <small>管理员</small>
          </span>
        </div>
        <a-button class="logout-btn" long @click="handleLogout">退出登录</a-button>
      </div>
    </aside>

    <main class="main">
      <header class="page-head">
        <div class="page-heading">
          <p class="eyebrow">caldav-free · 管理后台</p>
          <h1>{{ title }}</h1>
          <p v-if="subtitle" class="muted page-subtitle">{{ subtitle }}</p>
        </div>
        <div class="page-actions">
          <slot name="actions" />
        </div>
      </header>

      <slot />

      <footer class="page-foot">
        <span>caldav-free</span>
        <span>CalDAV · WebDAV · RFC 4791 / 4918 / 6578</span>
      </footer>
    </main>
  </div>
</template>

<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router'
import { IconCheckSquare, IconDashboard, IconUserGroup } from '@arco-design/web-vue/es/icon'
import { Message } from '@arco-design/web-vue'
import { auth, initials, logout } from '../auth'

defineProps<{ title: string; subtitle?: string }>()

const route = useRoute()
const router = useRouter()

async function handleLogout() {
  try {
    await logout()
    router.push('/login')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '退出失败')
  }
}
</script>
