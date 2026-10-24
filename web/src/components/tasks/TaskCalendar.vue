<template>
  <section class="tw-calendar" :class="`mode-${viewMode}`">
    <header class="tw-calendar-head">
      <div class="tw-calendar-title">
        <h2>{{ rangeTitle }}</h2>
        <span class="tw-calendar-sub">{{ summaryText }}</span>
      </div>
      <div class="tw-calendar-actions">
        <div class="tw-cal-view-switch">
          <button
            v-for="option in viewOptions"
            :key="option.value"
            :class="{ active: viewMode === option.value }"
            @click="$emit('change-view', option.value)"
          >
            {{ option.label }}
          </button>
        </div>
        <button class="tw-ghost-button" @click="$emit('today')">今天</button>
        <button class="tw-icon-button" title="上一段" @click="$emit('prev')">
          <TaskIcon name="back" :size="16" />
        </button>
        <button class="tw-icon-button" title="下一段" @click="$emit('next')">
          <TaskIcon name="chevron" :size="16" />
        </button>
        <button class="tw-icon-button" title="刷新日程" @click="loadEvents">
          <TaskIcon name="refresh" :size="15" />
        </button>
      </div>
    </header>

    <div v-if="sources.length || habitEntries.length" class="tw-cal-legend">
      <button v-for="source in sources" :key="source.id" :class="{ off: hiddenCalendarIds.has(source.id) }" @click="toggleCalendar(source.id)">
        <i :style="{ background: source.color || '#4772fa' }" />
        {{ source.name }}
      </button>
      <span class="tw-cal-legend-gap" />
      <button class="tw-cal-legend-tasks" :class="{ off: hiddenTasks }" @click="toggleTasks"><i />任务</button>
      <button class="tw-cal-legend-habits" :class="{ off: hiddenHabits }" @click="toggleHabits"><i />习惯</button>
      <span v-if="eventsLoading" class="tw-cal-loading">事件加载中…</span>
    </div>

    <!-- month -->
    <div v-if="viewMode === 'month'" class="tw-calendar-month">
      <div class="tw-calendar-weekdays">
        <span v-for="day in weekdays" :key="day">{{ day }}</span>
      </div>
      <div class="tw-calendar-grid">
        <div
          v-for="cell in monthCells"
          :key="cell.key"
          class="tw-calendar-cell"
          :class="{ muted: !cell.inMonth, today: cell.isToday }"
          @dragover.prevent
          @drop="dropOnDay(cell.key)"
        >
          <div class="tw-cell-head">
            <button class="tw-cell-day" title="查看当天安排" @click="openDay(cell.key)">{{ cell.label }}</button>
            <button class="tw-cell-add" title="添加任务" @click="startCreate(cell.key)">
              <TaskIcon name="plus" :size="13" />
            </button>
          </div>

          <form v-if="editingDay === cell.key" class="tw-cell-form" @submit.prevent="submitCreate">
            <input
              ref="createInput"
              v-model="newTitle"
              class="tw-cell-input"
              maxlength="200"
              placeholder="任务标题"
              @keydown.esc="cancelCreate"
              @blur="submitCreate"
            />
          </form>

          <div class="tw-cell-tasks">
            <template v-for="item in cellItems(cell.key).slice(0, 3)" :key="item.key">
              <button
                v-if="item.kind === 'task'"
                class="tw-calendar-task"
                :class="{ done: item.task!.completed, overdue: cell.key < todayKey && !item.task!.completed }"
                :title="item.title"
                draggable="true"
                @dragstart="startDrag(item, $event)"
                @click="$emit('open', item.task!)"
              >
                <i :style="{ background: item.task!.listColor || '#4772fa' }" />
                <span>{{ item.title }}</span>
              </button>
              <button
                v-else-if="item.kind === 'habit'"
                class="tw-calendar-task tw-calendar-habit"
                :class="{ done: item.habitDone }"
                :style="{ borderLeftColor: item.color }"
                :title="item.title"
                @click="$emit('open-habit', item.habitId!)"
              >
                <i :style="{ background: item.color }" />
                <span>{{ item.title }}</span>
              </button>
              <button
                v-else
                class="tw-calendar-task tw-calendar-event"
                :style="{ borderLeftColor: item.color, background: `color-mix(in srgb, ${item.color} 16%, var(--tw-surface))` }"
                :title="item.title"
                draggable="true"
                @dragstart="startDrag(item, $event)"
                @click="$emit('open-event', item.event!)"
              >
                <i :style="{ background: item.color }" />
                <span>{{ item.title }}</span>
              </button>
            </template>
            <button
              v-if="cellItems(cell.key).length > 3"
              class="tw-cell-more"
              @click="openDay(cell.key)"
            >
              +{{ cellItems(cell.key).length - 3 }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- week / day time grid -->
    <div v-else-if="viewMode === 'week' || viewMode === 'day'" class="tw-timegrid-wrap">
      <div class="tw-tg-head" :style="{ gridTemplateColumns: `46px repeat(${visibleDays.length}, minmax(0, 1fr))` }">
        <span class="tw-tg-gutter" />
        <button
          v-for="day in visibleDays"
          :key="day.key"
          class="tw-tg-dayhead"
          :class="{ today: day.key === todayKey }"
          @click="openDay(day.key)"
        >
          <span>{{ weekdays[day.date.getDay()] }}</span>
          <strong>{{ day.date.getDate() }}</strong>
        </button>
      </div>

      <div class="tw-tg-allday" :style="{ gridTemplateColumns: `46px repeat(${visibleDays.length}, minmax(0, 1fr))` }">
        <span class="tw-tg-allday-label">全天</span>
        <div v-for="day in visibleDays" :key="day.key" class="tw-tg-allday-cell" @dragover.prevent @drop="dropAllDay(day.key)">
          <template v-for="item in allDayItems(day.key).slice(0, 4)" :key="item.key">
            <button
              v-if="item.kind === 'task'"
              class="tw-tg-allday-chip task"
              :style="{ borderLeftColor: item.color }"
              :title="item.title"
              draggable="true"
              @dragstart="startDrag(item, $event)"
              @click="$emit('open', item.task!)"
            >
              {{ item.title }}
            </button>
            <button
              v-else-if="item.kind === 'habit'"
              class="tw-tg-allday-chip habit"
              :class="{ done: item.habitDone }"
              :style="{ borderLeftColor: item.color }"
              :title="item.title"
              @click="$emit('open-habit', item.habitId!)"
            >
              {{ item.title }}
            </button>
            <button
              v-else
              class="tw-tg-allday-chip event"
              :style="{ borderLeftColor: item.color }"
              :title="item.title"
              draggable="true"
              @dragstart="startDrag(item, $event)"
              @click="$emit('open-event', item.event!)"
            >
              {{ item.title }}
            </button>
          </template>
          <span v-if="allDayItems(day.key).length > 4" class="tw-tg-more">+{{ allDayItems(day.key).length - 4 }}</span>
        </div>
      </div>

      <div ref="scrollRef" class="tw-tg-scroll">
        <div class="tw-tg-body" :style="{ gridTemplateColumns: `46px repeat(${visibleDays.length}, minmax(0, 1fr))` }">
          <div class="tw-tg-hours">
            <div v-for="hour in 24" :key="hour" class="tw-tg-hour">
              <span>{{ String(hour - 1).padStart(2, '0') }}:00</span>
            </div>
          </div>
          <div v-for="day in visibleDays" :key="day.key" class="tw-tg-col">
            <div v-for="hour in 24" :key="hour" class="tw-tg-line" @dragover.prevent @drop="dropOnTime(day.key, hour - 1)" />
            <div
              v-for="item in layoutItems(day.key)"
              :key="item.key"
              class="tw-tg-block"
              :class="item.kind"
              :style="[item.style, resizeStyle(item)]"
              :title="`${item.title}${item.timeLabel ? ' · ' + item.timeLabel : ''}`"
              draggable="true"
              @dragstart="startDrag(item, $event)"
              @click="onBlockClick(item)"
            >
              <strong>{{ item.title }}</strong>
              <small v-if="item.height > 34">{{ item.timeLabel }}</small>
              <span
                v-if="item.kind === 'event' && item.event && !item.event.allDay"
                class="tw-tg-resize"
                title="拖动调整时长"
                @pointerdown.stop.prevent="startResize(item, $event)"
                @click.stop
              />
            </div>
            <div v-if="day.key === todayKey" class="tw-tg-now" :style="{ top: `${nowTop}px` }">
              <i />
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- agenda -->
    <div v-else class="tw-agenda">
      <section v-for="group in agendaGroups" :key="group.key" class="tw-agenda-group">
        <header class="tw-agenda-date" :class="{ today: group.key === todayKey }">
          <strong>{{ group.title }}</strong>
          <span>{{ group.items.length }}</span>
        </header>
        <button
          v-for="item in group.items"
          :key="item.key"
          class="tw-agenda-row"
          @click="openCalendarItem(item)"
        >
          <span class="tw-agenda-time">{{ item.timeLabel || '全天' }}</span>
          <i :style="{ background: item.color }" />
          <span class="tw-agenda-title" :class="{ done: item.task?.completed || item.habitDone }">{{ item.title }}</span>
          <small v-if="item.location">{{ item.location }}</small>
          <span class="tw-agenda-kind">{{ item.kind === 'task' ? '任务' : item.kind === 'habit' ? '习惯' : item.event?.calendarName }}</span>
        </button>
      </section>
      <div v-if="!agendaGroups.length" class="tw-agenda-empty">
        <TaskIcon name="calendar" :size="28" />
        <p>未来 30 天没有安排</p>
      </div>
    </div>

    <div v-if="dayOpen" class="tw-day-scrim" @click.self="dayOpen = ''">
      <div class="tw-day-sheet" role="dialog" aria-modal="true">
        <header class="tw-day-head">
          <div>
            <h3>{{ dayTitle }}</h3>
            <small>{{ dayItems.length }} 项安排</small>
          </div>
          <button class="tw-icon-button" title="关闭" @click="dayOpen = ''">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-day-list">
          <button
            v-for="item in dayItems"
            :key="item.key"
            class="tw-day-row"
            @click="openDayItem(item)"
          >
            <span v-if="item.kind === 'task'" class="tw-check" :class="{ checked: item.task!.completed }">
              <svg v-if="item.task!.completed" viewBox="0 0 20 20" width="10" height="10" aria-hidden="true">
                <path d="m4.5 10.2 3.6 3.7 7.4-8" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </span>
            <i v-else :style="{ background: item.color }" class="tw-day-event-dot" :class="{ habit: item.kind === 'habit', done: item.habitDone }" />
            <span class="tw-day-title" :class="{ done: item.task?.completed || item.habitDone }">{{ item.title }}</span>
            <small>{{ item.allDay ? '全天' : item.timeLabel }}</small>
          </button>
          <p v-if="!dayItems.length" class="tw-day-empty">这一天还没有安排</p>
        </div>
        <form class="tw-day-add" @submit.prevent="submitDay">
          <TaskIcon name="plus" :size="15" />
          <input v-model="dayTitleInput" maxlength="200" placeholder="添加任务，回车创建" />
        </form>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { CalendarEvent, CalendarSource, HabitCalendarEntry, TaskItem } from '../../types'
import { dayKey, startOfToday, taskDayKey } from '../../tasks-utils'
import { fetchCalendarEvents, fetchHabitCalendar } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  tasks: TaskItem[]
  cursor: Date
  viewMode: 'month' | 'week' | 'day' | 'agenda'
  reloadKey?: number
  focus?: { calendarId: number; href: string; occurrence: string } | null
}>()

