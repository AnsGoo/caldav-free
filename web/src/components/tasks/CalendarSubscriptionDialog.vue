<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-calendar-subscription-dialog" role="dialog" aria-modal="true" aria-label="日历订阅">
      <header class="tw-dialog-head">
        <h2>日历订阅</h2>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')"><TaskIcon name="close" :size="16" /></button>
      </header>
      <div class="tw-dialog-body">
        <div class="tw-calendar-sub-form">
          <input v-model="name" class="tw-dialog-input" maxlength="120" placeholder="订阅名称，例如：公司节假日" />
          <input v-model="url" class="tw-dialog-input" maxlength="1000" placeholder="https://example.com/holidays.ics" />
          <div class="tw-calendar-sub-actions">
            <input v-model="color" class="tw-calendar-sub-color" type="color" title="订阅颜色" />
            <button class="tw-primary-button" :disabled="busy || !name.trim() || !url.trim()" @click="add">{{ busy ? '添加中…' : '添加订阅' }}</button>
          </div>
        </div>
        <p class="tw-modal-note">支持公开的 ICS / WebCal 地址。订阅内容会定期同步并作为只读日历显示；不会修改远程数据。</p>
        <div v-if="subscriptions.length" class="tw-calendar-sub-list">
          <article v-for="item in subscriptions" :key="item.id">
            <i :style="{ background: item.color }" />
            <div><strong>{{ item.name }}</strong><small>{{ item.url }}</small><em v-if="item.lastError">{{ item.lastError }}</em></div>
            <button class="tw-icon-button danger" title="删除订阅" @click="remove(item)"><TaskIcon name="trash" :size="14" /></button>
          </article>
        </div>
        <p v-else class="tw-calendar-sub-empty">还没有日历订阅。</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { CalendarSubscription } from '../../types'
import { createCalendarSubscription, deleteCalendarSubscription, fetchCalendarSubscriptions } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const emit = defineEmits<{ (event: 'close'): void; (event: 'changed'): void }>()
const name = ref('')
const url = ref('')
const color = ref('#f0a020')
const busy = ref(false)
const subscriptions = ref<CalendarSubscription[]>([])

async function load() {
  try {
    subscriptions.value = (await fetchCalendarSubscriptions()).subscriptions || []
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载日历订阅失败')
  }
}

async function add() {
  if (busy.value || !name.value.trim() || !url.value.trim()) return
  busy.value = true
  try {
    const { subscription } = await createCalendarSubscription({ name: name.value.trim(), url: url.value.trim(), color: color.value })
    subscriptions.value = [...subscriptions.value, subscription]
    name.value = ''
    url.value = ''
    emit('changed')
    Message.success('订阅已添加')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '添加订阅失败')
  } finally {
    busy.value = false
  }
}

async function remove(item: CalendarSubscription) {
  try {
    await deleteCalendarSubscription(item.id)
    subscriptions.value = subscriptions.value.filter((entry) => entry.id !== item.id)
    emit('changed')
    Message.success('订阅已删除')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '删除订阅失败')
  }
}

onMounted(load)
</script>
