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

    <nav class="tw-smart-nav">
      <button
        v-for="item in smartItems"
        :key="item.view"
        class="tw-nav-item"
        :class="{ active: view === item.view && !activeListId }"
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
          <span>清单</span>
          <button class="tw-icon-button" aria-label="新建清单" title="新建清单" @click="toggleAdd">
            <TaskIcon name="plus" :size="16" />
          </button>
        </header>

        <form v-if="adding" class="tw-new-list" @submit.prevent="submitList">
          <input
            ref="nameInput"
            v-model="newListName"
            class="tw-inline-input"
            maxlength="40"
            placeholder="清单名称，回车创建"
            @keydown.esc="cancelAdd"
            @blur="maybeCancel"
          />
        </form>

        <ul class="tw-list-nav">
          <li v-for="list in customLists" :key="list.id">
            <button
              class="tw-nav-item tw-list-item"
              :class="{ active: activeListId === list.id }"
              @click="$emit('select-list', list.id)"
            >
              <span class="tw-list-dot" :style="{ background: list.color || '#4772fa' }">
                <TaskIcon v-if="list.isInbox" name="inbox" :size="13" />
              </span>
              <span class="tw-nav-label">{{ list.name }}</span>
              <span v-if="list.count" class="tw-nav-count">{{ list.count }}</span>
            </button>
            <div v-if="!list.isInbox" class="tw-list-actions">
              <button class="tw-icon-button" title="编辑清单" @click.stop="$emit('edit-list', list)">
                <TaskIcon name="edit" :size="14" />
              </button>
              <button class="tw-icon-button" title="删除清单" @click.stop="$emit('delete-list', list)">
                <TaskIcon name="trash" :size="14" />
              </button>
            </div>
          </li>
        </ul>

        <p v-if="lists.length <= 1" class="tw-side-hint">
          用清单来分类收集、组织和管理你的任务与笔记。
        </p>
      </section>

      <section v-if="tags.length" class="tw-side-section">
        <header class="tw-section-head">
          <span>标签</span>
          <button v-if="activeTag" class="tw-link-button" @click="$emit('select-tag', '')">清除</button>
        </header>
        <div class="tw-tag-cloud">
          <button
            v-for="tag in tags"
            :key="tag"
            class="tw-tag-chip"
            :class="{ active: activeTag === tag }"
            @click="$emit('select-tag', activeTag === tag ? '' : tag)"
          >
            # {{ tag }}
          </button>
        </div>
      </section>
    </div>

    <footer class="tw-side-foot">
      <p class="tw-sync-note" title="任务会写入自动创建的 VTODO 日历并同步到 CalDAV 客户端">
        <TaskIcon name="check" :size="13" />
        CalDAV VTODO 同步
      </p>
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
import type { TaskCounts, TaskList } from '../../types'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  lists: TaskList[]
  counts: TaskCounts
  view: string
  activeListId: number
  tags: string[]
  activeTag: string
  userName: string
  displayName: string
  open: boolean
}>()

const emit = defineEmits<{
  (event: 'select-view', view: string): void
  (event: 'select-list', id: number): void
  (event: 'create-list', name: string): void
  (event: 'edit-list', list: TaskList): void
  (event: 'delete-list', list: TaskList): void
  (event: 'select-tag', tag: string): void
  (event: 'logout'): void
  (event: 'close'): void
}>()

const adding = ref(false)
const newListName = ref('')
const nameInput = ref<HTMLInputElement | null>(null)

const initial = computed(() => (props.displayName || props.userName || '?').slice(0, 1).toUpperCase())
const customLists = computed(() => props.lists.filter((list) => !list.isInbox))

const smartItems = computed(() => [
  { view: 'all', label: '所有', icon: 'list', count: props.counts.all },
  { view: 'today', label: '今天', icon: 'today', count: props.counts.today },
  { view: 'next7', label: '最近 7 天', icon: 'next7', count: props.counts.next7 },
  { view: 'inbox', label: '收集箱', icon: 'inbox', count: props.counts.inbox },
  { view: 'completed', label: '已完成', icon: 'check', count: props.counts.completed },
])

async function toggleAdd() {
  adding.value = true
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
  emit('create-list', name)
  cancelAdd()
}
</script>
