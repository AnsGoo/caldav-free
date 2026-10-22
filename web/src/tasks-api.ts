import { api } from './api'
import type { ChecklistItem, TaskItem, TaskList, TaskWorkspaceData } from './types'

export type TaskView = 'all' | 'today' | 'next7' | 'inbox' | 'completed' | 'list'

export function browserTimezone() {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Shanghai'
  } catch {
    return 'Asia/Shanghai'
  }
}

export function fetchTaskWorkspace(params: { view: TaskView; listId?: number; q?: string }) {
  const query = new URLSearchParams()
  query.set('view', params.view)
  if (params.listId) query.set('listId', String(params.listId))
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

export function createTaskList(name: string, color: string) {
  return api<{ list: TaskList }>('/task-lists', {
    method: 'POST',
    body: JSON.stringify({ name, color }),
  })
}

export function updateTaskList(id: number, patch: { name?: string; color?: string; order?: number }) {
  return api<{ list: TaskList }>(`/task-lists/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  })
}

export function deleteTaskList(id: number) {
  return api<void>(`/task-lists/${id}`, { method: 'DELETE' })
}
