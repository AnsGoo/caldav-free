<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div
      class="tw-dialog tw-reminder-dialog"
      role="dialog"
      aria-modal="true"
      aria-label="提醒设置"
      @keydown.esc="$emit('close')"
    >
      <header class="tw-dialog-head">
        <h2>提醒设置</h2>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="16" />
        </button>
      </header>

      <div class="tw-dialog-body tw-reminder-body">
        <section class="tw-reminder-card">
          <span class="tw-reminder-icon"><TaskIcon name="bell" :size="18" /></span>
          <div class="tw-reminder-main">
            <div class="tw-reminder-title">
              <h3>页面内提醒</h3>
              <span class="tw-reminder-badge" :class="{ on: browserEnabled }">{{ browserEnabled ? '已开启' : '未开启' }}</span>
            </div>
            <p>前端每 30 秒检查一次到期提醒，适合保持工作台页面打开时使用。</p>
            <button class="tw-reminder-action" @click="$emit('toggle-browser')">
              {{ browserEnabled ? '关闭页面内提醒' : '开启页面内提醒' }}
            </button>
          </div>
        </section>

        <section class="tw-reminder-card">
          <span class="tw-reminder-icon"><TaskIcon name="sparkles" :size="18" /></span>
          <div class="tw-reminder-main">
            <div class="tw-reminder-title">
              <h3>后台推送</h3>
              <span class="tw-reminder-badge" :class="{ on: subscribed }">{{ subscribed ? '本设备已订阅' : '未订阅' }}</span>
            </div>
            <p>服务器按提醒时间投递 Web Push，页面关闭后仍可收到；浏览器需要保持运行。</p>
            <p v-if="serverCount" class="tw-reminder-meta">服务端已登记 {{ serverCount }} 台设备</p>
            <p v-if="!secure" class="tw-reminder-warning">后台推送需要 HTTPS 或 localhost 访问。</p>
            <p v-else-if="!supported" class="tw-reminder-warning">当前浏览器不支持 Web Push。</p>
            <div class="tw-reminder-actions">
              <button
                class="tw-reminder-action primary"
                :disabled="busy || !secure || !supported"
                @click="subscribed ? disablePush() : enablePush()"
              >
                {{ busy ? '处理中…' : subscribed ? '关闭本设备后台推送' : '开启后台推送' }}
              </button>
              <button v-if="supported && secure" class="tw-reminder-action" :disabled="busy" @click="sendTest">
                测试本地通知
              </button>
            </div>
          </div>
        </section>

        <section class="tw-reminder-card">
          <span class="tw-reminder-icon"><TaskIcon name="mail" :size="18" /></span>
          <div class="tw-reminder-main">
            <div class="tw-reminder-title">
              <h3>邮件提醒</h3>
              <span class="tw-reminder-badge" :class="{ on: email.enabled }">{{ email.enabled ? '已开启' : '未开启' }}</span>
            </div>
            <p>服务端在提醒时刻通过 SMTP 发送邮件。收件人使用当前账号邮箱。</p>
            <p v-if="email.recipientEmail" class="tw-reminder-meta">收件人：{{ email.recipientEmail }}</p>
            <p v-else class="tw-reminder-warning">当前账号没有邮箱，请先在管理后台用户资料中填写。</p>

            <div class="tw-reminder-form">
              <label class="tw-reminder-check">
                <input v-model="email.enabled" type="checkbox" />
                <span>启用邮件提醒</span>
              </label>
              <div class="tw-reminder-grid">
                <label class="tw-reminder-field">
                  <span>SMTP 服务器</span>
                  <input v-model="email.host" class="tw-dialog-input" placeholder="smtp.example.com" />
                </label>
                <label class="tw-reminder-field tw-reminder-field-sm">
                  <span>端口</span>
                  <input v-model.number="email.port" class="tw-dialog-input" type="number" min="1" max="65535" />
                </label>
              </div>
              <div class="tw-reminder-grid">
                <label class="tw-reminder-field">
                  <span>用户名</span>
                  <input v-model="email.username" class="tw-dialog-input" autocomplete="username" placeholder="可选" />
                </label>
                <label class="tw-reminder-field">
                  <span>密码 / 授权码</span>
                  <input
                    v-model="email.password"
                    class="tw-dialog-input"
                    type="password"
                    autocomplete="new-password"
                    :placeholder="email.passwordSet ? '已保存，留空不修改' : '可选'"
                  />
                </label>
              </div>
              <div class="tw-reminder-grid">
                <label class="tw-reminder-field">
                  <span>发件人</span>
                  <input v-model="email.from" class="tw-dialog-input" placeholder="CalDAV <caldav@example.com>" />
                </label>
                <label class="tw-reminder-field">
                  <span>加密方式</span>
                  <select v-model="email.security" class="tw-dialog-input">
                    <option value="starttls">STARTTLS（587）</option>
                    <option value="tls">SSL/TLS（465）</option>
                    <option value="none">无加密</option>
                  </select>
                </label>
              </div>
              <label v-if="email.passwordSet" class="tw-reminder-check">
                <input v-model="email.clearPassword" type="checkbox" />
                <span>清除已保存的密码</span>
              </label>
              <div class="tw-reminder-actions">
                <button class="tw-reminder-action primary" :disabled="emailBusy" @click="saveEmail">
                  {{ emailBusy ? '保存中…' : '保存邮件设置' }}
                </button>
                <button class="tw-reminder-action" :disabled="emailTestBusy || !email.enabled" @click="sendTestEmail">
                  {{ emailTestBusy ? '发送中…' : '发送测试邮件' }}
                </button>
              </div>
            </div>
          </div>
        </section>

        <p class="tw-reminder-note">
          后台提醒由 caldav-free 服务端定时检查任务，并通过浏览器推送服务或 SMTP 发送。若浏览器完全退出，通知可能延迟到下次启动。
        </p>
        <p v-if="message" class="tw-reminder-warning">{{ message }}</p>
      </div>

      <footer class="tw-dialog-foot">
        <button class="tw-dialog-ok" @click="$emit('close')">完成</button>
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import {
  deletePushSubscription,
  fetchEmailSettings,
  fetchPushPublicKey,
  fetchPushSubscriptions,
  saveEmailSettings,
  savePushSubscription,
  testEmail,
} from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

