<template>
  <div class="login-page">
    <div class="login-art">
      <div class="login-grid" />
      <div class="login-quote">
        <p class="eyebrow">self-hosted calendar</p>
        <h2>你的日程，<br />只属于你。</h2>
        <p>标准 CalDAV 服务端，兼容 Apple 日历、Thunderbird、DAVx⁵ 与所有遵循 RFC 4791 的客户端。</p>
        <ul class="tick-list">
          <li>CalDAV + WebDAV Sync</li>
          <li>重复事件与时区展开</li>
          <li>Vue + Arco Design 管理后台</li>
        </ul>
      </div>
    </div>

    <main class="login-panel">
      <div class="login-card">
        <a class="brand brand-dark" href="/">
          <span class="brand-mark">
            <svg viewBox="0 0 32 32" width="30" height="30" aria-hidden="true">
              <path d="M8 10.5h16M8 16h11M8 21.5h13" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" />
              <circle cx="24" cy="23" r="2.2" fill="currentColor" />
            </svg>
          </span>
          <span class="brand-name">caldav<em>free</em></span>
        </a>
        <h1>管理后台</h1>
        <p class="muted">使用管理员账号登录，管理用户、日历与事件。</p>

        <a-alert v-if="error" type="error" :show-icon="true" class="login-alert">{{ error }}</a-alert>

        <form class="login-form" @submit.prevent="submit">
          <label class="field">
            <span>用户名</span>
            <a-input v-model="username" size="large" placeholder="admin" autocomplete="username" allow-clear />
          </label>
          <label class="field">
            <span>密码</span>
            <a-input-password v-model="password" size="large" placeholder="请输入密码" autocomplete="current-password" allow-clear />
          </label>
          <a-button type="primary" size="large" long :loading="loading" html-type="submit">登录</a-button>
        </form>

        <p class="login-note">
          CalDAV 客户端请使用 Basic Auth 连接，无需登录此页面。公网入口已启用 HTTPS。
        </p>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { login } from '../auth'

const router = useRouter()
const username = ref('admin')
const password = ref('')
const loading = ref(false)
const error = ref('')

async function submit() {
  error.value = ''
  if (!username.value || !password.value) {
    error.value = '请输入用户名和密码'
    return
  }
  loading.value = true
  try {
    await login(username.value, password.value)
    router.push('/')
  } catch (e) {
    error.value = e instanceof Error ? e.message : '登录失败'
  } finally {
    loading.value = false
  }
}
</script>
