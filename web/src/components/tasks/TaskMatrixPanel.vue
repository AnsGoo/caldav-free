<template>
  <section class="tw-matrix">
    <header class="tw-matrix-head">
      <div>
        <h2>四象限</h2>
        <p>按优先级分组 · 重要且紧急 / 重要不紧急 / 不重要但紧急 / 不重要不紧急</p>
      </div>
      <span class="tw-matrix-total">{{ tasks.length }} 项</span>
    </header>

    <div class="tw-matrix-grid">
      <article
        v-for="quadrant in quadrants"
        :key="quadrant.id"
        class="tw-matrix-card"
        :style="{ '--matrix-color': quadrant.color }"
      >
        <header class="tw-matrix-card-head">
          <span class="tw-matrix-icon">
            <i /><i /><i /><i />
          </span>
          <strong>{{ quadrant.label }}</strong>
          <span class="tw-matrix-count">{{ quadrant.tasks.length }}</span>
        </header>

        <div v-if="quadrant.tasks.length" class="tw-matrix-body">
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
        <div v-else class="tw-matrix-empty">没有任务</div>
      </article>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { TaskItem } from '../../types'
import { dayKey, formatDue, isOverdue, recurrenceLabel, startOfToday } from '../../tasks-utils'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ tasks: TaskItem[] }>()
defineEmits<{
  (event: 'open', task: TaskItem): void
  (event: 'toggle', task: TaskItem): void
}>()

const quadrants = computed(() => {
  const buckets: Record<string, TaskItem[]> = { q1: [], q2: [], q3: [], q4: [] }
  for (const task of props.tasks) {
    const priority = task.priority > 3 || task.priority < 0 ? 0 : task.priority
    const key = priority === 3 ? 'q1' : priority === 2 ? 'q2' : priority === 1 ? 'q3' : 'q4'
    buckets[key].push(task)
  }
  return [
    { id: 'q1', label: '重要且紧急', color: '#ff5f68', tasks: buckets.q1, groups: group(buckets.q1) },
    { id: 'q2', label: '重要不紧急', color: '#ffb000', tasks: buckets.q2, groups: group(buckets.q2) },
    { id: 'q3', label: '不重要但紧急', color: '#4772fa', tasks: buckets.q3, groups: group(buckets.q3) },
    { id: 'q4', label: '不重要不紧急', color: '#0cce9c', tasks: buckets.q4, groups: group(buckets.q4) },
  ]
})

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
