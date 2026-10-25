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
          <div class="tw-matrix-rules-tools">
            <a-select v-model="template" class="tw-matrix-template-select" @change="applyTemplate">
              <a-option value="">套用模板…</a-option>
              <a-option value="builtin:priority">内置：按优先级分组</a-option>
              <a-option value="builtin:eisenhower">内置：优先级 + 日期</a-option>
              <a-option value="builtin:empty">内置：清空全部条件</a-option>
              <a-option v-for="item in templates" :key="item.id" :value="`custom:${item.id}`">我的模板：{{ item.name }}</a-option>
            </a-select>
            <button class="tw-matrix-rules-reset" @click="templateFormOpen = !templateFormOpen">
              <TaskIcon name="copy" :size="11" />
              保存为模板
            </button>
            <button class="tw-matrix-rules-reset" @click="form = defaultMatrixRules()">
              <TaskIcon name="restore" :size="11" />
              恢复内置规则与配色
            </button>
          </div>
        </div>

        <div v-if="templateFormOpen" class="tw-matrix-template-save">
          <a-input v-model="templateName" class="tw-dialog-input" placeholder="模板名称" :max-length="60" @keydown.enter="saveTemplate" />
          <button class="tw-dialog-ok" :disabled="templateSaving || !templateName.trim()" @click="saveTemplate">{{ templateSaving ? '保存中…' : '保存模板' }}</button>
          <button class="tw-dialog-cancel" @click="templateFormOpen = false">取消</button>
        </div>

        <div v-if="selectedTemplateId" class="tw-matrix-template-save tw-matrix-template-current">
          <span class="tw-matrix-template-label">当前模板</span>
          <a-input v-model="templateRename" class="tw-dialog-input" :max-length="60" aria-label="模板名称" @keydown.enter="renameTemplate" />
          <button class="tw-matrix-rule-action" :disabled="!templateRename.trim()" @click="renameTemplate">重命名</button>
          <button class="tw-matrix-rule-action" @click="updateTemplate">更新规则</button>
          <button class="tw-matrix-template-delete" :title="deleteArmed === selectedTemplateId ? '再次点击确认删除' : '删除当前模板'" @click="deleteTemplate">
            <TaskIcon name="trash" :size="11" />
            {{ deleteArmed === selectedTemplateId ? '确认删除' : '删除' }}
          </button>
        </div>

        <section v-for="quadrant in MATRIX_QUADRANTS" :key="quadrant.id" class="tw-matrix-rule-card" :style="{ '--matrix-color': form[quadrant.id].color }">
          <header class="tw-matrix-rule-head">
            <span class="tw-matrix-rule-dot" />
            <a-input
              v-model="form[quadrant.id].name"
              class="tw-matrix-rule-name"
              :max-length="12"
              aria-label="象限名称"
              placeholder="象限名称"
            />
            <input v-model="form[quadrant.id].color" class="tw-matrix-rule-color" type="color" :title="`${form[quadrant.id].name}颜色`" />
            <a-select v-if="form[quadrant.id].groups.length > 1" v-model="form[quadrant.id].match" class="tw-matrix-rule-match">
              <a-option value="all">满足全部条件组</a-option>
              <a-option value="any">满足任一条件组</a-option>
            </a-select>
            <span class="tw-matrix-rule-preview" title="按当前规则预览命中数量">{{ quadrantCounts[quadrant.id] }} 项</span>
            <button class="tw-matrix-rule-clear" title="重置当前象限的全部条件" @click="clearMatrixConditions(form[quadrant.id])">
              <TaskIcon name="refresh" :size="11" />
              重置条件
            </button>
          </header>

          <div
            v-for="(group, groupIndex) in form[quadrant.id].groups"
            :key="groupIndex"
            class="tw-matrix-condition-group"
            :class="{ 'drag-over': groupDrag?.quadrant === quadrant.id && groupOver === groupIndex && groupDrag?.index !== groupIndex }"
            @dragover.prevent="groupOver = groupIndex"
            @dragleave="groupOver = -1"
            @drop.prevent="dropConditionGroup(quadrant.id, groupIndex)"
          >
            <header v-if="form[quadrant.id].groups.length > 1" class="tw-matrix-condition-head">
              <span class="tw-matrix-condition-label">
                <span
                  class="tw-matrix-group-drag"
                  title="拖动排序"
                  draggable="true"
                  @dragstart.stop="startConditionDrag(quadrant.id, groupIndex, $event)"
                  @dragend="groupDrag = null; groupOver = -1"
                >
                  <TaskIcon name="drag" :size="12" />
                </span>
                条件组 {{ groupIndex + 1 }} · 命中 {{ groupCounts[quadrant.id]?.[groupIndex] ?? 0 }}
              </span>
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
              <div>
                <span>日期</span>
                <a-select v-model="group.due" class="tw-field-select">
                  <a-option value="any">任意</a-option>
                  <a-option value="urgent">紧急（逾期/今天/明天）</a-option>
                  <a-option value="overdue">已过期</a-option>
                  <a-option value="today">今天</a-option>
                  <a-option value="tomorrow">明天</a-option>
                  <a-option value="next7">未来 7 天</a-option>
                  <a-option value="later">7 天以后</a-option>
                  <a-option value="none">无日期</a-option>
                </a-select>
              </div>
              <div>
                <span>清单</span>
                <a-select v-model.number="group.listId" class="tw-field-select">
                  <a-option :value="0">任意清单</a-option>
                  <a-option v-for="list in lists" :key="list.id" :value="list.id">{{ list.name }}</a-option>
                </a-select>
              </div>
              <div>
                <span>标签</span>
                <a-select v-model="group.tag" class="tw-field-select">
                  <a-option value="">任意标签</a-option>
                  <a-option v-for="tag in tags" :key="tag" :value="tag">#{{ tag }}</a-option>
                </a-select>
              </div>
              <div>
                <span>指派人</span>
                <a-select v-model="group.assignee" class="tw-field-select">
                  <a-option value="">任意指派人</a-option>
                  <a-option v-for="name in assignees" :key="name" :value="name">@{{ name }}</a-option>
                </a-select>
              </div>
            </div>
            <p v-if="conditionEmpty(group)" class="tw-matrix-rule-hint">空白条件组会匹配全部任务。</p>
          </div>

          <div class="tw-matrix-rule-actions">
            <button class="tw-matrix-add-group" :disabled="form[quadrant.id].groups.length >= 12" @click="addConditionGroup(quadrant.id)">
              + 添加条件组（OR）
            </button>
            <button class="tw-matrix-rule-action" @click="copyConditions(quadrant.id)">复制条件</button>
            <button class="tw-matrix-rule-action" :disabled="!copiedConditions" @click="pasteConditions(quadrant.id)">粘贴条件</button>
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
import { computed, onMounted, ref, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { MatrixCondition, MatrixQuadrantKey, MatrixRuleTemplate, MatrixView, MatrixViewRules, TaskItem, TaskList } from '../../types'
import { clearMatrixConditions, defaultMatrixRules, emptyMatrixCondition, MATRIX_QUADRANTS, matchesMatrixCondition, matrixQuadrant, normalizeMatrixRules } from '../../matrix-utils'
import { createMatrixRuleTemplate, deleteMatrixRuleTemplate, fetchMatrixRuleTemplates, updateMatrixRuleTemplate, updateMatrixView } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  view: MatrixView
  lists: TaskList[]
  tags: string[]
  assignees: string[]
  tasks: TaskItem[]
}>()

