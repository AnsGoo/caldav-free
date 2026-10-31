<template>
  <section class="tw-notes-page">
    <aside class="tw-notes-side">
      <header class="tw-notes-side-head">
        <h2>笔记</h2>
        <span class="tw-section-actions">
          <button class="tw-icon-button" title="新建文件夹" @click="startAddFolder"><TaskIcon name="folder" :size="16" /></button>
          <button class="tw-icon-button" title="新建笔记清单" @click="startAdd"><TaskIcon name="plus" :size="16" /></button>
        </span>
      </header>

      <form v-if="addingFolder" class="tw-new-list" @submit.prevent="submitFolder">
        <input
          ref="folderInput"
          v-model="newFolderName"
          class="tw-inline-input"
          maxlength="40"
          placeholder="文件夹名称，回车创建"
          @keydown.enter.prevent="submitFolder"
          @keydown.esc="cancelAddFolder"
          @blur="maybeCancelFolder"
        />
      </form>

      <form v-if="adding" class="tw-new-list" @submit.prevent="submitList">
        <input
          ref="nameInput"
          v-model="newName"
          class="tw-inline-input"
          maxlength="40"
          placeholder="笔记清单名称，回车创建"
          @keydown.enter.prevent="submitList"
          @keydown.esc="cancelAdd"
          @blur="maybeCancel"
        />
      </form>

      <ul class="tw-list-nav tw-notes-lists">
        <li>
          <button class="tw-nav-item tw-list-item tw-notes-all" :class="{ active: activeListId === 0 }" @click="selectAll">
            <span class="tw-notes-all-mark"><TaskIcon name="note" :size="13" /></span>
            <span class="tw-nav-label">全部笔记</span>
            <span class="tw-nav-count">{{ props.notes.length }}</span>
          </button>
        </li>
        <template v-for="row in noteRows" :key="row.key">
          <li v-if="row.kind === 'folder'" class="tw-folder-row">
            <template v-if="renamingFolderId === row.folder.id">
              <form class="tw-new-list" @submit.prevent="submitFolderRename(row.folder)">
                <input
                  ref="renameFolderInput"
                  v-model="renameFolderName"
                  class="tw-inline-input"
                  maxlength="40"
                  @keydown.esc="renamingFolderId = 0"
                  @blur="renamingFolderId = 0"
                />
              </form>
            </template>
            <template v-else>
              <button class="tw-folder-head" @click="toggleFolder(row.folder.id)">
                <span class="tw-folder-caret" :class="{ collapsed: isFolderCollapsed(row.folder.id) }">
                  <TaskIcon name="chevron" :size="11" />
                </span>
                <TaskIcon name="folder" :size="15" />
                <span class="tw-nav-label">{{ row.folder.name }}</span>
                <span class="tw-nav-count">{{ row.count }}</span>
              </button>
              <div class="tw-list-actions tw-folder-actions">
                <button class="tw-icon-button" title="重命名文件夹" @click.stop="startFolderRename(row.folder)">
                  <TaskIcon name="edit" :size="14" />
                </button>
                <button class="tw-icon-button" title="删除文件夹" @click.stop="removeFolder(row.folder)">
                  <TaskIcon name="trash" :size="14" />
                </button>
              </div>
            </template>
          </li>
          <li v-else :class="{ 'tw-list-nested': row.nested }">
            <template v-if="renamingId === row.list.id">
              <form class="tw-new-list" @submit.prevent="submitRename(row.list)">
                <input
                  ref="renameInput"
                  v-model="renameName"
                  class="tw-inline-input"
                  maxlength="40"
                  @keydown.esc="renamingId = 0"
                  @blur="renamingId = 0"
                />
              </form>
            </template>
            <button
              v-else
              class="tw-nav-item tw-list-item"
              :class="{ active: activeListId === row.list.id }"
              @click="selectList(row.list.id)"
            >
              <span class="tw-list-dot" :style="{ background: row.list.color || '#4772fa' }" />
              <span class="tw-nav-label">{{ row.list.name }}</span>
              <span v-if="row.list.count" class="tw-nav-count">{{ row.list.count }}</span>
            </button>
            <div v-if="renamingId !== row.list.id" class="tw-list-actions">
              <button class="tw-icon-button" title="移动到文件夹" @click.stop="openMoveList(row.list)">
                <TaskIcon name="folder" :size="14" />
              </button>
              <button
                class="tw-icon-button"
                :class="{ 'is-pinned': row.list.pinned }"
                :title="row.list.pinned ? '取消置顶笔记清单' : '置顶笔记清单'"
                @click.stop="togglePin(row.list)"
              >
                <TaskIcon name="pin" :size="14" />
              </button>
              <button class="tw-icon-button" title="共享笔记清单" @click.stop="shareTarget = row.list">
                <TaskIcon name="share" :size="14" />
              </button>
              <button class="tw-icon-button" title="重命名笔记清单" @click.stop="startRename(row.list)">
                <TaskIcon name="edit" :size="14" />
              </button>
              <button class="tw-icon-button" title="删除笔记清单" @click.stop="removeList(row.list)">
                <TaskIcon name="trash" :size="14" />
              </button>
            </div>
          </li>
        </template>
      </ul>

      <p v-if="!noteLists.length && !adding && !addingFolder" class="tw-side-hint">新建一个笔记清单，开始记录想法。</p>

      <section v-if="sharedNotes.length" class="tw-notes-shared">
        <header class="tw-notes-shared-head">共享笔记</header>
        <ul class="tw-list-nav">
          <li v-for="note in sharedNotes" :key="`shared-${note.task.id}`">
            <button class="tw-nav-item tw-list-item" @click="$emit('open-shared', note)">
              <span class="tw-notes-all-mark"><TaskIcon name="note" :size="13" /></span>
              <span class="tw-nav-label">{{ note.task.title || '无标题笔记' }}</span>
              <small class="tw-notes-shared-owner">{{ note.ownerDisplay || note.ownerUsername }}</small>
            </button>
          </li>
        </ul>
      </section>
    </aside>

    <main class="tw-notes-main">
      <header class="tw-notes-toolbar">
        <div class="tw-notes-heading">
          <h1>{{ heading }}</h1>
          <small>{{ filteredNotes.length }} 篇</small>
        </div>
        <div class="tw-notes-tools">
          <a-input v-model="query" class="tw-notes-search" size="small" placeholder="搜索笔记" allow-clear />
          <button class="tw-notes-create" :disabled="creating" @click="createNote">
            <TaskIcon name="plus" :size="14" />
            新建笔记
          </button>
        </div>
      </header>

      <div v-if="filteredNotes.length" class="tw-note-grid tw-notes-grid">
        <NoteCard
          v-for="note in filteredNotes"
          :key="note.id"
          :task="note"
          :selected="selectedId === note.id"
          :tag-colors="tagColors"
          @open="$emit('open', $event)"
          @pin="$emit('pin', $event)"
          @remove="$emit('remove', $event)"
        />
      </div>
      <div v-else class="tw-empty tw-note-empty">
        <h2>{{ query ? '没有匹配的笔记' : '这里还没有笔记' }}</h2>
        <p>{{ query ? '换个关键词试试。' : '点击右上角「新建笔记」开始记录。' }}</p>
      </div>
    </main>

    <TaskListShareDialog v-if="shareTarget" :list="shareTarget" @close="shareTarget = null" @changed="$emit('reload')" />

    <div v-if="moveTarget" class="tw-dialog-scrim" @click.self="moveTarget = null">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true" aria-label="移动到文件夹">
        <header class="tw-dialog-head">
          <h2>移动到文件夹</h2>
          <button class="tw-icon-button" title="关闭" @click="moveTarget = null">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body tw-move-list">
          <button class="tw-move-option" :class="{ active: moveFolderId === 0 }" @click="moveFolderId = 0">
            <span class="tw-list-dot" style="background: #9aa0a6" />
            <span>根目录</span>
            <TaskIcon v-if="moveFolderId === 0" name="check" :size="14" />
          </button>
          <button
            v-for="folder in props.folders"
            :key="folder.id"
            class="tw-move-option"
            :class="{ active: moveFolderId === folder.id }"
            @click="moveFolderId = folder.id"
          >
            <TaskIcon name="folder" :size="14" />
            <span>{{ folder.name }}</span>
            <TaskIcon v-if="moveFolderId === folder.id" name="check" :size="14" />
          </button>
          <p v-if="!props.folders.length" class="tw-dialog-hint">还没有文件夹，先新建一个。</p>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="moveTarget = null">取消</button>
          <button class="tw-dialog-ok" :disabled="moveBusy" @click="confirmMoveList">{{ moveBusy ? '移动中…' : '移动' }}</button>
        </footer>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { Message, Modal } from '@arco-design/web-vue'
