<template>
  <section class="tw-notes-page">
    <aside class="tw-notes-side">
      <header class="tw-notes-side-head">
        <h2>笔记</h2>
        <button class="tw-icon-button" title="新建笔记清单" @click="startAdd"><TaskIcon name="plus" :size="16" /></button>
      </header>

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
        <li v-for="list in noteLists" :key="list.id">
          <template v-if="renamingId === list.id">
            <form class="tw-new-list" @submit.prevent="submitRename(list)">
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
            :class="{ active: activeListId === list.id }"
            @click="selectList(list.id)"
          >
            <span class="tw-list-dot" :style="{ background: list.color || '#4772fa' }" />
            <span class="tw-nav-label">{{ list.name }}</span>
            <span v-if="list.count" class="tw-nav-count">{{ list.count }}</span>
          </button>
          <div v-if="renamingId !== list.id" class="tw-list-actions">
            <button
              class="tw-icon-button"
              :class="{ 'is-pinned': list.pinned }"
              :title="list.pinned ? '取消置顶笔记清单' : '置顶笔记清单'"
              @click.stop="togglePin(list)"
            >
              <TaskIcon name="pin" :size="14" />
            </button>
            <button class="tw-icon-button" title="共享笔记清单" @click.stop="shareTarget = list">
              <TaskIcon name="share" :size="14" />
            </button>
            <button class="tw-icon-button" title="重命名笔记清单" @click.stop="startRename(list)">
              <TaskIcon name="edit" :size="14" />
            </button>
            <button class="tw-icon-button" title="删除笔记清单" @click.stop="removeList(list)">
              <TaskIcon name="trash" :size="14" />
            </button>
          </div>
        </li>
      </ul>

      <p v-if="!noteLists.length && !adding" class="tw-side-hint">新建一个笔记清单，开始记录想法。</p>

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
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { Message, Modal } from '@arco-design/web-vue'
import type { SharedNote, TaskItem, TaskList } from '../../types'
import { createTask, createTaskList, deleteTaskList, updateTaskList } from '../../tasks-api'
import { LIST_COLORS } from '../../tasks-utils'
import NoteCard from './NoteCard.vue'
import TaskIcon from './TaskIcon.vue'
import TaskListShareDialog from './TaskListShareDialog.vue'

const props = defineProps<{
  notes: TaskItem[]
  lists: TaskList[]
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
const renamingId = ref(0)
const renameName = ref('')
const renameInput = ref<HTMLInputElement | null>(null)
const query = ref('')
const creating = ref(false)
const shareTarget = ref<TaskList | null>(null)
const activeListId = ref(storedList())

function storedList() {
  try {
    return Number(localStorage.getItem('caldav-notes-list') || 0) || 0
  } catch {
    return 0
  }
}

const noteLists = computed(() =>
  props.lists
    .filter((list) => list.kind === 'NOTE')
    .slice()
    .sort((a, b) => Number(Boolean(b.pinned)) - Number(Boolean(a.pinned)) || a.order - b.order || a.id - b.id),
)

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
    const { list } = await createTaskList(name, color, 0, 'NOTE')
    adding.value = false
    newName.value = ''
    activeListId.value = list.id
    remember()
    emit('reload')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建笔记清单失败')
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
</script>