const emit = defineEmits<{
  (event: 'open', task: TaskItem): void
  (event: 'open-event', item: CalendarEvent): void
  (event: 'open-habit', id: number): void
  (event: 'create', payload: { date: string; title: string }): void
  (event: 'prev'): void
  (event: 'next'): void
  (event: 'today'): void
  (event: 'change-view', value: 'month' | 'week' | 'day' | 'agenda'): void
  (event: 'calendars', value: CalendarSource[]): void
  (event: 'reschedule-task', payload: { task: TaskItem; due: string; allDay: boolean }): void
  (event: 'reschedule-event', payload: { event: CalendarEvent; start: string; end: string; allDay: boolean }): void
  (event: 'focus-opened'): void
}>()

const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
const viewOptions = [
  { value: 'month', label: '月' },
  { value: 'week', label: '周' },
  { value: 'day', label: '日' },
  { value: 'agenda', label: '日程' },
] as const
const HOUR_HEIGHT = 56

const todayKey = dayKey(startOfToday())
const events = ref<CalendarEvent[]>([])
const habitEntries = ref<HabitCalendarEntry[]>([])
const sources = ref<CalendarSource[]>([])
const hiddenCalendarIds = ref<Set<number>>(new Set())
const hiddenTasks = ref(false)
const hiddenHabits = ref(false)
const eventsLoading = ref(false)
const editingDay = ref('')
const newTitle = ref('')
const dayOpen = ref('')
const dayTitleInput = ref('')
const scrollRef = ref<HTMLElement | null>(null)
const createInput = ref<HTMLInputElement[] | HTMLInputElement | null>(null)
let requestId = 0

