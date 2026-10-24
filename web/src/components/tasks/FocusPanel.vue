<template>
  <section class="tw-focus" :class="{ 'is-running': timerState === 'running' }">
    <header class="tw-focus-head">
      <div class="tw-focus-title">
        <span class="tw-focus-kicker">FOCUS</span>
        <h1>番茄专注</h1>
      </div>
      <div class="tw-focus-mode" role="tablist" aria-label="专注模式">
        <button :class="{ active: mode === 'pomodoro' }" :disabled="timerState !== 'idle'" @click="switchFocusMode('pomodoro')">番茄计时</button>
        <button :class="{ active: mode === 'stopwatch' }" :disabled="timerState !== 'idle'" @click="switchFocusMode('stopwatch')">正计时</button>
      </div>
      <div class="tw-focus-head-actions">
        <button class="tw-icon-button" title="添加专注记录" @click="openManual"><TaskIcon name="plus" :size="18" /></button>
        <button class="tw-icon-button" title="专注统计" @click="statsOpen = true"><TaskIcon name="chart" :size="18" /></button>
        <button class="tw-icon-button" title="专注设置" @click="openSettings"><TaskIcon name="settings" :size="18" /></button>
      </div>
    </header>

    <div v-if="loading" class="tw-focus-loading"><a-spin /></div>
    <div v-else class="tw-focus-body">
      <main class="tw-focus-main">
        <button class="tw-focus-target" :class="{ active: target }" @click="openPicker('timer')">
          <span class="tw-focus-target-icon"><TaskIcon :name="target?.type === 'habit' ? 'habit' : 'check'" :size="14" /></span>
          <span>{{ target?.title || '选择任务或习惯' }}</span>
          <TaskIcon name="chevron" :size="12" />
        </button>

        <div class="tw-focus-stage">
          <div class="tw-focus-ring" :style="{ '--focus-progress': progress }">
            <svg viewBox="0 0 400 400" aria-hidden="true">
              <circle class="track" cx="200" cy="200" r="190" />
              <circle class="value" cx="200" cy="200" r="190" :style="{ strokeDashoffset: 1193.8 * (1 - progress) }" />
            </svg>
            <div class="tw-focus-clock">
              <strong>{{ timerDisplay }}</strong>
              <span>{{ statusLabel }}</span>
            </div>
          </div>

          <div v-if="phase !== 'focus'" class="tw-focus-phase-label">{{ phase === 'longBreak' ? '长休息' : '短休息' }}</div>
          <div class="tw-focus-controls">
            <button v-if="timerState !== 'running'" class="tw-focus-primary" @click="handlePrimary">
              {{ timerState === 'paused' ? (phase === 'focus' ? '继续专注' : '继续休息') : (phase === 'focus' ? '开始' : '开始休息') }}
            </button>
            <button v-else class="tw-focus-primary pause" @click="pauseTimer">暂停</button>
            <button v-if="timerState !== 'idle'" class="tw-focus-secondary" @click="endCurrentTimer">
              {{ phase === 'focus' ? '结束' : '跳过休息' }}
            </button>
          </div>
          <p class="tw-focus-hint">
            <template v-if="phase === 'focus' && mode === 'pomodoro'">完成一个番茄后自动记录，并进入休息节奏</template>
            <template v-else-if="phase === 'focus'">正计时会持续累计，结束后保存本次专注</template>
            <template v-else>休息一下，下一轮专注会更清醒</template>
          </p>
        </div>

        <div class="tw-focus-note">
          <header>
            <span>专注笔记</span>
            <small>{{ note.length }}/2000</small>
          </header>
          <textarea v-model="note" maxlength="2000" placeholder="记录此刻的想法…" />
        </div>
      </main>

      <aside class="tw-focus-side">
        <div class="tw-focus-side-head">
          <h2>{{ timerState !== 'idle' && phase === 'focus' ? '当前专注' : '概览' }}</h2>
          <span v-if="timerState !== 'idle' && phase === 'focus'" class="tw-focus-live-dot">进行中</span>
        </div>

        <div class="tw-focus-stats">
          <article><span>今日番茄</span><strong>{{ dashboard?.stats.todayPomodoroCount || 0 }}</strong><small>个</small></article>
          <article><span>今日专注</span><strong>{{ dashboard?.stats.todayFocusMinutes || 0 }}</strong><small>m</small></article>
          <article><span>总番茄</span><strong>{{ dashboard?.stats.totalPomodoroCount || 0 }}</strong><small>个</small></article>
          <article><span>总专注</span><strong>{{ dashboard?.stats.totalFocusMinutes || 0 }}</strong><small>m</small></article>
        </div>

        <div v-if="timerState !== 'idle' && phase === 'focus'" class="tw-focus-current">
          <div class="tw-focus-current-row"><span>开始时间</span><strong>{{ currentStartLabel }}</strong></div>
          <div class="tw-focus-current-row"><span>本次目标</span><strong>{{ target?.title || '自由专注' }}</strong></div>
          <div class="tw-focus-current-row"><span>已专注</span><strong>{{ currentElapsedLabel }}</strong></div>
          <p>把注意力留给此刻，其他事情稍后再处理。</p>
        </div>

        <section class="tw-focus-history">
          <header>
            <h2>专注记录</h2>
            <span>{{ dashboard?.sessions.length || 0 }} 条</span>
          </header>
          <div v-if="!sessionGroups.length" class="tw-focus-empty">
            <div class="tw-focus-empty-icon"><TaskIcon name="clock" :size="30" /></div>
            <strong>还没有专注记录</strong>
            <span>完成一次番茄或正计时后会出现在这里</span>
          </div>
          <div v-for="group in sessionGroups" :key="group.date" class="tw-focus-day">
            <div class="tw-focus-day-label">{{ group.label }}</div>
            <article v-for="session in group.sessions" :key="session.id" class="tw-focus-record">
              <div class="tw-focus-record-main">
                <div class="tw-focus-record-line">
                  <strong>{{ formatTime(session.startedAt) }} - {{ formatTime(session.endedAt) }}</strong>
                  <span>{{ formatDuration(session.durationSeconds) }}</span>
                </div>
                <div class="tw-focus-record-meta">
                  <span class="tw-focus-record-mode">{{ session.mode === 'stopwatch' ? '正计时' : (session.pomodoroCount ? `${session.pomodoroCount} 个番茄` : '番茄计时') }}</span>
                  <span v-if="session.title && session.title !== '专注'" class="tw-focus-record-target">{{ session.title }}</span>
                </div>
                <p v-if="session.note">{{ session.note }}</p>
              </div>
              <button class="tw-icon-button tw-focus-record-delete" title="删除记录" @click="deleteRecord(session)"><TaskIcon name="trash" :size="14" /></button>
            </article>
          </div>
        </section>
      </aside>
    </div>

    <div v-if="pickerOpen" class="tw-dialog-scrim" @click.self="pickerOpen = false">
      <div class="tw-dialog tw-focus-picker" role="dialog" aria-modal="true">
        <header class="tw-dialog-head">
          <h2>关联专注对象</h2>
          <button class="tw-icon-button" title="关闭" @click="pickerOpen = false"><TaskIcon name="close" :size="16" /></button>
        </header>
        <div class="tw-focus-picker-tabs">
          <button :class="{ active: pickerTab === 'task' }" @click="pickerTab = 'task'">任务</button>
          <button :class="{ active: pickerTab === 'habit' }" @click="pickerTab = 'habit'">习惯</button>
        </div>
        <div class="tw-focus-picker-search">
          <TaskIcon name="search" :size="15" />
          <input v-model="pickerQuery" placeholder="搜索任务或习惯" />
        </div>
        <div class="tw-focus-picker-list">
          <button class="tw-focus-picker-clear" @click="selectTarget(null)">自由专注（不关联）</button>
          <button v-for="item in pickerItems" :key="`${item.type}-${item.id}`" class="tw-focus-picker-item" @click="selectTarget(item)">
            <span class="tw-focus-picker-icon"><TaskIcon :name="item.type === 'habit' ? 'habit' : 'check'" :size="14" /></span>
            <span>{{ item.title }}</span>
          </button>
          <p v-if="!pickerItems.length" class="tw-modal-note">没有匹配的{{ pickerTab === 'habit' ? '习惯' : '任务' }}。</p>
        </div>
      </div>
    </div>

    <div v-if="settingsOpen" class="tw-dialog-scrim" @click.self="settingsOpen = false">
      <div class="tw-dialog tw-focus-settings" role="dialog" aria-modal="true">
        <header class="tw-dialog-head">
          <h2>专注设置</h2>
          <button class="tw-icon-button" title="关闭" @click="settingsOpen = false"><TaskIcon name="close" :size="16" /></button>
        </header>
        <div class="tw-dialog-body tw-focus-settings-body">
          <section class="tw-focus-setting-card">
            <h3>计时选项</h3>
            <label class="tw-focus-setting-row"><span>番茄时长</span><input v-model.number="settingsDraft.pomodoroMinutes" type="number" min="5" max="180" /><em>分钟</em></label>
            <label class="tw-focus-setting-row"><span>短休息时长</span><input v-model.number="settingsDraft.shortBreakMinutes" type="number" min="1" max="60" /><em>分钟</em></label>
            <label class="tw-focus-setting-row"><span>长休息时长</span><input v-model.number="settingsDraft.longBreakMinutes" type="number" min="1" max="60" /><em>分钟</em></label>
            <label class="tw-focus-setting-row"><span>长休息间隔</span><input v-model.number="settingsDraft.longBreakInterval" type="number" min="1" max="60" /><em>个番茄</em></label>
            <label class="tw-focus-setting-row"><span>每日目标</span><input v-model.number="settingsDraft.dailyGoal" type="number" min="0" max="100" /><em>个番茄</em></label>
          </section>
          <section class="tw-focus-setting-card">
            <h3>自动选项</h3>
            <label class="tw-focus-setting-toggle"><span>自动开始下个番茄</span><input v-model="settingsDraft.autoStartPomodoro" type="checkbox" /></label>
            <label class="tw-focus-setting-toggle"><span>自动开始休息</span><input v-model="settingsDraft.autoStartBreak" type="checkbox" /></label>
            <label class="tw-focus-setting-toggle"><span>番茄提示音</span><input v-model="settingsDraft.soundEnabled" type="checkbox" /></label>
            <label class="tw-focus-setting-toggle"><span>浏览器标签页计时</span><input v-model="settingsDraft.tabTitleEnabled" type="checkbox" /></label>
          </section>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="settingsOpen = false">取消</button>
          <button class="tw-dialog-ok" :disabled="settingsBusy" @click="saveSettings">{{ settingsBusy ? '保存中…' : '保存' }}</button>
        </footer>
      </div>
    </div>

    <div v-if="manualOpen" class="tw-dialog-scrim" @click.self="manualOpen = false">
      <div class="tw-dialog tw-focus-manual" role="dialog" aria-modal="true">
        <header class="tw-dialog-head">
          <h2>添加专注记录</h2>
          <button class="tw-icon-button" title="关闭" @click="manualOpen = false"><TaskIcon name="close" :size="16" /></button>
        </header>
        <div class="tw-dialog-body tw-focus-manual-body">
          <button class="tw-focus-target manual" @click="openPicker('manual')">
            <span class="tw-focus-target-icon"><TaskIcon :name="manualTarget?.type === 'habit' ? 'habit' : 'check'" :size="14" /></span>
            <span>{{ manualTarget?.title || '选择任务或习惯' }}</span>
            <TaskIcon name="chevron" :size="12" />
          </button>
          <label class="tw-focus-field"><span>开始时间</span><a-date-picker v-model="manualForm.startedAt" class="tw-date-control" show-time value-format="YYYY-MM-DDTHH:mm" format="YYYY-MM-DD HH:mm" /></label>
          <label class="tw-focus-field"><span>结束时间</span><a-date-picker v-model="manualForm.endedAt" class="tw-date-control" show-time value-format="YYYY-MM-DDTHH:mm" format="YYYY-MM-DD HH:mm" /></label>
          <div class="tw-focus-field-row">
            <label class="tw-focus-field"><span>类型</span><select v-model="manualForm.mode"><option value="pomodoro">番茄计时</option><option value="stopwatch">正计时</option></select></label>
            <label v-if="manualForm.mode === 'pomodoro'" class="tw-focus-field small"><span>番茄数</span><input v-model.number="manualForm.pomodoroCount" type="number" min="0" max="10" /></label>
          </div>
          <label class="tw-focus-field"><span>专注笔记</span><textarea v-model="manualForm.note" maxlength="2000" placeholder="记录本次专注…" /></label>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="manualOpen = false">关闭</button>
          <button class="tw-dialog-ok" :disabled="manualBusy" @click="saveManual">{{ manualBusy ? '保存中…' : '确定' }}</button>
        </footer>
      </div>
    </div>

    <div v-if="statsOpen" class="tw-dialog-scrim" @click.self="statsOpen = false">
      <div class="tw-dialog tw-focus-stats-dialog" role="dialog" aria-modal="true">
        <header class="tw-dialog-head">
          <h2>专注统计</h2>
          <button class="tw-icon-button" title="关闭" @click="statsOpen = false"><TaskIcon name="close" :size="16" /></button>
        </header>
        <div class="tw-dialog-body tw-focus-stats-body">
          <div class="tw-focus-stats-overview">
            <article><span>今日番茄</span><strong>{{ dashboard?.stats.todayPomodoroCount || 0 }}<small>个</small></strong></article>
            <article><span>今日专注</span><strong>{{ dashboard?.stats.todayFocusMinutes || 0 }}<small>m</small></strong></article>
            <article><span>总番茄</span><strong>{{ dashboard?.stats.totalPomodoroCount || 0 }}<small>个</small></strong></article>
            <article><span>总专注</span><strong>{{ dashboard?.stats.totalFocusMinutes || 0 }}<small>m</small></strong></article>
          </div>
          <section class="tw-focus-stats-section">
            <header><strong>最近 7 天</strong><span>{{ weekTotalMinutes }} 分钟</span></header>
            <div class="tw-focus-week-bars">
              <div v-for="day in dashboard?.daily || []" :key="day.date" class="tw-focus-week-bar" :title="`${day.date} ${day.minutes} 分钟`">
                <i :style="{ height: `${weekBarHeight(day.minutes)}%` }" />
                <span>{{ weekdayLabel(day.date) }}</span>
              </div>
            </div>
          </section>
          <section class="tw-focus-stats-section">
            <header><strong>最佳专注时间</strong><span>{{ bestHour || '暂无数据' }}</span></header>
            <div class="tw-focus-hour-bars">
              <div v-for="hour in dashboard?.hourly || []" :key="hour.hour" class="tw-focus-hour" :title="`${hour.hour}:00 ${hour.minutes} 分钟`">
                <i :style="{ height: `${hourBarHeight(hour.minutes)}%` }" />
              </div>
            </div>
            <div class="tw-focus-hour-labels"><span>0</span><span>6</span><span>12</span><span>18</span><span>23</span></div>
          </section>
          <section class="tw-focus-stats-section">
            <header><strong>年度专注热力图</strong><span>{{ currentYear }}</span></header>
            <div class="tw-focus-heatmap">
              <div v-for="(week, index) in heatmapWeeks" :key="index" class="tw-focus-heatmap-week">
                <span v-for="day in week" :key="day.date" class="tw-focus-heatmap-day" :class="`level-${heatLevel(day.minutes)}`" :title="`${day.date} ${day.minutes} 分钟`" />
              </div>
            </div>
            <div class="tw-focus-heatmap-legend"><span>少</span><i class="level-0" /><i class="level-1" /><i class="level-2" /><i class="level-3" /><i class="level-4" /><span>多</span></div>
          </section>
        </div>
        <footer class="tw-dialog-foot"><button class="tw-dialog-ok" @click="statsOpen = false">完成</button></footer>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { Message, Modal } from '@arco-design/web-vue'
