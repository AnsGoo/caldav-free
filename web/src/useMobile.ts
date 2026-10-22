import { onMounted, onUnmounted, ref } from 'vue'

export function useIsMobile(breakpoint = 720) {
  const isMobile = ref(typeof window !== 'undefined' && window.innerWidth < breakpoint)
  const update = () => {
    isMobile.value = window.innerWidth < breakpoint
  }
  onMounted(() => window.addEventListener('resize', update, { passive: true }))
  onUnmounted(() => window.removeEventListener('resize', update))
  return isMobile
}