interface CalItem {
  key: string
  kind: 'task' | 'event' | 'habit'
  title: string
  color: string
  allDay: boolean
  start?: Date
  end?: Date
  timeLabel: string
  location?: string
  task?: TaskItem
  event?: CalendarEvent
  habitId?: number
  habitDone?: boolean
}

interface LayoutItem extends CalItem {
  style: Record<string, string>
  height: number
  top: number
  column?: number
  columns?: number
}

const monthStart = computed(() => new Date(props.cursor.getFullYear(), props.cursor.getMonth(), 1))
const weekStart = computed(() => {
  const start = new Date(props.cursor.getFullYear(), props.cursor.getMonth(), props.cursor.getDate())
  start.setDate(start.getDate() - start.getDay())
  return start
})

const visibleDays = computed(() => {
  if (props.viewMode === 'day') {
    const date = new Date(props.cursor.getFullYear(), props.cursor.getMonth(), props.cursor.getDate())
    return [{ key: dayKey(date), date }]
  }
  const start = weekStart.value
  return Array.from({ length: 7 }, (_, index) => {
    const date = new Date(start)
    date.setDate(start.getDate() + index)
    return { key: dayKey(date), date }
  })
})

const range = computed(() => {
  if (props.viewMode === 'month') {
    const start = new Date(monthStart.value)
    start.setDate(start.getDate() - start.getDay())
    const end = new Date(start)
    end.setDate(start.getDate() + 42)
    return { start, end }
  }
  if (props.viewMode === 'week') {
    const start = new Date(weekStart.value)
    const end = new Date(start)
    end.setDate(start.getDate() + 7)
    return { start, end }
  }
  if (props.viewMode === 'day') {
    const start = new Date(props.cursor.getFullYear(), props.cursor.getMonth(), props.cursor.getDate())
    const end = new Date(start)
    end.setDate(start.getDate() + 1)
    return { start, end }
  }
  const start = new Date(props.cursor.getFullYear(), props.cursor.getMonth(), props.cursor.getDate())
  const end = new Date(start)
  end.setDate(start.getDate() + 30)
  return { start, end }
})

