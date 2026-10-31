<template>
  <section class="tw-timeline">
    <header class="tw-timeline-toolbar">
      <div class="tw-timeline-range">
        <strong>{{ rangeLabel }}</strong>
        <span class="tw-timeline-sub">{{ tasks.length }} 个任务</span>
      </div>
      <div class="tw-timeline-actions">
        <a-select class="tw-field-select tw-timeline-select" :model-value="colorBy" @change="onColorChange">
          <a-option value="list">按清单着色</a-option>
          <a-option value="tag">按标签着色</a-option>
          <a-option value="priority">按优先级着色</a-option>
          <a-option value="none">无颜色</a-option>
        </a-select>
        <div class="tw-mode-switch" role="group" aria-label="时间线缩放">
          <button v-for="option in zoomOptions" :key="option.value" :class="{ active: zoom === option.value }" :title="option.label" @click="$emit('change-zoom', option.value)">
            {{ option.short }}
          </button>
        </div>
        <button class="tw-icon-button" title="上一段" @click="shift(-1)">
          <TaskIcon name="chevron" :size="15" class="tw-flip" />
        </button>
        <button class="tw-ghost-button" :title="history ? '回到最近完成' : '回到今天'" @click="goToday">{{ history ? '最近' : '今天' }}</button>
        <button class="tw-icon-button" title="下一段" @click="shift(1)">
          <TaskIcon name="chevron" :size="15" />
        </button>
      </div>
    </header>

    <div ref="scrollEl" class="tw-timeline-scroll">
      <div class="tw-timeline-canvas" :style="{ width: `${labelWidth + dayCount * dayWidth}px` }">
        <div class="tw-timeline-head">
          <div class="tw-timeline-label tw-timeline-corner">清单 / 任务</div>
          <div class="tw-timeline-scale" :style="{ width: `${dayCount * dayWidth}px` }">
            <div class="tw-timeline-months">
              <span v-for="month in months" :key="month.key" :style="{ left: `${month.left}px`, width: `${month.width}px` }">{{ month.label }}</span>
            </div>
            <div class="tw-timeline-days">
              <span
                v-for="(day, index) in days"
                :key="day.key"
                class="tw-timeline-day"
                :class="{ today: day.key === todayKey, weekend: day.weekend, major: day.major }"
                :style="{ width: `${dayWidth}px` }"
              >
                <template v-if="dayWidth >= 22">
                  <b>{{ day.day }}</b>
                  <small>{{ day.weekday }}</small>
                </template>
                <b v-else-if="day.major">{{ day.day }}</b>
              </span>
            </div>
          </div>
        </div>

        <div v-if="!rows.length" class="tw-timeline-empty">
          <template v-if="history">
            <p>这个时间范围内还没有已完成的任务。</p>
            <span>已完成的任务会按完成时间显示在这里。</span>
          </template>
          <template v-else>
            <p>这个时间范围内还没有带日期的任务。</p>
            <span>点击时间轴空白处可以直接新建任务。</span>
          </template>
        </div>

        <div v-for="row in rows" :key="row.list.id" class="tw-timeline-row">
          <div class="tw-timeline-label">
            <span class="tw-list-dot" :style="{ background: row.list.color || '#4772fa' }" />
            <span class="tw-timeline-list-name">{{ row.list.name }}</span>
            <span class="tw-timeline-list-count">{{ row.items.length }}</span>
          </div>
          <div
            class="tw-timeline-track"
            :style="{ width: `${dayCount * dayWidth}px` }"
            @click="onTrackClick(row.list.id, $event)"
          >
            <span
              v-for="(day, index) in days"
              :key="day.key"
              class="tw-timeline-cell"
              :class="{ today: day.key === todayKey, weekend: day.weekend }"
              :style="{ left: `${index * dayWidth}px`, width: `${dayWidth}px` }"
            />
            <button
              v-for="bar in row.bars"
              :key="bar.task.id"
              class="tw-timeline-bar"
              :class="{ done: bar.task.completed && !history, readonly: history, dragging: dragState?.task.id === bar.task.id && dragState.moved }"
              :style="{ left: `${bar.left}px`, width: `${bar.width}px`, background: bar.color, color: bar.textColor }"
              :title="`${bar.task.title}\n${bar.rangeLabel}`"
              @pointerdown.stop="startDrag(bar.task, $event)"
              @click.stop="onBarClick(bar.task)"
            >
              <TaskIcon v-if="bar.task.pinned" name="pin" :size="11" />
              <span>{{ bar.task.title }}</span>
            </button>

            <form
              v-if="draft && draft.listId === row.list.id"
              class="tw-timeline-draft"
              :style="{ left: `${draft.left}px` }"
              @click.stop
              @submit.prevent="commitDraft"
            >
              <input
                ref="draftInput"
                v-model="draft.title"
                class="tw-timeline-draft-input"
                maxlength="200"
                placeholder="新任务，回车创建"
                @keydown.enter.prevent="commitDraft"
                @keydown.esc.prevent="draft = null"
                @blur="commitDraft"
              />
            </form>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { TaskItem, TaskList } from '../../types'
