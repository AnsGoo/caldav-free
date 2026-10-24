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
          <span>条件组内部为“且”；条件组之间可按“任意/全部”组合。按 Q1 → Q4 顺序匹配，未匹配任务归入 Q4。</span>
          <button class="tw-matrix-rules-reset" @click="form = defaultMatrixRules()">恢复内置规则与配色</button>
        </div>

        <section v-for="quadrant in MATRIX_QUADRANTS" :key="quadrant.id" class="tw-matrix-rule-card" :style="{ '--matrix-color': form[quadrant.id].color }">
          <header class="tw-matrix-rule-head">
            <span class="tw-matrix-rule-dot" />
            <input
              v-model="form[quadrant.id].name"
              class="tw-matrix-rule-name"
              maxlength="12"
              aria-label="象限名称"
              placeholder="象限名称"
            />
            <input v-model="form[quadrant.id].color" class="tw-matrix-rule-color" type="color" :title="`${form[quadrant.id].name}颜色`" />
            <select v-if="form[quadrant.id].groups.length > 1" v-model="form[quadrant.id].match" class="tw-matrix-rule-match">
              <option value="all">满足全部条件组</option>
              <option value="any">满足任一条件组</option>
            </select>
            <button class="tw-matrix-rule-clear" @click="clearMatrixConditions(form[quadrant.id])">重置条件</button>
          </header>

          <div v-for="(group, groupIndex) in form[quadrant.id].groups" :key="groupIndex" class="tw-matrix-condition-group">
            <header v-if="form[quadrant.id].groups.length > 1" class="tw-matrix-condition-head">
              <span>条件组 {{ groupIndex + 1 }}</span>
              <button @click="removeConditionGroup(quadrant.id, groupIndex)">删除</button>
            </header>

            <div class="tw-matrix-rule-line">
              <span>优先级</span>
              <div class="tw-matrix-priority-chips">
                <button
                  v-for="option in priorityOptions"
                  :key="option.value"
                  :class="{ active: group.priorities.includes(option.value) }"
                  @click="togglePriority(quadrant.id, groupIndex, option.value)"
                >{{ option.label }}</button>
                <button v-if="group.priorities.length" class="clear" @click="group.priorities = []">任意</button>
                <small v-else>未选择时匹配任意优先级</small>
              </div>
            </div>

            <div class="tw-matrix-rule-grid">
              <label>
                <span>日期</span>
                <select v-model="group.due" class="tw-field-select">
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
                <select v-model.number="group.listId" class="tw-field-select">
                  <option :value="0">任意清单</option>
                  <option v-for="list in lists" :key="list.id" :value="list.id">{{ list.name }}</option>
                </select>
              </label>
              <label>
                <span>标签</span>
                <select v-model="group.tag" class="tw-field-select">
                  <option value="">任意标签</option>
                  <option v-for="tag in tags" :key="tag" :value="tag">#{{ tag }}</option>
                </select>
              </label>
              <label>
                <span>指派人</span>
                <select v-model="group.assignee" class="tw-field-select">
                  <option value="">任意指派人</option>
                  <option v-for="name in assignees" :key="name" :value="name">@{{ name }}</option>
                </select>
              </label>
            </div>
            <p v-if="conditionEmpty(group)" class="tw-matrix-rule-hint">空白条件组会匹配全部任务。</p>
          </div>

          <button class="tw-matrix-add-group" :disabled="form[quadrant.id].groups.length >= 12" @click="addConditionGroup(quadrant.id)">
            + 添加条件组（OR）
          </button>
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
import type { MatrixCondition, MatrixQuadrantKey, MatrixView, MatrixViewRules, TaskList } from '../../types'
import { clearMatrixConditions, defaultMatrixRules, emptyMatrixCondition, MATRIX_QUADRANTS, normalizeMatrixRules } from '../../matrix-utils'
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

function togglePriority(quadrant: MatrixQuadrantKey, groupIndex: number, priority: number) {
  const group = form.value[quadrant].groups[groupIndex]
  if (!group) return
  group.priorities = group.priorities.includes(priority)
    ? group.priorities.filter((value) => value !== priority)
    : [...group.priorities, priority]
}

function conditionEmpty(condition: MatrixCondition) {
  return condition.priorities.length === 0 && condition.due === 'any' && !condition.listId && !condition.tag && !condition.assignee
}

function addConditionGroup(quadrant: MatrixQuadrantKey) {
  const rule = form.value[quadrant]
  if (rule.groups.length >= 12) return
  rule.groups.push(emptyMatrixCondition())
}

function removeConditionGroup(quadrant: MatrixQuadrantKey, groupIndex: number) {
  const rule = form.value[quadrant]
  if (rule.groups.length <= 1) return
  rule.groups.splice(groupIndex, 1)
  if (rule.groups.length === 1) rule.match = 'all'
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