const rangeTitle = computed(() => {
  if (props.viewMode === 'month') return `${props.cursor.getFullYear()} 年 ${props.cursor.getMonth() + 1} 月`
  if (props.viewMode === 'week') {
    const start = weekStart.value
    const end = new Date(start)
    end.setDate(start.getDate() + 6)
    return `${start.getMonth() + 1} 月 ${start.getDate()} 日 - ${end.getMonth() + 1} 月 ${end.getDate()} 日`
  }
  if (props.viewMode === 'day') {
    return `${props.cursor.getFullYear()} 年 ${props.cursor.getMonth() + 1} 月 ${props.cursor.getDate()} 日 ${weekdays[props.cursor.getDay()]}`
  }
  const end = new Date(props.cursor)
  end.setDate(end.getDate() + 29)
  return `${props.cursor.getMonth() + 1} 月 ${props.cursor.getDate()} 日 - ${end.getMonth() + 1} 月 ${end.getDate()} 日`
})

const visibleTasks = computed(() => hiddenTasks.value ? [] : props.tasks)
const visibleHabitEntries = computed(() => hiddenHabits.value ? [] : habitEntries.value)
const visibleEvents = computed(() => events.value.filter((event) => !hiddenCalendarIds.value.has(event.calendarId)))

const summaryText = computed(() => {
  const taskCount = hiddenTasks.value ? 0 : (props.viewMode === 'month' ? tasksInMonth.value : tasksInRange.value)
  return `${taskCount} 个任务 · ${visibleEvents.value.length} 个日程`
})

const tasksInMonth = computed(() => {
  const prefix = `${props.cursor.getFullYear()}-${String(props.cursor.getMonth() + 1).padStart(2, '0')}`
  return visibleTasks.value.filter((task) => taskDayKey(task).startsWith(prefix)).length
})

const tasksInRange = computed(() => {
  const from = dayKey(range.value.start)
  const to = dayKey(range.value.end)
  return visibleTasks.value.filter((task) => {
    const key = taskDayKey(task)
    return key >= from && key < to
  }).length
})

