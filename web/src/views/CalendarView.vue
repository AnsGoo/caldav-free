<template>
  <AdminLayout :title="detail ? (detail.calendar.displayName || detail.calendar.slug) : '日历'" subtitle="事件、时区与日历属性">
    <template #actions>
      <a-button @click="router.push(`/users/${detail?.owner.id || ''}`)">
        <template #icon><IconLeft /></template>
        所属用户
      </a-button>
      <a-button @click="load" :loading="loading">
        <template #icon><IconRefresh /></template>
        刷新
      </a-button>
    </template>

    <a-spin :loading="loading" class="page-spin">
      <template v-if="detail">
        <nav class="breadcrumb">
          <router-link to="/users">用户</router-link>
          <span>/</span>
          <router-link :to="`/users/${detail.owner.id}`">{{ detail.owner.username }}</router-link>
          <span>/</span>
          <span>{{ detail.calendar.slug }}</span>
        </nav>

        <section class="calendar-layout">
          <div class="stack">
            <a-card :bordered="false" class="panel">
              <div class="panel-head">
                <div>
                  <p class="eyebrow">Events</p>
                  <h2>{{ detail.calendar.displayName || detail.calendar.slug }}</h2>
                </div>
                <a-space>
                  <a-tag>{{ detail.events.length }} 个对象</a-tag>
                  <a-button type="primary" @click="openEvent">
                    <template #icon><IconPlus /></template>
                    新建事件
                  </a-button>
                </a-space>
              </div>

              <div class="copy-row compact">
                <div class="copy-field">
                  <span class="copy-label">Calendar Home</span>
                  <code>{{ origin }}/calendars/{{ detail.owner.username }}/{{ detail.calendar.slug }}/</code>
                </div>
                <a-button size="small" @click="copy(`${origin}/calendars/${detail.owner.username}/${detail.calendar.slug}/`)">
                  <template #icon><IconCopy /></template>
                </a-button>
              </div>

              <a-table
                v-if="detail.events.length"
                :data="detail.events"
                :columns="eventColumns"
                :pagination="false"
                row-key="href"
                :bordered="false"
              >
                <template #event="{ record }">
                  <div class="event-cell">
                    <strong>{{ record.summary }}</strong>
                    <small>{{ record.location || record.componentType }}</small>
                  </div>
                </template>
                <template #start="{ record }">
                  {{ record.allDay ? formatDay(record.start) : formatDateTime(record.start) }}
                </template>
                <template #end="{ record }">
                  {{ record.allDay ? formatDay(record.end) : formatDateTime(record.end) }}
                </template>
                <template #type="{ record }">
                  <a-space>
                    <a-tag v-if="record.recurring" color="arcoblue">重复</a-tag>
                    <a-tag v-else>单次</a-tag>
                    <a-tag v-if="record.allDay">全天</a-tag>
                  </a-space>
                </template>
                <template #actions="{ record }">
                  <a-space>
                    <a-button type="text" size="small" @click="editEvent(record)">编辑</a-button>
                    <a-button type="text" status="danger" size="small" @click="removeEvent(record)">删除</a-button>
                  </a-space>
                </template>
              </a-table>
              <a-empty v-else description="还没有事件，创建第一条日程" />
            </a-card>

            <a-card :bordered="false" class="panel">
              <div class="panel-head">
                <div>
                  <p class="eyebrow">New event</p>
                  <h2>创建事件</h2>
                </div>
              </div>
              <a-form :model="eventForm" layout="vertical">
                <a-form-item label="标题" required>
                  <a-input v-model="eventForm.summary" placeholder="团队周会" allow-clear />
                </a-form-item>
                <div class="form-grid">
                  <a-form-item label="地点">
                    <a-input v-model="eventForm.location" placeholder="会议室 / 线上" allow-clear />
                  </a-form-item>
                  <a-form-item label="全天事件">
                    <a-switch v-model="eventForm.allDay" />
                  </a-form-item>
                </div>

                <div v-if="!eventForm.allDay" class="form-grid">
                  <a-form-item label="开始">
                    <a-date-picker
                      v-model="eventForm.startTime"
                      show-time
                      format="YYYY-MM-DD HH:mm"
                      value-format="YYYY-MM-DDTHH:mm"
                      style="width: 100%"
                    />
                  </a-form-item>
                  <a-form-item label="结束">
                    <a-date-picker
                      v-model="eventForm.endTime"
                      show-time
                      format="YYYY-MM-DD HH:mm"
                      value-format="YYYY-MM-DDTHH:mm"
                      style="width: 100%"
                    />
                  </a-form-item>
                </div>
                <div v-else class="form-grid">
                  <a-form-item label="开始日期">
                    <a-date-picker v-model="eventForm.startDate" format="YYYY-MM-DD" value-format="YYYY-MM-DD" style="width: 100%" />
                  </a-form-item>
                  <a-form-item label="结束日期（不含）">
                    <a-date-picker v-model="eventForm.endDate" format="YYYY-MM-DD" value-format="YYYY-MM-DD" style="width: 100%" />
                  </a-form-item>
                </div>

                <div class="form-grid">
                  <a-form-item label="重复">
                    <a-select v-model="eventForm.rrule" style="width: 100%">
                      <a-option value="">不重复</a-option>
                      <a-option value="DAILY">每天</a-option>
                      <a-option value="WEEKLY">每周</a-option>
                      <a-option value="MONTHLY">每月</a-option>
                      <a-option value="YEARLY">每年</a-option>
                    </a-select>
                  </a-form-item>
                  <a-form-item label="重复次数">
                    <a-input-number v-model="eventForm.count" :min="1" :max="999" style="width: 100%" placeholder="留空表示无限" />
                  </a-form-item>
                </div>
                <a-form-item label="描述">
                  <a-textarea v-model="eventForm.description" :rows="3" placeholder="可选" />
                </a-form-item>
                <div class="form-actions">
                  <a-button type="primary" :loading="creatingEvent" @click="createEvent">创建事件</a-button>
                </div>
              </a-form>
            </a-card>
          </div>

          <aside class="stack">
            <a-card :bordered="false" class="panel">
              <div class="panel-head">
                <div>
                  <p class="eyebrow">Settings</p>
                  <h2>日历设置</h2>
                </div>
              </div>
              <a-form :model="settings" layout="vertical">
                <a-form-item label="名称">
                  <a-input v-model="settings.displayName" allow-clear />
                </a-form-item>
                <a-form-item label="描述">
                  <a-textarea v-model="settings.description" :rows="2" />
                </a-form-item>
                <div class="form-grid">
                  <a-form-item label="颜色">
                    <input v-model="settings.color" class="color-input" type="color" />
                  </a-form-item>
                  <a-form-item label="排序">
                    <a-input-number v-model="settings.order" style="width: 100%" />
                  </a-form-item>
                </div>
                <a-form-item label="时区">
                  <a-auto-complete v-model="settings.timezone" :data="detail.timezones" />
                </a-form-item>
                <a-form-item label="支持的组件">
                  <a-checkbox-group v-model="settings.components">
                    <a-space direction="vertical">
                      <a-checkbox value="VEVENT">事件 VEVENT</a-checkbox>
                      <a-checkbox value="VTODO">待办 VTODO</a-checkbox>
                      <a-checkbox value="VJOURNAL">日志 VJOURNAL</a-checkbox>
                    </a-space>
                  </a-checkbox-group>
                </a-form-item>
                <a-button type="primary" long :loading="savingSettings" @click="saveSettings">保存设置</a-button>
              </a-form>
            </a-card>

            <a-card :bordered="false" class="panel">
              <p class="eyebrow">Metadata</p>
              <h2>信息</h2>
              <dl class="facts">
                <div><dt>所属用户</dt><dd><router-link :to="`/users/${detail.owner.id}`">{{ detail.owner.username }}</router-link></dd></div>
                <div><dt>URL 标识</dt><dd class="mono">{{ detail.calendar.slug }}</dd></div>
                <div><dt>时区</dt><dd>{{ detail.calendar.timezone }}</dd></div>
                <div><dt>创建时间</dt><dd>{{ formatDate(detail.calendar.createdAt) }}</dd></div>
                <div><dt>同步序号</dt><dd>#{{ detail.calendar.syncSeq }}</dd></div>
              </dl>
              <a-button status="danger" long class="danger-button" @click="removeCalendar">删除日历</a-button>
            </a-card>
          </aside>
        </section>
      </template>
    </a-spin>
  </AdminLayout>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import dayjs from 'dayjs'
