import { dayKey, startOfToday } from './tasks-utils'
import type { MatrixQuadrantKey, MatrixQuadrantRule, MatrixViewRules, TaskItem } from './types'

export const MATRIX_QUADRANTS: { id: MatrixQuadrantKey; label: string; color: string }[] = [
  { id: 'q1', label: '重要且紧急', color: '#ff5f68' },
  { id: 'q2', label: '重要不紧急', color: '#ffb000' },
  { id: 'q3', label: '不重要但紧急', color: '#4772fa' },
  { id: 'q4', label: '不重要不紧急', color: '#0cce9c' },
]

export function emptyMatrixRule(): MatrixQuadrantRule {
  return { priorities: [], due: 'any', listId: 0, tag: '', assignee: '' }
}

export function defaultMatrixRules(): MatrixViewRules {
  return {
    q1: { priorities: [2, 3], due: 'urgent', listId: 0, tag: '', assignee: '' },
    q2: { priorities: [2, 3], due: 'any', listId: 0, tag: '', assignee: '' },
    q3: { priorities: [0, 1], due: 'urgent', listId: 0, tag: '', assignee: '' },
    q4: emptyMatrixRule(),
  }
}

export function normalizeMatrixRules(input?: Partial<MatrixViewRules> | null): MatrixViewRules {
  const fallback = defaultMatrixRules()
  const output = {} as MatrixViewRules
  for (const key of ['q1', 'q2', 'q3', 'q4'] as MatrixQuadrantKey[]) {
    const raw = input?.[key]
    const base = raw || fallback[key]
    output[key] = {
      priorities: Array.isArray(base.priorities)
        ? base.priorities.map(Number).filter((value) => value >= 0 && value <= 3)
        : [],
      due: isDueRule(base.due) ? base.due : 'any',
      listId: Number(base.listId) || 0,
      tag: typeof base.tag === 'string' ? base.tag : '',
      assignee: typeof base.assignee === 'string' ? base.assignee : '',
    }
  }
  return output
}

function isDueRule(value: unknown): value is MatrixQuadrantRule['due'] {
  return ['any', 'urgent', 'overdue', 'today', 'tomorrow', 'next7', 'later', 'none'].includes(String(value))
}

function matchesDue(task: TaskItem, rule: MatrixQuadrantRule['due'], today: Date) {
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

function matchesRule(task: TaskItem, rule: MatrixQuadrantRule, priority: number, today: Date) {
  if (rule.priorities.length && !rule.priorities.includes(priority)) return false
  if (!matchesDue(task, rule.due, today)) return false
  if (rule.listId && task.listId !== rule.listId) return false
  if (rule.tag && !task.tags.includes(rule.tag)) return false
  if (rule.assignee && task.assignee !== rule.assignee) return false
  return true
}

export function matrixQuadrant(task: TaskItem, rules: MatrixViewRules, today = startOfToday()): MatrixQuadrantKey {
  const priority = task.priority > 3 || task.priority < 0 ? 0 : task.priority
  for (const quadrant of MATRIX_QUADRANTS) {
    if (matchesRule(task, rules[quadrant.id], priority, today)) return quadrant.id
  }
  return 'q4'
}
