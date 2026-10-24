<template>
  <section v-if="visible && items.length" class="tw-habit-today">
    <header>
      <strong><TaskIcon name="habit" :size="16" /> 习惯</strong>
      <span>{{ doneCount }}/{{ items.length }}</span>
      <router-link to="/tasks/habit">查看全部</router-link>
    </header>
    <div class="tw-habit-today-items">
      <article
        v-for="habit in items"
        :key="habit.id"
        class="tw-habit-today-item"
        :class="{ done: isDone(habit.id) }"
      >
        <span class="tw-habit-today-icon" :style="{ backgroundColor: habit.color }">{{ habit.icon }}</span>
        <div>
          <strong>{{ habit.name }}</strong>
          <small>连续 {{ habit.currentStreak }} 天</small>
        </div>
        <button class="tw-habit-today-check" :class="{ done: isDone(habit.id) }" :disabled="busyId === habit.id" :title="isDone(habit.id) ? '取消打卡' : '打卡'" @click="toggle(habit)">
          <TaskIcon v-if="isDone(habit.id)" name="check" :size="12" />
          <span v-else-if="partialValue(habit.id)">{{ partialValue(habit.id) }}</span>
        </button>
      </article>
    </div>
    <HabitLogDialog v-if="logTarget" :habit="logTarget.habit" :stamp="logTarget.stamp" @saved="onLogSaved" @close="logTarget = null" />
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { HabitCheckin, HabitItem, HabitPreference } from '../../types'
import { fetchHabits, toggleHabitCheckin } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'
import HabitLogDialog from './HabitLogDialog.vue'

const props = withDefaults(defineProps<{ source?: 'today' | 'calendar' }>(), { source: 'today' })
const habits = ref<HabitItem[]>([])
const checkins = ref<Record<string, HabitCheckin[]>>({})
const preferences = ref<HabitPreference | null>(null)
const busyId = ref(0)
const logTarget = ref<{ habit: HabitItem; stamp: number } | null>(null)

const now = new Date()
const todayStamp = Number(`${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`)
const items = computed(() => habits.value.filter((habit) => habit.dueToday))
const visible = computed(() => Boolean(props.source === 'calendar' ? preferences.value?.showInCalendar : preferences.value?.showInToday) && items.value.length > 0)
const doneCount = computed(() => items.value.filter((habit) => isDone(habit.id)).length)

onMounted(load)

async function load() {
  try {
    const data = await fetchHabits(false)
    habits.value = data.habits || []
    checkins.value = data.checkins || {}
    preferences.value = data.preferences || null
  } catch {
    /* best effort on the today view */
  }
}

function checkinFor(habitId: number) {
  return (checkins.value[String(habitId)] || []).find((item) => item.checkinStamp === todayStamp)
}

function isDone(habitId: number) {
  const checkin = checkinFor(habitId)
  return Boolean(checkin && (checkin.status === 2 || (checkin.goal > 0 && checkin.value >= checkin.goal)))
}

function partialValue(habitId: number) {
  const checkin = checkinFor(habitId)
  return checkin && checkin.value > 0 && !isDone(habitId) ? checkin.value : 0
}

async function toggle(habit: HabitItem) {
  if (busyId.value) return
  busyId.value = habit.id
  try {
    await toggleHabitCheckin(habit.id)
    await load()
    if (habit.recordEnable && isDone(habit.id)) {
      logTarget.value = { habit, stamp: todayStamp }
    }
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '打卡失败')
  } finally {
    busyId.value = 0
  }
}

function onLogSaved() {
  logTarget.value = null
}
</script>
