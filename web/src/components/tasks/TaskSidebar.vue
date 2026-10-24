<template>
  <aside class="tw-sidebar" :class="{ 'is-open': open }">
    <div class="tw-brand">
      <span class="tw-brand-mark">
        <svg viewBox="0 0 32 32" width="26" height="26" aria-hidden="true">
          <rect x="2" y="2" width="28" height="28" rx="9" fill="currentColor" />
          <path d="m9.5 16.5 4.2 4.3 8.8-9.6" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </span>
      <span class="tw-brand-name">我的任务</span>
      <button class="tw-icon-button tw-sidebar-close" aria-label="收起侧栏" @click="$emit('close')">
        <TaskIcon name="close" :size="18" />
      </button>
    </div>

    <div v-if="pinnedLists.length || pinnedFilters.length" class="tw-pinned-strip">
      <div v-for="list in pinnedLists" :key="`pinned-list-${list.id}`" class="tw-pinned-item-wrap">
        <button
          class="tw-pinned-item"
          :class="{ active: activeListId === list.id }"
          :title="`${list.name}（已置顶）`"
          @click="$emit('select-list', list.id)"
        >
          <span class="tw-pinned-dot" :style="{ background: list.color || '#4772fa' }" />
          <span class="tw-pinned-name">{{ list.name }}</span>
        </button>
        <button
          class="tw-pinned-unpin"
          title="取消置顶清单"
          aria-label="取消置顶清单"
          @click.stop="$emit('pin-list', list)"
        >
          <TaskIcon name="close" :size="11" />
        </button>
      </div>
      <div v-for="filter in pinnedFilters" :key="`pinned-filter-${filter.id}`" class="tw-pinned-item-wrap">
        <button
          class="tw-pinned-item"
          :class="{ active: activeFilterId === filter.id }"
          :title="`${filter.name}（已置顶）`"
          @click="$emit('select-filter', filter.id)"
        >
          <TaskIcon name="filter" :size="14" />
          <span class="tw-pinned-name">{{ filter.name }}</span>
        </button>
        <button
          class="tw-pinned-unpin"
          title="取消置顶过滤器"
          aria-label="取消置顶过滤器"
          @click.stop="$emit('pin-filter', filter)"
        >
          <TaskIcon name="close" :size="11" />
        </button>
      </div>
    </div>

    <nav class="tw-smart-nav">
      <button
        v-for="item in smartItems"
        :key="item.view"
        class="tw-nav-item"
        :class="{ active: view === item.view && !activeListId && !activeFilterId }"
        @click="$emit('select-view', item.view)"
      >
        <TaskIcon :name="item.icon" :size="18" />
        <span class="tw-nav-label">{{ item.label }}</span>
        <span v-if="item.count" class="tw-nav-count">{{ item.count }}</span>
      </button>
    </nav>

    <div class="tw-side-scroll">
      <section class="tw-side-section">
        <header class="tw-section-head">
          <span>笔记</span>
          <span class="tw-section-actions">
            <button class="tw-icon-button" aria-label="新建笔记清单" title="新建笔记清单" @click="startAddNoteList">
              <TaskIcon name="note" :size="16" />
            </button>
            <button class="tw-icon-button" aria-label="新建笔记" title="新建笔记" @click="$emit('create-note')">
              <TaskIcon name="plus" :size="16" />
            </button>
          </span>
        </header>

        <form v-if="addingNoteList" class="tw-new-list" @submit.prevent="submitNoteList">
          <input
            ref="noteNameInput"
            v-model="newNoteListName"
            class="tw-inline-input"
            maxlength="40"
            placeholder="笔记清单名称，回车创建"
            @keydown.enter.prevent="submitNoteList"
            @keydown.esc="cancelAddNoteList"
            @blur="maybeCancelNoteList"
          />
        </form>

        <ul v-if="customNoteLists.length" class="tw-list-nav">
          <li v-for="list in customNoteLists" :key="`note-${list.id}`">
            <button
              class="tw-nav-item tw-list-item tw-list-note-item"
              :class="{ active: activeListId === list.id }"
              @click="$emit('select-list', list.id)"
            >
              <span class="tw-note-list-mark"><TaskIcon name="note" :size="14" /></span>
              <span class="tw-nav-label">{{ list.name }}</span>
              <span v-if="list.count" class="tw-nav-count">{{ list.count }}</span>
            </button>
            <div class="tw-list-actions">
              <button
                class="tw-icon-button"
                :class="{ 'is-pinned': list.pinned }"
                :title="list.pinned ? '取消置顶笔记清单' : '置顶笔记清单'"
                @click.stop="$emit('pin-list', list)"
              >
                <TaskIcon name="pin" :size="14" />
              </button>
              <button class="tw-icon-button" title="编辑笔记清单" @click.stop="$emit('edit-list', list)">
                <TaskIcon name="edit" :size="14" />
              </button>
              <button class="tw-icon-button" title="删除笔记清单" @click.stop="$emit('delete-list', list)">
                <TaskIcon name="trash" :size="14" />
              </button>
            </div>
          </li>
        </ul>

        <template v-else-if="!hasNoteLists">
          <p class="tw-side-hint">新建笔记清单后，就可以开始记录想法和灵感。</p>
          <button class="tw-side-note-create" @click="startAddNoteList">
            <TaskIcon name="plus" :size="13" />
            新建笔记清单
          </button>
        </template>
      </section>

      <section class="tw-side-section">
        <header class="tw-section-head">
          <span>任务清单</span>
          <span class="tw-section-actions">
            <button class="tw-icon-button" aria-label="新建文件夹" title="新建文件夹" @click="$emit('create-folder')">
              <TaskIcon name="folder" :size="16" />
            </button>
            <button class="tw-icon-button" aria-label="新建任务清单" title="新建任务清单" @click="toggleAdd">
              <TaskIcon name="plus" :size="16" />
            </button>
          </span>
        </header>

        <form v-if="adding" class="tw-new-list" @submit.prevent="submitList">
          <input
            ref="nameInput"
            v-model="newListName"
            class="tw-inline-input"
            maxlength="40"
            placeholder="任务清单名称，回车创建"
            @keydown.enter.prevent="submitList"
            @keydown.esc="cancelAdd"
            @blur="maybeCancel"
          />
        </form>

        <ul class="tw-list-nav">
          <template v-for="row in listRows" :key="row.key">
            <li v-if="row.kind === 'folder'" class="tw-folder-row" draggable="true" @dragstart="startFolderDrag(row.folder!.id, $event)" @dragover.prevent @drop.prevent="dropFolder(row.folder!.id)" @dragend="endSidebarDrag">
              <button class="tw-folder-head" @click="toggleFolder(row.folder!.id)">
                <span class="tw-folder-caret" :class="{ collapsed: isFolderCollapsed(row.folder!.id) }">
                  <TaskIcon name="chevron" :size="11" />
                </span>
                <TaskIcon name="folder" :size="15" />
                <span class="tw-nav-label">{{ row.folder!.name }}</span>
                <span class="tw-nav-count">{{ row.count }}</span>
              </button>
              <div class="tw-list-actions tw-folder-actions">
                <button class="tw-icon-button" title="编辑文件夹" @click.stop="$emit('edit-folder', row.folder!)">
                  <TaskIcon name="edit" :size="14" />
                </button>
                <button class="tw-icon-button" title="删除文件夹" @click.stop="$emit('delete-folder', row.folder!)">
                  <TaskIcon name="trash" :size="14" />
                </button>
              </div>
            </li>
            <li v-else :class="{ 'tw-list-nested': row.nested }" draggable="true" @dragstart="startListDrag(row.list!.id, $event)" @dragover.prevent @drop.prevent="dropList(row.list!.id)" @dragend="endSidebarDrag">
              <button
                class="tw-nav-item tw-list-item"
                :class="{ active: activeListId === row.list!.id }"
                @click="$emit('select-list', row.list!.id)"
              >
                <span class="tw-list-dot" :style="{ background: row.list!.color || '#4772fa' }" />
                <span class="tw-nav-label">{{ row.list!.name }}</span>
                <span v-if="row.list!.count" class="tw-nav-count">{{ row.list!.count }}</span>
              </button>
              <div class="tw-list-actions">
                <button
                  class="tw-icon-button"
                  :class="{ 'is-pinned': row.list!.pinned }"
                  :title="row.list!.pinned ? '取消置顶清单' : '置顶清单'"
                  @click.stop="$emit('pin-list', row.list!)"
                >
                  <TaskIcon name="pin" :size="14" />
                </button>
                <button v-if="!row.list!.isInbox" class="tw-icon-button" title="复制清单" @click.stop="$emit('copy-list', row.list!)">
                  <TaskIcon name="copy" :size="14" />
                </button>
                <button v-if="!row.list!.isInbox" class="tw-icon-button" title="共享清单" @click.stop="$emit('share-list', row.list!)">
                  <TaskIcon name="share" :size="14" />
                </button>
                <button class="tw-icon-button" title="编辑清单" @click.stop="$emit('edit-list', row.list!)">
                  <TaskIcon name="edit" :size="14" />
                </button>
                <button class="tw-icon-button" title="删除清单" @click.stop="$emit('delete-list', row.list!)">
                  <TaskIcon name="trash" :size="14" />
                </button>
              </div>
            </li>
          </template>
        </ul>

        <p v-if="!customTaskLists.length && !folders.length && !pinnedLists.length" class="tw-side-hint">
          用清单来分类收集、组织和管理你的任务。
        </p>
      </section>

      <section class="tw-side-section">
        <header class="tw-section-head">
          <span>过滤器</span>
          <button class="tw-icon-button" aria-label="新建过滤器" title="新建过滤器" @click="$emit('create-filter')">
            <TaskIcon name="plus" :size="16" />
          </button>
        </header>
        <ul class="tw-list-nav">
          <li
            v-for="filter in unpinnedFilters"
            :key="filter.id"
            draggable="true"
            @dragstart="startFilterDrag(filter.id, $event)"
            @dragover.prevent
            @drop.prevent="dropFilter(filter.id)"
            @dragend="endSidebarDrag"
          >
            <button
              class="tw-nav-item tw-filter-item"
              :class="{ active: activeFilterId === filter.id }"
              @click="$emit('select-filter', filter.id)"
            >
              <span class="tw-filter-icon"><TaskIcon name="filter" :size="15" /></span>
              <span class="tw-nav-label">{{ filter.name }}</span>
            </button>
            <div class="tw-list-actions">
              <button
                class="tw-icon-button"
                :class="{ 'is-pinned': filter.pinned }"
                :title="filter.pinned ? '取消置顶过滤器' : '置顶过滤器'"
                @click.stop="$emit('pin-filter', filter)"
              >
                <TaskIcon name="pin" :size="14" />
              </button>
              <button class="tw-icon-button" title="编辑过滤器" @click.stop="$emit('edit-filter', filter)">
                <TaskIcon name="edit" :size="14" />
              </button>
              <button class="tw-icon-button" title="删除过滤器" @click.stop="$emit('delete-filter', filter)">
                <TaskIcon name="trash" :size="14" />
              </button>
            </div>
          </li>
        </ul>
        <p v-if="!filters.length" class="tw-side-hint">按清单、日期、优先级、标签与状态组合筛选，并保存为过滤器。</p>
      </section>

      <section v-if="sharedLists.length" class="tw-side-section">
        <header class="tw-section-head">
          <span>共享给我</span>
          <span class="tw-shared-readonly">共享</span>
        </header>
        <ul class="tw-list-nav">
          <li v-for="shared in sharedLists" :key="shared.listId">
            <button
              class="tw-nav-item tw-list-item"
              :class="{ active: activeSharedListId === shared.listId }"
              :title="`来自 ${shared.ownerDisplay || shared.ownerUsername}`"
              @click="$emit('select-shared', shared.listId)"
            >
              <span class="tw-list-dot" :style="{ background: shared.color || '#4772fa' }" />
              <span class="tw-nav-label">{{ shared.name }}</span>
              <span v-if="shared.count" class="tw-nav-count">{{ shared.count }}</span>
            </button>
            <p class="tw-shared-owner">{{ shared.ownerDisplay || shared.ownerUsername }} · {{ shared.role === 'editor' ? '可编辑' : '只读' }}</p>
          </li>
        </ul>
      </section>

      <section class="tw-side-section">
        <header class="tw-section-head">
          <span>标签</span>
          <button class="tw-icon-button" aria-label="管理标签" title="管理标签" @click="$emit('manage-tags')">
            <TaskIcon name="edit" :size="15" />
          </button>
        </header>
        <div v-if="tagCounts.length" class="tw-tag-cloud">
          <button
            v-for="tag in tagCounts"
            :key="tag.name"
            class="tw-tag-chip"
            :class="{ active: activeTag === tag.name }"
            :style="{ '--tag-color': tagColor(tag.name, tag.color), '--tag-tint': tagTint(tagColor(tag.name, tag.color)) }"
            @click="$emit('select-tag', activeTag === tag.name ? '' : tag.name)"
          >
            # {{ tag.name }}
          </button>
        </div>
        <p v-else class="tw-side-hint">添加任务时输入 “#” 可快速创建标签。</p>
      </section>
    </div>

    <footer class="tw-side-foot">
      <p class="tw-sync-note" title="任务会写入自动创建的 VTODO 日历并同步到 CalDAV 客户端">
        <TaskIcon name="check" :size="13" />
        CalDAV VTODO 同步
      </p>
      <button class="tw-side-link" @click="$emit('open-notifications')">
        <TaskIcon name="notice" :size="16" />
        <span>通知</span>
        <span v-if="unreadNotifications" class="tw-side-badge">{{ unreadNotifications > 99 ? '99+' : unreadNotifications }}</span>
      </button>
      <button class="tw-side-link" @click="$emit('open-reminders')">
        <TaskIcon name="bell" :size="16" />
        <span>提醒设置</span>
      </button>
      <router-link class="tw-side-link" to="/">
        <TaskIcon name="back" :size="16" />
        <span>管理后台</span>
      </router-link>
      <div class="tw-account">
        <span class="tw-avatar">{{ initial }}</span>
        <span class="tw-account-meta">
          <strong>{{ displayName || userName }}</strong>
          <small>{{ userName }}</small>
        </span>
        <button class="tw-icon-button" title="退出登录" @click="$emit('logout')">
          <TaskIcon name="close" :size="16" />
        </button>
      </div>
    </footer>
  </aside>
