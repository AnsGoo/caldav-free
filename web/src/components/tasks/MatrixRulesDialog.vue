<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-matrix-rules-dialog" role="dialog" aria-modal="true" aria-label="自定义四象限规则">
      <header class="tw-dialog-head">
        <div>
          <h2>自定义四象限规则</h2>
          <p class="tw-matrix-rules-sub">{{ view.name }}</p>
        </div>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="16" />
        </button>
      </header>
      <div class="tw-dialog-body tw-matrix-rules-body">
        <div class="tw-matrix-rules-toolbar">
          <span>同一象限内条件为“且”；按 Q1 → Q4 顺序匹配，未匹配任务归入 Q4。</span>
          <button class="tw-matrix-rules-reset" @click="form = defaultMatrixRules()">恢复内置规则</button>
        </div>

        <section v-for="quadrant in MATRIX_QUADRANTS" :key="quadrant.id" class="tw-matrix-rule-card" :style="{ '--matrix-color': quadrant.color }">
          <header class="tw-matrix-rule-head">
            <span class="tw-matrix-rule-dot" />
            <strong>{{ quadrant.label }}</strong>
            <button v-if="quadrant.id !== 'q4'" class="tw-matrix-rule-clear" @click="Object.assign(form[quadrant.id], emptyMatrixRule())">清除条件</button>
          </header>

          <div class="tw-matrix-rule-line">
            <span>优先级</span>
            <div class="tw-matrix-priority-chips">
              <button
                v-for="option in priorityOptions"
                :key="option.value"
                :class="{ active: form[quadrant.id].priorities.includes(option.value) }"
                @click="togglePriority(quadrant.id, option.value)"
              >{{ option.label }}</button>
              <button v-if="form[quadrant.id].priorities.length" class="clear" @click="form[quadrant.id].priorities = []">任意</button>
              <small v-else>未选择时匹配任意优先级</small>
            </div>
          </div>

          <div class="tw-matrix-rule-grid">
            <label>
              <span>日期</span>
              <select v-model="form[quadrant.id].due" class="tw-field-select">
                <option value="any">任意</option>
                <option value="urgent">紧急（逾期/今天/明天）</option>
                <option value="overdue">已过期</option>
                <option value="today">今天</option>
                <option value="tomorrow">明天</option>
                <option value="next7">未来 7 天</option>
                <option value="later">7 天以后</option>
                <option value="none">无日期</option>
              </select>
            </label>
            <label>
              <span>清单</span>
              <select v-model.number="form[quadrant.id].listId" class="tw-field-select">
                <option :value="0">任意清单</option>
                <option v-for="list in lists" :key="list.id" :value="list.id">{{ list.name }}</option>
              </select>
            </label>
            <label>
              <span>标签</span>
              <select v-model="form[quadrant.id].tag" class="tw-field-select">
                <option value="">任意标签</option>
                <option v-for="tag in tags" :key="tag" :value="tag">#{{ tag }}</option>
              </select>
            </label>
            <label>
              <span>指派人</span>
              <select v-model="form[quadrant.id].assignee" class="tw-field-select">
                <option value="">任意指派人</option>
                <option v-for="name in assignees" :key="name" :value="name">@{{ name }}</option>
              </select>
            </label>
          </div>
          <p v-if="quadrant.id === 'q4'" class="tw-matrix-rule-hint">未匹配 Q1–Q3 的任务会自动归入此象限。</p>
        </section>

        <p v-if="error" class="tw-reminder-warning">{{ error }}</p>
      </div>
      <footer class="tw-dialog-foot">
        <button class="tw-dialog-cancel" @click="$emit('close')">取消</button>
        <button class="tw-dialog-ok" :disabled="busy" @click="save">{{ busy ? '保存中…' : '保存规则' }}</button>
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import type { MatrixQuadrantKey, MatrixView, MatrixViewRules, TaskList } from '../../types'
import { defaultMatrixRules, emptyMatrixRule, MATRIX_QUADRANTS, normalizeMatrixRules } from '../../matrix-utils'
import { updateMatrixView } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  view: MatrixView
  lists: TaskList[]
  tags: string[]
  assignees: string[]
}>()

const emit = defineEmits<{
  (event: 'close'): void
  (event: 'saved', view: MatrixView): void
}>()

const form = ref<MatrixViewRules>(normalizeMatrixRules(props.view.rules))
const busy = ref(false)
const error = ref('')

const priorityOptions = [
  { value: 3, label: '高' },
  { value: 2, label: '中' },
  { value: 1, label: '低' },
  { value: 0, label: '无' },
]

function togglePriority(quadrant: MatrixQuadrantKey, priority: number) {
  const selected = form.value[quadrant].priorities
  form.value[quadrant].priorities = selected.includes(priority)
    ? selected.filter((value) => value !== priority)
    : [...selected, priority]
}

async function save() {
  if (busy.value) return
  busy.value = true
  error.value = ''
  try {
    const { view } = await updateMatrixView(props.view.id, {
      name: props.view.name,
      mode: 'custom',
      rules: form.value,
    })
    emit('saved', view)
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '保存自定义规则失败'
  } finally {
    busy.value = false
  }
}
</script>
