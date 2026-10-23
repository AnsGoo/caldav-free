/* Service worker for server-side task reminders. */
self.addEventListener('install', () => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener('push', (event) => {
  let payload = {}
  try {
    payload = event.data ? event.data.json() : {}
  } catch {
    payload = { body: event.data ? event.data.text() : '' }
  }
  const title = payload.title || '任务提醒'
  const body = payload.body || '你有一个任务即将到期'
  const url = new URL(payload.url || '/admin/tasks', self.location.origin).href
  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      tag: payload.tag || 'caldav-task-reminder',
      data: { url, taskId: payload.taskId || 0 },
      renotify: true,
    }),
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const target = new URL(event.notification.data?.url || '/admin/tasks', self.location.origin).href
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const client of windows) {
        if (client.url === target && 'focus' in client) return client.focus()
      }
      for (const client of windows) {
        if (client.url.startsWith(self.location.origin) && 'navigate' in client) {
          return client.navigate(target).then((navigated) => navigated?.focus())
        }
      }
      return self.clients.openWindow(target)
    }),
  )
})
