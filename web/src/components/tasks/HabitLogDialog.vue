<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true" aria-label="打卡日志">
      <header class="tw-dialog-head">
        <div>
          <h2>打卡日志</h2>
          <p class="tw-modal-note">{{ habit.icon }} {{ habit.name }} · {{ dateLabel }}</p>
        </div>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="16" />
        </button>
      </header>
      <div class="tw-dialog-body">
        <a-textarea
          v-model="content"
          class="tw-habit-log-input"
          :auto-size="{ minRows: 4, maxRows: 7 }"
          :max-length="1000"
          placeholder="记录一下今天的感受…"
        />
      </div>
      <footer class="tw-dialog-foot">
        <button class="tw-dialog-cancel" @click="$emit('close')">跳过</button>
        <button class="tw-dialog-ok" :disabled="busy || !content.trim()" @click="save">{{ busy ? '保存中…' : '保存日志' }}</button>
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { HabitItem } from '../../types'
import { createHabitRecord } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ habit: HabitItem; stamp: number }>()
const emit = defineEmits<{ (event: 'close'): void; (event: 'saved'): void }>()
const content = ref('')
const busy = ref(false)

const dateLabel = computed(() => {
  const value = String(props.stamp)
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`
})

async function save() {
  if (!content.value.trim() || busy.value) return
  busy.value = true
  try {
    await createHabitRecord(props.habit.id, {
      content: content.value.trim(),
      emoji: props.habit.icon || '📝',
      stamp: props.stamp,
    })
    emit('saved')
    emit('close')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存日志失败')
  } finally {
    busy.value = false
  }
}
</script>
