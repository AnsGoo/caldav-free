<template>
  <div class="tw-root" :data-theme="theme">
    <aside class="tw-rail">
      <button class="tw-rail-brand" title="任务" @click="sidebarOpen = !sidebarOpen">
        <svg viewBox="0 0 32 32" width="26" height="26" aria-hidden="true">
          <rect x="2" y="2" width="28" height="28" rx="9" fill="currentColor" />
          <path d="m9.5 16.5 4.2 4.3 8.8-9.6" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </button>
      <nav class="tw-rail-nav">
        <button class="tw-rail-button" :class="{ active: mode === 'list' }" title="清单" @click="switchMode('list')">
          <TaskIcon name="list" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: mode === 'board' }" title="看板" @click="switchMode('board')">
          <TaskIcon name="board" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: mode === 'calendar' }" title="日历" @click="switchMode('calendar')">
          <TaskIcon name="calendar" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: searchOpen }" title="搜索" @click="toggleSearch">
          <TaskIcon name="search" :size="21" />
        </button>
      </nav>
      <div class="tw-rail-foot">
        <button class="tw-rail-button" :title="theme === 'dark' ? '切换到浅色' : '切换到深色'" @click="toggleTheme">
          <TaskIcon :name="theme === 'dark' ? 'sun' : 'moon'" :size="20" />
        </button>
        <router-link class="tw-rail-button" to="/" title="管理后台">
          <TaskIcon name="settings" :size="20" />
        </router-link>
      </div>
    </aside>

    <TaskSidebar
      :lists="lists"
      :counts="counts"
      :view="view"
      :active-list-id="activeListId"
      :tags="tags"
      :active-tag="activeTag"
      :user-name="auth.user?.username || ''"
      :display-name="auth.user?.displayName || ''"
      :open="sidebarOpen"
      @select-view="selectView"
      @select-list="selectList"
      @create-list="createList"
      @edit-list="openEditList"
      @delete-list="confirmDeleteList"
      @select-tag="selectTag"
      @close="sidebarOpen = false"
      @logout="handleLogout"
    />

    <div v-if="sidebarOpen" class="tw-scrim" @click="sidebarOpen = false" />

    <main class="tw-main">
      <header class="tw-toolbar">
        <button class="tw-icon-button tw-menu-button" title="打开侧栏" @click="sidebarOpen = true">
          <TaskIcon name="list" :size="20" />
        </button>
        <div class="tw-heading">
          <span class="tw-heading-icon"><TaskIcon :name="headingIcon" :size="19" /></span>
          <h1>{{ heading }}</h1>
          <span v-if="openInView" class="tw-heading-count">{{ openInView }}</span>
        </div>
        <div class="tw-toolbar-actions">
          <div class="tw-mode-switch" role="group" aria-label="视图模式">
            <button :class="{ active: mode === 'list' }" title="清单" @click="switchMode('list')">
              <TaskIcon name="list" :size="16" />
            </button>
            <button :class="{ active: mode === 'board' }" title="看板" @click="switchMode('board')">
              <TaskIcon name="board" :size="16" />
            </button>
            <button :class="{ active: mode === 'calendar' }" title="日历" @click="switchMode('calendar')">
              <TaskIcon name="calendar" :size="16" />
            </button>
          </div>
          <button class="tw-icon-button" title="搜索" @click="toggleSearch">
            <TaskIcon name="search" :size="18" />
          </button>
        </div>
      </header>

      <div v-if="searchOpen" class="tw-search-bar">
        <TaskIcon name="search" :size="17" />
        <input
          ref="searchInputEl"
          v-model="searchInput"
          class="tw-search-input"
          placeholder="搜索任务标题与备注"
          @keydown.esc="closeSearch"
        />
        <button class="tw-icon-button" title="关闭搜索" @click="closeSearch">
          <TaskIcon name="close" :size="15" />
        </button>
      </div>

      <div class="tw-scroll">
        <div class="tw-content">
          <div v-if="mode !== 'calendar'" class="tw-quick-add">
            <TaskIcon name="plus" :size="18" />
            <input
              ref="quickInputEl"
              v-model="quickText"
              class="tw-quick-input"
              :placeholder="`添加任务至“${quickTargetName}”`"
              maxlength="500"
              @keydown.enter="onQuickEnter"
            />
            <button v-if="quickText.trim()" class="tw-quick-submit" :disabled="quickBusy" @click="submitQuick">
              <TaskIcon name="check" :size="16" />
            </button>
          </div>

          <div v-if="hint && mode !== 'calendar'" class="tw-quick-hint">
            <span v-if="hint.date" class="tw-hint-chip">{{ hint.date }}</span>
            <span v-if="hint.time" class="tw-hint-chip">{{ hint.time }}</span>
            <span v-for="tag in hint.tags" :key="tag" class="tw-hint-chip">#{{ tag }}</span>
            <span v-if="hint.priority" class="tw-hint-chip">优先级 {{ hint.priority }}</span>
            <span class="tw-hint-tip">回车添加</span>
          </div>

          <div v-if="loading" class="tw-loading">
            <a-spin />
          </div>

          <template v-else-if="mode === 'list'">
            <section v-for="group in groups" :key="group.key" class="tw-group">
              <header class="tw-group-head" @click="toggleGroup(group.key)">
                <span class="tw-group-caret" :class="{ collapsed: collapsed.has(group.key) }">
                  <TaskIcon name="chevron" :size="13" />
                </span>
                <span class="tw-group-title" :class="`tone-${group.tone || 'normal'}`">{{ group.label }}</span>
                <span class="tw-group-count">{{ group.tasks.length }}</span>
                <button
                  v-if="group.key === 'overdue'"
                  class="tw-group-action"
                  @click.stop="postponeOverdue"
                >
                  顺延到今天
                </button>
              </header>
              <div v-show="!collapsed.has(group.key)" class="tw-group-body">
                <TaskRow
                  v-for="task in group.tasks"
                  :key="task.id"
                  :task="task"
                  :selected="selectedId === task.id"
                  :show-list="!activeListId"
                  @toggle="toggleTask"
                  @open="openTask"
                  @remove="confirmRemoveTask"
                />
              </div>
            </section>

            <div v-if="!tasks.length" class="tw-empty">
              <div class="tw-empty-art">
                <svg viewBox="0 0 96 96" width="96" height="96" aria-hidden="true">
                  <rect x="14" y="12" width="68" height="72" rx="14" fill="none" stroke="currentColor" stroke-width="2" />
                  <path d="M28 34h28M28 48h22M28 62h30" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
                  <circle cx="68" cy="24" r="10" fill="var(--tw-accent)" />
                  <path d="m63.5 24 3.2 3.2 6-6.4" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              </div>
              <h2>这里还没有任务</h2>
              <p>{{ emptyHint }}</p>
              <button class="tw-primary-button" @click="focusQuick">添加第一个任务</button>
            </div>
          </template>

          <TaskCalendar
            v-else-if="mode === 'calendar'"
            :tasks="filteredTasks"
            :cursor="cursor"
            @open="openTask"
            @create="createFromCalendar"
            @prev="shiftMonth(-1)"
            @next="shiftMonth(1)"
            @today="cursor = new Date()"
          />

          <template v-else>
            <div class="tw-board">
              <section
                v-for="column in boardColumns"
                :key="column.list.id"
                class="tw-board-column"
                @dragover.prevent
                @drop="dropOnList(column.list.id)"
              >
                <header class="tw-board-head">
                  <span class="tw-list-dot" :style="{ background: column.list.color || '#4772fa' }" />
                  <strong>{{ column.list.name }}</strong>
                  <span class="tw-board-count">{{ column.tasks.length }}</span>
                  <button class="tw-icon-button" title="在此清单添加任务" @click="addToColumn(column.list.id)">
                    <TaskIcon name="plus" :size="15" />
                  </button>
                </header>
                <div class="tw-board-body">
                  <article
                    v-for="task in column.tasks"
                    :key="task.id"
                    class="tw-board-card"
                    :class="{ done: task.completed }"
                    draggable="true"
                    @dragstart="dragId = task.id"
                    @dragend="dragId = 0"
                    @click="openTask(task)"
                  >
                    <div class="tw-board-card-head">
                      <span v-if="task.priority" class="tw-priority-dot" :style="{ background: priorityColor(task.priority) }" />
                      <span class="tw-board-card-title">{{ task.title }}</span>
                    </div>
                    <div v-if="task.tags.length || task.due" class="tw-board-card-meta">
                      <span v-for="tag in task.tags.slice(0, 2)" :key="tag">#{{ tag }}</span>
                      <span v-if="task.due">{{ formatDue(task) }}</span>
                    </div>
                    <button class="tw-board-check" :class="{ checked: task.completed }" @click.stop="toggleTask(task)">
                      <TaskIcon name="check" :size="12" />
                    </button>
                  </article>
                  <p v-if="!column.tasks.length" class="tw-board-empty">拖动任务到这里，或点击 + 新建</p>
                </div>
              </section>
            </div>
          </template>
        </div>
      </div>
    </main>

    <TaskDetail
      v-if="selectedTask"
      :task="selectedTask"
      :lists="lists"
      @close="selectedId = 0"
      @changed="onTaskChanged"
      @deleted="onTaskDeleted"
      @remove="confirmRemoveTask"
    />

    <div v-if="editVisible" class="tw-dialog-scrim" @click.self="editVisible = false">
      <div class="tw-dialog" role="dialog" aria-modal="true" aria-label="编辑清单" @keydown.esc="editVisible = false">
        <header class="tw-dialog-head">
          <h2>编辑清单</h2>
          <button class="tw-icon-button" title="关闭" @click="editVisible = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body">
          <label class="tw-modal-label">
            名称
            <input
              ref="editNameInput"
              v-model="editForm.name"
              class="tw-dialog-input"
              maxlength="40"
              placeholder="清单名称"
              @keydown.enter="saveList"
            />
          </label>
          <div class="tw-modal-label">
            颜色
            <div class="tw-color-row">
              <button
                v-for="color in LIST_COLORS"
                :key="color"
                class="tw-color-swatch"
                :class="{ active: editForm.color === color }"
                :style="{ background: color }"
                @click="editForm.color = color"
              />
            </div>
          </div>
          <p class="tw-modal-note">删除清单会把其中的任务移动到收集箱。</p>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="editVisible = false">取消</button>
          <button class="tw-dialog-ok" :disabled="editBusy" @click="saveList">{{ editBusy ? '保存中…' : '保存' }}</button>
        </footer>
      </div>
    </div>

    <div v-if="confirmDialog.open" class="tw-dialog-scrim" @click.self="closeConfirm">
      <div class="tw-dialog tw-dialog-sm" role="alertdialog" aria-modal="true" @keydown.esc="closeConfirm">
        <header class="tw-dialog-head">
          <h2>{{ confirmDialog.title }}</h2>
          <button class="tw-icon-button" title="关闭" @click="closeConfirm">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body">
          <p class="tw-dialog-message">{{ confirmDialog.message }}</p>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="closeConfirm">取消</button>
          <button class="tw-dialog-ok tw-dialog-danger" :disabled="confirmBusy" @click="runConfirm">
            {{ confirmBusy ? '处理中…' : '删除' }}
          </button>
        </footer>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Message } from '@arco-design/web-vue'
