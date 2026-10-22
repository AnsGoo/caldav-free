import type { TaskItem } from './types'

export const PRIORITIES = [
  { value: 3, label: '高优先级', short: '高', color: '#e5533d' },
  { value: 2, label: '中优先级', short: '中', color: '#f0a020' },
  { value: 1, label: '低优先级', short: '低', color: '#4772fa' },
] as const

export const LIST_COLORS = [
  '#4772fa',
  '#2ea88a',
  '#f0a020',
  '#e5533d',
  '#a855f7',
  '#0ea5e9',
  '#ec4899',
  '#64748b',
]

export function startOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}

export function addDays(date: Date, days: number) {
  const copy = new Date(date)
  copy.setDate(copy.getDate() + days)
  return copy
}

export function startOfToday() {
  return startOfDay(new Date())
}

export function dayKey(value: Date | string) {
  const date = typeof value === 'string' ? new Date(value) : value
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

export function taskDayKey(task: TaskItem) {
  return task.due ? dayKey(new Date(task.due)) : ''
}

export function isOverdue(task: TaskItem) {
  if (!task.due || task.completed) return false
  const due = new Date(task.due)
  if (task.allDay) {
    return startOfDay(due).getTime() < startOfToday().getTime()
  }
  return due.getTime() < Date.now()
}

export function isToday(task: TaskItem) {
  if (!task.due) return false
  return dayKey(new Date(task.due)) === dayKey(new Date())
}

export function isTomorrow(task: TaskItem) {
  if (!task.due) return false
  return dayKey(new Date(task.due)) === dayKey(addDays(new Date(), 1))
}

export function isThisWeek(task: TaskItem) {
  if (!task.due) return false
  const due = startOfDay(new Date(task.due))
  const today = startOfToday()
  const end = addDays(today, 7)
  return due.getTime() >= addDays(today, 2).getTime() && due.getTime() < end.getTime()
}

export function isLater(task: TaskItem) {
  if (!task.due) return false
  return startOfDay(new Date(task.due)).getTime() >= addDays(startOfToday(), 7).getTime()
}

const WEEKDAYS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']

export function formatDue(task: TaskItem) {
  if (!task.due) return ''
  const due = new Date(task.due)
  const time = task.allDay
    ? ''
    : ` ${String(due.getHours()).padStart(2, '0')}:${String(due.getMinutes()).padStart(2, '0')}`
  const today = startOfToday()
  const diff = Math.round((startOfDay(due).getTime() - today.getTime()) / 86400000)
  if (diff < 0) {
    const sameYear = due.getFullYear() === today.getFullYear()
    return `${sameYear ? '' : `${due.getFullYear()}年`}${due.getMonth() + 1}月${due.getDate()}日`
  }
  if (diff === 0) return `今天${time}`
  if (diff === 1) return `明天${time}`
  if (diff === 2) return `后天${time}`
  if (diff > 2 && diff < 7) return `${WEEKDAYS[due.getDay()]}${time}`
  const sameYear = due.getFullYear() === today.getFullYear()
  return `${sameYear ? '' : `${due.getFullYear()}年`}${due.getMonth() + 1}月${due.getDate()}日${time}`
}

export interface TaskGroup {
  key: string
  label: string
  tone?: 'overdue' | 'today' | 'done'
  tasks: TaskItem[]
}

export function groupTasks(tasks: TaskItem[], view: string): TaskGroup[] {
  const groups: TaskGroup[] = []
  const open = tasks.filter((task) => !task.completed)
  const done = tasks.filter((task) => task.completed)
  const push = (key: string, label: string, items: TaskItem[], tone?: TaskGroup['tone']) => {
    if (items.length) groups.push({ key, label, tasks: items, tone })
  }
  if (view === 'completed') {
    push('done', '已完成', done, 'done')
    return groups
  }
  const overdue = open.filter(isOverdue)
  const today = open.filter((task) => !isOverdue(task) && isToday(task))
  const tomorrow = open.filter(isTomorrow)
  const week = open.filter(isThisWeek)
  const later = open.filter(isLater)
  const none = open.filter((task) => !task.due)
  push('overdue', '已过期', overdue, 'overdue')
  push('today', '今天', today, 'today')
  if (view === 'all' || view === 'list' || view === 'inbox') {
    push('tomorrow', '明天', tomorrow, 'today')
    push('week', '最近 7 天', week)
    push('later', '以后', later)
    push('none', '无日期', none)
  }
  if (view === 'today') {
    push('none', '无日期', none)
  }
  push('done', `已完成`, done, 'done')
  return groups
}

export interface QuickHint {
  date?: string
  time?: string
  tags: string[]
  priority: number
}

const HINT_DATE = /(今天|明天|后天|大后天|今晚|明晚|本周[一二三四五六日天]|下周[一二三四五六日天]|周[一二三四五六日天]|星期[一二三四五六日天]|\d{1,2}\s*月\s*\d{1,2}\s*[日号]?|\d{4}\s*[-/.]\s*\d{1,2}\s*[-/.]\s*\d{1,2})/
const HINT_TIME = /(凌晨|早上|早晨|上午|中午|下午|傍晚|晚上)?\s*\d{1,2}\s*(?:[:：]\s*\d{1,2}|点\s*(?:半|\d{1,2}\s*分?)?)/

export function quickHint(text: string): QuickHint | null {
  if (!text.trim()) return null
  const hint: QuickHint = { tags: [], priority: 0 }
  const date = text.match(HINT_DATE)
  if (date) hint.date = date[0].replace(/\s+/g, '')
  const time = text.match(HINT_TIME)
  if (time) hint.time = time[0].trim().replace(/\s+/g, '')
  const tags = text.match(/#([^\s#!！]+)/g)
  if (tags) hint.tags = tags.map((tag) => tag.slice(1))
  const priority = text.match(/[!！]{1,3}/)
  if (priority) hint.priority = priority[0].length
  if (!hint.date && !hint.time && !hint.tags.length && !hint.priority) return null
  return hint
}

export function toDateInput(task: Pick<TaskItem, 'due' | 'allDay'>) {
  if (!task.due) return ''
  const date = new Date(task.due)
  const pad = (value: number) => String(value).padStart(2, '0')
  if (task.allDay) {
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
  }
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

export function fromDateInput(value: string, allDay: boolean) {
  if (!value) return ''
  if (allDay) return `${value}T00:00:00`
  return value.length === 16 ? `${value}:00` : value
}
