<template>
  <div class="tw-command-scrim" @click.self="$emit('close')">
    <div class="tw-command" role="dialog" aria-modal="true" aria-label="指令菜单">
      <div class="tw-command-input-wrap">
        <TaskIcon name="search" :size="17" />
        <input
          ref="inputEl"
          v-model="query"
          class="tw-command-input"
          placeholder="输入指令或搜索"
          @keydown.down.prevent="move(1)"
          @keydown.up.prevent="move(-1)"
          @keydown.enter.prevent="runActive"
          @keydown.esc.prevent="$emit('close')"
        />
        <span class="tw-command-hint">{{ hint }}</span>
      </div>
      <div class="tw-command-list">
        <template v-for="group in filteredGroups" :key="group.name">
          <p class="tw-command-group">{{ group.name }}</p>
          <button
            v-for="item in group.items"
            :key="item.id"
            class="tw-command-item"
            :class="{ active: item.id === activeId }"
            @mouseenter="activeId = item.id"
            @click="run(item.id)"
          >
            <span class="tw-command-label">{{ item.label }}</span>
            <span v-if="item.keys.length" class="tw-command-keys">{{ item.keys.join(' / ') }}</span>
          </button>
        </template>
        <p v-if="!filteredGroups.length" class="tw-command-empty">没有匹配的指令</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, ref } from 'vue'
import TaskIcon from './TaskIcon.vue'

export interface PaletteCommand {
  id: string
  label: string
  group: string
  keys: string[]
}

const props = defineProps<{ commands: PaletteCommand[]; hint: string }>()
const emit = defineEmits<{ (event: 'run', id: string): void; (event: 'close'): void }>()

const query = ref('')
const activeId = ref('')
const inputEl = ref<HTMLInputElement | null>(null)

const filteredGroups = computed(() => {
  const keyword = query.value.trim().toLowerCase()
  const items = keyword
    ? props.commands.filter((item) => item.label.toLowerCase().includes(keyword))
    : props.commands
  const groups = new Map<string, PaletteCommand[]>()
  for (const item of items) {
    const list = groups.get(item.group) || []
    list.push(item)
    groups.set(item.group, list)
  }
  const rows = [...groups.entries()].map(([name, list]) => ({ name, items: list }))
  const flat = rows.flatMap((group) => group.items)
  if (!flat.some((item) => item.id === activeId.value)) activeId.value = flat[0]?.id || ''
  return rows
})

const flatItems = computed(() => filteredGroups.value.flatMap((group) => group.items))

function move(delta: number) {
  const items = flatItems.value
  if (!items.length) return
  const index = items.findIndex((item) => item.id === activeId.value)
  const next = (index + delta + items.length) % items.length
  activeId.value = items[next].id
}

function run(id: string) {
  if (!id) return
  emit('run', id)
}

function runActive() {
  run(activeId.value)
}

onMounted(async () => {
  await nextTick()
  inputEl.value?.focus()
  activeId.value = flatItems.value[0]?.id || ''
})
</script>
