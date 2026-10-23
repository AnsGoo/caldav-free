import { api } from './api'
import type { AIChatReply, AISettings, AppNotification, CalendarEvent, CalendarSource, ChecklistItem, SavedFilter, SharedTaskList, SummaryDocument, TaskComment, TaskFolder, TaskItem, TaskList, TaskListMember, TaskListShare, TaskStats, TaskSummaryData, TaskTagCount, TaskWorkspaceData } from './types'

export type TaskView = 'all' | 'today' | 'next7' | 'inbox' | 'completed' | 'trash' | 'stats' | 'summary' | 'ai' | 'list' | 'filter' | 'shared'

export function browserTimezone() {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Shanghai'
  } catch {
    return 'Asia/Shanghai'
  }
}

export function fetchTaskWorkspace(params: { view: TaskView; listId?: number; filterId?: number; q?: string }) {
  const query = new URLSearchParams()
  query.set('view', params.view)
  if (params.listId) query.set('listId', String(params.listId))
  if (params.filterId) query.set('filterId', String(params.filterId))
  if (params.q) query.set('q', params.q)
  return api<TaskWorkspaceData>(`/tasks?${query.toString()}`)
}

export interface TaskDraft {
  title?: string
  text?: string
  listId?: number
  notes?: string
  priority?: number
  due?: string
  allDay?: boolean
  completed?: boolean
  tags?: string[]
  checklist?: ChecklistItem[]
  recurrence?: string
  reminderOffset?: number
  reminderOffsets?: number[]
  assignee?: string
  timezone?: string
}

export function createTask(draft: TaskDraft) {
  return api<{ task: TaskItem }>('/tasks', {
    method: 'POST',
    body: JSON.stringify({ timezone: browserTimezone(), ...draft }),
  })
}

export function updateTask(id: number, draft: TaskDraft) {
  return api<{ task: TaskItem }>(`/tasks/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ timezone: browserTimezone(), ...draft }),
  })
}

export function deleteTask(id: number) {
  return api<void>(`/tasks/${id}`, { method: 'DELETE' })
}

export function createTaskList(name: string, color: string, folderId?: number) {
  return api<{ list: TaskList }>('/task-lists', {
    method: 'POST',
    body: JSON.stringify({ name, color, folderId: folderId || 0 }),
  })
}

export function updateTaskList(id: number, patch: { name?: string; color?: string; order?: number; folderId?: number }) {
  return api<{ list: TaskList }>(`/task-lists/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  })
}

export function createTaskFolder(name: string) {
  return api<{ folder: TaskFolder }>('/task-folders', {
    method: 'POST',
    body: JSON.stringify({ name }),
  })
}

export function updateTaskFolder(id: number, patch: { name?: string; order?: number }) {
  return api<{ folder: TaskFolder }>(`/task-folders/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  })
}

export function deleteTaskFolder(id: number) {
  return api<void>(`/task-folders/${id}`, { method: 'DELETE' })
}

export function createSavedFilter(payload: { name: string; color?: string; conditions: unknown }) {
  return api<{ filter: SavedFilter }>('/task-filters', {
    method: 'POST',
    body: JSON.stringify(payload),
  })
}

export function updateSavedFilter(id: number, payload: { name?: string; color?: string; conditions?: unknown; order?: number }) {
  return api<{ filter: SavedFilter }>(`/task-filters/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  })
}

export function deleteSavedFilter(id: number) {
  return api<void>(`/task-filters/${id}`, { method: 'DELETE' })
}

export function fetchTaskTags() {
  return api<{ tags: TaskTagCount[] }>('/task-tags')
}

export function renameTaskTag(from: string, to: string) {
  return api<{ tags: TaskTagCount[] }>('/task-tags/rename', {
    method: 'POST',
    body: JSON.stringify({ from, to }),
  })
}

export function deleteTaskTag(tag: string) {
  return api<{ tags: TaskTagCount[] }>('/task-tags/delete', {
    method: 'POST',
    body: JSON.stringify({ tag }),
  })
}

export function deleteTaskList(id: number) {
  return api<void>(`/task-lists/${id}`, { method: 'DELETE' })
}

