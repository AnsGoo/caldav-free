import { dayKey, startOfToday } from './tasks-utils'
import type {
  MatrixCondition,
  MatrixDueRule,
  MatrixQuadrantKey,
  MatrixQuadrantRule,
  MatrixViewRules,
  TaskItem,
} from './types'

export const MATRIX_QUADRANTS: { id: MatrixQuadrantKey; label: string; color: string }[] = [
  { id: 'q1', label: '重要且紧急', color: '#ff5f68' },
  { id: 'q2', label: '重要不紧急', color: '#ffb000' },
  { id: 'q3', label: '不重要但紧急', color: '#4772fa' },
  { id: 'q4', label: '不重要不紧急', color: '#0cce9c' },
]

export function emptyMatrixCondition(): MatrixCondition {
  return { priorities: [], due: 'any', listId: 0, tag: '', assignee: '' }
}

export function emptyMatrixRule(name = '', color = ''): MatrixQuadrantRule {
  return { name, color, match: 'all', groups: [emptyMatrixCondition()] }
}

export function clearMatrixConditions(rule: MatrixQuadrantRule) {
  rule.match = 'all'
  rule.groups = [emptyMatrixCondition()]
}

export function defaultMatrixRules(): MatrixViewRules {
  return {
    q1: { name: '重要且紧急', color: '#ff5f68', match: 'all', groups: [{ priorities: [2, 3], due: 'urgent', listId: 0, tag: '', assignee: '' }] },
    q2: { name: '重要不紧急', color: '#ffb000', match: 'all', groups: [{ priorities: [2, 3], due: 'any', listId: 0, tag: '', assignee: '' }] },
    q3: { name: '不重要但紧急', color: '#4772fa', match: 'all', groups: [{ priorities: [0, 1], due: 'urgent', listId: 0, tag: '', assignee: '' }] },
    q4: { name: '不重要不紧急', color: '#0cce9c', match: 'all', groups: [emptyMatrixCondition()] },
  }
}

// Rules saved before condition groups existed used flat fields.
type LegacyQuadrantRule = Partial<MatrixQuadrantRule> & Partial<MatrixCondition>

function normalizeColor(value: unknown, fallback: string) {
  if (typeof value !== 'string') return fallback
  const color = value.trim()
  return /^#[0-9a-f]{3,8}$/i.test(color) ? color : fallback
}

function normalizeCondition(input?: Partial<MatrixCondition>): MatrixCondition {
  return {
    priorities: Array.isArray(input?.priorities)
      ? Array.from(new Set(input.priorities.map(Number).filter((value) => value >= 0 && value <= 3))).sort((a, b) => b - a)
      : [],
    due: isDueRule(input?.due) ? input.due : 'any',
    listId: Number(input?.listId) || 0,
    tag: typeof input?.tag === 'string' ? input.tag : '',
    assignee: typeof input?.assignee === 'string' ? input.assignee : '',
  }
}

export function normalizeMatrixRules(input?: Partial<MatrixViewRules> | null): MatrixViewRules {
  const fallback = defaultMatrixRules()
  const output = {} as MatrixViewRules
  for (const key of ['q1', 'q2', 'q3', 'q4'] as MatrixQuadrantKey[]) {
    const raw = input?.[key] as LegacyQuadrantRule | undefined
    const base = raw || fallback[key]
    const groups = Array.isArray(raw?.groups) && raw.groups.length
      ? raw.groups.slice(0, 12).map((group) => normalizeCondition(group))
      : [normalizeCondition(raw)]
    output[key] = {
      name: typeof base.name === 'string' && base.name.trim() ? base.name.trim().slice(0, 12) : fallback[key].name,
      color: normalizeColor(base.color, fallback[key].color),
      match: base.match === 'any' ? 'any' : 'all',
      groups,
    }
  }
  return output
}

function isDueRule(value: unknown): value is MatrixCondition['due'] {
  return ['any', 'urgent', 'overdue', 'today', 'tomorrow', 'next7', 'later', 'none'].includes(String(value))
}

function matchesDue(task: TaskItem, rule: MatrixCondition['due'], today: Date) {
  if (rule === 'any') return true
  if (!task.due) return rule === 'none'
  const key = dayKey(new Date(task.due))
  const todayKey = dayKey(today)
  const tomorrow = new Date(today)
  tomorrow.setDate(tomorrow.getDate() + 1)
  const next7 = new Date(today)
  next7.setDate(next7.getDate() + 7)
  switch (rule) {
    case 'overdue':
      return key < todayKey
    case 'today':
      return key === todayKey
    case 'tomorrow':
      return key === dayKey(tomorrow)
    case 'urgent':
      return key <= dayKey(tomorrow)
    case 'next7':
      return key >= todayKey && key <= dayKey(next7)
    case 'later':
      return key > dayKey(next7)
    case 'none':
      return false
    default:
      return true
  }
}

