export interface TaskTheme {
  id: string
  label: string
  bg: string
  rail: string
  accent: string
  dark: boolean
}

// Pure-colour themes mirroring Dida's "颜色系列". City/season/photo themes
// need artwork and are intentionally out of scope for the first batch.
export const TASK_THEMES: TaskTheme[] = [
  { id: 'default', label: '默认', bg: '#ffffff', rail: '#f4f4f5', accent: '#4772fa', dark: false },
  { id: 'dark', label: '暗夜', bg: '#1b1b1c', rail: '#151516', accent: '#5b7cff', dark: true },
  { id: 'blue', label: '晴蓝', bg: '#f3f7ff', rail: '#e8efff', accent: '#4772fa', dark: false },
  { id: 'turquoise', label: '松石', bg: '#f1faf8', rail: '#e3f4f0', accent: '#17a38a', dark: false },
  { id: 'teal', label: '秘青', bg: '#f1f8f9', rail: '#e2f0f2', accent: '#2b7f8c', dark: false },
  { id: 'matcha', label: '蒹葭', bg: '#f6f9f1', rail: '#ebf2e2', accent: '#6f9a3f', dark: false },
  { id: 'sunshine', label: '杏黄', bg: '#fdf9ef', rail: '#f8f0dc', accent: '#c58a1d', dark: false },
  { id: 'peach', label: '桃夭', bg: '#fff6f7', rail: '#fde9ec', accent: '#d95b7c', dark: false },
  { id: 'lilac', label: '暮山紫', bg: '#f8f5fd', rail: '#efe8fa', accent: '#7b5bc4', dark: false },
  { id: 'ebony', label: '沉香', bg: '#faf7f3', rail: '#f1ebe3', accent: '#8a6a4b', dark: false },
  { id: 'navy', label: '藏蓝', bg: '#141a2b', rail: '#0f1422', accent: '#6d8cff', dark: true },
  { id: 'grey', label: '灰色', bg: '#f5f5f6', rail: '#ececee', accent: '#596273', dark: false },
]

export function themeById(id: string): TaskTheme {
  return TASK_THEMES.find((theme) => theme.id === id) || TASK_THEMES[0]
}

export function isDarkTheme(id: string): boolean {
  return themeById(id).dark
}
