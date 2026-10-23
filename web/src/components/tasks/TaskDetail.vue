<template>
  <section class="tw-detail" :class="{ 'is-readonly': readonly }">
    <header class="tw-detail-head">
      <label class="tw-detail-list">
        <i :style="{ background: currentList?.color || '#4772fa' }" />
        <select v-model.number="draft.listId" :disabled="readonly || listLocked" @change="save">
          <option v-for="list in lists" :key="list.id" :value="list.id">{{ list.name }}</option>
        </select>
      </label>
      <div class="tw-detail-head-actions">
        <span class="tw-save-state">{{ readonly ? '只读共享' : saving ? '保存中…' : saved ? '已保存' : '' }}</span>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="18" />
        </button>
      </div>
    </header>

    <div class="tw-detail-scroll" :inert="readonly">
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
        <span v-if="draft.recurrence" class="tw-pill">
          <TaskIcon name="repeat" :size="14" />
          {{ recurrenceLabel(draft.recurrence) }}
        </span>
        <span v-if="draft.reminderOffsets.length" class="tw-pill">
          <TaskIcon name="bell" :size="14" />
          {{ reminderSummary }}
        </span>
        <span v-if="draft.assignee" class="tw-pill">
          <TaskIcon name="share" :size="14" />
          @{{ draft.assignee }}
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
        <header class="tw-detail-section-head"><span>重复与提醒</span></header>
        <div class="tw-field-grid">
          <label class="tw-field">
            <span>重复</span>
            <select v-model="recurrenceChoice" class="tw-field-select" @change="onRecurrenceChoice">
              <option v-for="option in RECURRENCE_OPTIONS" :key="option.value" :value="option.value">{{ option.label }}</option>
            </select>
          </label>
          <div class="tw-field">
            <span>提醒</span>
            <div class="tw-reminder-editor">
              <div v-for="(offset, index) in draft.reminderOffsets" :key="`${offset}-${index}`" class="tw-reminder-edit-row">
                <select
                  class="tw-field-select"
                  :value="offset"
                  @change="changeReminder(index, Number(($event.target as HTMLSelectElement).value))"
                >
                  <option v-for="option in reminderChoices" :key="option.value" :value="option.value" :disabled="draft.reminderOffsets.includes(option.value) && option.value !== offset">
                    {{ option.label }}
                  </option>
                  <option v-if="!reminderChoices.some((option) => option.value === offset)" :value="offset">{{ reminderLabel(offset) }}</option>
                </select>
                <button type="button" class="tw-icon-button" title="删除提醒" @click="removeReminder(index)">
                  <TaskIcon name="close" :size="14" />
                </button>
              </div>
              <button v-if="draft.reminderOffsets.length < 10" type="button" class="tw-add-reminder" @click="addReminder">
                <TaskIcon name="plus" :size="13" />
                添加提醒
              </button>
              <p v-if="!draft.reminderOffsets.length" class="tw-field-hint">不提醒</p>
            </div>
          </div>
        </div>
        <label v-if="(members?.length || 0) > 1 || draft.assignee" class="tw-field tw-field-wide">
          <span>指派人</span>
          <select v-model="draft.assignee" class="tw-field-select" :disabled="readonly" @change="save">
            <option value="">未指派</option>
            <option v-for="member in members" :key="member.username" :value="member.username">
              {{ member.displayName || member.username }} (@{{ member.username }})
            </option>
          </select>
        </label>
        <input
          v-if="recurrenceChoice === 'custom'"
          v-model="customRule"
          class="tw-field-input"
          placeholder="FREQ=WEEKLY;BYDAY=MO,WE"
          @change="onCustomRule"
          @keydown.enter.prevent="onCustomRule"
        />
        <p class="tw-field-hint">
          重复任务完成后会自动滚到下一次。提醒会写入 CalDAV VALARM；页面打开时可同时使用浏览器通知。
        </p>
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

      <section class="tw-comments-section">
        <header class="tw-detail-section-head">
          <span>评论</span>
          <small v-if="comments.length">{{ comments.length }}</small>
        </header>
        <div v-if="commentsLoading" class="tw-comments-loading">加载评论…</div>
        <div v-else-if="comments.length" class="tw-comment-list">
          <article v-for="comment in comments" :key="comment.id" class="tw-comment-row">
            <span class="tw-avatar tw-avatar-sm">{{ (comment.displayName || comment.username).slice(0, 1).toUpperCase() }}</span>
            <div class="tw-comment-main">
              <div class="tw-comment-head">
                <strong>{{ comment.displayName || comment.username }}</strong>
                <small>{{ formatCommentTime(comment.createdAt) }}<template v-if="comment.editedAt"> · 已编辑</template></small>
                <button
                  v-if="!readonly && comment.canEdit && editingCommentId !== comment.id"
                  class="tw-icon-button tw-comment-delete"
                  title="编辑评论"
                  @click="startEditComment(comment)"
                >
                  <TaskIcon name="edit" :size="12" />
                </button>
                <button
                  v-if="!readonly && comment.canDelete"
                  class="tw-icon-button tw-comment-delete"
                  title="删除评论"
                  @click="removeComment(comment)"
                >
                  <TaskIcon name="trash" :size="12" />
                </button>
              </div>
              <template v-if="editingCommentId === comment.id">
                <textarea
                  v-model="editingCommentText"
                  class="tw-comment-input"
                  rows="2"
                  maxlength="4000"
                />
                <div class="tw-comment-edit-actions">
                  <button class="tw-dialog-cancel" @click="cancelEditComment">取消</button>
                  <button class="tw-comment-send" :disabled="!editingCommentText.trim()" @click="saveEditedComment(comment)">保存</button>
                </div>
              </template>
              <p v-else>{{ comment.body }}</p>
              <div v-if="comment.attachments.length" class="tw-comment-attachments">
                <template v-for="attachment in comment.attachments" :key="`img-${attachment.id}`">
                  <a
                    v-if="isImageAttachment(attachment)"
                    :href="attachmentURL(comment, attachment)"
                    target="_blank"
                    rel="noopener"
                    class="tw-comment-image-link"
                  >
                    <img :src="attachmentURL(comment, attachment)" :alt="attachment.filename" />
                  </a>
                </template>
                <div v-for="attachment in comment.attachments" :key="attachment.id" class="tw-comment-attachment">
                  <a :href="attachmentURL(comment, attachment)" target="_blank" rel="noopener">
                    <TaskIcon name="download" :size="13" />
                    <span>{{ attachment.filename }}</span>
                    <small>{{ formatSize(attachment.size) }}</small>
                  </a>
                  <button
                    v-if="!readonly && attachment.canDelete"
                    class="tw-icon-button"
                    title="删除附件"
                    @click="removeAttachment(comment, attachment)"
                  >
                    <TaskIcon name="trash" :size="12" />
                  </button>
                </div>
              </div>
            </div>
          </article>
        </div>
        <p v-else class="tw-comments-empty">还没有评论。</p>

        <div v-if="!readonly" class="tw-comment-compose">
          <textarea
            v-model="commentText"
            class="tw-comment-input"
            rows="2"
            maxlength="4000"
            placeholder="写评论，使用 @用户名 提及成员"
          />
          <div v-if="commentFiles.length" class="tw-comment-files">
            <span v-for="(file, index) in commentFiles" :key="`${file.name}-${index}`">
              {{ file.name }}
              <button type="button" title="移除" @click="commentFiles.splice(index, 1)">×</button>
            </span>
          </div>
          <div class="tw-comment-actions">
            <div class="tw-comment-mentions">
              <input ref="commentFileInput" type="file" multiple hidden @change="onCommentFiles" />
              <button type="button" class="tw-mention-chip" @click="commentFileInput?.click()">+ 附件</button>
              <button
                v-for="member in mentionMembers"
                :key="member.username"
                type="button"
                class="tw-mention-chip"
                @click="insertMention(member.username)"
              >
                @{{ member.username }}
              </button>
            </div>
            <button class="tw-comment-send" :disabled="commentBusy || (!commentText.trim() && !commentFiles.length)" @click="postComment">
              {{ commentBusy ? '发送中…' : '发表评论' }}
            </button>
          </div>
        </div>
      </section>

      <p class="tw-detail-meta">
        创建于 {{ formatMoment(task.createdAt) }}
        <template v-if="task.completedAt"> · 完成于 {{ formatMoment(task.completedAt) }}</template>
      </p>
    </div>

    <footer class="tw-detail-foot">
      <button v-if="!readonly" class="tw-danger-link" @click="$emit('remove', task)">
        <TaskIcon name="trash" :size="14" />
        删除任务
      </button>
      <span class="tw-foot-hint">{{ readonly ? '共享清单 · 只读' : '自动保存 · 同步 CalDAV' }}</span>
    </footer>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, reactive, ref, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { ChecklistItem, CommentAttachment, TaskComment, TaskItem, TaskList, TaskListMember } from '../../types'