function taskPriority(task: TaskItem) {
  return task.priority > 3 || task.priority < 0 ? 0 : task.priority
}

export function matchesMatrixCondition(task: TaskItem, condition: MatrixCondition, today = startOfToday()) {
  return matchesCondition(task, condition, taskPriority(task), today)
}

function matchesCondition(task: TaskItem, condition: MatrixCondition, priority: number, today: Date) {
  if (condition.priorities.length && !condition.priorities.includes(priority)) return false
  if (!matchesDue(task, condition.due, today)) return false
  if (condition.listId && task.listId !== condition.listId) return false
  if (condition.tag && !task.tags.includes(condition.tag)) return false
  if (condition.assignee && task.assignee !== condition.assignee) return false
  return true
}

export function matchesMatrixRule(task: TaskItem, rule: MatrixQuadrantRule, priority: number, today: Date) {
  const groups = rule.groups.length ? rule.groups : [emptyMatrixCondition()]
  if (rule.match === 'any') {
    return groups.some((group) => matchesCondition(task, group, priority, today))
  }
  return groups.every((group) => matchesCondition(task, group, priority, today))
}

export interface MatrixDropPatch {
  priority?: number
  due?: string
  listId?: number
  tags?: string[]
  assignee?: string
}

function dueDateForRule(rule: MatrixDueRule, today: Date): string | undefined {
  if (rule === 'any') return undefined
  if (rule === 'none') return ''
  const date = new Date(today)
  date.setHours(18, 0, 0, 0)
  if (rule === 'overdue') date.setDate(date.getDate() - 1)
  else if (rule === 'tomorrow') date.setDate(date.getDate() + 1)
  else if (rule === 'next7') date.setDate(date.getDate() + 3)
  else if (rule === 'later') date.setDate(date.getDate() + 8)
  // today and urgent both use today's deadline.
  return date.toISOString()
}

function patchForCondition(task: TaskItem, condition: MatrixCondition, today: Date): MatrixDropPatch {
  const patch: MatrixDropPatch = {}
  if (condition.priorities.length) patch.priority = Math.max(...condition.priorities)
  const due = dueDateForRule(condition.due, today)
  if (due !== undefined) patch.due = due
  if (condition.listId) patch.listId = condition.listId
  if (condition.tag && !task.tags.includes(condition.tag)) patch.tags = [...task.tags, condition.tag]
  if (condition.assignee) patch.assignee = condition.assignee
  return patch
}

function applyDropPatch(task: TaskItem, patch: MatrixDropPatch): TaskItem {
  return {
    ...task,
    priority: patch.priority ?? task.priority,
    due: patch.due !== undefined ? patch.due || undefined : task.due,
    listId: patch.listId ?? task.listId,
    tags: patch.tags ?? task.tags,
    assignee: patch.assignee ?? task.assignee,
  }
}

function mergeConditions(groups: MatrixCondition[]): MatrixCondition | null {
  let priorities: number[] | null = null
  let due: MatrixDueRule = 'any'
  let listId = 0
  let tag = ''
  let assignee = ''
  for (const group of groups) {
    if (group.priorities.length) {
      priorities = priorities === null
        ? [...group.priorities]
        : priorities.filter((value) => group.priorities.includes(value))
      if (!priorities.length) return null
    }
    if (group.due !== 'any') {
      if (due !== 'any' && due !== group.due) return null
      due = group.due
    }
    if (group.listId) {
      if (listId && listId !== group.listId) return null
      listId = group.listId
    }
    if (group.tag) {
      if (tag && tag !== group.tag) return null
      tag = group.tag
    }
    if (group.assignee) {
      if (assignee && assignee !== group.assignee) return null
      assignee = group.assignee
    }
  }
  return { priorities: priorities ?? [], due, listId, tag, assignee }
}

// Finds a task patch that makes the task land in the target quadrant, or null
// when the target conditions cannot be satisfied automatically.
export function planMatrixDrop(
  task: TaskItem,
  rules: MatrixViewRules,
  target: MatrixQuadrantKey,
  today = new Date(),
): MatrixDropPatch | null {
  const rule = rules[target]
  const groups = rule.groups.length ? rule.groups : [emptyMatrixCondition()]
  const candidates = rule.match === 'any'
    ? groups
    : [mergeConditions(groups)].filter((group): group is MatrixCondition => group !== null)
  for (const condition of candidates) {
    const patch = patchForCondition(task, condition, today)
    const next = applyDropPatch(task, patch)
    if (matrixQuadrant(next, rules, today) === target) return patch
  }
  return null
}

export function matrixQuadrant(task: TaskItem, rules: MatrixViewRules, today = startOfToday()): MatrixQuadrantKey {
  const priority = taskPriority(task)
  for (const quadrant of MATRIX_QUADRANTS) {
    if (matchesMatrixRule(task, rules[quadrant.id], priority, today)) return quadrant.id
  }
  return 'q4'
}
