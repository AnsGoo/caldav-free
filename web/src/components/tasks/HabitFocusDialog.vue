<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-habit-focus-dialog" role="dialog" aria-modal="true" aria-label="习惯专注">
      <header class="tw-dialog-head">
        <div>
          <h2>专注</h2>
          <p class="tw-modal-note">{{ habit.icon }} {{ habit.name }}</p>
        </div>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="16" />
        </button>
      </header>
      <div class="tw-dialog-body tw-habit-focus-body">
        <div class="tw-habit-focus-time" :class="{ done: remaining === 0 }">{{ clock }}</div>
        <div class="tw-habit-focus-presets">
          <button v-for="preset in presets" :key="preset" :class="{ active: minutes === preset }" :disabled="running" @click="setMinutes(preset)">{{ preset }} 分钟</button>
        </div>
        <div class="tw-habit-focus-actions">
          <button class="tw-primary-button" :disabled="remaining === 0 && !running" @click="toggle">
            {{ running ? '暂停' : remaining === 0 ? '重新开始' : '开始专注' }}
          </button>
          <button class="tw-ghost-button" :disabled="running" @click="reset">重置</button>
        </div>
        <p class="tw-modal-note">{{ running ? '保持专注，完成后会提醒你。' : '选择一个时长后开始。' }}</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { HabitItem } from '../../types'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ habit: HabitItem }>()
const emit = defineEmits<{ (event: 'close'): void }>()
const presets = [15, 25, 45, 60]
const minutes = ref(25)
const remaining = ref(25 * 60)
const running = ref(false)
let timer: ReturnType<typeof setInterval> | undefined

const clock = computed(() => {
  const value = Math.max(0, remaining.value)
  return `${String(Math.floor(value / 60)).padStart(2, '0')}:${String(value % 60).padStart(2, '0')}`
})

function setMinutes(value: number) {
  minutes.value = value
  remaining.value = value * 60
}

function tick() {
  if (remaining.value <= 0) {
    complete()
    return
  }
  remaining.value -= 1
}

function toggle() {
  if (running.value) {
    pause()
    return
  }
  if (remaining.value <= 0) remaining.value = minutes.value * 60
  running.value = true
  timer = setInterval(tick, 1000)
}

function pause() {
  running.value = false
  if (timer) clearInterval(timer)
  timer = undefined
}

function reset() {
  pause()
  remaining.value = minutes.value * 60
}

function complete() {
  pause()
  remaining.value = 0
  Message.success(`「${props.habit.name}」专注完成`)
  if (typeof Notification !== 'undefined' && Notification.permission === 'granted') {
    new Notification('专注完成', { body: props.habit.name, tag: `habit-focus-${props.habit.id}` })
  }
}

onBeforeUnmount(pause)
</script>