import { Message, Modal } from '@arco-design/web-vue'
import { IconCopy, IconLeft, IconPlus, IconRefresh } from '@arco-design/web-vue/es/icon'
import AdminLayout from '../layouts/AdminLayout.vue'
import { api } from '../api'
import { copyText } from '../auth'
import type { CalendarDetailData, EventItem } from '../types'

const route = useRoute()
const router = useRouter()
const loading = ref(true)
const detail = ref<CalendarDetailData | null>(null)
const origin = computed(() => window.location.origin)

const savingSettings = ref(false)
const creatingEvent = ref(false)

function todayTime(hours = 1) {
  return dayjs().add(hours, 'hour').startOf('hour').format('YYYY-MM-DDTHH:mm')
}
function todayDate() {
  return dayjs().format('YYYY-MM-DD')
}

const eventForm = reactive({
  summary: '',
  location: '',
  description: '',
  allDay: false,
  startTime: todayTime(),
  endTime: dayjs().add(2, 'hour').startOf('hour').format('YYYY-MM-DDTHH:mm'),
  startDate: todayDate(),
  endDate: dayjs().add(1, 'day').format('YYYY-MM-DD'),
  rrule: '',
  count: undefined as number | undefined,
})

const settings = reactive({
  displayName: '',
  description: '',
  color: '#3366CC',
  order: 0,
  timezone: 'UTC',
  components: [] as string[],
})