</template>

<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import type { SavedFilter, SharedTaskList, TaskCounts, TaskFolder, TaskList, TaskTagCount } from '../../types'
import { tagColor, tagTint } from '../../tag-colors'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  lists: TaskList[]
  sharedLists: SharedTaskList[]
  folders: TaskFolder[]
  filters: SavedFilter[]
  tagCounts: TaskTagCount[]
  counts: TaskCounts
  view: string
  activeListId: number
  activeFilterId: number
  activeTag: string
  activeSharedListId: number
  unreadNotifications: number
  userName: string
  displayName: string
  open: boolean
}>()

const emit = defineEmits<{
  (event: 'select-view', view: string): void
  (event: 'select-list', id: number): void
  (event: 'select-filter', id: number): void
  (event: 'select-tag', tag: string): void
  (event: 'select-shared', listId: number): void
  (event: 'create-list', payload: { name: string; kind: 'TASK' | 'NOTE' }): void
  (event: 'create-note'): void
  (event: 'edit-list', list: TaskList): void
  (event: 'delete-list', list: TaskList): void
  (event: 'pin-list', list: TaskList): void
  (event: 'copy-list', list: TaskList): void
  (event: 'create-folder'): void
  (event: 'edit-folder', folder: TaskFolder): void
  (event: 'delete-folder', folder: TaskFolder): void
  (event: 'create-filter'): void
  (event: 'edit-filter', filter: SavedFilter): void
  (event: 'delete-filter', filter: SavedFilter): void
  (event: 'pin-filter', filter: SavedFilter): void
  (event: 'reorder-filters', ids: number[]): void
  (event: 'reorder-lists', ids: number[]): void
  (event: 'reorder-folders', ids: number[]): void
  (event: 'share-list', list: TaskList): void
  (event: 'manage-tags'): void
  (event: 'open-reminders'): void
  (event: 'open-notifications'): void
  (event: 'logout'): void
  (event: 'close'): void
}>()

