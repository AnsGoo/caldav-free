<template>
  <section class="tw-focus-stats-page">
    <header class="tw-focus-stats-page-head">
      <button class="tw-icon-button" title="返回专注" @click="$emit('back')"><TaskIcon name="back" :size="18" /></button>
      <div>
        <span class="tw-focus-kicker">INSIGHTS</span>
        <h1>专注统计</h1>
      </div>
      <div class="tw-focus-range-tabs">
        <button v-for="option in ranges" :key="option.days" :class="{ active: days === option.days }" @click="days = option.days">{{ option.label }}</button>
      </div>
    </header>

    <div v-if="loading" class="tw-focus-stats-page-loading"><a-spin /></div>
    <div v-else-if="stats" class="tw-focus-stats-page-body">
      <div class="tw-focus-stats-page-kpis">
        <article><span>总专注</span><strong>{{ stats.totalFocusMinutes }}<small>m</small></strong></article>
        <article><span>番茄数</span><strong>{{ stats.totalPomodoroCount }}<small>个</small></strong></article>
        <article><span>专注次数</span><strong>{{ stats.sessionCount }}<small>次</small></strong></article>
        <article><span>活跃天数</span><strong>{{ stats.activeDays }}<small>天</small></strong></article>
        <article><span>日均专注</span><strong>{{ stats.averageMinutes }}<small>m</small></strong></article>
      </div>

      <div class="tw-focus-stats-grid">
        <section class="tw-focus-stats-card wide">
          <header><div><strong>每日专注</strong><span>{{ stats.from }} — {{ stats.to }}</span></div><b>{{ stats.totalFocusMinutes }} 分钟</b></header>
          <div class="tw-focus-daily-chart" :class="`days-${days}`">
            <div v-for="day in stats.daily" :key="day.date" class="tw-focus-daily-bar" :title="`${day.date} ${day.minutes} 分钟`">
              <i :style="{ height: `${dailyHeight(day.minutes)}%` }" />
            </div>
          </div>
          <div class="tw-focus-chart-axis"><span>{{ stats.from.slice(5) }}</span><span>{{ stats.to.slice(5) }}</span></div>
        </section>

        <section class="tw-focus-stats-card">
          <header><div><strong>时段分布</strong><span>按开始时间</span></div><b>{{ bestHour || '暂无' }}</b></header>
          <div class="tw-focus-hour-chart">
            <div v-for="hour in stats.hourly" :key="hour.hour" class="tw-focus-hour-column" :title="`${hour.hour}:00 ${hour.minutes} 分钟`"><i :style="{ height: `${hourHeight(hour.minutes)}%` }" /></div>
          </div>
          <div class="tw-focus-chart-axis"><span>00</span><span>06</span><span>12</span><span>18</span><span>23</span></div>
        </section>

        <section class="tw-focus-stats-card">
          <header><div><strong>模式</strong><span>番茄与正计时</span></div></header>
          <div v-if="stats.byMode.length" class="tw-focus-mode-stats">
            <article v-for="item in stats.byMode" :key="item.mode">
              <span>{{ item.mode === 'stopwatch' ? '正计时' : '番茄计时' }}</span>
              <strong>{{ item.minutes }}m</strong>
              <div><i :style="{ width: `${modeWidth(item)}%` }" /></div>
              <small>{{ item.count }} 次</small>
            </article>
          </div>
          <p v-else class="tw-modal-note">这个区间还没有专注记录。</p>
        </section>

        <section class="tw-focus-stats-card">
          <header><div><strong>专注对象</strong><span>按任务/习惯</span></div></header>
          <div v-if="stats.byTitle.length" class="tw-focus-target-stats">
            <article v-for="item in stats.byTitle" :key="item.title">
              <span>{{ item.title }}</span>
              <strong>{{ item.minutes }}m</strong>
              <div><i :style="{ width: `${targetWidth(item)}%` }" /></div>
            </article>
          </div>
          <p v-else class="tw-modal-note">还没有关联专注对象。</p>
        </section>
      </div>

      <section class="tw-focus-stats-card tw-focus-range-sessions">
        <header><div><strong>专注记录</strong><span>{{ stats.sessionCount }} 条</span></div></header>
        <div v-if="stats.sessions.length" class="tw-focus-range-session-list">
          <article v-for="session in stats.sessions.slice(0, 30)" :key="session.id">
            <time>{{ formatDate(session.startedAt) }} · {{ formatTime(session.startedAt) }} - {{ formatTime(session.endedAt) }}</time>
            <strong>{{ formatDuration(session.durationSeconds) }}</strong>
            <span>{{ session.title || '自由专注' }}</span>
          </article>
        </div>
        <p v-else class="tw-modal-note">这个区间还没有专注记录。</p>
      </section>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { FocusRangeStats, FocusModeStat, FocusTitleStat } from '../../types'
import { fetchFocusStats } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

defineEmits<{ (event: 'back'): void }>()

const ranges = [
  { days: 7, label: '7 天' },
  { days: 30, label: '30 天' },
  { days: 90, label: '90 天' },
  { days: 365, label: '一年' },
]
const days = ref(30)
const loading = ref(true)
const stats = ref<FocusRangeStats | null>(null)

const dailyMax = computed(() => Math.max(1, ...(stats.value?.daily || []).map((day) => day.minutes)))
const hourMax = computed(() => Math.max(1, ...(stats.value?.hourly || []).map((hour) => hour.minutes)))
const modeMax = computed(() => Math.max(1, ...(stats.value?.byMode || []).map((mode) => mode.minutes)))
const targetMax = computed(() => Math.max(1, ...(stats.value?.byTitle || []).map((item) => item.minutes)))
const bestHour = computed(() => {
  let result = ''
  let best = 0
  for (const hour of stats.value?.hourly || []) {
    if (hour.minutes > best) {
      best = hour.minutes
      result = `${String(hour.hour).padStart(2, '0')}:00`
    }
  }
  return result
})

function dailyHeight(minutes: number) {
  return Math.max(2, Math.round(minutes / dailyMax.value * 100))
}

function hourHeight(minutes: number) {
  return Math.max(2, Math.round(minutes / hourMax.value * 100))
}

function modeWidth(item: FocusModeStat) {
  return Math.max(2, Math.round(item.minutes / modeMax.value * 100))
}

function targetWidth(item: FocusTitleStat) {
  return Math.max(2, Math.round(item.minutes / targetMax.value * 100))
}

function formatTime(value: string) {
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '—' : date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
}

function formatDate(value: string) {
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '—' : date.toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' })
}

function formatDuration(seconds: number) {
  if (seconds < 60) return `${seconds} 秒`
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes}m`
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`
}

async function load() {
  loading.value = true
  try {
    stats.value = await fetchFocusStats(days.value)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载专注统计失败')
  } finally {
    loading.value = false
  }
}

watch(days, load)
onMounted(load)
</script>
