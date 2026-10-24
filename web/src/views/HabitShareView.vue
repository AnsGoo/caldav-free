<template>
  <section class="habit-share-page">
    <header class="habit-share-brand">
      <a href="/" class="habit-share-logo" aria-label="caldav-free">
        <span class="habit-share-mark">
          <svg viewBox="0 0 32 32" width="24" height="24" aria-hidden="true">
            <path d="M8 10.5h16M8 16h11M8 21.5h13" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" />
            <circle cx="24" cy="23" r="2.2" fill="currentColor" />
          </svg>
        </span>
        <span>caldav<em>free</em></span>
      </a>
      <span class="habit-share-badge">习惯分享</span>
    </header>

    <main class="habit-share-main">
      <div v-if="loading" class="habit-share-state"><a-spin :size="28" /></div>

      <div v-else-if="error" class="habit-share-state habit-share-error">
        <div class="habit-share-state-icon"><TaskIcon name="habit" :size="30" /></div>
        <h1>这个分享不可用</h1>
        <p>{{ error }}</p>
        <a href="/" class="habit-share-home">返回首页</a>
      </div>

      <article v-else-if="share" class="habit-share-card" :style="{ '--habit-color': share.color || '#97E38B' }">
        <section class="habit-share-head">
          <span class="habit-share-icon" :style="{ background: share.color || '#97E38B' }">{{ share.icon || '😊' }}</span>
          <div class="habit-share-title">
            <p class="habit-share-eyebrow">HABIT STREAK</p>
            <h1>{{ share.name }}</h1>
            <p>已经坚持 <strong>{{ share.stats.totalCheckinDays }}</strong> 天，当前连续 <strong>{{ share.stats.currentStreak }}</strong> 天</p>
          </div>
        </section>

        <div class="habit-share-stats">
          <article>
            <span>本月打卡</span>
            <strong>{{ share.stats.monthCheckinDays }}<small>天</small></strong>
          </article>
          <article>
            <span>本月完成率</span>
            <strong>{{ Math.round(share.stats.monthCompletionRate) }}<small>%</small></strong>
          </article>
          <article>
            <span>当前连续</span>
            <strong>{{ share.stats.currentStreak }}<small>天</small></strong>
          </article>
          <article>
            <span>总打卡</span>
            <strong>{{ share.stats.totalCheckinDays }}<small>天</small></strong>
          </article>
        </div>

        <section v-if="share.stats.targetDays > 0" class="habit-share-target">
          <header>
            <span>坚持目标</span>
            <strong>{{ share.stats.targetProgress }}/{{ share.stats.targetDays }} 天</strong>
          </header>
          <div><i :style="{ width: `${Math.min(100, share.stats.targetProgress / share.stats.targetDays * 100)}%` }" /></div>
          <p v-if="share.stats.completedCycles">已完成 {{ share.stats.completedCycles }} 轮</p>
        </section>

        <section class="habit-share-days">
          <header>
            <strong>最近 30 天</strong>
            <span>{{ doneDays }} / {{ share.days.length }} 天</span>
          </header>
          <div class="habit-share-day-grid">
            <div
              v-for="day in share.days"
              :key="day.date"
              class="habit-share-day"
              :class="{ done: day.done, today: day.date === today }"
              :title="dayTitle(day)"
            >
              <span>{{ dayNumber(day.date) }}</span>
              <i v-if="day.done"><TaskIcon name="check" :size="10" /></i>
            </div>
          </div>
        </section>

        <footer class="habit-share-foot">
          <span>由 caldav-free 生成 · {{ sharedDate }}</span>
          <a href="/">了解 caldav-free</a>
        </footer>
      </article>
    </main>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import type { HabitPublicDay, HabitPublicShare } from '../types'
import { fetchPublicHabitShare } from '../tasks-api'
import TaskIcon from '../components/tasks/TaskIcon.vue'

const route = useRoute()
const loading = ref(true)
const error = ref('')
const share = ref<HabitPublicShare | null>(null)