const adding = ref(false)
const addingNoteList = ref(false)
const newListName = ref('')
const newNoteListName = ref('')
const nameInput = ref<HTMLInputElement | null>(null)
const noteNameInput = ref<HTMLInputElement | null>(null)
const collapsedFolders = ref(new Set<number>())
const draggingFolderId = ref(0)
const draggingListId = ref(0)
const draggingFilterId = ref(0)

const initial = computed(() => (props.displayName || props.userName || '?').slice(0, 1).toUpperCase())
const pinnedLists = computed(() => props.lists.filter((list) => list.pinned && list.kind !== 'NOTE'))
const pinnedFilters = computed(() => props.filters.filter((filter) => filter.pinned))
const unpinnedFilters = computed(() => props.filters.filter((filter) => !filter.pinned))
const customTaskLists = computed(() =>
  props.lists.filter((list) => !list.isInbox && !list.pinned && list.kind !== 'NOTE'),
)
const customNoteLists = computed(() =>
  props.lists
    .filter((list) => !list.isInbox && list.kind === 'NOTE')
    .slice()
    .sort((a, b) => Number(b.pinned) - Number(a.pinned)),
)
const hasNoteLists = computed(() => props.lists.some((list) => !list.isInbox && list.kind === 'NOTE'))

type ListRow =
  | { kind: 'folder'; key: string; folder: TaskFolder; count: number }
  | { kind: 'list'; key: string; list: TaskList; nested: boolean }

