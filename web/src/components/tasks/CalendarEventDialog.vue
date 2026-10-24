<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-event-dialog" role="dialog" aria-modal="true" aria-label="编辑日程">
      <header class="tw-dialog-head">
        <h2>{{ editing ? '编辑日程' : '新建日程' }}</h2>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="16" />
        </button>
      </header>

      <div class="tw-dialog-body tw-event-body">
        <div class="tw-event-field">
          <span>标题</span>
          <a-input ref="titleInput" v-model="form.summary" class="tw-dialog-input" :max-length="300" placeholder="日程标题" @keydown.enter.prevent="save" />
        </div>

        <div class="tw-event-grid">
          <div class="tw-event-field">
            <span>日历</span>
            <a-select v-model.number="form.calendarId" class="tw-dialog-input" :disabled="editing">
              <a-option v-for="calendar in calendars" :key="calendar.id" :value="calendar.id">{{ calendar.name }}</a-option>
            </a-select>
          </div>
          <div class="tw-event-field">
            <span>重复</span>
            <a-select v-model="repeatChoice" class="tw-dialog-input" :disabled="editing && event?.recurring && scope === 'single'" @change="syncRepeat">
              <a-option value="NONE">不重复</a-option>
              <a-option value="FREQ=DAILY">每天</a-option>
              <a-option value="FREQ=WEEKLY">每周</a-option>
              <a-option value="FREQ=MONTHLY">每月</a-option>
              <a-option value="FREQ=YEARLY">每年</a-option>
              <a-option value="custom">自定义…</a-option>
            </a-select>
          </div>
        </div>
        <a-input
          v-if="repeatChoice === 'custom'"
          v-model="form.rrule"
          class="tw-dialog-input"
          placeholder="FREQ=WEEKLY;BYDAY=MO,WE"
        />

        <a-checkbox v-model="form.allDay" class="tw-event-check">全天日程</a-checkbox>

        <div class="tw-event-field">
          <span>提醒</span>
          <a-select v-model.number="form.reminder" class="tw-dialog-input">
            <a-option :value="-1">不提醒</a-option>
            <a-option :value="0">准时提醒</a-option>
            <a-option :value="5">提前 5 分钟</a-option>
            <a-option :value="15">提前 15 分钟</a-option>
            <a-option :value="60">提前 1 小时</a-option>
            <a-option :value="1440">提前 1 天</a-option>
          </a-select>
        </div>

        <a-radio-group v-if="editing && event?.recurring" v-model="scope" class="tw-event-scope">
          <a-radio value="single">仅修改此次</a-radio>
          <a-radio value="series">修改整个系列</a-radio>
        </a-radio-group>

        <div class="tw-event-grid">
          <div class="tw-event-field">
            <span>开始日期</span>
            <a-date-picker v-model="form.startDate" class="tw-date-control" value-format="YYYY-MM-DD" format="YYYY-MM-DD" />
          </div>
          <div v-if="!form.allDay" class="tw-event-field">
            <span>开始时间</span>
            <a-time-picker v-model="form.startTime" class="tw-date-control" format="HH:mm" />
          </div>
        </div>
        <div class="tw-event-grid">
          <div class="tw-event-field">
            <span>{{ form.allDay ? '结束日期（含）' : '结束日期' }}</span>
            <a-date-picker v-model="form.endDate" class="tw-date-control" value-format="YYYY-MM-DD" format="YYYY-MM-DD" />
          </div>
          <div v-if="!form.allDay" class="tw-event-field">
            <span>结束时间</span>
            <a-time-picker v-model="form.endTime" class="tw-date-control" format="HH:mm" />
          </div>
        </div>

        <div class="tw-event-field">
          <span>地点</span>
          <a-input v-model="form.location" class="tw-dialog-input" :max-length="500" placeholder="可选" />
        </div>
        <div class="tw-event-field">
          <span>参与人</span>
          <a-input v-model="form.attendees" class="tw-dialog-input" :max-length="2000" placeholder="邮箱，用逗号分隔" />
        </div>
        <p class="tw-reminder-warning">参与人只写入日程，不会自动发送邀请邮件。</p>
        <div class="tw-event-field">
          <span>描述</span>
          <a-textarea v-model="form.description" class="tw-event-textarea" :auto-size="{ minRows: 3, maxRows: 6 }" placeholder="可选" />
        </div>

        <p v-if="editing && event?.recurring && scope === 'single'" class="tw-reminder-warning">
          将只修改这一次日程，并写入独立的 RECURRENCE-ID 例外。
        </p>
        <p v-if="editing && event?.recurring && scope === 'series'" class="tw-reminder-warning">
          将修改整个重复系列。
        </p>
        <p v-if="error" class="tw-reminder-warning">{{ error }}</p>
      </div>

      <footer class="tw-dialog-foot tw-event-foot">
        <button v-if="editing" class="tw-event-delete" :disabled="busy" @click="remove">
          {{ deleteArmed ? '确认删除' : '删除日程' }}
        </button>
        <span class="tw-event-foot-spacer" />
        <button class="tw-dialog-cancel" :disabled="busy" @click="$emit('close')">取消</button>
        <button class="tw-dialog-ok" :disabled="busy || !form.calendarId" @click="save">
          {{ busy ? '保存中…' : '保存' }}
        </button>
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { CalendarEvent, CalendarSource } from '../../types'
import { createCalendarEvent, deleteCalendarEvent, updateCalendarEvent } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  event: CalendarEvent | null
  calendars: CalendarSource[]
  defaultDate?: Date
}>()
const emit = defineEmits<{
  (event: 'close'): void
  (event: 'saved'): void
}>()