const today = new Date().toISOString().slice(0, 10)
const doneDays = computed(() => share.value?.days.filter((day) => day.done).length || 0)
const sharedDate = computed(() => {
  if (!share.value) return ''
  const date = new Date(share.value.sharedAt)
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString('zh-CN', { year: 'numeric', month: 'short', day: 'numeric' })
})

function dayNumber(value: string) {
  return Number(value.slice(8, 10))
}

function dayTitle(day: HabitPublicDay) {
  const state = day.done ? '已完成' : '未完成'
  return `${day.date} · ${state}${day.goal > 1 ? ` · ${day.value}/${day.goal}` : ''}`
}

onMounted(async () => {
  try {
    share.value = await fetchPublicHabitShare(String(route.params.token || ''))
    document.title = `${share.value.name} · 习惯分享`
  } catch (err) {
    error.value = err instanceof Error ? err.message : '分享链接不存在或已停止分享'
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.habit-share-page {
  min-height: 100vh;
  min-height: 100dvh;
  padding: 32px 20px 56px;
  background:
    radial-gradient(circle at 12% 8%, rgba(151, 227, 139, 0.22), transparent 32%),
    radial-gradient(circle at 88% 20%, rgba(123, 156, 255, 0.12), transparent 28%),
    #f6f7f2;
  color: #20251f;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', sans-serif;
}

.habit-share-brand {
  width: min(760px, 100%);
  margin: 0 auto 28px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.habit-share-logo {
  display: inline-flex;
  align-items: center;
  gap: 9px;
  color: #20251f;
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.02em;
  text-decoration: none;
}

.habit-share-logo em { font-style: normal; color: #5c8f52; }
.habit-share-mark { width: 32px; height: 32px; display: inline-flex; align-items: center; justify-content: center; border-radius: 9px; background: #20251f; color: #f6f7f2; }
.habit-share-badge { padding: 5px 9px; border: 1px solid rgba(32, 37, 31, 0.12); border-radius: 999px; color: #6c7567; font-size: 10px; letter-spacing: 0.08em; }

.habit-share-main { width: min(760px, 100%); margin: 0 auto; }

.habit-share-card {
  overflow: hidden;
  border: 1px solid rgba(32, 37, 31, 0.09);
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.86);
  box-shadow: 0 30px 80px -42px rgba(32, 37, 31, 0.5);
  backdrop-filter: blur(16px);
}

.habit-share-head { display: flex; align-items: center; gap: 20px; padding: 34px 34px 26px; }
.habit-share-icon { width: 74px; height: 74px; flex: none; display: flex; align-items: center; justify-content: center; border-radius: 20px; font-size: 34px; box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.5), 0 12px 26px -16px rgba(32, 37, 31, 0.5); }
.habit-share-title { min-width: 0; }
.habit-share-eyebrow { margin: 0 0 6px; color: #87917f; font-size: 9px; font-weight: 700; letter-spacing: 0.2em; }
.habit-share-title h1 { margin: 0; color: #20251f; font-size: clamp(26px, 4vw, 38px); font-weight: 720; letter-spacing: -0.045em; line-height: 1.12; }
.habit-share-title p { margin: 8px 0 0; color: #717a6c; font-size: 12px; line-height: 1.6; }
.habit-share-title p strong { color: #20251f; font-weight: 700; }

.habit-share-stats { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 1px; margin: 0 34px; overflow: hidden; border: 1px solid rgba(32, 37, 31, 0.08); border-radius: 16px; background: rgba(32, 37, 31, 0.07); }
.habit-share-stats article { display: grid; gap: 6px; padding: 15px 14px; background: rgba(255, 255, 255, 0.92); }
.habit-share-stats span { color: #87917f; font-size: 9px; letter-spacing: 0.04em; }
.habit-share-stats strong { color: #20251f; font-size: 22px; font-weight: 720; letter-spacing: -0.03em; }
.habit-share-stats small { margin-left: 2px; color: #87917f; font-size: 9px; font-weight: 500; }

.habit-share-target { margin: 18px 34px 0; padding: 13px 15px; border-radius: 14px; background: rgba(151, 227, 139, 0.12); }
.habit-share-target header { display: flex; justify-content: space-between; color: #5f6a59; font-size: 10px; }
.habit-share-target header strong { color: #2f3a2b; }
.habit-share-target > div { height: 5px; margin-top: 9px; overflow: hidden; border-radius: 999px; background: rgba(32, 37, 31, 0.1); }
.habit-share-target > div i { display: block; height: 100%; border-radius: inherit; background: var(--habit-color); }
.habit-share-target p { margin: 7px 0 0; color: #87917f; font-size: 9px; }

.habit-share-days { padding: 26px 34px 8px; }
.habit-share-days > header { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 12px; }
.habit-share-days > header strong { color: #20251f; font-size: 12px; }
.habit-share-days > header span { color: #87917f; font-size: 10px; }
.habit-share-day-grid { display: grid; grid-template-columns: repeat(10, minmax(0, 1fr)); gap: 6px; }
.habit-share-day { position: relative; height: 48px; display: grid; place-items: center; border: 1px solid rgba(32, 37, 31, 0.07); border-radius: 9px; background: #fbfcf9; color: #b3b9ae; font-size: 9px; }
.habit-share-day.done { border-color: color-mix(in srgb, var(--habit-color) 55%, white); background: color-mix(in srgb, var(--habit-color) 22%, white); color: #33402e; }
.habit-share-day.today { box-shadow: inset 0 0 0 1px #20251f; }
.habit-share-day i { position: absolute; right: 3px; bottom: 3px; width: 14px; height: 14px; display: grid; place-items: center; border-radius: 50%; background: var(--habit-color); color: #1d261a; }

.habit-share-foot { display: flex; align-items: center; justify-content: space-between; gap: 14px; margin-top: 18px; padding: 16px 34px 20px; border-top: 1px solid rgba(32, 37, 31, 0.07); color: #9aa294; font-size: 9px; }
.habit-share-foot a { color: #5c8f52; text-decoration: none; }
.habit-share-foot a:hover { text-decoration: underline; }

.habit-share-state { display: grid; place-items: center; gap: 10px; min-height: 380px; padding: 40px 20px; border: 1px solid rgba(32, 37, 31, 0.09); border-radius: 24px; background: rgba(255, 255, 255, 0.78); text-align: center; }
.habit-share-error h1 { margin: 4px 0 0; font-size: 23px; letter-spacing: -0.03em; }
.habit-share-error p { margin: 0; color: #788173; font-size: 12px; }
.habit-share-state-icon { width: 58px; height: 58px; display: grid; place-items: center; border-radius: 16px; background: rgba(151, 227, 139, 0.22); color: #4f7d46; }
.habit-share-home { margin-top: 4px; padding: 8px 13px; border-radius: 999px; background: #20251f; color: #f6f7f2; font-size: 11px; text-decoration: none; }

@media (max-width: 620px) {
  .habit-share-page { padding: 20px 14px 40px; }
  .habit-share-brand { margin-bottom: 18px; }
  .habit-share-head { align-items: flex-start; gap: 14px; padding: 24px 20px 20px; }
  .habit-share-icon { width: 56px; height: 56px; border-radius: 16px; font-size: 27px; }
  .habit-share-stats { grid-template-columns: repeat(2, minmax(0, 1fr)); margin: 0 20px; }
  .habit-share-target { margin: 14px 20px 0; }
  .habit-share-days { padding: 22px 20px 6px; }
  .habit-share-day-grid { grid-template-columns: repeat(6, minmax(0, 1fr)); }
  .habit-share-day { height: 42px; }
  .habit-share-foot { align-items: flex-start; flex-direction: column; padding: 14px 20px 18px; }
}
</style>