import type { SharedNote, TaskFolder, TaskItem, TaskList } from '../../types'
import { createTask, createTaskFolder, createTaskList, deleteTaskFolder, deleteTaskList, updateTaskFolder, updateTaskList } from '../../tasks-api'
import { LIST_COLORS } from '../../tasks-utils'
import NoteCard from './NoteCard.vue'
import TaskIcon from './TaskIcon.vue'
import TaskListShareDialog from './TaskListShareDialog.vue'

const props = defineProps<{
  notes: TaskItem[]
  lists: TaskList[]
  folders: TaskFolder[]
  sharedNotes: SharedNote[]
  tagColors: Record<string, string>
  selectedId: number
}>()

const emit = defineEmits<{
  (event: 'open', task: TaskItem): void
  (event: 'pin', task: TaskItem): void
  (event: 'remove', task: TaskItem): void
  (event: 'open-shared', note: SharedNote): void
  (event: 'reload'): void
}>()

const adding = ref(false)
const newName = ref('')
const nameInput = ref<HTMLInputElement | null>(null)
const addingFolder = ref(false)
const newFolderName = ref('')
const folderInput = ref<HTMLInputElement | null>(null)
const renamingFolderId = ref(0)
const renameFolderName = ref('')
const renameFolderInput = ref<HTMLInputElement | HTMLInputElement[] | null>(null)
const collapsedFolders = ref(new Set<number>())
const renamingId = ref(0)
const renameName = ref('')
const renameInput = ref<HTMLInputElement | null>(null)
const query = ref('')
const creating = ref(false)
const shareTarget = ref<TaskList | null>(null)
const moveTarget = ref<TaskList | null>(null)
const moveFolderId = ref(0)
const moveBusy = ref(false)
const activeListId = ref(storedList())

