const CACHE = 'caldav-free-shell-v4'
const SHELL = [
  '/admin/',
  '/admin/index.html',
  '/admin/icon-192.png',
  '/admin/icon-512.png',
]

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL)).then(() => self.skipWaiting()))
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  )
})

// Web Push：服务端发的是 {title, body, tag, taskId, url}。
// 没有这个监听器时，浏览器只会显示“站点已在后台更新”，看不到标题和正文。
self.addEventListener('push', (event) => {
  let data = {}
  try {
    data = event.data ? event.data.json() : {}
  } catch (error) {
    data = { body: event.data ? event.data.text() : '' }
  }

  const title = data.title || '提醒'
  const options = {
    body: data.body || '',
    tag: data.tag || undefined,
    data: { url: data.url || '/admin/', taskId: data.taskId || 0 },
    icon: '/admin/icon-192.png',
    badge: '/admin/icon-192.png',
  }

  event.waitUntil(self.registration.showNotification(title, options))
})

// 点通知：优先聚焦已经打开的窗口并跳转，否则新开一个。
self.addEventListener('notificationclick', (event) => {
  event.notification.close()

  const raw = (event.notification.data && event.notification.data.url) || '/admin/'
  const target = new URL(raw, self.location.origin).href

  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    for (const client of windows) {
      if (client.url === target && 'focus' in client) return client.focus()
    }
    for (const client of windows) {
      if (!('focus' in client)) continue
      await client.focus()
      if ('navigate' in client) {
        try {
          await client.navigate(target)
        } catch (error) {
          // 跨域或正在卸载的窗口无法 navigate，退化成新开窗口。
        }
      }
      return undefined
    }
    return self.clients.openWindow(target)
  })())
})

self.addEventListener('fetch', (event) => {
  const request = event.request
  if (request.method !== 'GET') return
  const url = new URL(request.url)
  if (url.origin !== self.location.origin || !url.pathname.startsWith('/admin/')) return

  if (url.pathname.startsWith('/admin/assets/')) {
    event.respondWith(
      caches.match(request).then((cached) => cached || fetch(request).then((response) => {
        if (response.ok) {
          const copy = response.clone()
          caches.open(CACHE).then((cache) => cache.put(request, copy))
        }
        return response
      })),
    )
    return
  }

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.ok) {
            const copy = response.clone()
            caches.open(CACHE).then((cache) => cache.put('/admin/index.html', copy))
          }
          return response
        })
        .catch(() => caches.match('/admin/index.html').then((cached) => cached || caches.match('/admin/'))),
    )
  }
})
