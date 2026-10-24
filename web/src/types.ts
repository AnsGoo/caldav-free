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

export type MatrixRuleMode = 'simple' | 'complex' | 'custom'
export type MatrixDueRule = 'any' | 'urgent' | 'overdue' | 'today' | 'tomorrow' | 'next7' | 'later' | 'none'

export interface MatrixCondition {
  priorities: number[]
  due: MatrixDueRule
  listId: number
  tag: string
  assignee: string
}

export interface MatrixQuadrantRule {
  name: string
  color: string
  match: 'all' | 'any'
  groups: MatrixCondition[]
}

export type MatrixQuadrantKey = 'q1' | 'q2' | 'q3' | 'q4'

export interface MatrixViewRules {
  q1: MatrixQuadrantRule
  q2: MatrixQuadrantRule
  q3: MatrixQuadrantRule
  q4: MatrixQuadrantRule
}

export interface MatrixView {
  id: number
  name: string
  mode: MatrixRuleMode
  rules?: MatrixViewRules
  order: number
}

export interface MatrixRuleTemplate {
  id: number
  name: string
  rules: MatrixViewRules
}

export interface TaskTagCount {
  name: string
  count: number
  color: string
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

export interface CommentAttachment {
  id: number
  commentId: number
  filename: string
  contentType: string
  size: number
  canDelete: boolean
}

export interface TaskComment {
  id: number
  taskId: number
  userId: number
  username: string
  displayName: string
  body: string
  createdAt: string
  editedAt?: string
  canDelete: boolean
  canEdit: boolean
  attachments: CommentAttachment[]
}

export interface TaskActivity {
  id: number
  type: string
  detail: string
  username: string
  displayName: string
  createdAt: string
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
  matrixViews: MatrixView[]
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
  reminders: number[]
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
  color: string
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

export interface AIModelStat {
  calls: number
  totalMs: number
  lastMs: number
  lastAt: string
}

export interface AISettings {
  provider: string
  baseUrl: string
  model: string
  models: string[]
  recentModels: string[]
  modelStats: Record<string, AIModelStat>
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
  fallbackFrom?: string
  recentModels?: string[]
  modelStats?: Record<string, AIModelStat>
  latencyMs?: number
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

export interface HabitFrequency {
  type: 'daily' | 'weekly' | 'interval'
  weekdays?: number[]
  daysPerWeek?: number
  interval?: number
}

export interface HabitItem {
  id: number
  name: string
  icon: string
  color: string
  sectionId: number
  sortOrder: number
  status: number
  goal: number
  step: number
  unit: string
  frequency: string
  reminders: string
  recordEnable: boolean
  startDate: number
  targetDays: number
  completedCycles: number
  exDates: string
  style: string
  archivedAt?: string
  createdAt: string
  modifiedAt: string
  totalCheckIns: number
  currentStreak: number
  maxStreak: number
  dueToday: boolean
  doneToday: boolean
}

export interface HabitSection {
  id: number
  name: string
  sortOrder: number
  createdAt: string
  modifiedAt: string
}

export interface HabitCheckin {
  id: number
  habitId: number
  checkinStamp: number
  value: number
  goal: number
  status: number
  checkinTime?: string
  opTime: string
}

export interface HabitRecord {
  id: number
  habitId: number
  stamp: number
  content: string
  emoji: string
  opTime: string
}

export interface HabitFocusSession {
  id: number
  habitId: number
  minutes: number
  startedAt: string
  completedAt: string
  createdAt: string
}

export interface HabitFocusDailyStat {
  date: string
  minutes: number
  count: number
}

export interface HabitShareLink {
  token: string
  path: string
  createdAt: string
}

export interface HabitPublicDay {
  date: string
  done: boolean
  value: number
  goal: number
}

export interface HabitPublicShare {
  name: string
  icon: string
  color: string
  goal: number
  unit: string
  stats: {
    totalCheckinDays: number
    currentStreak: number
    monthCheckinDays: number
    monthCompletionRate: number
    monthCompletionCount: number
    targetDays: number
    targetProgress: number
    completedCycles: number
  }
  days: HabitPublicDay[]
  sharedAt: string
}

export interface HabitPreference {
  showInToday: boolean
  showInCalendar: boolean
  groupByCompleted: boolean
  displayType: 'list' | 'card'
  sortType: string
  defaultSectionId: number
  timezone: string
}

export interface HabitDailyStat {
  date: string
  value: number
  goal: number
}

export interface HabitStats {
  focusMinutes: number
  monthFocusMinutes: number
  focusCount: number
  focusDaily: HabitFocusDailyStat[]
  targetDays: number
  targetProgress: number
  completedCycles: number
  monthCheckinDays: number
  totalCheckinDays: number
  monthCompletionRate: number
  currentStreak: number
  monthCompletionCount: number
  totalCompletionCount: number
  daily: HabitDailyStat[]
}

export interface HabitDetail {
  habit: HabitItem
  checkins: HabitCheckin[]
  records: HabitRecord[]
  focusSessions: HabitFocusSession[]
  stats: HabitStats
}

export interface HabitListData {
  habits: HabitItem[]
  sections: HabitSection[]
  preferences: HabitPreference
  checkins: Record<string, HabitCheckin[]>
}

export interface HabitCalendarEntry {
  habitId: number
  name: string
  icon: string
  color: string
  date: string
  stamp: number
  value: number
  goal: number
  done: boolean
}

export type FocusMode = 'pomodoro' | 'stopwatch'

export interface FocusPreference {
  pomodoroMinutes: number
  shortBreakMinutes: number
  longBreakMinutes: number
  longBreakInterval: number
  dailyGoal: number
  autoStartPomodoro: boolean
  autoStartBreak: boolean
  soundEnabled: boolean
  tabTitleEnabled: boolean
}

export interface FocusSession {
  id: number
  taskId: number
  habitId: number
  title: string
  mode: FocusMode
  status: number
  startedAt: string
  endedAt: string
  pauseSeconds: number
  durationSeconds: number
  pomodoroCount: number
  note: string
  createdAt: string
}

export interface FocusStats {
  todayPomodoroCount: number
  todayFocusMinutes: number
  totalPomodoroCount: number
  totalFocusMinutes: number
  todayFocusSeconds: number
  totalFocusSeconds: number
  dailyGoal: number
}

export interface FocusDailyStat {
  date: string
  minutes: number
  seconds: number
}

export interface FocusHeatmapDay {
  date: string
  minutes: number
  seconds: number
}

export interface FocusHourlyStat {
  hour: number
  minutes: number
  seconds: number
}

export interface FocusDashboard {
  preferences: FocusPreference
  stats: FocusStats
  sessions: FocusSession[]
  daily: FocusDailyStat[]
  heatmap: FocusHeatmapDay[]
  hourly: FocusHourlyStat[]
}

export interface FocusSessionDraft {
  clientId?: string
  taskId?: number
  habitId?: number
  mode: FocusMode
  startedAt: string
  endedAt: string
  pauseSeconds?: number
  durationSeconds?: number
  pomodoroCount?: number
  note?: string
}

export interface FocusTimerView {
  sessionId: string
  mode: FocusMode
  phase: 'focus' | 'shortBreak' | 'longBreak'
  status: 'idle' | 'running' | 'paused'
  startedAt: string
  phaseTotalSeconds: number
  remainingSeconds: number
  elapsedSeconds: number
  pauseSeconds: number
  note: string
  taskId: number
  habitId: number
  title: string
  cyclePomodoros: number
  revision: number
  updatedAt: string
  serverNow: string
}

export interface FocusTimerDraft {
  sessionId: string
  mode: FocusMode
  phase: 'focus' | 'shortBreak' | 'longBreak'
  status: 'idle' | 'running' | 'paused'
  startedAt: string
  phaseTotalSeconds: number
  remainingSeconds: number
  elapsedSeconds: number
  pauseSeconds: number
  note: string
  taskId?: number
  habitId?: number
  title?: string
  cyclePomodoros: number
}

export interface FocusModeStat {
  mode: FocusMode
  seconds: number
  minutes: number
  count: number
}

export interface FocusTitleStat {
  title: string
  seconds: number
  minutes: number
  count: number
}

export interface FocusRangeStats {
  days: number
  from: string
  to: string
  totalPomodoroCount: number
  totalFocusSeconds: number
  totalFocusMinutes: number
  sessionCount: number
  activeDays: number
  averageMinutes: number
  bestDay: FocusDailyStat
  daily: FocusDailyStat[]
  hourly: FocusHourlyStat[]
  byMode: FocusModeStat[]
  byTitle: FocusTitleStat[]
  sessions: FocusSession[]
}

export type CountdownType = 'anniversary' | 'countdown' | 'birthday' | 'festival'
export type CountdownRepeat = 'none' | 'yearly' | 'monthly' | 'weekly'

export interface CountdownItem {
  id: number
  name: string
  type: CountdownType
  date: number
  icon: string
  color: string
  style: 'normal' | 'color' | 'soft' | 'outline'
  background: string
  remark: string
  reminders: string
  repeat: CountdownRepeat
  ignoreYear: boolean
  showAge: boolean
  dateDisplayFormat: 'day' | 'full'
  status: number
  pinned: boolean
  sortOrder: number
  createdAt: string
  modifiedAt: string
  days: number
  state: 'today' | 'future' | 'past'
  occurrenceDate: number
  age?: number
}

export interface CountdownDraft {
  name: string
  type: CountdownType
  date: number
  icon: string
  color: string
  style: 'normal' | 'color' | 'soft' | 'outline'
  background: string
  remark: string
  reminders: string
  repeat: CountdownRepeat
  ignoreYear: boolean
  showAge: boolean
  dateDisplayFormat: 'day' | 'full'
  status: number
  pinned: boolean
}
