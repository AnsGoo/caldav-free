<template>
  <section class="tw-matrix">
    <header class="tw-matrix-head">
      <div>
        <h2>四象限</h2>
        <p>{{ rule === 'simple' ? '按优先级分组 · 拖动任务可修改优先级' : rule === 'complex' ? '按优先级 + 截止日期分组' : '按自定义规则分组 · 拖动任务自动匹配目标条件' }}</p>
      </div>
      <div class="tw-matrix-head-actions">
        <div class="tw-matrix-view-picker">
          <select :value="activeViewId" @change="$emit('select-view', Number(($event.target as HTMLSelectElement).value))">
            <option :value="0">默认四象限</option>
            <option v-for="view in views" :key="view.id" :value="view.id">{{ view.name }}</option>
          </select>
          <button title="新建四象限视图" @click="$emit('create-view')">
            <TaskIcon name="plus" :size="13" />
          </button>
          <button title="管理四象限视图" @click="$emit('manage-views')">
            <TaskIcon name="settings" :size="13" />
          </button>
          <button v-if="activeViewId" title="编辑自定义规则" @click="$emit('edit-rules')">
            <TaskIcon name="filter" :size="13" />
          </button>
        </div>
        <div class="tw-matrix-rule">
          <button :class="{ active: rule === 'simple' }" @click="$emit('change-rule', 'simple')">按优先级</button>
          <button :class="{ active: rule === 'complex' }" @click="$emit('change-rule', 'complex')">优先级 + 日期</button>
          <button v-if="activeViewId" :class="{ active: rule === 'custom' }" @click="$emit('change-rule', 'custom')">自定义</button>
        </div>
        <button
          class="tw-matrix-completed-toggle"
          :class="{ active: showCompleted }"
          :title="showCompleted ? '隐藏已完成任务' : '显示已完成任务'"
          @click="$emit('toggle-completed')"
        >
          <TaskIcon name="check" :size="11" />
          已完成
        </button>
        <span class="tw-matrix-total">{{ tasks.length }} 项</span>
      </div>
    </header>

    <div class="tw-matrix-grid" :class="gridCollapseClass">
      <article
        v-for="quadrant in quadrants"
        :key="quadrant.id"
        class="tw-matrix-card"
        :class="{ 'drag-over': dragOver === quadrant.id, collapsed: collapsedQuadrants.has(quadrant.id) }"
        :style="{ '--matrix-color': quadrant.color }"
        @dragover.prevent="dragTask && rule !== 'complex' ? (dragOver = quadrant.id) : null"
        @dragleave="dragOver = ''"
        @drop.prevent="dropOnQuadrant(quadrant.id)"
      >
        <header class="tw-matrix-card-head">
          <span class="tw-matrix-icon">
            <i /><i /><i /><i />
          </span>
          <strong>{{ quadrant.label }}</strong>
          <span class="tw-matrix-count">{{ quadrant.tasks.length }}</span>
          <button
            class="tw-matrix-collapse"
            :class="{ active: collapsedQuadrants.has(quadrant.id) }"
            :title="collapsedQuadrants.has(quadrant.id) ? '展开象限' : '折叠象限'"
            :aria-label="collapsedQuadrants.has(quadrant.id) ? '展开象限' : '折叠象限'"
            :aria-expanded="!collapsedQuadrants.has(quadrant.id)"
            @click.stop="toggleCollapse(quadrant.id)"
          >
            <TaskIcon name="chevron" :size="13" />
          </button>
        </header>

        <div v-if="!collapsedQuadrants.has(quadrant.id) && quadrant.tasks.length" class="tw-matrix-body">
          <section
            v-for="group in quadrant.groups"
            :key="group.key"
            class="tw-matrix-group"
          >
            <header class="tw-matrix-group-head">
              <span>{{ group.label }}</span>
              <small>{{ group.tasks.length }}</small>
            </header>
            <div class="tw-matrix-rows">
              <button
                v-for="task in group.tasks"
                :key="task.id"
                class="tw-matrix-row"
                :class="{ done: task.completed }"
                :draggable="rule !== 'complex'"
                @dragstart="startDrag(task, $event)"
                @dragend="dragTask = null; dragOver = ''"
                @click="$emit('open', task)"
              >
                <span
                  class="tw-matrix-check"
                  :class="{ checked: task.completed }"
                  :title="task.completed ? '标记为未完成' : '标记为完成'"
                  @click.stop="$emit('toggle', task)"
                >
                  <TaskIcon v-if="task.completed" name="check" :size="11" />
                </span>
                <span class="tw-matrix-title">{{ task.title }}</span>
                <span v-for="tag in task.tags.slice(0, 2)" :key="tag" class="tw-matrix-tag">#{{ tag }}</span>
                <span class="tw-matrix-meta">
                  <span v-if="task.recurrence" :title="recurrenceLabel(task.recurrence)">
                    <TaskIcon name="repeat" :size="12" />
                  </span>
                  <span v-if="task.assignee" class="tw-matrix-assignee">@{{ task.assignee }}</span>
                  <span class="tw-matrix-list">
                    <i :style="{ background: task.listColor || '#4772fa' }" />
                    {{ task.listName }}
                  </span>
                  <span v-if="task.due" :class="{ overdue: isOverdue(task) }">{{ formatDue(task) }}</span>
                </span>
              </button>
            </div>
          </section>
        </div>
        <div v-else-if="!collapsedQuadrants.has(quadrant.id)" class="tw-matrix-empty">没有任务</div>
      </article>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import type { MatrixQuadrantKey, MatrixRuleMode, MatrixView, MatrixViewRules, TaskItem, TaskList } from '../../types'