const monthCells = computed(() => {
  const year = props.cursor.getFullYear()
  const month = props.cursor.getMonth()
  const first = new Date(year, month, 1)
  const start = new Date(year, month, 1 - first.getDay())
  return Array.from({ length: 42 }, (_, index) => {
    const date = new Date(start)
    date.setDate(start.getDate() + index)
    const key = dayKey(date)
    return {
      key,
      label: date.getDate() === 1 ? `${date.getMonth() + 1}/${date.getDate()}` : date.getDate(),
      inMonth: date.getMonth() === month,
      isToday: key === todayKey,
    }
  })
})

const itemsByDay = computed(() => {
  const map: Record<string, CalItem[]> = {}
  const push = (key: string, item: CalItem) => {
    if (!map[key]) map[key] = []
    map[key].push(item)
  }
  for (const task of visibleTasks.value) {
    if (!task.due) continue
    const start = new Date(task.due)
    const key = dayKey(start)
    push(key, {
      key: `task-${task.id}-${key}`,
      kind: 'task',
      title: task.title,
      color: task.listColor || '#4772fa',
      allDay: task.allDay,
      start: task.allDay ? undefined : start,
      end: task.allDay ? undefined : new Date(start.getTime() + 30 * 60000),
      timeLabel: task.allDay ? '全天' : timeText(start),
      task,
    })
  }
  for (const entry of visibleHabitEntries.value) {
    push(entry.date, {
      key: `habit-${entry.habitId}-${entry.date}`,
      kind: 'habit',
      title: `${entry.icon || '✓'} ${entry.name}`,
      color: entry.color || '#97E38B',
      allDay: true,
      timeLabel: '全天',
      habitId: entry.habitId,
      habitDone: entry.done,
    })
  }
  for (const event of visibleEvents.value) {
    const start = new Date(event.start)
    const end = new Date(event.end)
    if (event.allDay) {
      const cursor = new Date(start.getFullYear(), start.getMonth(), start.getDate())
      const last = new Date(end)
      if (last.getHours() === 0 && last.getMinutes() === 0) last.setDate(last.getDate() - 1)
      while (cursor <= last) {
        const key = dayKey(cursor)
        push(key, {
          key: `event-${event.id}-${key}`,
          kind: 'event',
          title: event.summary,
          color: event.color || '#4772fa',
          allDay: true,
          timeLabel: '全天',
          location: event.location,
          event,
        })
        cursor.setDate(cursor.getDate() + 1)
      }
    } else {
      const lastDay = new Date(end)
      if (lastDay.getHours() === 0 && lastDay.getMinutes() === 0 && lastDay.getSeconds() === 0) {
        lastDay.setDate(lastDay.getDate() - 1)
      }
      lastDay.setHours(0, 0, 0, 0)
      const cursor = new Date(start.getFullYear(), start.getMonth(), start.getDate())
      while (cursor <= lastDay) {
        const dayStart = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate())
        const dayEnd = new Date(dayStart)
        dayEnd.setDate(dayEnd.getDate() + 1)
        const segmentStart = start > dayStart ? start : dayStart
        const segmentEnd = end < dayEnd ? end : dayEnd
        if (segmentStart < segmentEnd) {
          push(dayKey(cursor), {
            key: `event-${event.id}-${dayKey(cursor)}`,
            kind: 'event',
            title: event.summary,
            color: event.color || '#4772fa',
            allDay: false,
            start: segmentStart,
            end: segmentEnd,
            timeLabel: timeText(segmentStart),
            location: event.location,
            event,
          })
        }
        cursor.setDate(cursor.getDate() + 1)
      }
    }
  }
  for (const key of Object.keys(map)) {
    map[key].sort((a, b) => {
      if (a.allDay !== b.allDay) return a.allDay ? -1 : 1
      return (a.start?.getTime() || 0) - (b.start?.getTime() || 0)
    })
  }
  return map
})

const agendaGroups = computed(() => {
  const out: Array<{ key: string; title: string; items: CalItem[] }> = []
  const start = new Date(props.cursor.getFullYear(), props.cursor.getMonth(), props.cursor.getDate())
  for (let index = 0; index < 30; index += 1) {
    const date = new Date(start)
    date.setDate(start.getDate() + index)
    const key = dayKey(date)
    const items = itemsByDay.value[key] || []
    if (!items.length) continue
    out.push({ key, title: `${date.getMonth() + 1} 月 ${date.getDate()} 日 ${weekdays[date.getDay()]}`, items })
  }
  return out
})