type NoteRow =
  | { kind: 'folder'; key: string; folder: TaskFolder; count: number }
  | { kind: 'list'; key: string; list: TaskList; nested: boolean }

function storedList() {
  try {
    return Number(localStorage.getItem('caldav-notes-list') || 0) || 0
  } catch {
    return 0
  }
}

function isFolderCollapsed(id: number) {
  return collapsedFolders.value.has(id)
}

function toggleFolder(id: number) {
  const next = new Set(collapsedFolders.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  collapsedFolders.value = next
  try {
    localStorage.setItem('caldav-note-folders', JSON.stringify([...next]))
  } catch {
    /* ignore */
  }
}

const noteLists = computed(() =>
  props.lists
    .filter((list) => list.kind === 'NOTE')
    .slice()
    .sort((a, b) => Number(Boolean(b.pinned)) - Number(Boolean(a.pinned)) || a.order - b.order || a.id - b.id),
)

const noteRows = computed<NoteRow[]>(() => {
  const rows: NoteRow[] = []
  const folderIds = new Set(props.folders.map((folder) => folder.id))
  for (const folder of props.folders) {
    const children = noteLists.value.filter((list) => list.folderId === folder.id)
    rows.push({ kind: 'folder', key: `folder-${folder.id}`, folder, count: children.length })
    if (collapsedFolders.value.has(folder.id)) continue
    for (const list of children) {
      rows.push({ kind: 'list', key: `list-${list.id}`, list, nested: true })
    }
  }
  for (const list of noteLists.value.filter((item) => !folderIds.has(item.folderId))) {
    rows.push({ kind: 'list', key: `list-${list.id}`, list, nested: false })
  }
  return rows
})

const currentList = computed(() => noteLists.value.find((list) => list.id === activeListId.value))
const heading = computed(() => (activeListId.value ? currentList.value?.name || '笔记' : '全部笔记'))

const filteredNotes = computed(() => {
  const keyword = query.value.trim().toLowerCase()
  return props.notes
    .filter((note) => !activeListId.value || note.listId === activeListId.value)
    .filter((note) => {
      if (!keyword) return true
      const text = `${note.title}\n${note.notesText || note.notes || ''}`.toLowerCase()
      return text.includes(keyword)
    })
    .slice()
    .sort((a, b) => Number(Boolean(b.pinned)) - Number(Boolean(a.pinned)) || String(b.modifiedAt).localeCompare(String(a.modifiedAt)))
})

function selectAll() {
  activeListId.value = 0
  remember()
}

function selectList(id: number) {
  activeListId.value = id
  remember()
}

function remember() {
  try {
    localStorage.setItem('caldav-notes-list', String(activeListId.value))
  } catch {
    /* ignore */
  }
}

function startAdd() {
  addingFolder.value = false
  adding.value = true
  newName.value = ''
  void nextTick(() => nameInput.value?.focus())
}

function cancelAdd() {
  adding.value = false
  newName.value = ''
}

function maybeCancel() {
  if (!newName.value.trim()) adding.value = false
}

async function submitList() {
  const name = newName.value.trim()
  if (!name) return
  try {
    const color = LIST_COLORS[noteLists.value.length % LIST_COLORS.length]
    const folderId = currentList.value?.folderId || 0
    const { list } = await createTaskList(name, color, folderId, 'NOTE')
    adding.value = false
    newName.value = ''
    activeListId.value = list.id
    remember()
    emit('reload')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建笔记清单失败')
  }
}

function startAddFolder() {
  adding.value = false
  addingFolder.value = true
  newFolderName.value = ''
  void nextTick(() => folderInput.value?.focus())
}

function cancelAddFolder() {
  addingFolder.value = false
  newFolderName.value = ''
}

function maybeCancelFolder() {
  if (!newFolderName.value.trim()) addingFolder.value = false
}

async function submitFolder() {
  const name = newFolderName.value.trim()
  if (!name) return
  try {
    await createTaskFolder(name, 'NOTE')
    addingFolder.value = false
    newFolderName.value = ''
    emit('reload')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建文件夹失败')
  }
}

function startFolderRename(folder: TaskFolder) {
  renamingFolderId.value = folder.id
  renameFolderName.value = folder.name
  void nextTick(() => {
    const el = renameFolderInput.value
    const input = Array.isArray(el) ? el[0] : el
    input?.focus()
  })
}

async function submitFolderRename(folder: TaskFolder) {
  const name = renameFolderName.value.trim()
  renamingFolderId.value = 0
  if (!name || name === folder.name) return
  try {
    await updateTaskFolder(folder.id, { name })
    emit('reload')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '重命名文件夹失败')
  }
}

