<template>
  <section class="tw-stats">
    <header class="tw-stats-top">
      <div>
        <h2>任务统计</h2>
        <p>最近 {{ days }} 天的完成情况与分布</p>
      </div>
      <div class="tw-stats-controls">
        <div class="tw-cal-view-switch">
          <button v-for="option in periodOptions" :key="option" :class="{ active: days === option }" @click="setDays(option)">
            {{ option }} 天
          </button>
        </div>
        <button class="tw-icon-button" title="刷新统计" @click="load">
          <TaskIcon name="refresh" :size="16" />
        </button>
      </div>
    </header>

    <div v-if="loading && !stats" class="tw-loading"><a-spin /></div>

    <template v-else-if="stats">
      <div class="tw-stat-cards">
        <article class="tw-stat-card">
          <span class="tw-stat-label">未完成</span>
          <strong>{{ stats.open }}</strong>
          <small>今天 {{ stats.today }} · 逾期 {{ stats.overdue }}</small>
        </article>
        <article class="tw-stat-card">
          <span class="tw-stat-label">已完成</span>
          <strong>{{ stats.completed }}</strong>
          <small>本周期完成 {{ stats.completedInPeriod }}</small>
        </article>
        <article class="tw-stat-card" :class="{ danger: stats.overdue > 0 }">
          <span class="tw-stat-label">已逾期</span>
          <strong>{{ stats.overdue }}</strong>
          <small>本周期到期 {{ stats.dueInPeriod }}</small>
        </article>
        <article class="tw-stat-card">
          <span class="tw-stat-label">完成率</span>
          <strong>{{ stats.completionRate.toFixed(1) }}%</strong>
          <small>按当前全部任务计算</small>
        </article>
      </div>

      <div class="tw-stats-row">
        <article class="tw-stats-panel tw-stats-trend">
          <header class="tw-stats-panel-head">
            <div>
              <h3>每日趋势</h3>
              <small>新建 / 完成 / 到期</small>
            </div>
            <div class="tw-trend-legend">
              <span><i class="created" />新建</span>
              <span><i class="completed" />完成</span>
              <span><i class="due" />到期</span>
            </div>
          </header>
          <svg :viewBox="`0 0 ${trend.width} ${trend.height}`" class="tw-trend-chart" role="img" aria-label="每日任务趋势">
            <g class="tw-trend-grid">
              <template v-for="line in trend.grid" :key="line.y">
                <line :x1="trend.padX" :x2="trend.width - trend.padX" :y1="line.y" :y2="line.y" />
                <text :x="4" :y="line.y + 3">{{ line.label }}</text>
              </template>
            </g>
            <rect
              v-for="bar in trend.bars"
              :key="bar.key"
              :x="bar.x"
              :y="bar.y"
              :width="bar.width"
              :height="bar.height"
              :class="bar.kind"
              rx="2"
            >
              <title>{{ bar.title }}</title>
            </rect>
            <polyline v-if="trend.duePoints" :points="trend.duePoints" class="tw-trend-due-line" />
            <g class="tw-trend-labels">
              <text v-for="label in trend.labels" :key="label.x" :x="label.x" :y="trend.height - 8">{{ label.text }}</text>
            </g>
          </svg>
        </article>

        <article class="tw-stats-panel tw-stats-donut">
          <header class="tw-stats-panel-head">
            <div>
              <h3>完成情况</h3>
              <small>本周期完成 {{ stats.completedInPeriod }} 个</small>
            </div>
          </header>
          <div class="tw-ring-wrap">
            <div class="tw-ring" :style="ringStyle">
              <div class="tw-ring-inner">
                <strong>{{ stats.completionRate.toFixed(0) }}%</strong>
                <small>完成率</small>
              </div>
            </div>
            <div class="tw-ring-legend">
              <div><i class="done" /><span>已完成</span><strong>{{ stats.completed }}</strong></div>
              <div><i class="open" /><span>未完成</span><strong>{{ stats.open }}</strong></div>
              <div><i class="overdue" /><span>已逾期</span><strong>{{ stats.overdue }}</strong></div>
              <div><i class="ontime" /><span>按时完成</span><strong>{{ stats.onTimeInPeriod }}</strong></div>
            </div>
          </div>
        </article>
      </div>

      <div class="tw-stats-grid">
        <article class="tw-stats-panel">
          <header class="tw-stats-panel-head">
            <div><h3>按清单</h3><small>点击清单查看任务</small></div>
          </header>
          <div class="tw-stat-list">
            <button v-for="list in stats.lists" :key="list.id" class="tw-stat-list-row" @click="$emit('open-list', list.id)">
              <span class="tw-stat-dot" :style="{ background: list.color || '#4772fa' }" />
              <span class="tw-stat-list-name">{{ list.name }}</span>
              <span class="tw-stat-list-nums">
                <em>{{ list.open }}</em> 未完成
                <b>{{ list.completed }}</b> 完成
                <u v-if="list.overdue">{{ list.overdue }} 逾期</u>
              </span>
              <span class="tw-stat-bar">
                <i class="open" :style="{ width: `${(list.open / listMax) * 100}%` }" />
                <i class="done" :style="{ width: `${(list.completed / listMax) * 100}%` }" />
              </span>
            </button>
          </div>
        </article>

        <article class="tw-stats-panel">
          <header class="tw-stats-panel-head">
            <div><h3>优先级</h3><small>未完成 / 已完成</small></div>
          </header>
          <div class="tw-stat-list">
            <div v-for="item in priorityRows" :key="item.priority" class="tw-stat-list-row static">
              <i class="tw-priority-dot" :style="{ background: item.color }" />
              <span class="tw-stat-list-name">{{ item.label }}</span>
              <span class="tw-stat-list-nums"><em>{{ item.open }}</em> / <b>{{ item.completed }}</b></span>
              <span class="tw-stat-bar">
                <i class="open" :style="{ width: `${(item.open / priorityMax) * 100}%` }" />
                <i class="done" :style="{ width: `${(item.completed / priorityMax) * 100}%` }" />
              </span>
            </div>
          </div>
        </article>

        <article class="tw-stats-panel">
          <header class="tw-stats-panel-head">
            <div><h3>标签</h3><small>点击标签筛选任务</small></div>
          </header>
          <div v-if="stats.tags.length" class="tw-stat-tags">
            <button v-for="tag in stats.tags.slice(0, 12)" :key="tag.name" class="tw-stat-tag" @click="$emit('select-tag', tag.name)">
              <span>#{{ tag.name }}</span>
              <strong>{{ tag.open + tag.completed }}</strong>
              <small v-if="tag.overdue">{{ tag.overdue }} 逾期</small>
            </button>
          </div>
          <p v-else class="tw-filter-empty">还没有标签。</p>
        </article>
      </div>

      <article class="tw-stats-panel tw-stats-overview">
        <header class="tw-stats-panel-head">
          <div><h3>周期概览</h3><small>最近 {{ days }} 天</small></div>
        </header>
        <div class="tw-overview-grid">
          <div><span>新建任务</span><strong>{{ stats.createdInPeriod }}</strong></div>
          <div><span>完成任务</span><strong>{{ stats.completedInPeriod }}</strong></div>
          <div><span>到期任务</span><strong>{{ stats.dueInPeriod }}</strong></div>
          <div><span>按时完成</span><strong>{{ stats.onTimeInPeriod }}</strong></div>
          <div><span>平均完成耗时</span><strong>{{ avgCompletion }}</strong></div>
          <div><span>垃圾桶</span><strong>{{ stats.trash }}</strong></div>
        </div>
      </article>
    </template>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { TaskStats } from '../../types'