import { PRIORITIES, RECURRENCE_OPTIONS, REMINDER_OPTIONS, addDays, dayKey, formatDue, recurrenceLabel, reminderLabel, startOfToday, toDateInput } from '../../tasks-utils'
import { createTaskComment, deleteCommentAttachment, deleteTaskComment, fetchTaskComments, updateTask, updateTaskComment, uploadCommentAttachment } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ task: TaskItem; lists: TaskList[]; members?: TaskListMember[]; readonly?: boolean; listLocked?: boolean }>()
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
  recurrence: string
  reminderOffsets: number[]
  assignee: string
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
  recurrence: '',
  reminderOffsets: [],
  assignee: '',
  tags: [],
  checklist: [],
})

const titleEl = ref<HTMLTextAreaElement | null>(null)
const dateOpen = ref(false)
const tagInput = ref('')
const recurrenceChoice = ref('')
const customRule = ref('')
const saving = ref(false)
const saved = ref(false)
const comments = ref<TaskComment[]>([])
const commentsLoading = ref(false)
const commentBusy = ref(false)
const commentText = ref('')
const commentFiles = ref<File[]>([])
const commentFileInput = ref<HTMLInputElement | null>(null)
const editingCommentId = ref(0)
const editingCommentText = ref('')
let hydrating = true
let saveTimer: ReturnType<typeof setTimeout> | undefined
let lastSaved = ''