function removeFolder(folder: TaskFolder) {
  Modal.confirm({
    title: '删除文件夹',
    content: `确定删除「${folder.name}」吗？其中的笔记清单会回到根目录。`,
    okText: '删除',
    cancelText: '取消',
    okButtonProps: { status: 'danger' },
    onOk: async () => {
      try {
        await deleteTaskFolder(folder.id)
        emit('reload')
      } catch (error) {
        Message.error(error instanceof Error ? error.message : '删除文件夹失败')
      }
    },
  })
}

function openMoveList(list: TaskList) {
  moveTarget.value = list
  moveFolderId.value = list.folderId || 0
}

async function confirmMoveList() {
  if (!moveTarget.value || moveBusy.value) return
  moveBusy.value = true
  try {
    await updateTaskList(moveTarget.value.id, { folderId: moveFolderId.value })
    moveTarget.value = null
    emit('reload')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '移动失败')
  } finally {
    moveBusy.value = false
  }
}

function startRename(list: TaskList) {
  renamingId.value = list.id
  renameName.value = list.name
  void nextTick(() => renameInput.value?.focus())
}

async function submitRename(list: TaskList) {
  const name = renameName.value.trim()
  renamingId.value = 0
  if (!name || name === list.name) return
  try {
    await updateTaskList(list.id, { name })
    emit('reload')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '重命名失败')
  }
}

async function togglePin(list: TaskList) {
  try {
    await updateTaskList(list.id, { pinned: !list.pinned })
    emit('reload')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '更新置顶失败')
  }
}

function removeList(list: TaskList) {
  Modal.confirm({
    title: '删除笔记清单',
    content: `确定删除「${list.name}」吗？清单中的笔记会移动到其他笔记清单。`,
    okText: '删除',
    cancelText: '取消',
    okButtonProps: { status: 'danger' },
    onOk: async () => {
      try {
        await deleteTaskList(list.id)
        if (activeListId.value === list.id) selectAll()
        emit('reload')
      } catch (error) {
        Message.error(error instanceof Error ? error.message : '删除笔记清单失败')
      }
    },
  })
}

async function createNote() {
  if (creating.value) return
  let target = currentList.value
  if (!target) target = noteLists.value[0]
  creating.value = true
  try {
    if (!target) {
      const color = LIST_COLORS[noteLists.value.length % LIST_COLORS.length]
      const { list } = await createTaskList('笔记', color, 0, 'NOTE')
      target = list
    }
    const { task } = await createTask({ title: '无标题笔记', kind: 'NOTE', listId: target.id })
    activeListId.value = target.id
    remember()
    emit('reload')
    emit('open', task)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '新建笔记失败')
  } finally {
    creating.value = false
  }
}

// Restore folder collapse state on first render.
try {
  const raw = localStorage.getItem('caldav-note-folders')
  if (raw) collapsedFolders.value = new Set(JSON.parse(raw) as number[])
} catch {
  /* ignore */
}
</script>
