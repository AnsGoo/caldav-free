<template>
  <svg
    class="tw-ico"
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.7"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <template v-if="name === 'list'">
      <path d="M4 6.5h16M4 12h16M4 17.5h10" />
      <circle cx="18.6" cy="17.5" r="1.6" fill="currentColor" stroke="none" />
    </template>
    <template v-else-if="name === 'matrix'">
      <rect x="3.5" y="3.5" width="7" height="7" rx="1.5" />
      <rect x="13.5" y="3.5" width="7" height="7" rx="1.5" />
      <rect x="3.5" y="13.5" width="7" height="7" rx="1.5" />
      <rect x="13.5" y="13.5" width="7" height="7" rx="1.5" />
    </template>
    <template v-else-if="name === 'board'">
      <rect x="3.5" y="4.5" width="5" height="15" rx="1.5" />
      <rect x="10" y="4.5" width="5" height="10" rx="1.5" />
      <rect x="16.5" y="4.5" width="4" height="13" rx="1.5" />
    </template>
    <template v-else-if="name === 'calendar'">
      <rect x="3.5" y="5.5" width="17" height="15" rx="2.5" />
      <path d="M3.5 9.5h17M8 3.5v4M16 3.5v4" />
    </template>
    <template v-else-if="name === 'search'">
      <circle cx="10.8" cy="10.8" r="6.3" />
      <path d="m15.4 15.4 4.1 4.1" />
    </template>
    <template v-else-if="name === 'inbox'">
      <path d="M4 5.5h16l1.4 8.2a2 2 0 0 1-2 2.3h-3.1l-1.6 2.2H9.3l-1.6-2.2H4.6a2 2 0 0 1-2-2.3L4 5.5Z" />
    </template>
    <template v-else-if="name === 'today'">
      <rect x="3.5" y="5.5" width="17" height="15" rx="2.5" />
      <path d="M3.5 9.5h17M8 3.5v4M16 3.5v4" />
      <path d="M9 13.5h2.5v4" />
    </template>
    <template v-else-if="name === 'next7'">
      <path d="M4.5 7.5h11a4 4 0 0 1 4 4v5" />
      <path d="m16.5 13.5 3 3 3-3" />
      <path d="M4.5 12h7M4.5 16.5h5" />
    </template>
    <template v-else-if="name === 'habit'">
      <circle cx="12" cy="12" r="8.2" />
      <path d="m8.2 12.2 2.4 2.4 5.2-5.4" />
    </template>
    <template v-else-if="name === 'check'">
      <path d="m4.5 12.5 5 5 10-11" />
    </template>
    <template v-else-if="name === 'plus'">
      <path d="M12 4.5v15M4.5 12h15" />
    </template>
    <template v-else-if="name === 'close'">
      <path d="m5.5 5.5 13 13M18.5 5.5l-13 13" />
    </template>
    <template v-else-if="name === 'trash'">
      <path d="M4.5 6.5h15M9.5 6.5v-2h5v2M6.5 6.5l1 13h9l1-13M10 10v6M14 10v6" />
    </template>
    <template v-else-if="name === 'edit'">
      <path d="M4.5 19.5h4l10-10a2.1 2.1 0 0 0-3-3l-10 10v3Z" />
      <path d="m13.5 6.5 3 3" />
    </template>
    <template v-else-if="name === 'more'">
      <circle cx="5.5" cy="12" r="1.3" fill="currentColor" stroke="none" />
      <circle cx="12" cy="12" r="1.3" fill="currentColor" stroke="none" />
      <circle cx="18.5" cy="12" r="1.3" fill="currentColor" stroke="none" />
    </template>
    <template v-else-if="name === 'sun'">
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.2 5.2l1.6 1.6M17.2 17.2l1.6 1.6M18.8 5.2l-1.6 1.6M6.8 17.2l-1.6 1.6" />
    </template>
    <template v-else-if="name === 'moon'">
      <path d="M20 14.5A8.2 8.2 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5Z" />
    </template>
    <template v-else-if="name === 'settings'">
      <circle cx="12" cy="12" r="8.1" stroke-dasharray="2.4 2.2" />
      <circle cx="12" cy="12" r="3.1" />
      <path d="M12 3.9v1.6M12 18.5v1.6M3.9 12h1.6M18.5 12h1.6" />
    </template>
    <template v-else-if="name === 'back'">
      <path d="M14.5 5.5 8 12l6.5 6.5" />
    </template>
    <template v-else-if="name === 'chevron'">
      <path d="m8.5 5.5 6.5 6.5-6.5 6.5" />
    </template>
    <template v-else-if="name === 'clock'">
      <circle cx="12" cy="12" r="8.2" />
      <path d="M12 7.5V12l3 1.8" />
    </template>
    <template v-else-if="name === 'note'">
      <rect x="4.5" y="4" width="15" height="16" rx="2.5" />
      <path d="M8.5 9h7M8.5 12.5h7M8.5 16h4" />
    </template>
    <template v-else-if="name === 'tag'">
      <path d="M4 4.5h7.2l8.3 8.3a2 2 0 0 1 0 2.8l-4 4a2 2 0 0 1-2.8 0L4.5 11.3V4.5Z" />
      <circle cx="8.2" cy="8.2" r="1.2" fill="currentColor" stroke="none" />
    </template>
    <template v-else-if="name === 'flag'">
      <path d="M6 20.5V4.5h9.5l-1.5 3.8 1.5 3.7H6" />
    </template>
    <template v-else-if="name === 'download'">
      <path d="M12 3.5v11M7.5 10l4.5 4.5 4.5-4.5" />
      <path d="M4.5 17.5v2h15v-2" />
    </template>
    <template v-else-if="name === 'copy'">
      <rect x="8" y="8" width="11.5" height="11.5" rx="2" />
      <path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" />
    </template>
    <template v-else-if="name === 'sparkles'">
      <path d="M12 3.5l1.6 4.9 4.9 1.6-4.9 1.6L12 16.5l-1.6-4.9L5.5 10l4.9-1.6L12 3.5Z" fill="currentColor" stroke="none" />
      <path d="M18.5 15.5l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8.8-2.2Z" fill="currentColor" stroke="none" />
    </template>
    <template v-else-if="name === 'mic'">
      <rect x="9" y="3.5" width="6" height="10" rx="3" />
      <path d="M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v3M9 21h6" />
    </template>
    <template v-else-if="name === 'send'">
      <path d="M20.5 3.5 10 14M20.5 3.5l-6.5 17-4-7-7-4 17-6Z" />
    </template>
    <template v-else-if="name === 'chart'">
      <path d="M4 20h16" />
      <path d="M7 20V11M12 20V5M17 20v-6" />
    </template>
    <template v-else-if="name === 'folder'">
      <path d="M3.5 6.5a2 2 0 0 1 2-2h4l2 2h7a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2v-11Z" />
    </template>
    <template v-else-if="name === 'filter'">
      <path d="M3.5 5.5h17l-6.5 7v5l-4 2v-7l-6.5-7Z" />
    </template>
    <template v-else-if="name === 'refresh'">
      <path d="M20.5 11a8.5 8.5 0 1 0-2.3 6.6" />
      <path d="M20.5 4.5V11H14" />
    </template>
    <template v-else-if="name === 'repeat'">
      <path d="M17 2.5v4.5h-4.5" />
      <path d="M7 21.5V17h4.5" />
      <path d="M4.8 8.5A7.5 7.5 0 0 1 17 6.6" />
      <path d="M19.2 15.5A7.5 7.5 0 0 1 7 17.4" />
    </template>
    <template v-else-if="name === 'bell'">
      <path d="M18 9.5a6 6 0 1 0-12 0c0 5-2 6-2 6h16s-2-1-2-6Z" />
      <path d="M10 19.5a2.2 2.2 0 0 0 4 0" />
    </template>
    <template v-else-if="name === 'notice'">
      <path d="M18 10a6 6 0 1 0-12 0c0 5-2 6-2 6h16s-2-1-2-6Z" />
      <path d="M10 19.5a2.2 2.2 0 0 0 4 0" />
      <circle cx="18.5" cy="5" r="2.5" fill="currentColor" stroke="none" />
    </template>
    <template v-else-if="name === 'mail'">
      <rect x="3.5" y="5.5" width="17" height="13" rx="2.5" />
      <path d="m4.5 7 7.5 6 7.5-6" />
    </template>
    <template v-else-if="name === 'link'">
      <path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1.2 1.2" />
      <path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1.2-1.2" />
    </template>
    <template v-else-if="name === 'share'">
      <circle cx="9" cy="8" r="2.5" />
      <circle cx="17" cy="7" r="2" />
      <path d="M4.5 19c0-3 2-5 4.5-5s4.5 2 4.5 5M14.5 19c.2-2.3 1.4-4 3.1-4 1.4 0 2.4 1 2.9 2.6" />
    </template>
    <template v-else-if="name === 'restore'">
      <path d="M4 10.5a8 8 0 1 1 2.1 8" />
      <path d="M4 4.5v6h6" />
    </template>
    <template v-else-if="name === 'sort'">
      <path d="M5 7h14M5 12h9M5 17h5" />
      <path d="m17 14 3 3-3 3" />
    </template>
    <template v-else-if="name === 'select'">
      <rect x="4" y="4" width="16" height="16" rx="3" />
      <path d="m8 12.2 2.8 2.8 5.4-6" />
    </template>
    <template v-else-if="name === 'drag'">
      <circle cx="9" cy="7" r="1.2" fill="currentColor" stroke="none" />
      <circle cx="15" cy="7" r="1.2" fill="currentColor" stroke="none" />
      <circle cx="9" cy="12" r="1.2" fill="currentColor" stroke="none" />
      <circle cx="15" cy="12" r="1.2" fill="currentColor" stroke="none" />
      <circle cx="9" cy="17" r="1.2" fill="currentColor" stroke="none" />
      <circle cx="15" cy="17" r="1.2" fill="currentColor" stroke="none" />
    </template>
    <template v-else-if="name === 'sunrise'">
      <path d="M4 18h16M6.5 14a5.5 5.5 0 0 1 11 0M12 4v3M4.8 8.2l1.8 1.8M19.2 8.2l-1.8 1.8" />
    </template>
    <template v-else>
      <path d="m4.5 12.5 5 5 10-11" />
    </template>
  </svg>
</template>

<script setup lang="ts">
withDefaults(defineProps<{ name: string; size?: number }>(), { size: 18 })
</script>