import type { FocusDashboard, FocusMode, FocusPreference, FocusSession, HabitItem, TaskItem } from '../../types'
import { createFocusSession, deleteFocusSession, fetchFocusDashboard, fetchHabits, saveFocusPreferences } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ tasks: TaskItem[] }>()

type TimerState = 'idle' | 'running' | 'paused'
type FocusPhase = 'focus' | 'shortBreak' | 'longBreak'
type FocusTarget = { type: 'task' | 'habit'; id: number; title: string }

const loading = ref(true)
const dashboard = ref<FocusDashboard | null>(null)
const habits = ref<HabitItem[]>([])
const mode = ref<FocusMode>('pomodoro')
const phase = ref<FocusPhase>('focus')
const timerState = ref<TimerState>('idle')
const remaining = ref(25 * 60)
const elapsed = ref(0)
const phaseTotal = ref(25 * 60)
const deadline = ref(0)
const stopwatchBase = ref(0)
const sessionStartedAt = ref<Date | null>(null)
const pausedAccumMs = ref(0)
const pauseStartedAt = ref(0)
const note = ref('')
const target = ref<FocusTarget | null>(null)
const cyclePomodoros = ref(0)
const preferences = ref<FocusPreference>(defaultPreferences())

const settingsOpen = ref(false)
const settingsBusy = ref(false)
const settingsDraft = reactive<FocusPreference>(defaultPreferences())
const statsOpen = ref(false)
const manualOpen = ref(false)
const manualBusy = ref(false)
const manualTarget = ref<FocusTarget | null>(null)
const manualForm = reactive({
  startedAt: toLocalInput(new Date(Date.now() - 25 * 60 * 1000)),
  endedAt: toLocalInput(new Date()),
  mode: 'pomodoro' as FocusMode,
  pomodoroCount: 1,
  note: '',
})
const pickerOpen = ref(false)
const pickerTab = ref<'task' | 'habit'>('task')
const pickerQuery = ref('')
const pickerFor = ref<'timer' | 'manual'>('timer')