defineProps<{ browserEnabled: boolean }>()
defineEmits<{
  (event: 'toggle-browser'): void
  (event: 'close'): void
}>()

const supported = computed(
  () => 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window,
)
const secure = window.isSecureContext
const base = import.meta.env.BASE_URL
const busy = ref(false)
const subscribed = ref(false)
const serverCount = ref(0)
const message = ref('')
const emailBusy = ref(false)
const emailTestBusy = ref(false)
const email = reactive({
  enabled: false,
  host: '',
  port: 587,
  username: '',
  password: '',
  from: '',
  security: 'starttls' as 'starttls' | 'tls' | 'none',
  passwordSet: false,
  recipientEmail: '',
  clearPassword: false,
})

function base64Key(value: string) {
  const padding = '='.repeat((4 - (value.length % 4)) % 4)
  const normalized = (value + padding).replace(/-/g, '+').replace(/_/g, '/')
  const raw = atob(normalized)
  const bytes = new Uint8Array(raw.length)
  for (let index = 0; index < raw.length; index += 1) bytes[index] = raw.charCodeAt(index)
  return bytes
}

async function registration() {
  let current = await navigator.serviceWorker.getRegistration(base)
  if (!current) {
    current = await navigator.serviceWorker.register(`${base}sw.js`, { scope: base })
  }
  await navigator.serviceWorker.ready
  return current
}

