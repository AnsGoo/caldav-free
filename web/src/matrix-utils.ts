import { dayKey, startOfToday } from './tasks-utils'
import type {
  MatrixCondition,
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

export function matrixQuadrant(task: TaskItem, rules: MatrixViewRules, today = startOfToday()): MatrixQuadrantKey {
  const priority = task.priority > 3 || task.priority < 0 ? 0 : task.priority
  for (const quadrant of MATRIX_QUADRANTS) {
    if (matchesMatrixRule(task, rules[quadrant.id], priority, today)) return quadrant.id
  }
  return 'q4'
}
