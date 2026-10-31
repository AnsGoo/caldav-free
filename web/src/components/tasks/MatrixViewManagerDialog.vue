<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-matrix-manager-dialog" role="dialog" aria-modal="true" aria-label="管理矩阵视图">
      <header class="tw-dialog-head">
        <h2>管理矩阵视图</h2>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="16" />
        </button>
      </header>
      <div class="tw-dialog-body tw-matrix-manager-body">
        <p class="tw-matrix-manager-hint">拖动行调整顺序；名称失焦或规则变化后自动保存。</p>
        <div
          v-for="(view, index) in items"
          :key="view.id"
          class="tw-matrix-manager-row"
          :class="{ dragging: dragIndex === index, 'drag-over': overIndex === index && dragIndex !== index }"
          @dragover.prevent="overIndex = index"
          @dragleave="overIndex = -1"
          @drop.prevent="dropOn(index)"
        >
          <span
            class="tw-matrix-drag"
            title="拖动排序"
            draggable="true"
            @dragstart="startDrag(index, $event)"
            @dragend="dragIndex = -1; overIndex = -1"
          >
            <TaskIcon name="drag" :size="14" />
          </span>
          <a-input v-model="view.name" class="tw-dialog-input" :max-length="60" @blur="saveName(view)" @keydown.enter="saveName(view)" />
          <a-select v-model="view.mode" class="tw-field-select tw-matrix-mode-select" @change="saveMode(view)">
            <a-option value="simple">按优先级</a-option>
            <a-option value="complex">优先级 + 日期</a-option>
            <a-option value="custom">自定义规则</a-option>
          </a-select>
          <button v-if="view.mode === 'custom'" class="tw-icon-button" title="编辑自定义规则" @click="$emit('edit-rules', view)">
            <TaskIcon name="filter" :size="14" />
          </button>
          <button class="tw-icon-button" :title="deleteArmed === view.id ? '确认删除' : '删除视图'" @click="remove(view)">
            <TaskIcon name="trash" :size="14" />
          </button>
        </div>
        <p v-if="!items.length" class="tw-filter-empty">还没有保存的矩阵视图。</p>
        <p v-if="error" class="tw-reminder-warning">{{ error }}</p>
      </div>
      <footer class="tw-dialog-foot">
        <button class="tw-dialog-ok" @click="$emit('close')">完成</button>
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { MatrixView } from '../../types'
import { deleteMatrixView, updateMatrixView } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ views: MatrixView[] }>()
const emit = defineEmits<{
  (event: 'close'): void
  (event: 'changed', views: MatrixView[]): void
  (event: 'edit-rules', view: MatrixView): void
}>()

const items = ref(props.views.map((view) => ({ ...view })))
const dragIndex = ref(-1)
const overIndex = ref(-1)
const deleteArmed = ref(0)
const error = ref('')

function startDrag(index: number, event: DragEvent) {
  dragIndex.value = index
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', String(items.value[index]?.id || ''))
  }
}

async function dropOn(index: number) {
  const from = dragIndex.value
  dragIndex.value = -1
  overIndex.value = -1
  if (from < 0 || from === index) return
  const next = items.value.slice()
  const [moved] = next.splice(from, 1)
  next.splice(index, 0, moved)
  next.forEach((view, position) => { view.order = position + 1 })
  items.value = next
  try {
    await Promise.all(next.map((view) => updateMatrixView(view.id, { name: view.name, mode: view.mode, order: view.order })))
    emit('changed', items.value.map((view) => ({ ...view })))
    Message.success('视图顺序已更新')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '调整顺序失败'
  }
}

async function saveName(view: MatrixView) {
  const name = view.name.trim()
  if (!name) {
    error.value = '视图名称不能为空'
    return
  }
  try {
    const result = await updateMatrixView(view.id, { name, mode: view.mode, order: view.order })
    Object.assign(view, result.view)
    emit('changed', items.value.map((item) => ({ ...item })))
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '保存名称失败'
  }
}

async function saveMode(view: MatrixView) {
  try {
    const result = await updateMatrixView(view.id, { name: view.name, mode: view.mode, order: view.order })
    Object.assign(view, result.view)
    emit('changed', items.value.map((item) => ({ ...item })))
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '保存规则失败'
  }
}

async function remove(view: MatrixView) {
  if (deleteArmed.value !== view.id) {
    deleteArmed.value = view.id
    return
  }
  try {
    await deleteMatrixView(view.id)
    items.value = items.value.filter((item) => item.id !== view.id)
    emit('changed', items.value.map((item) => ({ ...item })))
    deleteArmed.value = 0
    Message.success('视图已删除')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '删除视图失败'
  }
}
</script>