export function fetchNotifications() {
  return api<{ notifications: AppNotification[]; unread: number }>('/notifications')
}

export function markNotificationRead(id: number) {
  return api<{ unread: number }>('/notifications/read', {
    method: 'POST',
    body: JSON.stringify({ id }),
  })
}

export function markAllNotificationsRead() {
  return api<{ unread: number }>('/notifications/read', {
    method: 'POST',
    body: JSON.stringify({ all: true }),
  })
}

export function fetchSharedTasks(listId: number) {
  return api<{ list: SharedTaskList; tasks: TaskItem[] }>(`/tasks/shared?listId=${listId}`)
}

export function fetchTaskComments(taskId: number) {
  return api<{ comments: TaskComment[] }>(`/tasks/${taskId}/comments`)
}

export function createTaskComment(taskId: number, body: string) {
  return api<{ comment: TaskComment }>(`/tasks/${taskId}/comments`, {
    method: 'POST',
    body: JSON.stringify({ body }),
  })
}

export function deleteTaskComment(taskId: number, commentId: number) {
  return api<void>(`/tasks/${taskId}/comments/${commentId}`, { method: 'DELETE' })
}

export function fetchTaskListMembers(listId: number) {
  return api<{ members: TaskListMember[] }>(`/task-lists/${listId}/members`)
}

export function fetchTaskListShares(listId: number) {
  return api<{ shares: TaskListShare[] }>(`/task-lists/${listId}/shares`)
}

export function createTaskListShare(listId: number, username: string, role: 'viewer' | 'editor' = 'viewer') {
  return api<{ share: TaskListShare }>(`/task-lists/${listId}/shares`, {
    method: 'POST',
    body: JSON.stringify({ username, role }),
  })
}

export function deleteTaskListShare(listId: number, userId: number) {
  return api<void>(`/task-lists/${listId}/shares/${userId}`, { method: 'DELETE' })
}

export function fetchTaskReminders() {
  return api<{ tasks: TaskItem[] }>('/tasks/reminders')
}

export function fetchPushPublicKey() {
  return api<{ publicKey: string }>('/tasks/push/public-key')
}

export function fetchPushSubscriptions() {
  return api<{ count: number; subscribed: boolean }>('/tasks/push/subscriptions')
}

export function savePushSubscription(subscription: PushSubscriptionJSON) {
  return api<{ subscribed: boolean }>('/tasks/push/subscribe', {
    method: 'POST',
    body: JSON.stringify(subscription),
  })
}

export function deletePushSubscription(endpoint: string) {
  return api<{ subscribed: boolean }>('/tasks/push/subscribe', {
    method: 'DELETE',
    body: JSON.stringify({ endpoint }),
  })
}

export function restoreTask(id: number) {
  return api<{ task: TaskItem }>(`/tasks/${id}/restore`, { method: 'POST' })
}

export function purgeTask(id: number) {
  return api<void>(`/tasks/${id}/purge`, { method: 'DELETE' })
}

export function emptyTaskTrash() {
  return api<void>('/tasks/trash', { method: 'DELETE' })
}

export type BatchAction = 'complete' | 'uncomplete' | 'move' | 'delete'

export function batchTasks(ids: number[], action: BatchAction, listId?: number) {
  return api<{ updated: number }>('/tasks/batch', {
    method: 'POST',
    body: JSON.stringify({ ids, action, listId }),
  })
}

export function reorderTasks(ids: number[]) {
  return api<void>('/tasks/reorder', {
    method: 'POST',
    body: JSON.stringify({ ids }),
  })
}

export function fetchCalendarEvents(from: Date, to: Date) {
  const query = new URLSearchParams({ from: from.toISOString(), to: to.toISOString() })
  return api<{ calendars: CalendarSource[]; events: CalendarEvent[] }>(`/tasks/calendar?${query.toString()}`)
}

export interface CalendarEventInput {
  summary: string
  location?: string
  description?: string
  start: string
  end: string
  allDay: boolean
  rrule?: string
  count?: number
  recurrenceId?: string
  scope?: 'single' | 'series'
  reminders?: number[]
}