const currentList = computed(() => props.lists.find((list) => list.id === draft.listId))
const priorityMeta = computed(() => PRIORITIES.find((item) => item.value === draft.priority))
const reminderChoices = REMINDER_OPTIONS.filter((option) => option.value >= 0)
const reminderSummary = computed(() => {
  if (draft.reminderOffsets.length === 1) return reminderLabel(draft.reminderOffsets[0])
  return `${draft.reminderOffsets.length} 个提醒`
})
const doneCount = computed(() => draft.checklist.filter((item) => item.done).length)
const mentionMembers = computed(() => (props.members || []).slice(0, 6))

function hydrate() {
  hydrating = true
  dateOpen.value = false
  draft.title = props.task.title
  draft.notes = props.task.notes
  draft.listId = props.task.listId
  draft.priority = props.task.priority
  draft.completed = props.task.completed
  draft.allDay = props.task.allDay
  draft.recurrence = props.task.recurrence || ''
  draft.reminderOffsets = props.task.reminderOffsets?.length
    ? [...props.task.reminderOffsets].sort((a, b) => a - b)
    : props.task.reminderOffset >= 0
      ? [props.task.reminderOffset]
      : []
  draft.assignee = props.task.assignee || ''
  const preset = RECURRENCE_OPTIONS.some((option) => option.value === props.task.recurrence && option.value !== 'custom')
  recurrenceChoice.value = props.task.recurrence ? (preset ? props.task.recurrence : 'custom') : ''
  customRule.value = preset ? '' : props.task.recurrence || ''
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
  commentText.value = ''
  commentFiles.value = []
  editingCommentId.value = 0
  editingCommentText.value = ''
  void loadComments()
  nextTick(() => {
    growTitle()
    lastSaved = snapshotDraft()
    hydrating = false
  })
}

function addReminder() {
  const preferred = [15, 5, 60, 0, 1440]
  const next = preferred.find((value) => !draft.reminderOffsets.includes(value))
  if (next === undefined) return
  draft.reminderOffsets.push(next)
  draft.reminderOffsets.sort((a, b) => a - b)
}

function removeReminder(index: number) {
  draft.reminderOffsets.splice(index, 1)
}

function changeReminder(index: number, value: number) {
  if (value < 0) {
    removeReminder(index)
    return
  }
  if (draft.reminderOffsets.some((offset, position) => offset === value && position !== index)) {
    draft.reminderOffsets.splice(index, 1)
    return
  }
  draft.reminderOffsets[index] = value
  draft.reminderOffsets.sort((a, b) => a - b)
}

async function loadComments() {
  const id = props.task.id
  if (!id) return
  commentsLoading.value = true
  try {
    const result = await fetchTaskComments(id)
    if (id === props.task.id) comments.value = result.comments
  } catch {
    if (id === props.task.id) comments.value = []
  } finally {
    if (id === props.task.id) commentsLoading.value = false
  }
}

function insertMention(username: string) {
  const prefix = commentText.value && !commentText.value.endsWith(' ') ? ' ' : ''
  commentText.value += `${prefix}@${username} `
}

function onCommentFiles(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files || [])
  for (const file of files) {
    if (file.size > 10 * 1024 * 1024) {
      Message.warning(`${file.name} 超过 10MB，已跳过`)
      continue
    }
    commentFiles.value.push(file)
  }
  input.value = ''
}