import { auth, logout } from '../auth'
import type { TaskCounts, TaskItem, TaskList, TaskWorkspaceData } from '../types'
import { createTask, createTaskList, deleteTask, deleteTaskList, fetchTaskWorkspace, updateTask, updateTaskList, type TaskView } from '../tasks-api'
import {
  LIST_COLORS,
  PRIORITIES,
  dayKey,
  formatDue,
  groupTasks,
  isOverdue,
  quickHint,
  startOfToday,
} from '../tasks-utils'
import TaskSidebar from '../components/tasks/TaskSidebar.vue'
import TaskRow from '../components/tasks/TaskRow.vue'
import TaskDetail from '../components/tasks/TaskDetail.vue'
import TaskCalendar from '../components/tasks/TaskCalendar.vue'
import TaskIcon from '../components/tasks/TaskIcon.vue'

type Mode = 'list' | 'board' | 'calendar'

const route = useRoute()
const router = useRouter()

const lists = ref<TaskList[]>([])
const tasks = ref<TaskItem[]>([])
const tags = ref<string[]>([])
const counts = reactive<TaskCounts>({ all: 0, today: 0, next7: 0, inbox: 0, completed: 0 })
const inboxId = ref(0)

const view = ref<TaskView>('all')
const activeListId = ref(0)
const activeTag = ref('')
const mode = ref<Mode>('list')
const query = ref('')
const searchOpen = ref(false)
const searchInput = ref('')
const selectedId = ref(0)
const loading = ref(true)
const sidebarOpen = ref(false)
const quickText = ref('')
const quickBusy = ref(false)
const quickListId = ref(0)
const cursor = ref(new Date())
const theme = ref<'dark' | 'light'>('dark')
const collapsed = ref(new Set<string>())
const dragId = ref(0)

