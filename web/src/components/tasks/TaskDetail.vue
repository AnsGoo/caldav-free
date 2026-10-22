<template>
  <section class="tw-detail">
    <header class="tw-detail-head">
      <label class="tw-detail-list">
        <i :style="{ background: currentList?.color || '#4772fa' }" />
        <select v-model.number="draft.listId" @change="save">
          <option v-for="list in lists" :key="list.id" :value="list.id">{{ list.name }}</option>
        </select>
      </label>
      <div class="tw-detail-head-actions">
        <span class="tw-save-state">{{ saving ? '保存中…' : saved ? '已保存' : '' }}</span>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="18" />
        </button>
      </div>
    </header>

    <div class="tw-detail-scroll">
      <div class="tw-detail-title-row">
        <button
          class="tw-check tw-check-lg"
          :class="{ checked: draft.completed }"
          :aria-label="draft.completed ? '标记为未完成' : '标记为完成'"
          @click="toggleCompleted"
        >
          <svg v-if="draft.completed" viewBox="0 0 20 20" width="14" height="14" aria-hidden="true">
            <path d="m4.5 10.2 3.6 3.7 7.4-8" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </button>
        <textarea
          ref="titleEl"
          v-model="draft.title"
          class="tw-detail-title"
          rows="1"
          maxlength="500"
          placeholder="任务标题"
          @input="growTitle"
        />
      </div>

      <div class="tw-pill-row">
        <button class="tw-pill" :class="{ 'is-overdue': dueOverdue }" @click="dateOpen = !dateOpen">
          <TaskIcon name="calendar" :size="14" />
          {{ dueLabel || '设置日期' }}
        </button>
        <span v-if="draft.priority" class="tw-pill" :style="{ color: priorityMeta?.color }">
          <TaskIcon name="flag" :size="14" />
          {{ priorityMeta?.short }}优先级
        </span>
        <span v-if="draft.tags.length" class="tw-pill">
          <TaskIcon name="tag" :size="14" />
          {{ draft.tags.length }} 个标签
        </span>
      </div>

      <div v-if="dateOpen" class="tw-date-panel">
        <input v-model="draft.dueDate" type="date" class="tw-date-input" @change="save" />
        <input v-model="draft.dueTime" type="time" class="tw-date-input" :disabled="draft.allDay" @change="save" />
        <label class="tw-check-label">
          <input v-model="draft.allDay" type="checkbox" @change="save" />
          全天
        </label>
        <div class="tw-date-quick">
          <button type="button" @click="setDueDate(0)">今天</button>
          <button type="button" @click="setDueDate(1)">明天</button>
          <button type="button" @click="setDueDate(7)">下周</button>
          <button type="button" @click="clearDue">清除</button>
        </div>
      </div>

      <textarea
        v-model="draft.notes"
        class="tw-notes"
        rows="3"
        placeholder="输入内容或使用 / 快速插入"
      />

      <section class="tw-checklists">
        <header class="tw-detail-section-head">
          <span>子任务</span>
          <small v-if="draft.checklist.length">{{ doneCount }}/{{ draft.checklist.length }}</small>
        </header>
        <div class="tw-checklist">
          <div v-for="(item, index) in draft.checklist" :key="item.id" class="tw-checklist-item">
            <button
              class="tw-check tw-check-sm"
              :class="{ checked: item.done }"
              :aria-label="item.done ? '标记为未完成' : '标记为完成'"
              @click="toggleChecklist(index)"
            >
              <svg v-if="item.done" viewBox="0 0 20 20" width="10" height="10" aria-hidden="true">
                <path d="m4.5 10.2 3.6 3.7 7.4-8" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </button>
            <input
              v-model="item.title"
              class="tw-checklist-input"
              :class="{ done: item.done }"
              maxlength="300"
              @keydown.enter="onChecklistEnter"
            />
            <button class="tw-icon-button tw-checklist-remove" title="删除子任务" @click="removeChecklist(index)">
              <TaskIcon name="close" :size="14" />
            </button>
          </div>
        </div>
        <button class="tw-add-subtask" @click="addChecklist">
          <TaskIcon name="plus" :size="14" />
          添加子任务
        </button>
      </section>

      <section class="tw-detail-section">
        <header class="tw-detail-section-head"><span>标签</span></header>
        <div class="tw-detail-tags">
          <span v-for="tag in draft.tags" :key="tag" class="tw-detail-tag" @click="removeTag(tag)">
            #{{ tag }}
            <TaskIcon name="close" :size="11" />
          </span>
          <input
            v-model="tagInput"
            class="tw-tag-input"
            placeholder="+ 添加标签"
            maxlength="30"
            @keydown.enter="onTagEnter"
            @blur="addTag"
          />
        </div>
      </section>

      <section class="tw-detail-section">
        <header class="tw-detail-section-head"><span>优先级</span></header>
        <div class="tw-priority-row">
          <button
            v-for="item in PRIORITIES"
            :key="item.value"
            class="tw-priority-button"
            :class="{ active: draft.priority === item.value }"
            :style="draft.priority === item.value ? { color: item.color, borderColor: item.color } : undefined"
            @click="setPriority(item.value)"
          >
            <TaskIcon name="flag" :size="14" />
            {{ item.short }}
          </button>
          <button class="tw-priority-button" :class="{ active: draft.priority === 0 }" @click="setPriority(0)">
            无
          </button>
        </div>
      </section>

      <p class="tw-detail-meta">
        创建于 {{ formatMoment(task.createdAt) }}
        <template v-if="task.completedAt"> · 完成于 {{ formatMoment(task.completedAt) }}</template>
      </p>
    </div>

    <footer class="tw-detail-foot">
      <button class="tw-danger-link" @click="$emit('remove', task)">
        <TaskIcon name="trash" :size="14" />
        删除任务
      </button>
      <span class="tw-foot-hint">自动保存 · 同步 CalDAV</span>
    </footer>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, reactive, ref, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { ChecklistItem, TaskItem, TaskList } from '../../types'
