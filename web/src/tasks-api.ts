import { api } from './api'
import type { CalendarEvent, CalendarSource, ChecklistItem, SavedFilter, TaskFolder, TaskItem, TaskList, TaskStats, TaskTagCount, TaskWorkspaceData } from './types'

export type TaskView = 'all' | 'today' | 'next7' | 'inbox' | 'completed' | 'trash' | 'stats' | 'list' | 'filter'

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

export function fetchTaskReminders() {
  return api<{ tasks: TaskItem[] }>('/tasks/reminders')
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

export function fetchTaskStats(days = 30) {
  return api<{ stats: TaskStats }>(`/tasks/stats?days=${days}`)
}