const emit = defineEmits<{
  (event: 'close'): void
  (event: 'saved', view: MatrixView): void
}>()

const form = ref<MatrixViewRules>(normalizeMatrixRules(props.view.rules))
const busy = ref(false)
const error = ref('')
const groupDrag = ref<{ quadrant: MatrixQuadrantKey; index: number } | null>(null)
const groupOver = ref(-1)
const template = ref('')
const templates = ref<MatrixRuleTemplate[]>([])
const templateFormOpen = ref(false)
const templateName = ref('')
const templateRename = ref('')
const templateSaving = ref(false)
const deleteArmed = ref(0)
const copiedConditions = ref<{ match: 'all' | 'any'; groups: MatrixCondition[] } | null>(null)
const selectedTemplateId = computed(() => template.value.startsWith('custom:') ? Number(template.value.slice(7)) || 0 : 0)

watch(template, () => {
  deleteArmed.value = 0
  templateRename.value = templates.value.find((item) => `custom:${item.id}` === template.value)?.name || ''
})

onMounted(async () => {
  try {
    templates.value = (await fetchMatrixRuleTemplates()).templates
  } catch {
    /* keep built-in templates usable */
  }
})

const quadrantCounts = computed(() => {
  const counts: Record<MatrixQuadrantKey, number> = { q1: 0, q2: 0, q3: 0, q4: 0 }
  for (const task of props.tasks) counts[matrixQuadrant(task, form.value)] += 1
  return counts
})

