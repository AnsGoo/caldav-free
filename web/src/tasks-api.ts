import { api, apiForm, getCSRFToken, notifyUnauthorized } from './api'
import type { AIChatReply, AISettings, AppNotification, CalendarEvent, CalendarSource, ChecklistItem, CommentAttachment, CountdownDraft, CountdownItem, FocusDashboard, FocusPreference, FocusRangeStats, FocusSession, FocusSessionDraft, FocusTimerDraft, FocusTimerView, HabitCalendarEntry, HabitDetail, HabitFocusSession, HabitItem, HabitListData, HabitPreference, HabitPublicShare, HabitRecord, HabitSection, HabitShareLink, MatrixRuleMode, MatrixRuleTemplate, MatrixView, MatrixViewRules, SavedFilter, SharedTaskList, SummaryDocument, TaskActivity, TaskComment, TaskFolder, TaskItem, TaskList, TaskListMember, TaskListShare, TaskStats, TaskSummaryData, TaskTagCount, TaskTemplate, TaskWorkspaceData } from './types'

export type TaskView = 'all' | 'today' | 'next7' | 'inbox' | 'completed' | 'trash' | 'stats' | 'summary' | 'ai' | 'list' | 'filter' | 'shared' | 'matrix' | 'habit' | 'focus' | 'countdown'

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