const quickInputEl = ref<HTMLInputElement | null>(null)
const searchInputEl = ref<HTMLInputElement | null>(null)
const editNameInput = ref<HTMLInputElement | null>(null)

const editVisible = ref(false)
const editBusy = ref(false)
const editForm = reactive({ id: 0, name: '', color: LIST_COLORS[0] })
const confirmBusy = ref(false)
const confirmDialog = reactive<{ open: boolean; title: string; message: string; action: (() => Promise<void> | void) | null }>({
  open: false,
  title: '',
  message: '',
  action: null,
})

let searchTimer: ReturnType<typeof setTimeout> | undefined
let initialized = false
let refreshTimer: ReturnType<typeof setTimeout> | undefined

const smartLabels: Record<string, string> = {
  all: '所有',
  today: '今天',
  next7: '最近 7 天',
  inbox: '收集箱',
  completed: '已完成',
  list: '清单',
}

const heading = computed(() => {
  if (view.value === 'list') {
    const list = lists.value.find((item) => item.id === activeListId.value)
    return list?.name || '清单'
  }
  return smartLabels[view.value] || '任务'
})

const headingIcon = computed(() => {
  if (view.value === 'list') return 'inbox'
  if (view.value === 'today') return 'today'
  if (view.value === 'next7') return 'next7'
  if (view.value === 'inbox') return 'inbox'
  if (view.value === 'completed') return 'check'
  return 'list'
})