const dayItems = computed(() => itemsByDay.value[dayOpen.value] || [])

const dayTitle = computed(() => {
  if (!dayOpen.value) return ''
  const [year, month, day] = dayOpen.value.split('-').map(Number)
  const date = new Date(year, month - 1, day)
  return `${month} 月 ${day} 日 ${weekdays[date.getDay()]}`
})

const nowTop = computed(() => {
  const now = new Date()
  return (now.getHours() + now.getMinutes() / 60) * HOUR_HEIGHT
})

function timeText(date: Date) {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

function cellItems(key: string) {
  return itemsByDay.value[key] || []
}

function allDayItems(key: string) {
  return (itemsByDay.value[key] || []).filter((item) => item.allDay)
}

function timedItems(key: string) {
  const day = new Date(`${key}T00:00:00`)
  const dayEnd = new Date(day)
  dayEnd.setDate(day.getDate() + 1)
  return (itemsByDay.value[key] || []).filter((item) => {
    if (item.allDay || !item.start) return false
    return item.end ? item.end > day && item.start < dayEnd : item.start >= day && item.start < dayEnd
  })
}

function layoutItems(key: string): LayoutItem[] {
  const day = new Date(`${key}T00:00:00`)
  const dayEnd = new Date(day)
  dayEnd.setDate(day.getDate() + 1)
  const items = timedItems(key).map((item) => {
    const start = item.start && item.start < day ? day : item.start || day
    const end = item.end && item.end > dayEnd ? dayEnd : item.end || new Date((item.start || day).getTime() + 30 * 60000)
    const top = (start.getHours() + start.getMinutes() / 60) * HOUR_HEIGHT
    const height = Math.max(((end.getTime() - start.getTime()) / 3600000) * HOUR_HEIGHT, 22)
    return { ...item, start, end, top, height, column: 0, columns: 1 }
  })
  items.sort((a, b) => (a.start?.getTime() || 0) - (b.start?.getTime() || 0) || b.height - a.height)
  const result: LayoutItem[] = []
  let cluster: typeof items = []
  let clusterEnd = 0
  const flush = () => {
    if (!cluster.length) return
    const columnEnds: number[] = []
    for (const item of cluster) {
      const start = item.start?.getTime() || 0
      let column = columnEnds.findIndex((value) => value <= start)
      if (column === -1) {
        column = columnEnds.length
        columnEnds.push(0)
      }
      columnEnds[column] = item.end?.getTime() || start
      item.column = column
    }
    const columns = Math.max(columnEnds.length, 1)
    for (const item of cluster) {
      result.push({
        ...item,
        columns,
        style: {
          top: `${item.top}px`,
          height: `${item.height}px`,
          left: `calc(${(item.column / columns) * 100}% + 2px)`,
          width: `calc(${100 / columns}% - 4px)`,
          borderLeftColor: item.color,
          background: `color-mix(in srgb, ${item.color} 22%, var(--tw-bg))`,
        },
      })
    }
    cluster = []
    clusterEnd = 0
  }
  for (const item of items) {
    const start = item.start?.getTime() || 0
    const end = item.end?.getTime() || start
    if (cluster.length && start >= clusterEnd) flush()
    cluster.push(item)
    clusterEnd = Math.max(clusterEnd, end)
  }
  flush()
  return result
}

const dragItem = ref<CalItem | null>(null)
const suppressClick = ref(false)
const resizeState = ref<{ item: CalItem; startY: number; start: number; end: number; nextEnd: number } | null>(null)

function startDrag(item: CalItem, event: DragEvent) {
  dragItem.value = item
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', item.key)
  }
}

