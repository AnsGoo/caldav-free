<template>
  <div class="tw-note-discussion-body">
    <section v-if="activities.length" class="tw-activity-section">
      <header class="tw-detail-section-head"><span>动态</span></header>
      <div class="tw-activity-list">
        <div v-for="activity in activities" :key="activity.id" class="tw-activity-row">
          <span class="tw-activity-dot" />
          <span class="tw-activity-text">
            <strong>{{ activity.displayName || activity.username }}</strong>
            {{ activity.detail }}
          </span>
          <small>{{ formatCommentTime(activity.createdAt) }}</small>
        </div>
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
              <a-textarea
                v-model="editingCommentText"
                class="tw-comment-input"
                :auto-size="{ minRows: 2, maxRows: 5 }"
                :max-length="4000"
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
        <a-textarea
          v-model="commentText"
          class="tw-comment-input"
          :auto-size="{ minRows: 2, maxRows: 5 }"
          :max-length="4000"
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
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { CommentAttachment, TaskActivity, TaskComment, TaskListMember } from '../../types'
import {
  createTaskComment,
  deleteCommentAttachment,
  deleteTaskComment,
  fetchTaskActivities,
  fetchTaskComments,
  fetchTaskListMembers,
  updateTaskComment,
  uploadCommentAttachment,
} from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  taskId: number
  listId: number
  readonly?: boolean
}>()

const activities = ref<TaskActivity[]>([])
const comments = ref<TaskComment[]>([])
const members = ref<TaskListMember[]>([])
const commentsLoading = ref(false)
const commentBusy = ref(false)
const commentText = ref('')
const commentFiles = ref<File[]>([])
const commentFileInput = ref<HTMLInputElement | null>(null)
const editingCommentId = ref(0)
const editingCommentText = ref('')

const mentionMembers = computed(() => members.value.slice(0, 6))

async function loadActivities() {
  const id = props.taskId
  if (!id) return
  try {
    const result = await fetchTaskActivities(id)
    if (id === props.taskId) activities.value = result.activities
  } catch {
    if (id === props.taskId) activities.value = []
  }
}

async function loadComments() {
  const id = props.taskId
  if (!id) return
  commentsLoading.value = true
  try {
    const result = await fetchTaskComments(id)
    if (id === props.taskId) comments.value = result.comments
  } catch {
    if (id === props.taskId) comments.value = []
  } finally {
    if (id === props.taskId) commentsLoading.value = false
  }
}

async function loadMembers() {
  try {
    const result = await fetchTaskListMembers(props.listId)
    members.value = result.members || []
  } catch {
    members.value = []
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
    const { comment } = await createTaskComment(props.taskId, body || '（附件）')
    if (commentFiles.value.length) {
      for (const file of commentFiles.value) {
        await uploadCommentAttachment(props.taskId, comment.id, file)
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
  return `/api/admin/tasks/${props.taskId}/comments/${comment.id}/attachments/${attachment.id}`
}

function formatSize(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`
}

async function removeAttachment(comment: TaskComment, attachment: CommentAttachment) {
  try {
    await deleteCommentAttachment(props.taskId, comment.id, attachment.id)
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
    const result = await updateTaskComment(props.taskId, comment.id, body)
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
    await deleteTaskComment(props.taskId, comment.id)
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

watch(
  () => props.taskId,
  () => {
    commentText.value = ''
    commentFiles.value = []
    editingCommentId.value = 0
    editingCommentText.value = ''
    void loadActivities()
    void loadComments()
  },
  { immediate: true },
)

onMounted(() => {
  void loadMembers()
})
</script>