import { PRIORITIES, addDays, dayKey, formatDue, startOfToday, toDateInput } from '../../tasks-utils'
import { updateTask } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ task: TaskItem; lists: TaskList[] }>()
const emit = defineEmits<{
  (event: 'close'): void
  (event: 'changed', task: TaskItem): void
  (event: 'deleted', id: number): void
  (event: 'remove', task: TaskItem): void
}>()

interface Draft {
  title: string
  notes: string
  listId: number
  priority: number
  dueDate: string
  dueTime: string
  allDay: boolean
  completed: boolean
  tags: string[]
  checklist: ChecklistItem[]
}

const draft = reactive<Draft>({
  title: '',
  notes: '',
  listId: 0,
  priority: 0,
  dueDate: '',
  dueTime: '',
  allDay: false,
  completed: false,
  tags: [],
  checklist: [],
})

const titleEl = ref<HTMLTextAreaElement | null>(null)
const dateOpen = ref(false)
const tagInput = ref('')
const saving = ref(false)
const saved = ref(false)
let hydrating = true
let saveTimer: ReturnType<typeof setTimeout> | undefined

const currentList = computed(() => props.lists.find((list) => list.id === draft.listId))
const priorityMeta = computed(() => PRIORITIES.find((item) => item.value === draft.priority))
const doneCount = computed(() => draft.checklist.filter((item) => item.done).length)

function hydrate() {
  hydrating = true
  dateOpen.value = false
  draft.title = props.task.title
  draft.notes = props.task.notes
  draft.listId = props.task.listId
  draft.priority = props.task.priority
  draft.completed = props.task.completed
  draft.allDay = props.task.allDay
  draft.tags = [...props.task.tags]
  draft.checklist = props.task.checklist.map((item) => ({ ...item }))
  const input = toDateInput(props.task)
  if (input) {
    const [datePart, timePart] = input.split('T')
    draft.dueDate = datePart
    draft.dueTime = props.task.allDay ? '09:00' : timePart || '09:00'
  } else {
    draft.dueDate = ''
    draft.dueTime = '09:00'
  }
  saved.value = false
  nextTick(() => {
    growTitle()
    hydrating = false
  })
}

