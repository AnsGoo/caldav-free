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