import { dayKey, formatDue, isOverdue, recurrenceLabel, startOfToday } from '../../tasks-utils'
import { matrixQuadrant, normalizeMatrixRules } from '../../matrix-utils'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  tasks: TaskItem[]
  rule: MatrixRuleMode
  views: MatrixView[]
  activeViewId: number
  customRules?: MatrixViewRules
  lists: TaskList[]
  tags: string[]
  assignees: string[]
  showCompleted: boolean
}>()

const emit = defineEmits<{
  (event: 'open', task: TaskItem): void
  (event: 'toggle', task: TaskItem): void
  (event: 'move', payload: { task: TaskItem; priority: number }): void
  (event: 'move-custom', payload: { task: TaskItem; quadrant: MatrixQuadrantKey }): void
  (event: 'change-rule', rule: MatrixRuleMode): void
  (event: 'select-view', id: number): void
  (event: 'create-view'): void
  (event: 'manage-views'): void
  (event: 'edit-rules'): void
  (event: 'toggle-completed'): void
}>()

const dragTask = ref<TaskItem | null>(null)
const dragOver = ref('')
const collapsedQuadrants = ref<Set<string>>(new Set())

const collapseStorageKey = computed(() => `caldav-matrix-collapsed-${props.activeViewId}`)
const gridCollapseClass = computed(() => ({
  'top-collapsed': collapsedQuadrants.value.has('q1') && collapsedQuadrants.value.has('q2'),
  'bottom-collapsed': collapsedQuadrants.value.has('q3') && collapsedQuadrants.value.has('q4'),
}))

function loadCollapsed() {
  try {
    const parsed = JSON.parse(localStorage.getItem(collapseStorageKey.value) || '[]')
    collapsedQuadrants.value = new Set(Array.isArray(parsed) ? parsed.filter((id) => typeof id === 'string') : [])
  } catch {
    collapsedQuadrants.value = new Set()
  }
}

function toggleCollapse(quadrant: string) {
  const next = new Set(collapsedQuadrants.value)
  if (next.has(quadrant)) next.delete(quadrant)
  else next.add(quadrant)
  collapsedQuadrants.value = next
  try {
    localStorage.setItem(collapseStorageKey.value, JSON.stringify([...next]))
  } catch {
    /* ignore */
  }
}

onMounted(loadCollapsed)
watch(() => props.activeViewId, loadCollapsed)

const customRules = computed(() => normalizeMatrixRules(props.customRules))

