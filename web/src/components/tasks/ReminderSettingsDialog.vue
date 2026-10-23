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

        <p class="tw-reminder-note">
          后台提醒由 caldav-free 服务端定时检查任务，并通过浏览器推送服务发送。若浏览器完全退出，通知可能延迟到下次启动。
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
import { computed, onMounted, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import {
  deletePushSubscription,
  fetchPushPublicKey,
  fetchPushSubscriptions,
  savePushSubscription,
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

onMounted(() => {
  void refresh()
})
</script>