const eventColumns = [
  { title: '事件', dataIndex: 'summary', slotName: 'event' },
  { title: '开始', slotName: 'start', width: 150 },
  { title: '结束', slotName: 'end', width: 150 },
  { title: '类型', slotName: 'type', width: 140 },
  { title: '', slotName: 'actions', width: 120, align: 'right' },
]

async function load() {
  loading.value = true
  try {
    detail.value = await api<CalendarDetailData>(`/calendars/${route.params.id}`)
    settings.displayName = detail.value.calendar.displayName
    settings.description = detail.value.calendar.description
    settings.color = detail.value.calendar.color || '#3366CC'
    settings.order = detail.value.calendar.order
    settings.timezone = detail.value.calendar.timezone
    settings.components = [...detail.value.calendar.components]
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载失败')
  } finally {
    loading.value = false
  }
}

function openEvent() {
  eventForm.summary = ''
  eventForm.location = ''
  eventForm.description = ''
  eventForm.allDay = false
  eventForm.startTime = todayTime()
  eventForm.endTime = dayjs().add(2, 'hour').startOf('hour').format('YYYY-MM-DDTHH:mm')
  eventForm.startDate = todayDate()
  eventForm.endDate = dayjs().add(1, 'day').format('YYYY-MM-DD')
  eventForm.rrule = ''
  eventForm.count = undefined
}

async function createEvent() {
  if (!eventForm.summary.trim()) {
    Message.warning('请填写事件标题')
    return
  }
  const payload = {
    summary: eventForm.summary,
    location: eventForm.location,
    description: eventForm.description,
    allDay: eventForm.allDay,
    start: eventForm.allDay ? eventForm.startDate : eventForm.startTime,
    end: eventForm.allDay ? eventForm.endDate : eventForm.endTime,
    rrule: eventForm.rrule,
    count: eventForm.count || 0,
  }
  creatingEvent.value = true
  try {
    await api(`/calendars/${route.params.id}/events`, {
      method: 'POST',
      body: JSON.stringify(payload),
    })
    Message.success('事件已创建')
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建失败')
  } finally {
    creatingEvent.value = false
  }
}

function editEvent(event: EventItem) {
  router.push({ name: 'event-edit', params: { id: route.params.id, name: event.href } })
}

function removeEvent(event: EventItem) {
  Modal.confirm({
    title: '删除事件',
    content: `确定删除「${event.summary}」吗？`,
    okText: '删除',
    cancelText: '取消',
    okButtonProps: { status: 'danger' },
    async onOk() {
      await api(`/calendars/${route.params.id}/events/${encodeURIComponent(event.href)}`, { method: 'DELETE' })
      Message.success('事件已删除')
      await load()
    },
  })
}

async function saveSettings() {
  if (!settings.components.length) {
    Message.warning('至少选择一种组件')
    return
  }
  savingSettings.value = true
  try {
    await api(`/calendars/${route.params.id}`, {
      method: 'PATCH',
      body: JSON.stringify(settings),
    })
    Message.success('日历设置已保存')
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存失败')
  } finally {
    savingSettings.value = false
  }
}

function removeCalendar() {
  if (!detail.value) return
  Modal.confirm({
    title: '删除日历',
    content: `确定删除「${detail.value.calendar.displayName || detail.value.calendar.slug}」及全部事件吗？`,
    okText: '删除',
    cancelText: '取消',
    okButtonProps: { status: 'danger' },
    async onOk() {
      await api(`/calendars/${detail.value!.calendar.id}`, { method: 'DELETE' })
      Message.success('日历已删除')
      router.push(`/users/${detail.value!.owner.id}`)
    },
  })
}

async function copy(text: string) {
  await copyText(text)
  Message.success('已复制')
}

function formatDateTime(value: string) {
  return value ? dayjs(value).format('YYYY-MM-DD HH:mm') : '—'
}
function formatDay(value: string) {
  return value ? dayjs(value).format('YYYY-MM-DD') : '—'
}
function formatDate(value: string) {
  return value ? dayjs(value).format('YYYY-MM-DD') : '—'
}

onMounted(load)
</script>