const editing = computed(() => Boolean(props.event))
const busy = ref(false)
const error = ref('')
const deleteArmed = ref(false)
const titleInput = ref<{ focus?: () => void } | null>(null)
const repeatChoice = ref('NONE')
const scope = ref<'single' | 'series'>('single')
const form = reactive({
  calendarId: 0,
  summary: '',
  location: '',
  description: '',
  attendees: '',
  allDay: false,
  startDate: '',
  startTime: '09:00',
  endDate: '',
  endTime: '10:00',
  rrule: '',
  reminder: -1,
})

function dateInput(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

function timeInput(date: Date) {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

function addDays(date: Date, days: number) {
  const next = new Date(date)
  next.setDate(next.getDate() + days)
  return next
}

function hydrate() {
  error.value = ''
  deleteArmed.value = false
  scope.value = 'single'
  const event = props.event
  if (event) {
    const start = new Date(event.start)
    const end = new Date(event.end)
    form.calendarId = event.calendarId
    form.summary = event.summary
    form.location = event.location || ''
    form.description = event.description || ''
    form.attendees = (event.attendees || []).join(', ')
    form.allDay = event.allDay
    form.startDate = dateInput(start)
    form.startTime = timeInput(start)
    if (event.allDay) {
      form.endDate = dateInput(addDays(end, -1))
      form.endTime = '10:00'
    } else {
      form.endDate = dateInput(end)
      form.endTime = timeInput(end)
    }
    form.rrule = event.rrule || ''
    form.reminder = event.reminders?.[0] ?? -1
    repeatChoice.value = ['FREQ=DAILY', 'FREQ=WEEKLY', 'FREQ=MONTHLY', 'FREQ=YEARLY'].includes(form.rrule)
      ? form.rrule
      : form.rrule
        ? 'custom'
        : 'NONE'
  } else {
    const base = props.defaultDate || new Date()
    const start = new Date(base.getFullYear(), base.getMonth(), base.getDate(), 9, 0, 0)
    form.calendarId = props.calendars[0]?.id || 0
    form.summary = ''
    form.location = ''
    form.description = ''
    form.attendees = ''
    form.allDay = false
    form.startDate = dateInput(start)
    form.startTime = '09:00'
    form.endDate = dateInput(start)
    form.endTime = '10:00'
    form.rrule = ''
    form.reminder = -1
    repeatChoice.value = 'NONE'
  }
}

function syncRepeat() {
  if (repeatChoice.value !== 'custom') {
    form.rrule = repeatChoice.value === 'NONE' ? '' : repeatChoice.value
  }
}

async function save() {
  error.value = ''
  const summary = form.summary.trim()
  if (!summary) {
    error.value = '请填写日程标题'
    return
  }
  if (!form.calendarId) {
    error.value = '请选择日历'
    return
  }
  if (!form.startDate) {
    error.value = '请选择开始日期'
    return
  }
  if (repeatChoice.value === 'custom') form.rrule = form.rrule.trim()
  let start = ''
  let end = ''
  if (form.allDay) {
    const endDate = form.endDate || form.startDate
    start = `${form.startDate}T00:00:00`
    end = `${dateInput(addDays(new Date(`${endDate}T00:00:00`), 1))}T00:00:00`
  } else {
    if (!form.startTime || !form.endTime) {
      error.value = '请选择开始和结束时间'
      return
    }
    start = `${form.startDate}T${form.startTime}`
    end = `${form.endDate || form.startDate}T${form.endTime}`
    if (new Date(end) <= new Date(start)) {
      error.value = '结束时间必须晚于开始时间'
      return
    }
  }
  busy.value = true
  try {
    const payload = {
      summary,
      location: form.location.trim(),
      description: form.description.trim(),
      start,
      end,
      allDay: form.allDay,
      rrule: form.rrule.trim(),
      reminders: form.reminder >= 0 ? [form.reminder] : [],
      attendees: [...new Set(form.attendees.split(/[,，;\n]/).map((item) => item.trim()).filter(Boolean))].slice(0, 50),
      ...(props.event && props.event.recurring && scope.value === 'single'
        ? { recurrenceId: props.event.recurrenceId || props.event.start, scope: 'single' as const }
        : { scope: 'series' as const }),
    }
    if (props.event) {
      await updateCalendarEvent(props.event.calendarId, props.event.href, payload)
    } else {
      await createCalendarEvent(form.calendarId, payload)
    }
    Message.success(editing.value ? '日程已保存' : '日程已创建')
    emit('saved')
    emit('close')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '保存日程失败'
  } finally {
    busy.value = false
  }
}

async function remove() {
  if (!props.event) return
  if (!deleteArmed.value) {
    deleteArmed.value = true
    return
  }
  busy.value = true
  try {
    const recurrenceId =
      props.event.recurring && scope.value === 'single'
        ? props.event.recurrenceId || props.event.start
        : undefined
    await deleteCalendarEvent(props.event.calendarId, props.event.href, recurrenceId)
    Message.success('日程已删除')
    emit('saved')
    emit('close')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '删除日程失败'
    deleteArmed.value = false
  } finally {
    busy.value = false
  }
}

onMounted(() => {
  hydrate()
  void nextTick(() => titleInput.value?.focus?.())
})
</script>