watch(() => props.task.id, hydrate, { immediate: true })

watch(
  draft,
  () => {
    if (hydrating) return
    scheduleSave()
  },
  { deep: true },
)

function scheduleSave() {
  if (saveTimer) clearTimeout(saveTimer)
  saveTimer = setTimeout(() => {
    void save()
  }, 500)
}

function duePayload() {
  if (!draft.dueDate) return ''
  if (draft.allDay) return `${draft.dueDate}T00:00:00`
  return `${draft.dueDate}T${draft.dueTime || '09:00'}:00`
}

const dueLabel = computed(() => {
  if (!draft.dueDate) return ''
  const view: TaskItem = {
    ...props.task,
    due: duePayload() || undefined,
    allDay: draft.allDay,
  }
  return formatDue(view)
})

const dueOverdue = computed(() => {
  if (!draft.dueDate || draft.completed) return false
  const due = draft.allDay
    ? new Date(`${draft.dueDate}T23:59:59`)
    : new Date(`${draft.dueDate}T${draft.dueTime || '09:00'}:00`)
  return due.getTime() < Date.now()
})

function growTitle() {
  const el = titleEl.value
  if (!el) return
  el.style.height = 'auto'
  el.style.height = `${el.scrollHeight}px`
}

async function save() {
  if (saving.value) {
    scheduleSave()
    return
  }
  const title = draft.title.trim()
  if (!title) return
  saving.value = true
  saved.value = false
  try {
    const { task } = await updateTask(props.task.id, {
      title,
      notes: draft.notes,
      listId: draft.listId,
      priority: draft.priority,
      due: duePayload(),
      allDay: draft.allDay,
      completed: draft.completed,
      tags: draft.tags,
      checklist: draft.checklist.filter((item) => item.title.trim() !== ''),
    })
    emit('changed', task)
    saved.value = true
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存失败')
  } finally {
    saving.value = false
  }
}

function toggleCompleted() {
  draft.completed = !draft.completed
  void save()
}

function setDueDate(days: number) {
  const target = addDays(startOfToday(), days)
  draft.dueDate = dayKey(target)
  if (!draft.dueTime) draft.dueTime = '09:00'
  void save()
}

function clearDue() {
  draft.dueDate = ''
  void save()
}

function onChecklistEnter(event: KeyboardEvent) {
  if (event.isComposing) return
  event.preventDefault()
  addChecklist()
}

function onTagEnter(event: KeyboardEvent) {
  if (event.isComposing) return
  event.preventDefault()
  addTag()
}

function addChecklist() {
  draft.checklist.push({
    id: `c${Date.now()}${Math.random().toString(36).slice(2, 6)}`,
    title: '',
    done: false,
  })
  nextTick(() => {
    const inputs = document.querySelectorAll<HTMLInputElement>('.tw-checklist-input')
    inputs[inputs.length - 1]?.focus()
  })
}

function toggleChecklist(index: number) {
  const item = draft.checklist[index]
  if (!item) return
  item.done = !item.done
  void save()
}

function removeChecklist(index: number) {
  draft.checklist.splice(index, 1)
  void save()
}

function addTag() {
  const tag = tagInput.value.replace(/^#/, '').trim()
  if (!tag) return
  if (!draft.tags.includes(tag)) draft.tags.push(tag)
  tagInput.value = ''
  void save()
}

function removeTag(tag: string) {
  draft.tags = draft.tags.filter((item) => item !== tag)
  void save()
}

function setPriority(priority: number) {
  draft.priority = priority
  void save()
}

function formatMoment(value: string) {
  const date = new Date(value)
  const pad = (item: number) => String(item).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`
}


// Keep the checkbox state in sync when the list row toggles completion.
watch(
  () => props.task.completed,
  (value) => {
    if (!hydrating && draft.completed !== value) draft.completed = value
  },
)

onBeforeUnmount(() => {
  if (saveTimer) clearTimeout(saveTimer)
  void save()
})
</script>
