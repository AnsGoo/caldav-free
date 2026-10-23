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
        <label class="tw-event-field">
          <span>标题</span>
          <input ref="titleInput" v-model="form.summary" class="tw-dialog-input" maxlength="300" placeholder="日程标题" @keydown.enter.prevent="save" />
        </label>

        <div class="tw-event-grid">
          <label class="tw-event-field">
            <span>日历</span>
            <select v-model.number="form.calendarId" class="tw-dialog-input" :disabled="editing">
              <option v-for="calendar in calendars" :key="calendar.id" :value="calendar.id">{{ calendar.name }}</option>
            </select>
          </label>
          <label class="tw-event-field">
            <span>重复</span>
            <select v-model="repeatChoice" class="tw-dialog-input" @change="syncRepeat">
              <option value="NONE">不重复</option>
              <option value="FREQ=DAILY">每天</option>
              <option value="FREQ=WEEKLY">每周</option>
              <option value="FREQ=MONTHLY">每月</option>
              <option value="FREQ=YEARLY">每年</option>
              <option value="custom">自定义…</option>
            </select>
          </label>
        </div>
        <input
          v-if="repeatChoice === 'custom'"
          v-model="form.rrule"
          class="tw-dialog-input"
          placeholder="FREQ=WEEKLY;BYDAY=MO,WE"
        />

        <label class="tw-event-check">
          <input v-model="form.allDay" type="checkbox" />
          <span>全天日程</span>
        </label>

        <div class="tw-event-grid">
          <label class="tw-event-field">
            <span>开始日期</span>
            <input v-model="form.startDate" type="date" class="tw-dialog-input" />
          </label>
          <label v-if="!form.allDay" class="tw-event-field">
            <span>开始时间</span>
            <input v-model="form.startTime" type="time" class="tw-dialog-input" />
          </label>
        </div>
        <div class="tw-event-grid">
          <label class="tw-event-field">
            <span>{{ form.allDay ? '结束日期（含）' : '结束日期' }}</span>
            <input v-model="form.endDate" type="date" class="tw-dialog-input" />
          </label>
          <label v-if="!form.allDay" class="tw-event-field">
            <span>结束时间</span>
            <input v-model="form.endTime" type="time" class="tw-dialog-input" />
          </label>
        </div>

        <label class="tw-event-field">
          <span>地点</span>
          <input v-model="form.location" class="tw-dialog-input" maxlength="500" placeholder="可选" />
        </label>
        <label class="tw-event-field">
          <span>描述</span>
          <textarea v-model="form.description" class="tw-event-textarea" rows="3" placeholder="可选" />
        </label>

        <p v-if="editing && event?.recurring" class="tw-reminder-warning">
          这是重复日程，保存会修改整个重复系列；暂不支持只改单次。
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
const titleInput = ref<HTMLInputElement | null>(null)
const repeatChoice = ref('NONE')
const form = reactive({
  calendarId: 0,
  summary: '',
  location: '',
  description: '',
  allDay: false,
  startDate: '',
  startTime: '09:00',
  endDate: '',
  endTime: '10:00',
  rrule: '',
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
  const event = props.event
  if (event) {
    const start = new Date(event.start)
    const end = new Date(event.end)
    form.calendarId = event.calendarId
    form.summary = event.summary
    form.location = event.location || ''
    form.description = event.description || ''
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
    form.allDay = false
    form.startDate = dateInput(start)
    form.startTime = '09:00'
    form.endDate = dateInput(start)
    form.endTime = '10:00'
    form.rrule = ''
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
    await deleteCalendarEvent(props.event.calendarId, props.event.href)
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
  void nextTick(() => titleInput.value?.focus())
})
</script>