export function setTaskTagColor(tag: string, color: string) {
  return api<{ tags: TaskTagCount[] }>('/task-tags/color', {
    method: 'PUT',
    body: JSON.stringify({ tag, color }),
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

export function snoozeEventNotification(id: number, minutes = 10) {
  return api<{ snooze: { id: number; remindAt: string }; unread: number }>(`/notifications/${id}/snooze`, {
    method: 'POST',
    body: JSON.stringify({ minutes }),
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

export function fetchTaskActivities(taskId: number) {
  return api<{ activities: TaskActivity[] }>(`/tasks/${taskId}/activities`)
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

export function updateTaskComment(taskId: number, commentId: number, body: string) {
  return api<{ comment: TaskComment }>(`/tasks/${taskId}/comments/${commentId}`, {
    method: 'PATCH',
    body: JSON.stringify({ body }),
  })
}

export function deleteTaskComment(taskId: number, commentId: number) {
  return api<void>(`/tasks/${taskId}/comments/${commentId}`, { method: 'DELETE' })
}

export function uploadCommentAttachment(taskId: number, commentId: number, file: File) {
  const form = new FormData()
  form.append('file', file)
  return apiForm<{ attachment: CommentAttachment }>(`/tasks/${taskId}/comments/${commentId}/attachments`, form)
}

export function deleteCommentAttachment(taskId: number, commentId: number, attachmentId: number) {
  return api<void>(`/tasks/${taskId}/comments/${commentId}/attachments/${attachmentId}`, { method: 'DELETE' })
}

export function createMatrixView(name: string, mode: MatrixRuleMode, rules?: MatrixViewRules) {
  return api<{ view: MatrixView }>('/task-matrix-views', {
    method: 'POST',
    body: JSON.stringify({ name, mode, rules }),
  })
}

export function updateMatrixView(id: number, payload: { name?: string; mode?: MatrixRuleMode; rules?: MatrixViewRules; order?: number }) {
  return api<{ view: MatrixView }>(`/task-matrix-views/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  })
}

export function deleteMatrixView(id: number) {
  return api<void>(`/task-matrix-views/${id}`, { method: 'DELETE' })
}

export function fetchMatrixRuleTemplates() {
  return api<{ templates: MatrixRuleTemplate[] }>('/task-matrix-templates')
}

export function createMatrixRuleTemplate(name: string, rules: MatrixViewRules) {
  return api<{ template: MatrixRuleTemplate }>('/task-matrix-templates', {
    method: 'POST',
    body: JSON.stringify({ name, rules }),
  })
}

export function updateMatrixRuleTemplate(id: number, payload: { name?: string; rules?: MatrixViewRules }) {
  return api<{ template: MatrixRuleTemplate }>(`/task-matrix-templates/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  })
}

export function deleteMatrixRuleTemplate(id: number) {
  return api<void>(`/task-matrix-templates/${id}`, { method: 'DELETE' })
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
  attendees?: string[]
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

export function fetchAIModels(payload: { provider?: string; baseUrl?: string; apiKey?: string }) {
  return api<{ models: string[] }>('/tasks/ai/models', {
    method: 'POST',
    body: JSON.stringify(payload),
  })
}

export function saveAISettings(payload: { provider?: string; baseUrl: string; model: string; apiKey?: string; clearKey?: boolean }) {
  return api<AISettings>('/tasks/ai/settings', {
    method: 'PUT',
    body: JSON.stringify(payload),
  })
}

export function testAIModel(payload: { provider?: string; baseUrl?: string; apiKey?: string; model: string; mode?: 'chat' | 'tools' }) {
  return api<{ ok: boolean; model: string; latencyMs: number; sample: string; toolsSupported?: boolean }>('/tasks/ai/test', {
    method: 'POST',
    body: JSON.stringify(payload),
  })
}

export function sendAIChat(messages: Array<{ role: string; content: string }>, timezone: string, model?: string) {
  return api<AIChatReply>('/tasks/ai/chat', {
    method: 'POST',
    body: JSON.stringify({ messages, timezone, model }),
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


export function fetchHabits(archived = false) {
  return api<HabitListData>(`/habits${archived ? '?archived=1' : ''}`)
}

export function createHabit(payload: Partial<HabitItem>) {
  return api<{ habit: HabitItem }>('/habits', { method: 'POST', body: JSON.stringify(payload) })
}

export function updateHabit(id: number, payload: Partial<HabitItem>) {
  return api<{ habit: HabitItem }>(`/habits/${id}`, { method: 'PATCH', body: JSON.stringify(payload) })
}

export function deleteHabit(id: number) {
  return api<void>(`/habits/${id}`, { method: 'DELETE' })
}

export function reorderHabits(ids: number[]) {
  return api<void>('/habits/reorder', { method: 'POST', body: JSON.stringify({ ids }) })
}

export function toggleHabitCheckin(id: number, stamp?: number, value?: number) {
  return api<{ checkin: import('./types').HabitCheckin | null; habit: HabitItem; detail: HabitDetail }>(`/habits/${id}/checkin`, {
    method: 'POST',
    body: JSON.stringify({ stamp, value }),
  })
}

export function saveHabitFocus(id: number, payload: { minutes: number; startedAt?: string; completedAt?: string }) {
  return api<{ session: HabitFocusSession }>(`/habits/${id}/focus`, { method: 'POST', body: JSON.stringify(payload) })
}

export function fetchHabitDetail(id: number, month: string) {
  return api<HabitDetail>(`/habits/${id}/detail?month=${encodeURIComponent(month)}`)
}

export function createHabitShare(id: number) {
  return api<{ share: HabitShareLink }>(`/habits/${id}/share`, { method: 'POST' })
}

export function revokeHabitShare(id: number) {
  return api<void>(`/habits/${id}/share`, { method: 'DELETE' })
}

export async function fetchPublicHabitShare(token: string): Promise<HabitPublicShare> {
  const response = await fetch(`/api/public/habit-shares/${encodeURIComponent(token)}`, { credentials: 'same-origin' })
  const text = await response.text()
  let payload: unknown = null
  if (text) {
    try {
      payload = JSON.parse(text)
    } catch {
      payload = text
    }
  }
  if (!response.ok) {
    const message = payload && typeof payload === 'object' && 'error' in payload
      ? String((payload as { error: unknown }).error)
      : `请求失败（${response.status}）`
    throw new Error(message)
  }
  return (payload as { share: HabitPublicShare }).share
}

export function createHabitRecord(id: number, payload: { content: string; emoji?: string; stamp?: number }) {
  return api<{ record: HabitRecord }>(`/habits/${id}/records`, { method: 'POST', body: JSON.stringify(payload) })
}

export function updateHabitRecord(id: number, recordId: number, payload: { content?: string; emoji?: string }) {
  return api<{ record: HabitRecord }>(`/habits/${id}/records/${recordId}`, { method: 'PATCH', body: JSON.stringify(payload) })
}

export function deleteHabitRecord(id: number, recordId: number) {
  return api<void>(`/habits/${id}/records/${recordId}`, { method: 'DELETE' })
}

export function fetchHabitPreferences() {
  return api<HabitPreference>('/habit-preferences')
}

export function saveHabitPreferences(payload: Partial<HabitPreference>) {
  return api<HabitPreference>('/habit-preferences', { method: 'PATCH', body: JSON.stringify(payload) })
}

export function importDidaHabits(file: File, mode: 'append' | 'skip' | 'overwrite' = 'append') {
  const form = new FormData()
  form.append('file', file)
  return apiForm<{ habits: number; checkins: number; records: number; updated: number; skipped: number }>(
    `/habits/import-dida?mode=${encodeURIComponent(mode)}`,
    form,
  )
}

export function importHabitsBackup(payload: unknown, mode: 'append' | 'skip' | 'overwrite' = 'append') {
  return api<{ habits: number; checkins: number; records: number; updated: number; skipped: number }>(
    `/habits/import?mode=${encodeURIComponent(mode)}`,
    { method: 'POST', body: JSON.stringify(payload) },
  )
}

export function createHabitSection(name: string) {
  return api<{ section: HabitSection }>('/habit-sections', { method: 'POST', body: JSON.stringify({ name }) })
}

export function updateHabitSection(id: number, payload: { name?: string; sortOrder?: number }) {
  return api<{ section: HabitSection }>(`/habit-sections/${id}`, { method: 'PATCH', body: JSON.stringify(payload) })
}

export function deleteHabitSection(id: number) {
  return api<void>(`/habit-sections/${id}`, { method: 'DELETE' })
}


export function fetchHabitCalendar(from: string, to: string) {
  return api<{ entries: HabitCalendarEntry[] }>(`/habits/calendar?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`)
}


export function fetchFocusDashboard() {
  return api<FocusDashboard>('/focus')
}

export function saveFocusPreferences(payload: FocusPreference) {
  return api<{ preferences: FocusPreference }>('/focus/preferences', { method: 'PATCH', body: JSON.stringify(payload) })
}

export function createFocusSession(payload: FocusSessionDraft) {
  return api<{ session: FocusSession }>('/focus/sessions', { method: 'POST', body: JSON.stringify(payload) })
}

export function deleteFocusSession(id: number) {
  return api<void>(`/focus/sessions/${id}`, { method: 'DELETE' })
}


export function fetchFocusTimer() {
  return api<{ timer: FocusTimerView | null; serverNow: string }>('/focus/timer')
}

export function saveFocusTimer(payload: FocusTimerDraft) {
  return api<{ timer: FocusTimerView; serverNow: string }>('/focus/timer', { method: 'PUT', body: JSON.stringify(payload) })
}

export function clearFocusTimer() {
  return api<void>('/focus/timer', { method: 'DELETE' })
}


export function fetchFocusStats(days: number) {
  return api<FocusRangeStats>(`/focus/stats?days=${days}`)
}


export function fetchCountdowns(archived = false) {
  return api<{ countdowns: CountdownItem[] }>(`/countdowns${archived ? '?archived=1' : ''}`)
}

export function createCountdown(payload: CountdownDraft) {
  return api<{ countdown: CountdownItem }>('/countdowns', { method: 'POST', body: JSON.stringify(payload) })
}

export function updateCountdown(id: number, patch: Partial<CountdownDraft>) {
  return api<{ countdown: CountdownItem }>(`/countdowns/${id}`, { method: 'PATCH', body: JSON.stringify(patch) })
}

export function deleteCountdown(id: number) {
  return api<void>(`/countdowns/${id}`, { method: 'DELETE' })
}

export function reorderCountdowns(ids: number[]) {
  return api<void>('/countdowns/reorder', { method: 'POST', body: JSON.stringify({ ids }) })
}

export function uploadCountdownBackground(id: number, file: File) {
  const form = new FormData()
  form.append('file', file)
  return apiForm<{ ok: boolean }>(`/countdowns/${id}/background`, form)
}

export function deleteCountdownBackground(id: number) {
  return api<void>(`/countdowns/${id}/background`, { method: 'DELETE' })
}

export function fetchTaskTemplates() {
  return api<{ templates: TaskTemplate[] }>('/task-templates')
}

export function createTaskTemplate(name: string, payload: string) {
  return api<{ template: TaskTemplate }>('/task-templates', {
    method: 'POST',
    body: JSON.stringify({ name, payload }),
  })
}

export function deleteTaskTemplate(id: number) {
  return api<void>(`/task-templates/${id}`, { method: 'DELETE' })
}

export async function streamAIChat(
  messages: Array<{ role: string; content: string }>,
  timezone: string,
  model: string | undefined,
  onDelta: (text: string) => void,
  onDone: (reply: AIChatReply) => void,
) {
  const response = await fetch('/api/admin/tasks/ai/chat/stream', {
    method: 'POST',
    credentials: 'same-origin',
    headers: {
      'Content-Type': 'application/json',
      ...(getCSRFToken() ? { 'X-CSRF-Token': getCSRFToken() } : {}),
    },
    body: JSON.stringify({ messages, timezone, model }),
  })
  if (response.status === 401) notifyUnauthorized()
  if (!response.ok) {
    const text = await response.text()
    let message = `请求失败（${response.status}）`
    try {
      const payload = JSON.parse(text) as { error?: string }
      if (payload.error) message = payload.error
    } catch {
      if (text.trim()) message = text.trim().slice(0, 300)
    }
    throw new Error(message)
  }
  if (!response.body) throw new Error('当前浏览器不支持流式响应')
  const reader = response.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    buffer += decoder.decode(value, { stream: true })
    let boundary = buffer.indexOf('\n\n')
    while (boundary >= 0) {
      const block = buffer.slice(0, boundary)
      buffer = buffer.slice(boundary + 2)
      for (const line of block.split('\n')) {
        if (!line.startsWith('data:')) continue
        const data = line.slice(5).trim()
        if (!data) continue
        const event = JSON.parse(data) as { type?: string; text?: string; error?: string } & AIChatReply
        if (event.type === 'delta' && event.text) onDelta(event.text)
        else if (event.type === 'error') throw new Error(event.error || 'AI 请求失败')
        else if (event.type === 'done') onDone(event)
      }
      boundary = buffer.indexOf('\n\n')
    }
  }
}