const filteredTasks = computed(() => {
  if (!activeTag.value) return tasks.value
  return tasks.value.filter((task) => task.tags.includes(activeTag.value))
})

const openInView = computed(() => filteredTasks.value.filter((task) => !task.completed).length)
const groups = computed(() => groupTasks(filteredTasks.value, view.value))
const selectedTask = computed(() => tasks.value.find((task) => task.id === selectedId.value))

const quickTargetList = computed(() => {
  const id = quickListId.value || (view.value === 'list' || view.value === 'inbox' ? activeListId.value : inboxId.value) || inboxId.value
  return lists.value.find((list) => list.id === id)
})
const quickTargetName = computed(() => quickTargetList.value?.name || '收集箱')
const hint = computed(() => quickHint(quickText.value))

const emptyHint = computed(() => {
  if (query.value) return `没有找到“${query.value}”相关的任务。`
  if (activeTag.value) return `还没有带 #${activeTag.value} 标签的任务。`
  return '按 N 或点击上方输入框，快速记下一件事。'
})

const boardColumns = computed(() => {
  const base = view.value === 'completed' ? filteredTasks.value.filter((task) => task.completed) : filteredTasks.value.filter((task) => !task.completed)
  return lists.value.map((list) => ({
    list,
    tasks: base.filter((task) => task.listId === list.id),
  }))
})

function priorityColor(priority: number) {
  return PRIORITIES.find((item) => item.value === priority)?.color || '#4772fa'
}

async function loadWorkspace(silent = false) {
  if (!silent) loading.value = true
  try {
    const data: TaskWorkspaceData = await fetchTaskWorkspace({
      view: view.value,
      listId: activeListId.value || undefined,
      q: query.value || undefined,
    })
    lists.value = data.lists
    tasks.value = data.tasks
    tags.value = data.tags
    inboxId.value = data.inbox
    Object.assign(counts, data.counts)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载任务失败')
  } finally {
    loading.value = false
  }
}

function scheduleRefresh() {
  if (refreshTimer) clearTimeout(refreshTimer)
  refreshTimer = setTimeout(() => {
    void loadWorkspace(true)
  }, 250)
}

function syncURL() {
  const next: Record<string, string> = { view: view.value }
  if (view.value === 'list' && activeListId.value) next.list = String(activeListId.value)
  if (mode.value !== 'list') next.mode = mode.value
  if (selectedId.value) next.task = String(selectedId.value)
  if (query.value) next.q = query.value
  const current = route.query
  const same = Object.keys(next).every((key) => current[key] === next[key]) && Object.keys(current).length === Object.keys(next).length
  if (!same) void router.replace({ path: '/tasks', query: next })
}

function selectView(nextView: string) {
  view.value = nextView as TaskView
  activeListId.value = 0
  activeTag.value = ''
  selectedId.value = 0
  sidebarOpen.value = false
  syncURL()
}

function selectList(id: number) {
  view.value = 'list'
  activeListId.value = id
  activeTag.value = ''
  selectedId.value = 0
  sidebarOpen.value = false
  syncURL()
}

function selectTag(tag: string) {
  activeTag.value = tag
  sidebarOpen.value = false
}

function switchMode(next: Mode) {
  mode.value = next
  if (next === 'calendar') {
    cursor.value = new Date()
  }
  syncURL()
}

