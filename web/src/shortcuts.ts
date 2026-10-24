export type ShortcutGroup = '通用' | '任务' | '视图' | '导航'

export interface ShortcutAction {
  id: string
  label: string
  group: ShortcutGroup
  keys: string[]
}

export type ShortcutBindings = Record<string, string[]>

export const SHORTCUT_STORAGE_KEY = 'caldav-task-shortcuts'

export const DEFAULT_SHORTCUTS: ShortcutAction[] = [
  { id: 'commandPalette', label: '打开指令菜单', group: '通用', keys: ['meta+k', 'ctrl+k'] },
  { id: 'shortcutHelp', label: '快捷键', group: '通用', keys: ['?'] },
  { id: 'search', label: '打开搜索', group: '通用', keys: ['/'] },
  { id: 'newTask', label: '添加任务', group: '通用', keys: ['tab+n', 'n'] },
  { id: 'toggleSidebar', label: '显示/隐藏侧栏', group: '通用', keys: ['['] },
  { id: 'pinTask', label: '置顶任务', group: '任务', keys: ['tab+p'] },
  { id: 'completeTask', label: '完成任务', group: '任务', keys: ['tab+m'] },
  { id: 'setToday', label: '设为今天', group: '任务', keys: ['tab+1'] },
  { id: 'setTomorrow', label: '设为明天', group: '任务', keys: ['tab+2'] },
  { id: 'clearDate', label: '清除日期', group: '任务', keys: ['tab+0'] },
  { id: 'priorityNone', label: '优先级：无', group: '任务', keys: ['alt+0'] },
  { id: 'priorityLow', label: '优先级：低', group: '任务', keys: ['alt+1'] },
  { id: 'priorityMedium', label: '优先级：中', group: '任务', keys: ['alt+2'] },
  { id: 'priorityHigh', label: '优先级：高', group: '任务', keys: ['alt+3'] },
  { id: 'listMode', label: '列表视图', group: '视图', keys: ['v l'] },
  { id: 'boardMode', label: '看板视图', group: '视图', keys: ['v k'] },
  { id: 'calendarMode', label: '日历视图', group: '视图', keys: ['v c'] },
  { id: 'timelineMode', label: '时间线视图', group: '视图', keys: ['v t'] },
  { id: 'navAll', label: '前往“所有”', group: '导航', keys: ['g a'] },
  { id: 'navToday', label: '前往“今天”', group: '导航', keys: ['g t'] },
  { id: 'navNext7', label: '前往“最近 7 天”', group: '导航', keys: ['g r'] },
  { id: 'navInbox', label: '前往“收集箱”', group: '导航', keys: ['g i'] },
  { id: 'navCompleted', label: '前往“已完成”', group: '导航', keys: ['g c'] },
  { id: 'navSummary', label: '前往“摘要”', group: '导航', keys: ['g b'] },
  { id: 'navTrash', label: '前往“垃圾桶”', group: '导航', keys: ['g g'] },
  { id: 'navMatrix', label: '前往“四象限”', group: '导航', keys: ['g m'] },
  { id: 'navHabit', label: '前往“习惯”', group: '导航', keys: ['g h'] },
  { id: 'navFocus', label: '前往“专注”', group: '导航', keys: ['g f'] },
  { id: 'navCountdown', label: '前往“倒数纪念日”', group: '导航', keys: ['g d'] },
  { id: 'navStats', label: '前往“统计”', group: '导航', keys: ['g s'] },
]

export function defaultBindings(): ShortcutBindings {
  return Object.fromEntries(DEFAULT_SHORTCUTS.map((action) => [action.id, [...action.keys]]))
}

export function loadBindings(): ShortcutBindings {
  const base = defaultBindings()
  try {
    const raw = localStorage.getItem(SHORTCUT_STORAGE_KEY)
    if (!raw) return base
    const saved = JSON.parse(raw) as Record<string, unknown>
    for (const action of DEFAULT_SHORTCUTS) {
      const value = saved[action.id]
      if (Array.isArray(value)) {
        const keys = value.filter((item): item is string => typeof item === 'string' && item.trim() !== '')
        if (keys.length) base[action.id] = keys
        else delete base[action.id]
      }
    }
  } catch {
    /* ignore */
  }
  return base
}