const groupCounts = computed(() => {
  const counts = {} as Record<MatrixQuadrantKey, number[]>
  for (const quadrant of MATRIX_QUADRANTS) {
    counts[quadrant.id] = form.value[quadrant.id].groups.map((group) =>
      props.tasks.filter((task) => matchesMatrixCondition(task, group)).length,
    )
  }
  return counts
})

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

function cloneCondition(condition: MatrixCondition): MatrixCondition {
  return { ...condition, priorities: [...condition.priorities] }
}

function applyTemplate() {
  const selected = template.value
  if (!selected) return
  if (selected.startsWith('custom:')) {
    const item = templates.value.find((entry) => `custom:${entry.id}` === selected)
    if (item) form.value = normalizeMatrixRules(item.rules)
    return
  }
  template.value = ''
  const priorities: Record<MatrixQuadrantKey, number[]> = { q1: [3], q2: [2], q3: [1], q4: [0] }
  const presets = selected === 'builtin:eisenhower' ? defaultMatrixRules() : null
  for (const quadrant of MATRIX_QUADRANTS) {
    const rule = form.value[quadrant.id]
    if (selected === 'builtin:priority') {
      rule.match = 'all'
      rule.groups = [{ ...emptyMatrixCondition(), priorities: priorities[quadrant.id] }]
    } else if (presets) {
      rule.match = presets[quadrant.id].match
      rule.groups = presets[quadrant.id].groups.map(cloneCondition)
    } else {
      rule.match = 'all'
      rule.groups = [emptyMatrixCondition()]
    }
  }
}

async function saveTemplate() {
  const name = templateName.value.trim()
  if (!name || templateSaving.value) return
  templateSaving.value = true
  error.value = ''
  try {
    const { template: created } = await createMatrixRuleTemplate(name, normalizeMatrixRules(form.value))
    templates.value = [created, ...templates.value]
    template.value = `custom:${created.id}`
    templateName.value = ''
    templateFormOpen.value = false
    Message.success('规则模板已保存')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '保存规则模板失败'
  } finally {
    templateSaving.value = false
  }
}

async function renameTemplate() {
  const id = selectedTemplateId.value
  const name = templateRename.value.trim()
  if (!id || !name) return
  try {
    const { template: updated } = await updateMatrixRuleTemplate(id, { name })
    templates.value = templates.value.map((item) => item.id === updated.id ? updated : item)
    Message.success('模板名称已更新')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '重命名模板失败'
  }
}

async function updateTemplate() {
  const id = selectedTemplateId.value
  if (!id) return
  try {
    const { template: updated } = await updateMatrixRuleTemplate(id, { rules: normalizeMatrixRules(form.value) })
    templates.value = templates.value.map((item) => item.id === updated.id ? updated : item)
    Message.success('模板规则已更新')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '更新模板失败'
  }
}

async function deleteTemplate() {
  const id = selectedTemplateId.value
  if (!id) return
  if (deleteArmed.value !== id) {
    deleteArmed.value = id
    return
  }
  try {
    await deleteMatrixRuleTemplate(id)
    templates.value = templates.value.filter((item) => item.id !== id)
    template.value = ''
    deleteArmed.value = 0
    Message.success('规则模板已删除')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '删除规则模板失败'
  }
}

function copyConditions(quadrant: MatrixQuadrantKey) {
  const rule = form.value[quadrant]
  copiedConditions.value = { match: rule.match, groups: rule.groups.map(cloneCondition) }
  Message.success(`已复制「${rule.name}」的条件`)
}

function pasteConditions(quadrant: MatrixQuadrantKey) {
  const copied = copiedConditions.value
  if (!copied) return
  const rule = form.value[quadrant]
  rule.match = copied.match
  rule.groups = copied.groups.map(cloneCondition)
  Message.success(`已粘贴到「${rule.name}」`)
}

function conditionEmpty(condition: MatrixCondition) {
  return condition.priorities.length === 0 && condition.due === 'any' && !condition.listId && !condition.tag && !condition.assignee
}

function startConditionDrag(quadrant: MatrixQuadrantKey, index: number, event: DragEvent) {
  groupDrag.value = { quadrant, index }
  groupOver.value = index
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', String(index))
  }
}

function dropConditionGroup(quadrant: MatrixQuadrantKey, target: number) {
  const drag = groupDrag.value
  groupDrag.value = null
  groupOver.value = -1
  if (!drag || drag.quadrant !== quadrant || drag.index === target) return
  const groups = form.value[quadrant].groups
  const [moved] = groups.splice(drag.index, 1)
  if (moved) groups.splice(target, 0, moved)
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
  groupDrag.value = null
  groupOver.value = -1
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