function toggleGroup(key: string) {
  const next = new Set(collapsed.value)
  if (next.has(key)) next.delete(key)
  else next.add(key)
  collapsed.value = next
  try {
    localStorage.setItem('caldav-task-collapsed', JSON.stringify([...next]))
  } catch {
    /* ignore */
  }
}

function openTask(task: TaskItem) {
  selectedId.value = task.id
  syncURL()
}

async function toggleTask(task: TaskItem) {
  const target = !task.completed
  task.completed = target
  try {
    const { task: updated } = await updateTask(task.id, { completed: target })
    replaceTask(updated)
    scheduleRefresh()
  } catch (error) {
    task.completed = !target
    Message.error(error instanceof Error ? error.message : '更新任务失败')
  }
}

function onQuickEnter(event: KeyboardEvent) {
  if (event.isComposing) return
  event.preventDefault()
  void submitQuick()
}

async function submitQuick() {
  const text = quickText.value.trim()
  if (!text || quickBusy.value) return
  quickBusy.value = true
  try {
    const { task } = await createTask({ text, listId: quickTargetList.value?.id })
    quickText.value = ''
    quickListId.value = 0
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建任务失败')
  } finally {
    quickBusy.value = false
    quickInputEl.value?.focus()
  }
}

function createFromCalendar(payload: { date: string; title: string }) {
  void (async () => {
    try {
      const { task } = await createTask({
        title: payload.title,
        listId: quickTargetList.value?.id,
        due: `${payload.date}T00:00:00`,
        allDay: true,
      })
      await loadWorkspace(true)
      selectedId.value = task.id
    } catch (error) {
      Message.error(error instanceof Error ? error.message : '创建任务失败')
    }
  })()
}

function addToColumn(listId: number) {
  quickListId.value = listId
  quickInputEl.value?.scrollIntoView({ block: 'center', behavior: 'smooth' })
  quickInputEl.value?.focus()
}

function focusQuick() {
  mode.value = 'list'
  requestAnimationFrame(() => quickInputEl.value?.focus())
}

async function createList(name: string) {
  try {
    const color = LIST_COLORS[lists.value.length % LIST_COLORS.length]
    await createTaskList(name, color)
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建清单失败')
  }
}

function openEditList(list: TaskList) {
  editForm.id = list.id
  editForm.name = list.name
  editForm.color = list.color || LIST_COLORS[0]
  editVisible.value = true
  requestAnimationFrame(() => editNameInput.value?.focus())
}

async function saveList() {
  const name = editForm.name.trim()
  if (!name) {
    Message.warning('清单名称不能为空')
    return
  }
  editBusy.value = true
  try {
    await updateTaskList(editForm.id, { name, color: editForm.color })
    editVisible.value = false
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存清单失败')
  } finally {
    editBusy.value = false
  }
}

function askConfirm(title: string, message: string, action: () => Promise<void> | void) {
  confirmDialog.title = title
  confirmDialog.message = message
  confirmDialog.action = action
  confirmDialog.open = true
}

function closeConfirm() {
  confirmDialog.open = false
  confirmDialog.action = null
  confirmBusy.value = false
}

async function runConfirm() {
  if (!confirmDialog.action) return
  confirmBusy.value = true
  try {
    await confirmDialog.action()
    closeConfirm()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '操作失败')
    confirmBusy.value = false
  }
}

function confirmDeleteList(list: TaskList) {
  askConfirm('删除清单', `确定删除「${list.name}」吗？其中的任务会移动到收集箱。`, async () => {
    await deleteTaskList(list.id)
    if (activeListId.value === list.id) selectView('all')
    await loadWorkspace(true)
  })
}

function replaceTask(updated: TaskItem) {
  const index = tasks.value.findIndex((task) => task.id === updated.id)
  if (index >= 0) tasks.value[index] = updated
}

function onTaskChanged(updated: TaskItem) {
  replaceTask(updated)
  scheduleRefresh()
}

function onTaskDeleted(id: number) {
  tasks.value = tasks.value.filter((task) => task.id !== id)
  if (selectedId.value === id) selectedId.value = 0
  scheduleRefresh()
}

function confirmRemoveTask(task: TaskItem) {
  askConfirm('删除任务', `确定删除「${task.title}」吗？`, async () => {
    await deleteTask(task.id)
    onTaskDeleted(task.id)
  })
}