import { PRIORITIES, dayKey, formatDue } from '../../tasks-utils'
import { tagColor } from '../../tag-colors'
import TaskIcon from './TaskIcon.vue'

type Zoom = 'day' | 'week' | 'month'
type ColorBy = 'list' | 'tag' | 'priority' | 'none'

const props = defineProps<{
  tasks: TaskItem[]
  lists: TaskList[]
  zoom: Zoom
  colorBy: ColorBy
  tagColors: Record<string, string>
  /** 历史模式：展示已完成任务，按完成时间定位，且只读。 */
  history?: boolean
  /** 历史模式下默认定位到的日期（通常是最近一次完成时间）。 */
  anchorDate?: string
}>()

const emit = defineEmits<{
  (event: 'open', task: TaskItem): void
  (event: 'create', payload: { title: string; date: string; listId: number }): void
  (event: 'reschedule', payload: { task: TaskItem; due: string; start?: string; allDay: boolean }): void
  (event: 'change-zoom', value: Zoom): void
  (event: 'change-color', value: ColorBy): void
}>()

const zoomOptions: Array<{ value: Zoom; label: string; short: string }> = [
  { value: 'day', label: '日视图', short: '日' },
  { value: 'week', label: '周视图', short: '周' },
  { value: 'month', label: '月视图', short: '月' },
]
const labelWidth = 176
const scrollEl = ref<HTMLElement | null>(null)
const draftInput = ref<HTMLInputElement | HTMLInputElement[] | null>(null)
const anchor = ref(startOfDay(new Date()))
const draft = ref<{ listId: number; left: number; date: string; title: string } | null>(null)
const dragState = ref<{ task: TaskItem; startX: number; start?: string; due?: string; moved: boolean } | null>(null)
let suppressClick = false
let appliedAnchor = ''

const todayKey = computed(() => dayKey(new Date()))

const spec = computed(() => {
  if (props.zoom === 'day') return { start: addDays(anchor.value, -7), count: 21, width: 44 }
  if (props.zoom === 'week') return { start: addDays(mondayOf(anchor.value), -14), count: 70, width: 24 }
  const first = new Date(anchor.value.getFullYear(), anchor.value.getMonth(), 1)
  const start = new Date(first.getFullYear(), first.getMonth() - 1, 1)
  const end = new Date(first.getFullYear(), first.getMonth() + 5, 1)
  return { start, count: diffDays(start, end), width: 8 }
})

const dayCount = computed(() => spec.value.count)
const dayWidth = computed(() => spec.value.width)

const days = computed(() =>
  Array.from({ length: dayCount.value }, (_, index) => {
    const date = addDays(spec.value.start, index)
    return {
      key: dayKey(date),
      date,
      day: date.getDate(),
      weekday: '日一二三四五六'[date.getDay()],
      weekend: date.getDay() === 0 || date.getDay() === 6,
      major: date.getDate() === 1 || (props.zoom === 'day' ? true : date.getDay() === 1),
    }
  }),
)

const months = computed(() => {
  const rows: Array<{ key: string; label: string; left: number; width: number }> = []
  let current: { key: string; label: string; left: number; width: number } | null = null
  days.value.forEach((day, index) => {
    const key = `${day.date.getFullYear()}-${day.date.getMonth()}`
    if (!current || current.key !== key) {
      if (current) rows.push(current)
      current = { key, label: `${day.date.getMonth() + 1}月`, left: index * dayWidth.value, width: dayWidth.value }
    } else {
      current.width += dayWidth.value
    }
  })
  if (current) rows.push(current)
  return rows
})

const rangeLabel = computed(() => {
  const start = days.value[0]?.date
  const end = days.value[days.value.length - 1]?.date
  if (!start || !end) return ''
  return `${start.getFullYear()}年${start.getMonth() + 1}月${start.getDate()}日 – ${end.getMonth() + 1}月${end.getDate()}日`
})

interface Bar {
  task: TaskItem
  left: number
  width: number
  color: string
  textColor: string
  rangeLabel: string
}

