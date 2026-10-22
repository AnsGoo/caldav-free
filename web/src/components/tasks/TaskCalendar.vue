<template>
  <section class="tw-calendar">
    <header class="tw-calendar-head">
      <div class="tw-calendar-title">
        <h2>{{ monthTitle }}</h2>
        <span class="tw-calendar-sub">{{ tasksInMonth }} 个任务</span>
      </div>
      <div class="tw-calendar-actions">
        <button class="tw-ghost-button" @click="$emit('today')">今天</button>
        <button class="tw-icon-button" title="上个月" @click="$emit('prev')">
          <TaskIcon name="back" :size="16" />
        </button>
        <button class="tw-icon-button" title="下个月" @click="$emit('next')">
          <TaskIcon name="chevron" :size="16" />
        </button>
      </div>
    </header>

    <div class="tw-calendar-weekdays">
      <span v-for="day in weekdays" :key="day">{{ day }}</span>
    </div>

    <div class="tw-calendar-grid">
      <div
        v-for="cell in cells"
        :key="cell.key"
        class="tw-calendar-cell"
        :class="{ muted: !cell.inMonth, today: cell.isToday }"
      >
        <div class="tw-cell-head">
          <button class="tw-cell-day" title="查看当天任务" @click="openDay(cell.key)">{{ cell.label }}</button>
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
          <button
            v-for="task in (tasksByDay[cell.key] || []).slice(0, 3)"
            :key="task.id"
            class="tw-calendar-task"
            :class="{ done: task.completed, overdue: cell.key < todayKey && !task.completed }"
            :title="task.title"
            @click="$emit('open', task)"
          >
            <i :style="{ background: task.listColor || '#4772fa' }" />
            <span>{{ task.title }}</span>
          </button>
          <button
            v-if="(tasksByDay[cell.key] || []).length > 3"
            class="tw-cell-more"
            @click="$emit('open', tasksByDay[cell.key][3])"
          >
            +{{ tasksByDay[cell.key].length - 3 }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="dayOpen" class="tw-day-scrim" @click.self="dayOpen = ''">
      <div class="tw-day-sheet" role="dialog" aria-modal="true">
        <header class="tw-day-head">
          <div>
            <h3>{{ dayTitle }}</h3>
            <small>{{ dayTasks.length }} 个任务</small>
          </div>
          <button class="tw-icon-button" title="关闭" @click="dayOpen = ''">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-day-list">
          <button v-for="task in dayTasks" :key="task.id" class="tw-day-row" @click="openFromDay(task)">
            <span class="tw-check" :class="{ checked: task.completed }">
              <svg v-if="task.completed" viewBox="0 0 20 20" width="10" height="10" aria-hidden="true">
                <path d="m4.5 10.2 3.6 3.7 7.4-8" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </span>
            <span class="tw-day-title" :class="{ done: task.completed }">{{ task.title }}</span>
            <small>{{ task.allDay ? '全天' : timeOf(task.due || '') }}</small>
          </button>
          <p v-if="!dayTasks.length" class="tw-day-empty">这一天还没有任务</p>
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
import { computed, nextTick, ref } from 'vue'
import type { TaskItem } from '../../types'
import { dayKey, startOfToday, taskDayKey } from '../../tasks-utils'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ tasks: TaskItem[]; cursor: Date }>()
const emit = defineEmits<{
  (event: 'open', task: TaskItem): void
  (event: 'create', payload: { date: string; title: string }): void
  (event: 'prev'): void
  (event: 'next'): void
  (event: 'today'): void
}>()

const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
const editingDay = ref('')
const newTitle = ref('')
const dayOpen = ref('')
const dayTitleInput = ref('')
const createInput = ref<HTMLInputElement[] | HTMLInputElement | null>(null)

const todayKey = dayKey(startOfToday())

const monthTitle = computed(() => `${props.cursor.getFullYear()} 年 ${props.cursor.getMonth() + 1} 月`)

const tasksByDay = computed(() => {
  const map: Record<string, TaskItem[]> = {}
  for (const task of props.tasks) {
    const key = taskDayKey(task)
    if (!key) continue
    if (!map[key]) map[key] = []
    map[key].push(task)
  }
  for (const key of Object.keys(map)) {
    map[key].sort((a, b) => {
      if (a.allDay !== b.allDay) return a.allDay ? -1 : 1
      return (a.due || '').localeCompare(b.due || '')
    })
  }
  return map
})

const cells = computed(() => {
  const year = props.cursor.getFullYear()
  const month = props.cursor.getMonth()
  const first = new Date(year, month, 1)
  const start = new Date(year, month, 1 - first.getDay())
  const out: Array<{ key: string; label: number | string; inMonth: boolean; isToday: boolean }> = []
  for (let index = 0; index < 42; index += 1) {
    const date = new Date(start)
    date.setDate(start.getDate() + index)
    const key = dayKey(date)
    out.push({
      key,
      label: date.getDate() === 1 ? `${date.getMonth() + 1}/${date.getDate()}` : date.getDate(),
      inMonth: date.getMonth() === month,
      isToday: key === todayKey,
    })
  }
  return out
})

const dayTasks = computed(() => tasksByDay.value[dayOpen.value] || [])

const dayTitle = computed(() => {
  if (!dayOpen.value) return ''
  const [year, month, day] = dayOpen.value.split('-').map(Number)
  const date = new Date(year, month - 1, day)
  return `${month} 月 ${day} 日 ${weekdays[date.getDay()]}`
})

const tasksInMonth = computed(() => {
  const prefix = `${props.cursor.getFullYear()}-${String(props.cursor.getMonth() + 1).padStart(2, '0')}`
  return props.tasks.filter((task) => taskDayKey(task).startsWith(prefix)).length
})

async function startCreate(key: string) {
  editingDay.value = key
  newTitle.value = ''
  await nextTick()
  const input = createInput.value
  if (Array.isArray(input)) input[0]?.focus()
  else input?.focus()
}

function openFromDay(task: TaskItem) {
  dayOpen.value = ''
  emit('open', task)
}

function openDay(key: string) {
  dayOpen.value = key
  dayTitleInput.value = ''
}

function submitDay() {
  const title = dayTitleInput.value.trim()
  if (!title) return
  emit('create', { date: dayOpen.value, title })
  dayTitleInput.value = ''
  dayOpen.value = ''
}

function timeOf(value: string) {
  if (!value) return ''
  const date = new Date(value)
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
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
</script>