async function refresh() {
  try {
    const status = await fetchPushSubscriptions()
    serverCount.value = status.count
  } catch {
    /* status is best-effort */
  }
  if (!supported.value) return
  try {
    const current = await navigator.serviceWorker.getRegistration(base)
    const subscription = await current?.pushManager.getSubscription()
    subscribed.value = Boolean(subscription)
    if (subscription && Notification.permission === 'granted') {
      await savePushSubscription(subscription.toJSON())
    }
  } catch {
    /* ignore stale subscriptions */
  }
}

async function enablePush() {
  if (!supported.value || !secure) return
  busy.value = true
  message.value = ''
  try {
    let permission = Notification.permission
    if (permission === 'default') permission = await Notification.requestPermission()
    if (permission !== 'granted') {
      message.value = '未获得通知权限，请在浏览器站点设置中允许通知。'
      return
    }
    const { publicKey } = await fetchPushPublicKey()
    const current = await registration()
    const existing = await current.pushManager.getSubscription()
    const subscription =
      existing ||
      (await current.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: base64Key(publicKey),
      }))
    await savePushSubscription(subscription.toJSON())
    subscribed.value = true
    await refresh()
    Message.success('已开启后台推送')
  } catch (error) {
    message.value = error instanceof Error ? error.message : '开启后台推送失败'
    Message.error(message.value)
  } finally {
    busy.value = false
  }
}

async function disablePush() {
  busy.value = true
  message.value = ''
  try {
    const current = await navigator.serviceWorker.getRegistration(base)
    const subscription = await current?.pushManager.getSubscription()
    if (subscription) {
      const endpoint = subscription.endpoint
      await subscription.unsubscribe()
      await deletePushSubscription(endpoint)
    }
    subscribed.value = false
    await refresh()
    Message.success('已关闭本设备后台推送')
  } catch (error) {
    message.value = error instanceof Error ? error.message : '关闭后台推送失败'
    Message.error(message.value)
  } finally {
    busy.value = false
  }
}

async function sendTest() {
  try {
    const current = await registration()
    await current.showNotification('测试提醒', {
      body: '通知权限正常，服务器到期提醒会以同样方式显示。',
      tag: 'caldav-task-test',
    })
    Message.success('已发送测试通知')
  } catch (error) {
    message.value = error instanceof Error ? error.message : '测试通知发送失败'
  }
}

async function loadEmail() {
  try {
    const settings = await fetchEmailSettings()
    email.enabled = settings.enabled
    email.host = settings.host
    email.port = settings.port || 587
    email.username = settings.username
    email.from = settings.from
    email.security = settings.security || 'starttls'
    email.password = ''
    email.passwordSet = settings.passwordSet
    email.recipientEmail = settings.recipientEmail
    email.clearPassword = false
  } catch (error) {
    message.value = error instanceof Error ? error.message : '读取邮件设置失败'
  }
}

async function saveEmail() {
  emailBusy.value = true
  message.value = ''
  try {
    const settings = await saveEmailSettings({
      enabled: email.enabled,
      host: email.host,
      port: email.port,
      username: email.username,
      password: email.password,
      clearPassword: email.clearPassword,
      from: email.from,
      security: email.security,
    })
    email.enabled = settings.enabled
    email.host = settings.host
    email.port = settings.port || 587
    email.username = settings.username
    email.from = settings.from
    email.security = settings.security || 'starttls'
    email.password = ''
    email.passwordSet = settings.passwordSet
    email.recipientEmail = settings.recipientEmail
    email.clearPassword = false
    Message.success('邮件设置已保存')
  } catch (error) {
    message.value = error instanceof Error ? error.message : '保存邮件设置失败'
    Message.error(message.value)
  } finally {
    emailBusy.value = false
  }
}

async function sendTestEmail() {
  emailTestBusy.value = true
  message.value = ''
  try {
    const result = await testEmail()
    Message.success(`测试邮件已发送到 ${result.to}`)
  } catch (error) {
    message.value = error instanceof Error ? error.message : '测试邮件发送失败'
    Message.error(message.value)
  } finally {
    emailTestBusy.value = false
  }
}

onMounted(() => {
  void refresh()
  void loadEmail()
})
</script>