interface Row {
  list: TaskList
  items: TaskItem[]
  bars: Bar[]
}

const rows = computed<Row[]>(() => {
  const start = spec.value.start
  const limit = dayCount.value
  const byList = new Map<number, TaskItem[]>()
  for (const task of props.tasks) {
    if (task.kind === 'NOTE') continue
    if (task.completed && !props.history) continue
    const hasDate = Boolean(task.start || task.due || (task.completed && task.completedAt))
    if (!hasDate) continue
    const list = byList.get(task.listId) || []
    list.push(task)
    byList.set(task.listId, list)
  }
  const result: Row[] = []
  for (const list of props.lists) {
    if (list.kind === 'NOTE') continue
    const items = byList.get(list.id) || []
    const bars: Bar[] = []
    for (const task of items) {
      const { first, last } = taskSpan(task)
      const startDate = startOfDay(first)
      const endDate = startOfDay(last < first ? first : last)
      const from = diffDays(start, startDate)
      const to = diffDays(start, endDate)
      if (to < 0 || from >= limit) continue
      const clampedFrom = Math.max(0, from)
      const clampedTo = Math.min(limit - 1, to)
      const barWidth = Math.max(dayWidth.value - 4, (clampedTo - clampedFrom + 1) * dayWidth.value - 4)
      bars.push({
        task,
        left: clampedFrom * dayWidth.value + 2,
        width: barWidth,
        color: barColor(task),
        textColor: barTextColor(task),
        rangeLabel: barRangeLabel(task),
      })
    }
    bars.sort((a, b) => a.left - b.left)
    // 历史视图只保留当前时间范围内确实有完成记录的清单，避免整屏空泳道。
    if (props.history && !bars.length) continue
    result.push({ list, items, bars })
  }
  return result
})

function taskSpan(task: TaskItem) {
  if (props.history && task.completed) {
    const stamp = task.completedAt || task.due || task.start
    if (stamp) {
      const date = new Date(stamp)
      if (!Number.isNaN(date.getTime())) return { first: date, last: date }
    }
  }
  const first = task.start ? new Date(task.start) : new Date(task.due!)
  const last = task.due ? new Date(task.due) : first
  return { first, last: last < first ? first : last }
}

function barRangeLabel(task: TaskItem) {
  if (props.history && task.completed) {
    const stamp = task.completedAt || task.due || task.start
    if (!stamp) return '已完成'
    const date = new Date(stamp)
    if (Number.isNaN(date.getTime())) return '已完成'
    const sameYear = date.getFullYear() === new Date().getFullYear()
    return `完成于 ${sameYear ? '' : `${date.getFullYear()}年`}${date.getMonth() + 1}月${date.getDate()}日`
  }
  return formatDue(task)
}

function startOfDay(value: Date) {
  return new Date(value.getFullYear(), value.getMonth(), value.getDate())
}

function addDays(value: Date, amount: number) {
  const date = new Date(value)
  date.setDate(date.getDate() + amount)
  return date
}

function mondayOf(value: Date) {
  const day = value.getDay()
  return addDays(startOfDay(value), day === 0 ? -6 : 1 - day)
}

function diffDays(from: Date, to: Date) {
  const a = Date.UTC(from.getFullYear(), from.getMonth(), from.getDate())
  const b = Date.UTC(to.getFullYear(), to.getMonth(), to.getDate())
  return Math.round((b - a) / 86400000)
}

function hashedColor(value: string) {
  let hash = 0
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) % 360
  }
  return `hsl(${hash} 52% 48%)`
}

function barColor(task: TaskItem) {
  if (props.colorBy === 'none') return 'var(--tw-accent)'
  if (props.colorBy === 'priority') {
    return PRIORITIES.find((item) => item.value === task.priority)?.color || 'var(--tw-accent)'
  }
  if (props.colorBy === 'tag') {
    const tag = task.tags[0]
    return tag ? tagColor(tag, props.tagColors[tag]) : hashedColor(task.title)
  }
  return task.listColor || 'var(--tw-accent)'
}

function barTextColor(task: TaskItem) {
  if (props.colorBy === 'priority' && task.priority === 0) return 'var(--tw-text)'
  return '#fff'
}

function onColorChange(value: unknown) {
  emit('change-color', String(value) as ColorBy)
}

function shift(direction: number) {
  const step = props.zoom === 'day' ? 7 : props.zoom === 'week' ? 14 : 30
  anchor.value = addDays(anchor.value, direction * step)
}

