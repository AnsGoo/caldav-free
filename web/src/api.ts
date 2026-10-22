let csrfToken = ''
let unauthorizedHandler: (() => void) | null = null

export class ApiError extends Error {
  status: number
  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

export function setCSRF(token: string) {
  csrfToken = token
}

export function setUnauthorizedHandler(handler: () => void) {
  unauthorizedHandler = handler
}

interface RequestOptions {
  auth?: boolean
  csrf?: boolean
}

export async function api<T>(
  path: string,
  init: RequestInit = {},
  options: RequestOptions = {},
): Promise<T> {
  const method = (init.method || 'GET').toUpperCase()
  const headers = new Headers(init.headers)
  if (init.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json')
  }
  if (options.csrf !== false && method !== 'GET' && method !== 'HEAD' && csrfToken) {
    headers.set('X-CSRF-Token', csrfToken)
  }
  const response = await fetch(`/api/admin${path}`, {
    ...init,
    method,
    headers,
    credentials: 'same-origin',
  })
  if (response.status === 401 && options.auth !== false) {
    unauthorizedHandler?.()
  }
  const text = await response.text()
  let payload: unknown = null
  if (text) {
    try {
      payload = JSON.parse(text)
    } catch {
      payload = text
    }
  }
  if (!response.ok) {
    const message =
      payload && typeof payload === 'object' && 'error' in payload
        ? String((payload as { error: unknown }).error)
        : response.status === 401
          ? '未登录或认证失败'
          : `请求失败（${response.status}）`
    throw new ApiError(response.status, message)
  }
  return payload as T
}

export async function loginRequest(username: string, password: string) {
  return api<{ user: unknown; csrf: string; baseUrl: string }>(
    '/login',
    {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    },
    { auth: false, csrf: false },
  )
}

export async function logoutRequest() {
  return api<void>('/logout', { method: 'POST' })
}

export async function meRequest() {
  return api<{ user: unknown; csrf: string; baseUrl: string }>('/me', {}, { auth: false, csrf: false })
}