const quadrants = computed(() => {
  const buckets: Record<string, TaskItem[]> = { q1: [], q2: [], q3: [], q4: [] }
  const tomorrowEnd = new Date(startOfToday())
  tomorrowEnd.setDate(tomorrowEnd.getDate() + 2)
  const today = startOfToday()
  for (const task of props.tasks) {
    const priority = task.priority > 3 || task.priority < 0 ? 0 : task.priority
    let key: string
    if (props.rule === 'simple') {
      key = priority === 3 ? 'q1' : priority === 2 ? 'q2' : priority === 1 ? 'q3' : 'q4'
    } else if (props.rule === 'custom') {
      key = matrixQuadrant(task, customRules.value, today)
    } else {
      const important = priority >= 2
      const due = task.due ? new Date(task.due) : null
      const urgent = Boolean(due && due.getTime() < tomorrowEnd.getTime())
      key = important ? (urgent ? 'q1' : 'q2') : (urgent ? 'q3' : 'q4')
    }
    buckets[key].push(task)
  }
  return [
    { id: 'q1', label: customRules.value.q1.name, color: customRules.value.q1.color, tasks: buckets.q1, groups: group(buckets.q1) },
    { id: 'q2', label: customRules.value.q2.name, color: customRules.value.q2.color, tasks: buckets.q2, groups: group(buckets.q2) },
    { id: 'q3', label: customRules.value.q3.name, color: customRules.value.q3.color, tasks: buckets.q3, groups: group(buckets.q3) },
    { id: 'q4', label: customRules.value.q4.name, color: customRules.value.q4.color, tasks: buckets.q4, groups: group(buckets.q4) },
  ]
})

function startDrag(task: TaskItem, event: DragEvent) {
  if (props.rule === 'complex') return
  dragTask.value = task
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', String(task.id))
  }
}

function dropOnQuadrant(quadrant: string) {
  const task = dragTask.value
  dragTask.value = null
  dragOver.value = ''
  if (!task || props.rule === 'complex') return
  if (props.rule === 'custom') {
    emit('move-custom', { task, quadrant: quadrant as MatrixQuadrantKey })
    return
  }
  const priority = quadrant === 'q1' ? 3 : quadrant === 'q2' ? 2 : quadrant === 'q3' ? 1 : 0
  if (task.priority !== priority) emit('move', { task, priority })
}

function group(tasks: TaskItem[]) {
  const today = startOfToday()
  const tomorrow = new Date(today)
  tomorrow.setDate(tomorrow.getDate() + 1)
  const buckets: Record<string, TaskItem[]> = {
    overdue: [],
    today: [],
    tomorrow: [],
    later: [],
    none: [],
    done: [],
  }
  for (const task of tasks) {
    if (task.completed) {
      buckets.done.push(task)
      continue
    }
    if (!task.due) {
      buckets.none.push(task)
      continue
    }
    const due = new Date(task.due)
    const key = dayKey(due)
    if (key < dayKey(today)) buckets.overdue.push(task)
    else if (key === dayKey(today)) buckets.today.push(task)
    else if (key === dayKey(tomorrow)) buckets.tomorrow.push(task)
    else buckets.later.push(task)
  }
  const sort = (items: TaskItem[]) =>
    items.slice().sort((a, b) => {
      const ad = a.due ? new Date(a.due).getTime() : Number.MAX_SAFE_INTEGER
      const bd = b.due ? new Date(b.due).getTime() : Number.MAX_SAFE_INTEGER
      return ad - bd || a.order - b.order || a.id - b.id
    })
  return [
    { key: 'none', label: '无日期', tasks: sort(buckets.none) },
    { key: 'overdue', label: '已过期', tasks: sort(buckets.overdue) },
    { key: 'today', label: '今天', tasks: sort(buckets.today) },
    { key: 'tomorrow', label: '明天', tasks: sort(buckets.tomorrow) },
    { key: 'later', label: '未来', tasks: sort(buckets.later) },
    { key: 'done', label: '已完成', tasks: sort(buckets.done) },
  ].filter((group) => group.tasks.length > 0)
}
</script>