export function saveBindings(bindings: ShortcutBindings) {
  try {
    localStorage.setItem(SHORTCUT_STORAGE_KEY, JSON.stringify(bindings))
  } catch {
    /* ignore */
  }
}

export function resetBindings(): ShortcutBindings {
  try {
    localStorage.removeItem(SHORTCUT_STORAGE_KEY)
  } catch {
    /* ignore */
  }
  return defaultBindings()
}

const KEY_ALIASES: Record<string, string> = {
  ' ': 'space',
  escape: 'esc',
  arrowup: 'up',
  arrowdown: 'down',
  arrowleft: 'left',
  arrowright: 'right',
  backspace: 'backspace',
  delete: 'del',
  enter: 'enter',
  tab: 'tab',
}

/** Normalizes a KeyboardEvent into a lowercase combo such as `meta+k` or `tab+n`. */
export function keyEventToCombo(event: KeyboardEvent): string | null {
  if (['Meta', 'Control', 'Alt', 'Shift', 'CapsLock', 'Dead'].includes(event.key)) return null
  let key = event.key.toLowerCase()
  key = KEY_ALIASES[key] || key
  // Alt/Meta combinations can rewrite event.key on macOS (Alt+1 -> "¡").
  // The physical key is the stable identity for letters and digits.
  if (/^Digit[0-9]$/.test(event.code)) key = event.code.slice(5)
  else if (/^Key[A-Z]$/.test(event.code)) key = event.code.slice(3).toLowerCase()
  if (key === '?') return '?'
  if (key === '+') return 'plus'
  const parts: string[] = []
  if (event.metaKey) parts.push('meta')
  if (event.ctrlKey) parts.push('ctrl')
  if (event.altKey) parts.push('alt')
  if (event.shiftKey) parts.push('shift')
  // Shift is implied by symbols; avoid `shift+/` never matching `/`.
  if (event.shiftKey && /^[a-z0-9]$/.test(key)) parts.push('shift')
  parts.push(key)
  return parts.join('+')
}

export function comboLabel(combo: string, isMac = false): string {
  return combo
    .split(' ')
    .map((part) => {
      const tokens = part
        .split('+')
        .map((token) => {
          switch (token) {
            case 'meta':
              return isMac ? '⌘' : 'Ctrl'
            case 'ctrl':
              return 'Ctrl'
            case 'alt':
              return isMac ? '⌥' : 'Alt'
            case 'shift':
              return isMac ? '⇧' : 'Shift'
            case 'tab':
              return 'Tab'
            case 'enter':
              return 'Enter'
            case 'esc':
              return 'Esc'
            case 'del':
              return 'Del'
            case 'space':
              return 'Space'
            case 'up':
              return '↑'
            case 'down':
              return '↓'
            case 'left':
              return '←'
            case 'right':
              return '→'
            default:
              return token.toUpperCase()
          }
        })
      return tokens.join(isMac && ['⌘', '⌥', '⇧'].includes(tokens[0]) ? '' : '+')
    })
    .join(' 然后 ')
}

export function isMacPlatform(): boolean {
  if (typeof navigator === 'undefined') return false
  return /mac|iphone|ipad|ipod/i.test(navigator.platform || navigator.userAgent)
}

export function findAction(bindings: ShortcutBindings, combo: string): ShortcutAction | null {
  const match = DEFAULT_SHORTCUTS.find((action) => (bindings[action.id] || []).includes(combo))
  return match || null
}

export function isPrefix(bindings: ShortcutBindings, combo: string): boolean {
  return DEFAULT_SHORTCUTS.some((action) =>
    (bindings[action.id] || []).some((binding) => binding.startsWith(combo + ' ')),
  )
}

export function hasConflict(bindings: ShortcutBindings, actionId: string, combo: string): boolean {
  return DEFAULT_SHORTCUTS.some(
    (action) => action.id !== actionId && (bindings[action.id] || []).includes(combo),
  )
}