const listRows = computed<ListRow[]>(() => {
  const rows: ListRow[] = []
  for (const folder of props.folders) {
    const lists = customTaskLists.value.filter((list) => list.folderId === folder.id)
    rows.push({ kind: 'folder', key: `folder-${folder.id}`, folder, count: lists.length })
    if (collapsedFolders.value.has(folder.id)) continue
    for (const list of lists) {
      rows.push({ kind: 'list', key: `list-${list.id}`, list, nested: true })
    }
  }
  for (const list of customTaskLists.value.filter((item) => item.folderId === 0)) {
    rows.push({ kind: 'list', key: `list-${list.id}`, list, nested: false })
  }
  return rows
})

const smartItems = computed(() => [
  { view: 'all', label: '所有', icon: 'list', count: props.counts.all },
  { view: 'today', label: '今天', icon: 'today', count: props.counts.today },
  { view: 'next7', label: '最近 7 天', icon: 'next7', count: props.counts.next7 },
  { view: 'inbox', label: '收集箱', icon: 'inbox', count: props.counts.inbox },
  { view: 'completed', label: '已完成', icon: 'check', count: props.counts.completed },
  { view: 'trash', label: '垃圾桶', icon: 'trash', count: props.counts.trash },
  { view: 'summary', label: '摘要', icon: 'note', count: 0 },
  { view: 'stats', label: '统计', icon: 'chart', count: 0 },
  { view: 'ai', label: 'AI 助手', icon: 'sparkles', count: 0 },
])