function formatLocal(date: Date) {
  const pad = (value: number) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

function addDaysLocal(date: Date, days: number) {
  const next = new Date(date)
  next.setDate(next.getDate() + days)
  return next
}

function eventDuration(event: CalendarEvent) {
  const start = new Date(event.start).getTime()
  const end = new Date(event.end).getTime()
  return Math.max(15 * 60000, end - start)
}

function allDayDuration(event: CalendarEvent) {
  const start = new Date(event.start)
  const end = new Date(event.end)
  const days = Math.round((end.getTime() - start.getTime()) / 86400000)
  return Math.max(1, days)
}

function dropOnDay(key: string) {
  const item = dragItem.value
  dragItem.value = null
  if (!item) return
  if (item.kind === 'task' && item.task) {
    const task = item.task
    if (task.allDay || !task.due) {
      emit('reschedule-task', { task, due: `${key}T00:00:00`, allDay: true })
      return
    }
    const original = new Date(task.due)
    emit('reschedule-task', {
      task,
      due: `${key}T${String(original.getHours()).padStart(2, '0')}:${String(original.getMinutes()).padStart(2, '0')}`,
      allDay: false,
    })
    return
  }
  if (!item.event) return
  const event = item.event
  if (event.allDay) {
    const start = new Date(`${key}T00:00:00`)
    const end = addDaysLocal(start, allDayDuration(event))
    emit('reschedule-event', { event, start: `${key}T00:00:00`, end: formatLocal(end), allDay: true })
    return
  }
  const original = new Date(event.start)
  const start = new Date(`${key}T${String(original.getHours()).padStart(2, '0')}:${String(original.getMinutes()).padStart(2, '0')}:00`)
  const end = new Date(start.getTime() + eventDuration(event))
  emit('reschedule-event', { event, start: formatLocal(start), end: formatLocal(end), allDay: false })
}

function dropAllDay(key: string) {
  const item = dragItem.value
  dragItem.value = null
  if (!item) return
  if (item.kind === 'task' && item.task) {
    emit('reschedule-task', { task: item.task, due: `${key}T00:00:00`, allDay: true })
    return
  }
  if (!item.event) return
  const event = item.event
  const days = event.allDay ? allDayDuration(event) : 1
  const start = new Date(`${key}T00:00:00`)
  const end = addDaysLocal(start, days)
  emit('reschedule-event', { event, start: `${key}T00:00:00`, end: formatLocal(end), allDay: true })
}

function dropOnTime(key: string, hour: number) {
  const item = dragItem.value
  dragItem.value = null
  if (!item) return
  const time = `${String(hour).padStart(2, '0')}:00`
  if (item.kind === 'task' && item.task) {
    emit('reschedule-task', { task: item.task, due: `${key}T${time}`, allDay: false })
    return
  }
  if (!item.event) return
  const event = item.event
  const start = new Date(`${key}T${time}:00`)
  const duration = event.allDay ? 60 * 60000 : eventDuration(event)
  const end = new Date(start.getTime() + duration)
  emit('reschedule-event', { event, start: formatLocal(start), end: formatLocal(end), allDay: false })
}

function startResize(item: CalItem, event: PointerEvent) {
  if (!item.event || item.event.allDay) return
  const start = new Date(item.event.start).getTime()
  const end = new Date(item.event.end).getTime()
  resizeState.value = { item, startY: event.clientY, start, end, nextEnd: end }
  window.addEventListener('pointermove', moveResize)
  window.addEventListener('pointerup', finishResize, { once: true })
}

function moveResize(event: PointerEvent) {
  const state = resizeState.value
  if (!state) return
  const deltaMinutes = Math.round((event.clientY - state.startY) / (HOUR_HEIGHT / 60) / 15) * 15
  const next = Math.max(state.start + 15 * 60000, state.end + deltaMinutes * 60000)
  state.nextEnd = next
  resizeState.value = { ...state }
}

function finishResize() {
  const state = resizeState.value
  resizeState.value = null
  window.removeEventListener('pointermove', moveResize)
  if (!state || state.nextEnd === state.end) return
  suppressClick.value = true
  window.setTimeout(() => { suppressClick.value = false }, 0)
  emit('reschedule-event', {
    event: state.item.event!,
    start: formatLocal(new Date(state.start)),
    end: formatLocal(new Date(state.nextEnd)),
    allDay: false,
  })
}

function onBlockClick(item: CalItem) {
  if (suppressClick.value) return
  if (item.kind === 'task') emit('open', item.task!)
  else emit('open-event', item.event!)
}

function resizeStyle(item: CalItem) {
  const state = resizeState.value
  if (!state || state.item.key !== item.key) return {}
  const height = Math.max(18, ((state.nextEnd - state.start) / 3600000) * HOUR_HEIGHT)
  return { height: `${height}px`, zIndex: 3 }
}

function cleanupResize() {
  window.removeEventListener('pointermove', moveResize)
  resizeState.value = null
}

onBeforeUnmount(cleanupResize)

function toggleCalendar(id: number) {
  const next = new Set(hiddenCalendarIds.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  hiddenCalendarIds.value = next
  persistCalendarVisibility()
}

function toggleTasks() {
  hiddenTasks.value = !hiddenTasks.value
  persistCalendarVisibility()
}

function toggleHabits() {
  hiddenHabits.value = !hiddenHabits.value
  persistCalendarVisibility()
}

function persistCalendarVisibility() {
  try {
    localStorage.setItem('caldav-calendar-visibility', JSON.stringify({
      calendars: [...hiddenCalendarIds.value], tasks: hiddenTasks.value, habits: hiddenHabits.value,
    }))
  } catch {
    // Ignore private mode/storage failures.
  }
}

function restoreCalendarVisibility() {
  try {
    const raw = localStorage.getItem('caldav-calendar-visibility')
    if (!raw) return
    const value = JSON.parse(raw) as { calendars?: number[]; tasks?: boolean; habits?: boolean }
    hiddenCalendarIds.value = new Set(Array.isArray(value.calendars) ? value.calendars : [])
    hiddenTasks.value = Boolean(value.tasks)
    hiddenHabits.value = Boolean(value.habits)
  } catch {
    // Ignore malformed or unavailable storage.
  }
}

async function loadEvents() {
  const current = ++requestId
  eventsLoading.value = true
  try {
    const [data, habitData] = await Promise.all([
      fetchCalendarEvents(range.value.start, range.value.end),
      fetchHabitCalendar(dayKey(range.value.start), dayKey(range.value.end)).catch(() => ({ entries: [] })),
    ])
    if (current !== requestId) return
    events.value = data.events
    habitEntries.value = habitData.entries || []
    sources.value = data.calendars
    emit('calendars', data.calendars)
    openFocusEvent()
  } catch {
    if (current === requestId) {
      events.value = []
      habitEntries.value = []
      sources.value = []
    }
  } finally {
    if (current === requestId) eventsLoading.value = false
  }
}

function openFocusEvent() {
  const focus = props.focus
  if (!focus) return
  if (hiddenCalendarIds.value.has(focus.calendarId)) {
    const next = new Set(hiddenCalendarIds.value)
    next.delete(focus.calendarId)
    hiddenCalendarIds.value = next
    persistCalendarVisibility()
  }
  const candidates = events.value.filter((event) => event.calendarId === focus.calendarId && event.href === focus.href)
  const target = candidates.find((event) => sameInstant(event.start, focus.occurrence)) || candidates[0]
  if (!target) return
  emit('open-event', target)
  emit('focus-opened')
}

function sameInstant(left: string, right: string) {
  return new Date(left).getTime() === new Date(right).getTime()
}

async function scrollToMorning() {
  await nextTick()
  if (scrollRef.value) scrollRef.value.scrollTop = 7 * HOUR_HEIGHT
}

watch([() => props.viewMode, () => props.cursor, () => props.reloadKey], () => {
  void loadEvents()
  if (props.viewMode === 'week' || props.viewMode === 'day') void scrollToMorning()
})

restoreCalendarVisibility()

onMounted(() => {
  void loadEvents()
  if (props.viewMode === 'week' || props.viewMode === 'day') void scrollToMorning()
})

function openDay(key: string) {
  dayOpen.value = key
  dayTitleInput.value = ''
}

function openCalendarItem(item: CalItem) {
  if (item.kind === 'task' && item.task) emit('open', item.task)
  else if (item.kind === 'habit' && item.habitId) emit('open-habit', item.habitId)
  else if (item.event) emit('open-event', item.event)
}

function openDayItem(item: CalItem) {
  dayOpen.value = ''
  openCalendarItem(item)
}

async function startCreate(key: string) {
  editingDay.value = key
  newTitle.value = ''
  await nextTick()
  const input = createInput.value
  if (Array.isArray(input)) input[0]?.focus()
  else input?.focus()
}

function cancelCreate() {
  editingDay.value = ''
  newTitle.value = ''
}

function submitCreate() {
  const title = newTitle.value.trim()
  if (!title) return cancelCreate()
  emit('create', { date: editingDay.value, title })
  cancelCreate()
}

function submitDay() {
  const title = dayTitleInput.value.trim()
  if (!title) return
  emit('create', { date: dayOpen.value, title })
  dayTitleInput.value = ''
  dayOpen.value = ''
}
</script>