let ticker: ReturnType<typeof setInterval> | undefined
let transitionTimer: ReturnType<typeof setTimeout> | undefined
let audioContext: AudioContext | null = null
const originalTitle = document.title

const currentYear = new Date().getFullYear()

const focusTotal = computed(() => Math.max(1, preferences.value.pomodoroMinutes * 60))
const timerDisplay = computed(() => {
  if (phase.value !== 'focus' || mode.value === 'pomodoro') return formatClock(remaining.value)
  return formatClock(elapsed.value)
})
const progress = computed(() => {
  if (phase.value === 'focus' && mode.value === 'stopwatch') {
    return Math.min(1, (elapsed.value % 3600) / 3600)
  }
  return Math.max(0, Math.min(1, 1 - remaining.value / Math.max(1, phaseTotal.value)))
})
const statusLabel = computed(() => {
  if (phase.value === 'longBreak') return timerState.value === 'running' ? '长休息中' : (timerState.value === 'paused' ? '长休息已暂停' : '长休息')
  if (phase.value === 'shortBreak') return timerState.value === 'running' ? '短休息中' : (timerState.value === 'paused' ? '短休息已暂停' : '短休息')
  if (timerState.value === 'running') return '专注中'
  if (timerState.value === 'paused') return '已暂停'
  return '准备专注'
})
const currentStartLabel = computed(() => sessionStartedAt.value ? formatTime(sessionStartedAt.value.toISOString()) : '—')
const currentElapsedLabel = computed(() => {
  if (mode.value === 'stopwatch') return formatDuration(elapsed.value)
  return formatDuration(Math.max(0, phaseTotal.value - remaining.value))
})
const sessionGroups = computed(() => {
  const groups: Array<{ date: string; label: string; sessions: FocusSession[] }> = []
  for (const session of dashboard.value?.sessions || []) {
    const date = new Date(session.startedAt)
    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
    let group = groups.find((item) => item.date === key)
    if (!group) {
      group = { date: key, label: date.toLocaleDateString('zh-CN', { month: 'long', day: 'numeric' }), sessions: [] }
      groups.push(group)
    }
    group.sessions.push(session)
  }
  return groups
})
const pickerItems = computed(() => {
  const query = pickerQuery.value.trim().toLowerCase()
  if (pickerTab.value === 'habit') {
    return habits.value
      .filter((habit) => !query || habit.name.toLowerCase().includes(query))
      .map((habit) => ({ type: 'habit' as const, id: habit.id, title: habit.name }))
  }
  return props.tasks
    .filter((task) => !task.completed && (!query || task.title.toLowerCase().includes(query)))
    .slice(0, 100)
    .map((task) => ({ type: 'task' as const, id: task.id, title: task.title }))
})
const weekTotalMinutes = computed(() => (dashboard.value?.daily || []).reduce((sum, day) => sum + day.minutes, 0))
const weekMax = computed(() => Math.max(1, ...(dashboard.value?.daily || []).map((day) => day.minutes)))
const hourMax = computed(() => Math.max(1, ...(dashboard.value?.hourly || []).map((hour) => hour.minutes)))
const bestHour = computed(() => {
  let best = -1
  let value = 0
  for (const hour of dashboard.value?.hourly || []) {
    if (hour.minutes > value) {
      value = hour.minutes
      best = hour.hour
    }
  }
  return best < 0 ? '' : `${String(best).padStart(2, '0')}:00 - ${String((best + 1) % 24).padStart(2, '0')}:00`
})
const heatmapWeeks = computed(() => {
  const days = dashboard.value?.heatmap || []
  if (!days.length) return []
  const map = new Map(days.map((day) => [day.date, day]))
  const first = new Date(`${currentYear}-01-01T00:00:00`)
  const last = new Date(`${currentYear}-12-31T00:00:00`)
  const cursor = new Date(first)
  cursor.setDate(cursor.getDate() - cursor.getDay())
  const weeks: Array<Array<{ date: string; minutes: number }>> = []
  while (cursor <= last || cursor.getDay() !== 0) {
    const week: Array<{ date: string; minutes: number }> = []
    for (let index = 0; index < 7; index++) {
      const key = `${cursor.getFullYear()}-${String(cursor.getMonth() + 1).padStart(2, '0')}-${String(cursor.getDate()).padStart(2, '0')}`
      week.push({ date: key, minutes: map.get(key)?.minutes || 0 })
      cursor.setDate(cursor.getDate() + 1)
    }
    weeks.push(week)
    if (weeks.length > 54) break
  }
  return weeks
})