import { fetchTaskStats } from '../../tasks-api'
import { PRIORITIES } from '../../tasks-utils'
import TaskIcon from './TaskIcon.vue'

defineEmits<{
  (event: 'open-list', id: number): void
  (event: 'select-tag', tag: string): void
}>()

const periodOptions = [7, 30, 90]
const days = ref(30)
const stats = ref<TaskStats | null>(null)
const loading = ref(false)

const listMax = computed(() => {
  if (!stats.value) return 1
  return Math.max(1, ...stats.value.lists.map((list) => list.open + list.completed))
})

const priorityMax = computed(() => {
  if (!stats.value) return 1
  return Math.max(1, ...stats.value.priorities.map((item) => item.open + item.completed))
})

const priorityRows = computed(() => {
  const rows: Array<{ priority: number; label: string; color: string; open: number; completed: number }> = PRIORITIES.map((item) => {
    const entry = stats.value?.priorities.find((value) => value.priority === item.value)
    return {
      priority: item.value,
      label: `${item.short}优先级`,
      color: item.color,
      open: entry?.open || 0,
      completed: entry?.completed || 0,
    }
  })
  const none = stats.value?.priorities.find((value) => value.priority === 0)
  rows.push({ priority: 0, label: '无优先级', color: 'var(--tw-text-3)', open: none?.open || 0, completed: none?.completed || 0 })
  return rows
})