export function createCalendarEvent(calendarId: number, payload: CalendarEventInput) {
  return api<{ event: CalendarEvent }>(`/calendars/${calendarId}/events`, {
    method: 'POST',
    body: JSON.stringify(payload),
  })
}

export function updateCalendarEvent(calendarId: number, href: string, payload: CalendarEventInput) {
  return api<{ event: CalendarEvent; data: string }>(`/calendars/${calendarId}/events/${encodeURIComponent(href)}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  })
}

export function deleteCalendarEvent(calendarId: number, href: string, recurrenceId?: string) {
  const query = recurrenceId ? `?recurrenceId=${encodeURIComponent(recurrenceId)}` : ''
  return api<void>(`/calendars/${calendarId}/events/${encodeURIComponent(href)}${query}`, { method: 'DELETE' })
}

export function fetchTaskStats(days = 30) {
  return api<{ stats: TaskStats }>(`/tasks/stats?days=${days}`)
}

export function fetchAISettings() {
  return api<AISettings>('/tasks/ai/settings')
}

export function saveAISettings(payload: { baseUrl: string; model: string; apiKey?: string; clearKey?: boolean }) {
  return api<AISettings>('/tasks/ai/settings', {
    method: 'PUT',
    body: JSON.stringify(payload),
  })
}

export function sendAIChat(messages: Array<{ role: string; content: string }>, timezone: string) {
  return api<AIChatReply>('/tasks/ai/chat', {
    method: 'POST',
    body: JSON.stringify({ messages, timezone }),
  })
}

export function fetchTaskSummary(params: {
  from: Date
  to: Date
  listId?: number
  status?: string
  priority?: number
  tag?: string
  includeNext?: boolean
}) {
  const query = new URLSearchParams({
    from: params.from.toISOString(),
    to: params.to.toISOString(),
  })
  if (params.listId) query.set('listId', String(params.listId))
  if (params.status && params.status !== 'all') query.set('status', params.status)
  if (params.priority) query.set('priority', String(params.priority))
  if (params.tag) query.set('tag', params.tag)
  if (params.includeNext) query.set('includeNext', '1')
  return api<TaskSummaryData>(`/tasks/summary?${query.toString()}`)
}

export function fetchSummaryDocuments(kind?: 'template' | 'history') {
  const query = kind ? `?kind=${kind}` : ''
  return api<{ documents: SummaryDocument[] }>(`/task-summary-documents${query}`)
}

export function createSummaryDocument(payload: { kind: 'template' | 'history'; name: string; content: string }) {
  return api<{ document: SummaryDocument }>('/task-summary-documents', {
    method: 'POST',
    body: JSON.stringify(payload),
  })
}

export function updateSummaryDocument(id: number, payload: { name?: string; content: string }) {
  return api<{ document: SummaryDocument }>(`/task-summary-documents/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  })
}

export function deleteSummaryDocument(id: number) {
  return api<void>(`/task-summary-documents/${id}`, { method: 'DELETE' })
}

export function optimizeSummary(title: string, text: string) {
  return api<{ markdown: string; model: string }>('/tasks/summary/optimize', {
    method: 'POST',
    body: JSON.stringify({ title, text }),
  })
}

export interface EmailNotificationSettings {
  enabled: boolean
  host: string
  port: number
  username: string
  from: string
  security: 'starttls' | 'tls' | 'none'
  passwordSet: boolean
  recipientEmail: string
}

export interface EmailNotificationSettingsInput extends Omit<EmailNotificationSettings, 'passwordSet' | 'recipientEmail'> {
  password?: string
  clearPassword?: boolean
}

export function fetchEmailSettings() {
  return api<EmailNotificationSettings>('/tasks/notifications/email')
}

export function saveEmailSettings(settings: EmailNotificationSettingsInput) {
  return api<EmailNotificationSettings>('/tasks/notifications/email', {
    method: 'PUT',
    body: JSON.stringify(settings),
  })
}

export function testEmail() {
  return api<{ sent: boolean; to: string }>('/tasks/notifications/email/test', { method: 'POST' })
}