function goToday() {
  if (props.history && props.anchorDate) {
    const date = new Date(props.anchorDate)
    if (!Number.isNaN(date.getTime())) {
      anchor.value = startOfDay(date)
      scrollToDayKey(dayKey(date))
      return
    }
  }
  anchor.value = startOfDay(new Date())
  scrollToToday()
}

function scrollToToday() {
  scrollToDayKey(dayKey(new Date()))
}

function scrollToDayKey(key: string, behavior: ScrollBehavior = 'smooth') {
  const index = days.value.findIndex((day) => day.key === key)
  if (index < 0 || !scrollEl.value) return
  scrollEl.value.scrollTo({ left: Math.max(0, index * dayWidth.value - 260), behavior })
}

function applyAnchor() {
  if (!props.history || !props.anchorDate) return false
  if (appliedAnchor === props.anchorDate) return false
  const date = new Date(props.anchorDate)
  if (Number.isNaN(date.getTime())) return false
  appliedAnchor = props.anchorDate
  anchor.value = startOfDay(date)
  nextTick(() => scrollToDayKey(dayKey(date), 'auto'))
  return true
}

function onTrackClick(listId: number, event: MouseEvent) {
  if (props.history) return
  const track = event.currentTarget as HTMLElement
  const rect = track.getBoundingClientRect()
  const offset = Math.max(0, Math.min(track.clientWidth - 1, event.clientX - rect.left))
  const index = Math.min(dayCount.value - 1, Math.floor(offset / dayWidth.value))
  const date = addDays(spec.value.start, index)
  draft.value = {
    listId,
    left: Math.max(0, Math.min(track.clientWidth - 220, index * dayWidth.value)),
    date: dayKey(date),
    title: '',
  }
  nextTick(() => {
    const input = Array.isArray(draftInput.value) ? draftInput.value[0] : draftInput.value
    input?.focus()
  })
}

function commitDraft() {
  if (!draft.value) return
  const title = draft.value.title.trim()
  const payload = { title, date: draft.value.date, listId: draft.value.listId }
  draft.value = null
  if (title) emit('create', payload)
}

function onBarClick(task: TaskItem) {
  if (suppressClick) {
    suppressClick = false
    return
  }
  emit('open', task)
}

function startDrag(task: TaskItem, event: PointerEvent) {
  if (props.history) return
  dragState.value = {
    task,
    startX: event.clientX,
    start: task.start,
    due: task.due,
    moved: false,
  }
  window.addEventListener('pointermove', onPointerMove)
  window.addEventListener('pointerup', onPointerUp, { once: true })
}

function onPointerMove(event: PointerEvent) {
  if (!dragState.value) return
  if (Math.abs(event.clientX - dragState.value.startX) > 4) dragState.value.moved = true
}

function onPointerUp(event: PointerEvent) {
  window.removeEventListener('pointermove', onPointerMove)
  const state = dragState.value
  dragState.value = null
  if (!state || !state.moved) return
  suppressClick = true
  setTimeout(() => {
    suppressClick = false
  }, 0)
  const delta = Math.round((event.clientX - state.startX) / dayWidth.value)
  if (!delta) return
  const due = state.due ? shiftISO(state.due, delta) : undefined
  const start = state.start ? shiftISO(state.start, delta) : undefined
  if (!due && !start) return
  emit('reschedule', { task: state.task, due: due || start || state.due || '', start, allDay: state.task.allDay })
}

function shiftISO(value: string, delta: number) {
  const date = new Date(value)
  date.setDate(date.getDate() + delta)
  const pad = (input: number) => String(input).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:00`
}

watch(
  () => props.anchorDate,
  () => {
    if (props.history) applyAnchor()
  },
  { immediate: true },
)

watch(
  () => props.history,
  (history) => {
    appliedAnchor = ''
    if (history) {
      applyAnchor()
    } else {
      anchor.value = startOfDay(new Date())
      nextTick(scrollToToday)
    }
  },
)

watch(
  () => [props.zoom, props.tasks.length],
  () => {
    if (props.history && appliedAnchor) {
      const date = new Date(appliedAnchor)
      nextTick(() => scrollToDayKey(dayKey(date), 'auto'))
    } else {
      nextTick(scrollToToday)
    }
  },
)

onMounted(() => {
  if (props.history && props.anchorDate) {
    const date = new Date(props.anchorDate)
    if (!Number.isNaN(date.getTime())) {
      nextTick(() => scrollToDayKey(dayKey(date), 'auto'))
      return
    }
  }
  nextTick(() => scrollToToday())
})
onBeforeUnmount(() => window.removeEventListener('pointermove', onPointerMove))
</script>
