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
  reminderOffsets: number[]
  assignee: string
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

export interface SharedTaskList {
  listId: number
  name: string
  color: string
  ownerId: number
  ownerUsername: string
  ownerDisplay: string
  role: 'viewer' | 'editor'
  count: number
}

export interface TaskListShare {
  userId: number
  username: string
  displayName: string
  role: 'viewer' | 'editor'
  createdAt: string
}

export interface AppNotification {
  id: number
  type: string
  title: string
  body: string
  url: string
  taskId: number
  read: boolean
  createdAt: string
}

export interface TaskComment {
  id: number
  taskId: number
  userId: number
  username: string
  displayName: string
  body: string
  createdAt: string
  canDelete: boolean
}

export interface TaskListMember {
  username: string
  displayName: string
  role: 'owner' | 'viewer' | 'editor'
}

export interface TaskWorkspaceData {
  lists: TaskList[]
  sharedLists: SharedTaskList[]
  folders: TaskFolder[]
  filters: SavedFilter[]
  tasks: TaskItem[]
  counts: TaskCounts
  tags: string[]
  tagCounts: TaskTagCount[]
  inbox: number
}

export interface CalendarSource {
  id: number
  name: string
  color: string
}

export interface CalendarEvent {
  id: string
  uid: string
  href: string
  calendarId: number
  calendarName: string
  color: string
  summary: string
  location: string
  description: string
  rrule: string
  start: string
  end: string
  allDay: boolean
  recurring: boolean
  recurrenceId?: string
}

export interface TaskDailyStat {
  date: string
  created: number
  completed: number
  due: number
}

export interface TaskListStat {
  id: number
  name: string
  color: string
  open: number
  completed: number
  overdue: number
}

export interface TaskTagStat {
  name: string
  open: number
  completed: number
  overdue: number
}

export interface TaskPriorityStat {
  priority: number
  open: number
  completed: number
}

export interface TaskStats {
  days: number
  open: number
  completed: number
  overdue: number
  today: number
  trash: number
  completionRate: number
  createdInPeriod: number
  completedInPeriod: number
  dueInPeriod: number
  onTimeInPeriod: number
  avgCompletionHours: number
  daily: TaskDailyStat[]
  lists: TaskListStat[]
  tags: TaskTagStat[]
  priorities: TaskPriorityStat[]
}

export interface AISettings {
  baseUrl: string
  model: string
  hasKey: boolean
  configured: boolean
}

export interface AIAction {
  type: string
  label: string
  taskId?: number
  listId?: number
}

export interface AIChatAction {
  type: string
  label: string
  taskId?: number
  listId?: number
}

export interface AIChatMessage {
  role: 'user' | 'assistant'
  content: string
  actions?: AIAction[]
  error?: boolean
}

export interface AIChatReply {
  message: string
  actions: AIAction[]
  model: string
}

export interface SummaryTask {
  id: number
  title: string
  listId: number
  listName: string
  listColor: string
  completed: boolean
  completedAt?: string
  due?: string
  allDay: boolean
  priority: number
  tags: string[]
  notes: string
  checklist: ChecklistItem[]
  createdAt: string
}

export interface TaskSummaryData {
  title: string
  from: string
  to: string
  tasks: SummaryTask[]
  nextTasks: SummaryTask[]
  counts: {
    completed: number
    open: number
  }
}

export interface SummaryDocument {
  id: number
  kind: 'template' | 'history'
  name: string
  content: string
  createdAt: string
  modifiedAt: string
}