async function postComment() {
  const body = commentText.value.trim()
  if ((!body && !commentFiles.value.length) || commentBusy.value) return
  commentBusy.value = true
  try {
    const { comment } = await createTaskComment(props.task.id, body || '（附件）')
    if (commentFiles.value.length) {
      for (const file of commentFiles.value) {
        await uploadCommentAttachment(props.task.id, comment.id, file)
      }
      commentFiles.value = []
      await loadComments()
    } else {
      comments.value.push(comment)
    }
    commentText.value = ''
    Message.success('评论已发布')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '发表评论失败')
    await loadComments()
  } finally {
    commentBusy.value = false
  }
}

function attachmentURL(comment: TaskComment, attachment: CommentAttachment) {
  return `/api/admin/tasks/${props.task.id}/comments/${comment.id}/attachments/${attachment.id}`
}

function formatSize(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`
}

async function removeAttachment(comment: TaskComment, attachment: CommentAttachment) {
  try {
    await deleteCommentAttachment(props.task.id, comment.id, attachment.id)
    comment.attachments = comment.attachments.filter((item) => item.id !== attachment.id)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '删除附件失败')
  }
}

function startEditComment(comment: TaskComment) {
  editingCommentId.value = comment.id
  editingCommentText.value = comment.body
}

function cancelEditComment() {
  editingCommentId.value = 0
  editingCommentText.value = ''
}

async function saveEditedComment(comment: TaskComment) {
  const body = editingCommentText.value.trim()
  if (!body) return
  try {
    const result = await updateTaskComment(props.task.id, comment.id, body)
    const index = comments.value.findIndex((item) => item.id === comment.id)
    if (index >= 0) comments.value[index] = { ...comments.value[index], ...result.comment, attachments: comments.value[index].attachments }
    cancelEditComment()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '编辑评论失败')
  }
}

function isImageAttachment(attachment: CommentAttachment) {
  return attachment.contentType.startsWith('image/')
}

async function removeComment(comment: TaskComment) {
  try {
    await deleteTaskComment(props.task.id, comment.id)
    comments.value = comments.value.filter((item) => item.id !== comment.id)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '删除评论失败')
  }
}

function formatCommentTime(value: string) {
  const time = new Date(value).getTime()
  const diff = Date.now() - time
  if (diff < 60000) return '刚刚'
  if (diff < 3600000) return `${Math.floor(diff / 60000)} 分钟前`
  if (diff < 86400000) return `${Math.floor(diff / 3600000)} 小时前`
  return new Date(value).toLocaleDateString('zh-CN')
}

function snapshotDraft() {
  return JSON.stringify({
    title: draft.title.trim(),
    notes: draft.notes,
    listId: draft.listId,
    priority: draft.priority,
    due: duePayload(),
    allDay: draft.allDay,
    completed: draft.completed,
    recurrence: draft.recurrence,
    reminderOffsets: draft.reminderOffsets,
    assignee: draft.assignee,
    tags: draft.tags,
    checklist: draft.checklist.filter((item) => item.title.trim() !== ''),
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
  const completing = draft.completed && !props.task.completed
  const payload = {
    title,
    notes: draft.notes,
    listId: draft.listId,
    priority: draft.priority,
    due: duePayload(),
    allDay: draft.allDay,
    completed: draft.completed,
    recurrence: draft.recurrence,
    reminderOffsets: draft.reminderOffsets,
    assignee: draft.assignee,
    tags: draft.tags,
    checklist: draft.checklist.filter((item) => item.title.trim() !== ''),
  }
  try {
    const { task } = await updateTask(props.task.id, payload)
    lastSaved = JSON.stringify({ ...payload, title, checklist: payload.checklist })
    if (completing && !task.completed && task.recurrence) {
      draft.completed = false
      const input = toDateInput(task)
      const [datePart, timePart] = input.split('T')
      draft.dueDate = datePart || ''
      draft.dueTime = task.allDay ? '09:00' : timePart || '09:00'
      draft.allDay = task.allDay
      Message.info(`已完成本次，下次 ${formatDue(task)}`)
    }
    emit('changed', task)
    saved.value = true
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存失败')
  } finally {
    saving.value = false
  }
}

function toggleCompleted() {
  if (props.readonly) return
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

function onRecurrenceChoice() {
  if (recurrenceChoice.value === 'custom') {
    draft.recurrence = customRule.value.trim()
  } else {
    draft.recurrence = recurrenceChoice.value
  }
  void save()
}

function onCustomRule() {
  draft.recurrence = customRule.value.trim()
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
  if (!props.readonly && snapshotDraft() !== lastSaved) void save()
})
</script>