function isFolderCollapsed(id: number) {
  return collapsedFolders.value.has(id)
}

function toggleFolder(id: number) {
  const next = new Set(collapsedFolders.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  collapsedFolders.value = next
  try {
    localStorage.setItem('caldav-task-folders', JSON.stringify([...next]))
  } catch {
    /* ignore */
  }
}

async function toggleAdd() {
  adding.value = true
  addingNoteList.value = false
  newListName.value = ''
  await nextTick()
  nameInput.value?.focus()
}

function cancelAdd() {
  adding.value = false
  newListName.value = ''
}

function maybeCancel() {
  if (!newListName.value.trim()) cancelAdd()
}

function submitList() {
  const name = newListName.value.trim()
  if (!name) return cancelAdd()
  emit('create-list', { name, kind: 'TASK' })
  cancelAdd()
}

async function startAddNoteList() {
  addingNoteList.value = true
  adding.value = false
  newNoteListName.value = ''
  await nextTick()
  noteNameInput.value?.focus()
}

function cancelAddNoteList() {
  addingNoteList.value = false
  newNoteListName.value = ''
}

function maybeCancelNoteList() {
  if (!newNoteListName.value.trim()) cancelAddNoteList()
}

function submitNoteList() {
  const name = newNoteListName.value.trim()
  if (!name) return cancelAddNoteList()
  emit('create-list', { name, kind: 'NOTE' })
  cancelAddNoteList()
}

function startFolderDrag(id: number, event: DragEvent) {
  draggingFolderId.value = id
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
}

function dropFolder(targetId: number) {
  const sourceId = draggingFolderId.value
  endSidebarDrag()
  if (!sourceId || sourceId === targetId) return
  const list = props.folders.slice()
  const from = list.findIndex((folder) => folder.id === sourceId)
  const to = list.findIndex((folder) => folder.id === targetId)
  if (from < 0 || to < 0) return
  const [moved] = list.splice(from, 1)
  list.splice(to, 0, moved)
  emit('reorder-folders', list.map((folder) => folder.id))
}

function startListDrag(id: number, event: DragEvent) {
  draggingListId.value = id
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
}

function dropList(targetId: number) {
  const sourceId = draggingListId.value
  endSidebarDrag()
  if (!sourceId || sourceId === targetId) return
  const source = props.lists.find((list) => list.id === sourceId)
  const target = props.lists.find((list) => list.id === targetId)
  if (!source || !target || source.folderId !== target.folderId) return
  const list = props.lists.slice()
  const from = list.findIndex((item) => item.id === sourceId)
  const to = list.findIndex((item) => item.id === targetId)
  if (from < 0 || to < 0) return
  const [moved] = list.splice(from, 1)
  list.splice(to, 0, moved)
  emit('reorder-lists', list.filter((item) => item.folderId === source.folderId).map((item) => item.id))
}

function startFilterDrag(id: number, event: DragEvent) {
  draggingFilterId.value = id
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
}

function dropFilter(targetId: number) {
  const sourceId = draggingFilterId.value
  endSidebarDrag()
  if (!sourceId || sourceId === targetId) return
  const list = props.filters.filter((filter) => !filter.pinned)
  const from = list.findIndex((filter) => filter.id === sourceId)
  const to = list.findIndex((filter) => filter.id === targetId)
  if (from < 0 || to < 0) return
  const [moved] = list.splice(from, 1)
  list.splice(to, 0, moved)
  emit('reorder-filters', list.map((filter) => filter.id))
}

function endSidebarDrag() {
  draggingFolderId.value = 0
  draggingListId.value = 0
  draggingFilterId.value = 0
}

// Restore folder collapse state on first render.
try {
  const raw = localStorage.getItem('caldav-task-folders')
  if (raw) collapsedFolders.value = new Set(JSON.parse(raw) as number[])
} catch {
  /* ignore */
}
</script>
