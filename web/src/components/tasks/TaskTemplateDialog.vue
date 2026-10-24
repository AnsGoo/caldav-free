<template>
  <div v-if="open" class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-task-template-dialog" role="dialog" aria-modal="true" aria-label="任务模板">
      <header class="tw-dialog-head">
        <h2>任务模板</h2>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')"><TaskIcon name="close" :size="16" /></button>
      </header>
      <div class="tw-dialog-body">
        <p class="tw-modal-note">在任务详情右上角点击复制图标，可以把当前任务保存为模板。</p>
        <div v-if="!templates.length" class="tw-task-template-empty">还没有任务模板。</div>
        <div v-else class="tw-task-template-list">
          <article v-for="template in templates" :key="template.id" class="tw-task-template-row">
            <button class="tw-task-template-main" :disabled="busy" @click="$emit('apply', template)">
              <span class="tw-task-template-icon"><TaskIcon name="copy" :size="15" /></span>
              <span>
                <strong>{{ template.name }}</strong>
                <small>{{ templatePreview(template) }}</small>
              </span>
              <span class="tw-task-template-use">使用</span>
            </button>
            <button class="tw-icon-button danger" title="删除模板" :disabled="busy" @click="$emit('delete', template)"><TaskIcon name="trash" :size="14" /></button>
          </article>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { TaskTemplate } from '../../types'
import TaskIcon from './TaskIcon.vue'

defineProps<{ open: boolean; templates: TaskTemplate[]; busy?: boolean }>()
defineEmits<{
  (event: 'close'): void
  (event: 'apply', template: TaskTemplate): void
  (event: 'delete', template: TaskTemplate): void
}>()

function templatePreview(template: TaskTemplate) {
  try {
    const payload = JSON.parse(template.payload) as { title?: string; notes?: string; priority?: number; tags?: string[] }
    const parts = [payload.title || '未命名任务']
    if (payload.priority) parts.push(`P${payload.priority}`)
    if (payload.tags?.length) parts.push(payload.tags.map((tag) => `#${tag}`).join(' '))
    if (payload.notes) parts.push(payload.notes.slice(0, 30))
    return parts.join(' · ')
  } catch {
    return '模板内容无效'
  }
}
</script>