function defaultPreferences(): FocusPreference {
  return {
    pomodoroMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakInterval: 4,
    dailyGoal: 4, autoStartPomodoro: false, autoStartBreak: false, soundEnabled: true, tabTitleEnabled: false,
  }
}

function formatClock(seconds: number, showHours = false) {
  const total = Math.max(0, Math.floor(seconds))
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  const secs = total % 60
  if (showHours || hours > 0) return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
  return `${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
}

function formatTime(value: string) {
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '—' : date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
}

function formatDuration(seconds: number) {
  if (seconds < 60) return `${seconds} 秒`
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes}m`
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`
}

function weekdayLabel(date: string) {
  const value = new Date(`${date}T00:00:00`)
  return Number.isNaN(value.getTime()) ? '' : value.toLocaleDateString('zh-CN', { weekday: 'short' }).replace('周', '')
}

function weekBarHeight(minutes: number) {
  return Math.max(3, Math.round((minutes / weekMax.value) * 100))
}

function hourBarHeight(minutes: number) {
  return Math.max(3, Math.round((minutes / hourMax.value) * 100))
}

function heatLevel(minutes: number) {
  if (minutes <= 0) return 0
  if (minutes <= 15) return 1
  if (minutes <= 30) return 2
  if (minutes <= 60) return 3
  return 4
}

function toLocalInput(date: Date) {
  const pad = (value: number) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

async function loadDashboard() {
  try {
    dashboard.value = await fetchFocusDashboard()
    preferences.value = { ...dashboard.value.preferences }
    if (timerState.value === 'idle' && phase.value === 'focus' && mode.value === 'pomodoro') {
      resetCountdown()
    }
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载专注数据失败')
  }
}

async function loadHabits() {
  try {
    const data = await fetchHabits()
    habits.value = data.habits
  } catch {
    habits.value = []
  }
}

function resetCountdown() {
  phaseTotal.value = focusTotal.value
  remaining.value = focusTotal.value
}

function resetForFocus() {
  phase.value = 'focus'
  timerState.value = 'idle'
  sessionStartedAt.value = null
  pausedAccumMs.value = 0
  pauseStartedAt.value = 0
  deadline.value = 0
  stopwatchBase.value = 0
  note.value = ''
  if (mode.value === 'stopwatch') {
    elapsed.value = 0
    phaseTotal.value = 0
  } else {
    resetCountdown()
  }
  persistTimer()
}

function switchFocusMode(next: FocusMode) {
  if (timerState.value !== 'idle') {
    Message.info('请先结束当前专注再切换模式')
    return
  }
  mode.value = next
  phase.value = 'focus'
  note.value = ''
  if (next === 'pomodoro') resetCountdown()
  else {
    elapsed.value = 0
    phaseTotal.value = 0
  }
  persistTimer()
}

function handlePrimary() {
  if (timerState.value === 'paused') resumeTimer()
  else startTimer()
}

function startTimer() {
  if (timerState.value === 'running') return
  if (phase.value === 'focus' && mode.value === 'pomodoro' && remaining.value <= 0) resetCountdown()
  if (phase.value === 'focus' && mode.value === 'stopwatch' && elapsed.value === 0) phaseTotal.value = 0
  if (!sessionStartedAt.value && phase.value === 'focus') sessionStartedAt.value = new Date()
  timerState.value = 'running'
  if (phase.value === 'focus' && mode.value === 'stopwatch') {
    stopwatchBase.value = Date.now() - elapsed.value * 1000
  } else {
    deadline.value = Date.now() + remaining.value * 1000
  }
  startTicker()
  persistTimer()
}

function pauseTimer() {
  if (timerState.value !== 'running') return
  syncClock()
  if (timerState.value !== 'running') return
  timerState.value = 'paused'
  pauseStartedAt.value = Date.now()
  stopTicker()
  persistTimer()
}

function resumeTimer() {
  if (timerState.value !== 'paused') return
  if (pauseStartedAt.value) pausedAccumMs.value += Date.now() - pauseStartedAt.value
  pauseStartedAt.value = 0
  timerState.value = 'running'
  if (phase.value === 'focus' && mode.value === 'stopwatch') {
    stopwatchBase.value = Date.now() - elapsed.value * 1000
  } else {
    deadline.value = Date.now() + remaining.value * 1000
  }
  startTicker()
  persistTimer()
}

function startTicker() {
  stopTicker()
  ticker = setInterval(syncClock, 250)
  syncClock()
}

function stopTicker() {
  if (ticker) clearInterval(ticker)
  ticker = undefined
}

function syncClock() {
  if (timerState.value !== 'running') return
  if (phase.value === 'focus' && mode.value === 'stopwatch') {
    elapsed.value = Math.max(0, Math.floor((Date.now() - stopwatchBase.value) / 1000))
    return
  }
  remaining.value = Math.max(0, Math.ceil((deadline.value - Date.now()) / 1000))
  if (remaining.value <= 0) completePhase()
}

function completePhase() {
  stopTicker()
  if (phase.value === 'focus') {
    const startedAt = sessionStartedAt.value || new Date(Date.now() - focusTotal.value * 1000)
    const endedAt = new Date()
    const duration = mode.value === 'stopwatch' ? elapsed.value : phaseTotal.value
    if (duration >= 1) {
      void saveSession({
        mode: mode.value,
        startedAt: startedAt.toISOString(),
        endedAt: endedAt.toISOString(),
        pauseSeconds: Math.round(pausedAccumMs.value / 1000),
        durationSeconds: duration,
        pomodoroCount: mode.value === 'pomodoro' ? 1 : 0,
        note: note.value,
      })
    }
    if (mode.value === 'pomodoro') {
      cyclePomodoros.value += 1
      const isLong = cyclePomodoros.value % Math.max(1, preferences.value.longBreakInterval) === 0
      phase.value = isLong ? 'longBreak' : 'shortBreak'
      phaseTotal.value = (isLong ? preferences.value.longBreakMinutes : preferences.value.shortBreakMinutes) * 60
      remaining.value = phaseTotal.value
      elapsed.value = 0
      timerState.value = 'idle'
      sessionStartedAt.value = null
      pausedAccumMs.value = 0
      pauseStartedAt.value = 0
      note.value = ''
      playChime()
      persistTimer()
      if (preferences.value.autoStartBreak) {
        transitionTimer = setTimeout(startTimer, 500)
      }
    } else {
      playChime()
      resetForFocus()
    }
    return
  }
  playChime()
  phase.value = 'focus'
  timerState.value = 'idle'
  remaining.value = 0
  elapsed.value = 0
  note.value = ''
  if (mode.value === 'pomodoro') resetCountdown()
  if (preferences.value.autoStartPomodoro) {
    transitionTimer = setTimeout(startTimer, 500)
  }
  persistTimer()
}

function endCurrentTimer() {
  if (timerState.value === 'idle') return
  if (phase.value === 'focus') {
    syncClock()
    const duration = mode.value === 'stopwatch'
      ? elapsed.value
      : Math.max(0, phaseTotal.value - remaining.value)
    if ((mode.value === 'stopwatch' && duration >= 1) || duration >= 60) {
      const startedAt = sessionStartedAt.value || new Date(Date.now() - duration * 1000)
      void saveSession({
        mode: mode.value,
        startedAt: startedAt.toISOString(),
        endedAt: new Date().toISOString(),
        pauseSeconds: Math.round(pausedAccumMs.value / 1000),
        durationSeconds: duration,
        pomodoroCount: 0,
        note: note.value,
      })
    }
  }
  stopTicker()
  resetForFocus()
}

async function saveSession(payload: {
  mode: FocusMode
  startedAt: string
  endedAt: string
  pauseSeconds: number
  durationSeconds: number
  pomodoroCount: number
  note: string
}) {
  try {
    await createFocusSession({
      ...payload,
      taskId: target.value?.type === 'task' ? target.value.id : undefined,
      habitId: target.value?.type === 'habit' ? target.value.id : undefined,
    })
    Message.success('专注记录已保存')
    await loadDashboard()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存专注记录失败')
  }
}

function playChime() {
  if (!preferences.value.soundEnabled) return
  try {
    const Ctx = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
    if (!Ctx) return
    audioContext ??= new Ctx()
    const now = audioContext.currentTime
    const gain = audioContext.createGain()
    gain.gain.setValueAtTime(0.0001, now)
    gain.connect(audioContext.destination)
    ;[523.25, 659.25, 783.99].forEach((frequency, index) => {
      const oscillator = audioContext!.createOscillator()
      oscillator.type = 'sine'
      oscillator.frequency.value = frequency
      oscillator.connect(gain)
      const start = now + index * 0.12
      oscillator.start(start)
      oscillator.stop(start + 0.28)
    })
    gain.gain.exponentialRampToValueAtTime(0.16, now + 0.03)
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 1.05)
  } catch {
    // Audio is optional; browsers may block it without a gesture.
  }
}

function openSettings() {
  Object.assign(settingsDraft, preferences.value)
  settingsOpen.value = true
}

async function saveSettings() {
  settingsBusy.value = true
  try {
    const { preferences: saved } = await saveFocusPreferences({ ...settingsDraft })
    preferences.value = saved
    if (timerState.value === 'idle' && phase.value === 'focus' && mode.value === 'pomodoro') resetCountdown()
    if (timerState.value === 'idle' && phase.value !== 'focus') {
      phaseTotal.value = (phase.value === 'longBreak' ? saved.longBreakMinutes : saved.shortBreakMinutes) * 60
      remaining.value = phaseTotal.value
    }
    settingsOpen.value = false
    Message.success('专注设置已保存')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存专注设置失败')
  } finally {
    settingsBusy.value = false
  }
}

function openManual() {
  const end = new Date()
  manualForm.startedAt = toLocalInput(new Date(end.getTime() - preferences.value.pomodoroMinutes * 60 * 1000))
  manualForm.endedAt = toLocalInput(end)
  manualForm.mode = 'pomodoro'
  manualForm.pomodoroCount = 1
  manualForm.note = ''
  manualTarget.value = target.value
  manualOpen.value = true
}

async function saveManual() {
  const start = new Date(manualForm.startedAt)
  const end = new Date(manualForm.endedAt)
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
    Message.error('结束时间必须晚于开始时间')
    return
  }
  const duration = Math.floor((end.getTime() - start.getTime()) / 1000)
  if (duration > 24 * 60 * 60) {
    Message.error('单次专注不能超过 24 小时')
    return
  }
  manualBusy.value = true
  try {
    await createFocusSession({
      mode: manualForm.mode,
      startedAt: start.toISOString(),
      endedAt: end.toISOString(),
      durationSeconds: duration,
      pomodoroCount: manualForm.mode === 'pomodoro' ? manualForm.pomodoroCount : 0,
      note: manualForm.note,
      taskId: manualTarget.value?.type === 'task' ? manualTarget.value.id : undefined,
      habitId: manualTarget.value?.type === 'habit' ? manualTarget.value.id : undefined,
    })
    manualOpen.value = false
    Message.success('专注记录已添加')
    await loadDashboard()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '添加专注记录失败')
  } finally {
    manualBusy.value = false
  }
}

function openPicker(forWho: 'timer' | 'manual') {
  pickerFor.value = forWho
  pickerTab.value = forWho === 'manual' && manualTarget.value?.type === 'habit' ? 'habit' : (target.value?.type === 'habit' ? 'habit' : 'task')
  pickerQuery.value = ''
  pickerOpen.value = true
}

function selectTarget(item: FocusTarget | null) {
  if (pickerFor.value === 'manual') manualTarget.value = item
  else target.value = item
  pickerOpen.value = false
}

function deleteRecord(session: FocusSession) {
  Modal.confirm({
    title: '删除专注记录',
    content: `确定删除 ${formatTime(session.startedAt)} 的这条专注记录吗？`,
    okText: '删除',
    cancelText: '取消',
    okButtonProps: { status: 'danger' },
    async onOk() {
      try {
        await deleteFocusSession(session.id)
        Message.success('记录已删除')
        await loadDashboard()
      } catch (error) {
        Message.error(error instanceof Error ? error.message : '删除失败')
      }
    },
  })
}

function timerSnapshot() {
  return {
    mode: mode.value, phase: phase.value, timerState: timerState.value,
    remaining: remaining.value, elapsed: elapsed.value, phaseTotal: phaseTotal.value,
    deadline: deadline.value, stopwatchBase: stopwatchBase.value,
    startedAt: sessionStartedAt.value?.toISOString() || '', pausedAccumMs: pausedAccumMs.value,
    note: note.value, target: target.value, cyclePomodoros: cyclePomodoros.value,
  }
}

function persistTimer() {
  try {
    localStorage.setItem('caldav-focus-timer', JSON.stringify(timerSnapshot()))
  } catch {
    // localStorage may be unavailable in private mode.
  }
}

function restoreTimer() {
  try {
    const raw = localStorage.getItem('caldav-focus-timer')
    if (!raw) return false
    const state = JSON.parse(raw) as ReturnType<typeof timerSnapshot>
    if (!state || !state.mode) return false
    mode.value = state.mode
    phase.value = state.phase || 'focus'
    timerState.value = state.timerState || 'idle'
    remaining.value = state.remaining || 0
    elapsed.value = state.elapsed || 0
    phaseTotal.value = state.phaseTotal || 0
    deadline.value = state.deadline || 0
    stopwatchBase.value = state.stopwatchBase || 0
    sessionStartedAt.value = state.startedAt ? new Date(state.startedAt) : null
    pausedAccumMs.value = state.pausedAccumMs || 0
    note.value = state.note || ''
    target.value = state.target || null
    cyclePomodoros.value = state.cyclePomodoros || 0
    if (timerState.value === 'running') {
      if (phase.value === 'focus' && mode.value === 'stopwatch') {
        elapsed.value = Math.max(0, Math.floor((Date.now() - stopwatchBase.value) / 1000))
      } else {
        remaining.value = Math.max(0, Math.ceil((deadline.value - Date.now()) / 1000))
        if (remaining.value <= 0) {
          timerState.value = 'idle'
          phase.value = 'focus'
          sessionStartedAt.value = null
          if (mode.value === 'pomodoro') resetCountdown()
          else {
            elapsed.value = 0
            phaseTotal.value = 0
          }
          return true
        }
      }
      startTicker()
    }
    return true
  } catch {
    return false
  }
}

watch([note, target], persistTimer, { deep: true })

watch([timerState, timerDisplay, preferences], () => {
  if (preferences.value.tabTitleEnabled && timerState.value !== 'idle') {
    document.title = `${timerDisplay.value} · ${phase.value === 'focus' ? '专注' : '休息'}`
  } else {
    document.title = originalTitle
  }
  if (timerState.value !== 'idle') persistTimer()
}, { deep: true })

onMounted(async () => {
  await Promise.all([loadDashboard(), loadHabits()])
  if (!restoreTimer()) {
    resetCountdown()
  }
  loading.value = false
})

onBeforeUnmount(() => {
  stopTicker()
  if (transitionTimer) clearTimeout(transitionTimer)
  document.title = originalTitle
  persistTimer()
})
</script>