const ringStyle = computed(() => {
  const rate = stats.value?.completionRate || 0
  return { background: `conic-gradient(var(--tw-accent) ${rate}%, var(--tw-surface) ${rate}% 100%)` }
})

const avgCompletion = computed(() => {
  const hours = stats.value?.avgCompletionHours || 0
  if (!hours) return '—'
  if (hours < 24) return `${hours.toFixed(1)} 小时`
  return `${(hours / 24).toFixed(1)} 天`
})

const trend = computed(() => {
  const data = stats.value?.daily || []
  const width = 640
  const height = 210
  const padX = 28
  const padTop = 16
  const padBottom = 30
  const innerW = width - padX * 2
  const innerH = height - padTop - padBottom
  const max = Math.max(1, ...data.map((item) => Math.max(item.created, item.completed, item.due)))
  const slot = data.length ? innerW / data.length : innerW
  const barWidth = Math.max(2, Math.min(8, slot * 0.26))
  const bars: Array<{ key: string; kind: string; x: number; y: number; width: number; height: number; title: string }> = []
  data.forEach((item, index) => {
    const center = padX + index * slot + slot / 2
    const createdHeight = (item.created / max) * innerH
    const completedHeight = (item.completed / max) * innerH
    bars.push({
      key: `${item.date}-created`,
      kind: 'created',
      x: center - barWidth - 1,
      y: padTop + innerH - createdHeight,
      width: barWidth,
      height: createdHeight,
      title: `${item.date} 新建 ${item.created}`,
    })
    bars.push({
      key: `${item.date}-completed`,
      kind: 'completed',
      x: center + 1,
      y: padTop + innerH - completedHeight,
      width: barWidth,
      height: completedHeight,
      title: `${item.date} 完成 ${item.completed}`,
    })
  })
  const duePoints = data
    .map((item, index) => `${padX + index * slot + slot / 2},${padTop + innerH - (item.due / max) * innerH}`)
    .join(' ')
  const grid = [0, 0.5, 1].map((ratio) => ({
    y: padTop + innerH * ratio,
    label: String(Math.round(max * (1 - ratio))),
  }))
  const step = Math.max(1, Math.ceil(data.length / 6))
  const labels = data
    .map((item, index) => ({
      x: padX + index * slot + slot / 2,
      text: index === 0 || index === data.length - 1 || index % step === 0 ? item.date.slice(5) : '',
    }))
    .filter((item) => item.text)
  return { width, height, padX, innerH, bars, duePoints, grid, labels }
})

async function load() {
  loading.value = true
  try {
    const data = await fetchTaskStats(days.value)
    stats.value = data.stats
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载统计失败')
  } finally {
    loading.value = false
  }
}

function setDays(value: number) {
  days.value = value
  void load()
}

onMounted(load)
</script>
