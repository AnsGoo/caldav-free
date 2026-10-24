<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-dialog-sm tw-theme-dialog" role="dialog" aria-modal="true" aria-label="主题">
      <header class="tw-dialog-head">
        <h2>主题</h2>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="16" />
        </button>
      </header>
      <div class="tw-dialog-body">
        <div class="tw-theme-grid">
          <button
            v-for="item in TASK_THEMES"
            :key="item.id"
            class="tw-theme-card"
            :class="{ active: modelValue === item.id }"
            @click="$emit('select', item.id)"
          >
            <span class="tw-theme-preview" :style="{ background: item.bg, borderColor: item.rail }">
              <span class="tw-theme-preview-rail" :style="{ background: item.rail }" />
              <span class="tw-theme-preview-accent" :style="{ background: item.accent }" />
              <span class="tw-theme-preview-line" :style="{ background: item.accent }" />
            </span>
            <span class="tw-theme-label">
              {{ item.label }}
              <TaskIcon v-if="modelValue === item.id" name="check" :size="13" />
            </span>
          </button>
        </div>
      </div>
      <footer class="tw-dialog-foot">
        <button class="tw-dialog-cancel" @click="$emit('close')">关闭</button>
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { TASK_THEMES } from '../../themes'
import TaskIcon from './TaskIcon.vue'

defineProps<{ modelValue: string }>()
defineEmits<{ (event: 'select', id: string): void; (event: 'close'): void }>()
</script>