async function postponeOverdue() {
  const overdue = filteredTasks.value.filter((task) => !task.completed && isOverdue(task))
  if (!overdue.length) return
  const today = dayKey(startOfToday())
  const now = Date.now()
  try {
    await Promise.all(
      overdue.map((task) => {
        if (task.allDay) return updateTask(task.id, { due: `${today}T00:00:00`, allDay: true })
        const original = new Date(task.due as string)
        let due = new Date(`${today}T${String(original.getHours()).padStart(2, '0')}:${String(original.getMinutes()).padStart(2, '0')}:00`)
        // A time that already passed today would stay overdue; move it to the
        // end of the day so "顺延到今天" actually clears the overdue group.
        if (due.getTime() <= now) {
          due = new Date(`${today}T23:59:00`)
        }
        return updateTask(task.id, { due: due.toISOString() })
      }),
    )
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '顺延失败')
  }
}

function dropOnList(listId: number) {
  const id = dragId.value
  dragId.value = 0
  if (!id) return
  const task = tasks.value.find((item) => item.id === id)
  if (!task || task.listId === listId) return
  const previous = task.listId
  task.listId = listId
  void updateTask(id, { listId }).then(({ task: updated }) => {
    replaceTask(updated)
    scheduleRefresh()
  }).catch((error) => {
    task.listId = previous
    Message.error(error instanceof Error ? error.message : '移动任务失败')
  })
}

function shiftMonth(delta: number) {
  cursor.value = new Date(cursor.value.getFullYear(), cursor.value.getMonth() + delta, 1)
}

function toggleSearch() {
  searchOpen.value = !searchOpen.value
  if (searchOpen.value) {
    requestAnimationFrame(() => searchInputEl.value?.focus())
  } else {
    closeSearch()
  }
}

function closeSearch() {
  searchOpen.value = false
  searchInput.value = ''
  query.value = ''
  syncURL()
}

function applyTheme(next: 'dark' | 'light') {
  theme.value = next
  try {
    localStorage.setItem('caldav-task-theme', next)
  } catch {
    /* ignore */
  }
}

function toggleTheme() {
  applyTheme(theme.value === 'dark' ? 'light' : 'dark')
}

async function handleLogout() {
  try {
    await logout()
    void router.push('/login')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '退出失败')
  }
}

function onKeydown(event: KeyboardEvent) {
  const target = event.target as HTMLElement | null
  const typing = target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable)
  if (typing) return
  if (event.key === 'n' || event.key === 'N') {
    event.preventDefault()
    if (mode.value === 'calendar') mode.value = 'list'
    requestAnimationFrame(() => quickInputEl.value?.focus())
  }
  if (event.key === 'Escape') {
    selectedId.value = 0
  }
}

function hydrateFromRoute() {
  const q = route.query
  const nextView = typeof q.view === 'string' ? q.view : 'all'
  view.value = (['all', 'today', 'next7', 'inbox', 'completed', 'list'].includes(nextView) ? nextView : 'all') as TaskView
  const listId = typeof q.list === 'string' ? Number(q.list) : 0
  if (view.value === 'list' && listId) activeListId.value = listId
  else if (view.value === 'list') view.value = 'all'
  const nextMode = typeof q.mode === 'string' ? q.mode : 'list'
  mode.value = (['list', 'board', 'calendar'].includes(nextMode) ? nextMode : 'list') as Mode
  const taskId = typeof q.task === 'string' ? Number(q.task) : 0
  if (taskId) selectedId.value = taskId
  if (typeof q.q === 'string') {
    query.value = q.q
    searchInput.value = q.q
    searchOpen.value = Boolean(q.q)
  }
}

onMounted(async () => {
  try {
    const stored = localStorage.getItem('caldav-task-theme')
    if (stored === 'dark' || stored === 'light') theme.value = stored
    else theme.value = window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
    const collapsedRaw = localStorage.getItem('caldav-task-collapsed')
    if (collapsedRaw) collapsed.value = new Set(JSON.parse(collapsedRaw) as string[])
  } catch {
    /* ignore */
  }
  hydrateFromRoute()
  await loadWorkspace()
  initialized = true
  window.addEventListener('keydown', onKeydown)
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeydown)
  if (searchTimer) clearTimeout(searchTimer)
  if (refreshTimer) clearTimeout(refreshTimer)
})

watch([view, activeListId, query], () => {
  if (!initialized) return
  void loadWorkspace()
})

watch(selectedId, () => {
  if (initialized) syncURL()
})

watch(searchInput, (value) => {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(() => {
    query.value = value.trim()
    syncURL()
  }, 250)
})
</script>
