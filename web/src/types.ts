export interface User {
  id: number
  username: string
  displayName: string
  email: string
  isAdmin: boolean
  createdAt: string
  calendars?: number
  objects?: number
}

export interface Calendar {
  id: number
  userId: number
  slug: string
  displayName: string
  description: string
  color: string
  order: number
  timezone: string
  components: string[]
  syncSeq: number
  createdAt: string
  modifiedAt: string
  eventCount?: number
}

export interface EventItem {
  href: string
  uid: string
  summary: string
  location: string
  start: string
  end: string
  allDay: boolean
  recurring: boolean
  size: number
  componentType: string
}

export interface Stats {
  users: number
  calendars: number
  objects: number
}

export interface DashboardData {
  stats: Stats
  users: User[]
  baseUrl: string
  principalUrl: string
  calendarHome: string
}

export interface MeData {
  user: User
  csrf: string
  baseUrl: string
  caldavUrl?: string
}

export interface UserDetailData {
  user: User
  calendars: Calendar[]
  timezones: string[]
  isSelf: boolean
  adminCount: number
}

export interface CalendarDetailData {
  calendar: Calendar
  owner: User
  events: EventItem[]
  timezones: string[]
}

export interface EventDetailData {
  event: EventItem
  data: string
}

export interface ListData<T> {
  users?: T[]
  calendars?: T[]
  events?: T[]
  calendar?: T
  user?: T
  event?: T
}

export interface ChecklistItem {
  id: string
  title: string
  done: boolean
}

export interface TaskItem {
  id: number
  parentId?: number
  listId: number
  listName: string
  listColor: string
  title: string
  notes: string
  priority: number
  due?: string
  allDay: boolean
  recurrence: string
  reminderOffset: number
  completed: boolean
  completedAt?: string
  deletedAt?: string
  tags: string[]
  checklist: ChecklistItem[]
  order: number
  createdAt: string
  modifiedAt: string
}

export interface TaskList {
  id: number
  folderId: number
  name: string
  color: string
  order: number
  isInbox: boolean
  count: number
}

export interface TaskFolder {
  id: number
  name: string
  order: number
}

export interface TaskFilterConditions {
  listIds: number[]
  tags: string[]
  tagMode: 'any' | 'all'
  priorities: number[]
  status: 'open' | 'completed' | 'all'
  date: 'any' | 'today' | 'next7' | 'overdue' | 'none'
  keyword: string
}

export interface SavedFilter {
  id: number
  name: string
  color: string
  conditions: TaskFilterConditions
  order: number
}

export interface TaskTagCount {
  name: string
  count: number
}

export interface TaskCounts {
  all: number
  today: number
  next7: number
  inbox: number
  completed: number
  trash: number
}

export interface TaskWorkspaceData {
  lists: TaskList[]
  folders: TaskFolder[]
  filters: SavedFilter[]
  tasks: TaskItem[]
  counts: TaskCounts
  tags: string[]
  tagCounts: TaskTagCount[]
  inbox: number
}
