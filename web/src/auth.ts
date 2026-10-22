import { reactive } from 'vue'
import type { User } from './types'
import { loginRequest, logoutRequest, meRequest, setCSRF } from './api'

export const auth = reactive<{
  user: User | null
  baseUrl: string
  ready: boolean
}>({
  user: null,
  baseUrl: '',
  ready: false,
})

export async function bootstrapAuth() {
  try {
    const data = await meRequest()
    auth.user = data.user as User
    auth.baseUrl = data.baseUrl
    setCSRF(data.csrf)
  } catch {
    auth.user = null
  } finally {
    auth.ready = true
  }
}

export async function login(username: string, password: string) {
  const data = await loginRequest(username, password)
  auth.user = data.user as User
  auth.baseUrl = data.baseUrl
  setCSRF(data.csrf)
}

export async function logout() {
  try {
    await logoutRequest()
  } finally {
    auth.user = null
    setCSRF('')
  }
}

export function initials(value: string) {
  const text = (value || '').trim()
  if (!text) return '?'
  return text.slice(0, 1).toUpperCase()
}

export function copyText(text: string) {
  if (navigator.clipboard?.writeText) {
    return navigator.clipboard.writeText(text)
  }
  const input = document.createElement('textarea')
  input.value = text
  input.style.position = 'fixed'
  input.style.opacity = '0'
  document.body.appendChild(input)
  input.select()
  document.execCommand('copy')
  input.remove()
  return Promise.resolve()
}
