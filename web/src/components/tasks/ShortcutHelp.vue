<template>
  <div class="tw-dialog-scrim" @click.self="$emit('close')">
    <div class="tw-dialog tw-shortcut-dialog" role="dialog" aria-modal="true" aria-label="快捷键">
      <header class="tw-dialog-head">
        <h2>快捷键</h2>
        <button class="tw-icon-button" title="关闭" @click="$emit('close')">
          <TaskIcon name="close" :size="16" />
        </button>
      </header>
      <div class="tw-dialog-body tw-shortcut-body">
        <p class="tw-shortcut-tip">点击键位即可重新录制；输入框聚焦时快捷键不生效。</p>
        <section v-for="group in groups" :key="group" class="tw-shortcut-group">
          <h3>{{ group }}</h3>
          <div v-for="action in actionsByGroup(group)" :key="action.id" class="tw-shortcut-row">
            <span class="tw-shortcut-label">{{ action.label }}</span>
            <span class="tw-shortcut-keys">
              <button
                v-for="(combo, index) in bindings[action.id] || []"
                :key="combo + index"
                class="tw-shortcut-key"
                :class="{ recording: recordingId === action.id && recordingIndex === index }"
                @click="startRecording(action.id, index)"
              >
                {{ recordingId === action.id && recordingIndex === index ? '按下按键…' : comboLabel(combo, isMac) }}
              </button>
              <button v-if="!(bindings[action.id] || []).length" class="tw-shortcut-key empty" @click="startRecording(action.id, 0)">
                设置快捷键
              </button>

            </span>
          </div>
        </section>
        <p v-if="error" class="tw-shortcut-error">{{ error }}</p>
      </div>
      <footer class="tw-dialog-foot tw-shortcut-foot">
        <button class="tw-dialog-cancel" @click="reset">恢复默认设置</button>
        <span class="tw-shortcut-spacer" />
        <button class="tw-dialog-cancel" @click="$emit('close')">取消</button>
        <button class="tw-dialog-ok" @click="save">保存</button>
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import {
  DEFAULT_SHORTCUTS,
  comboLabel,
  defaultBindings,
  hasConflict,
  keyEventToCombo,
  type ShortcutBindings,
} from '../../shortcuts'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{ bindings: ShortcutBindings; isMac: boolean }>()
const emit = defineEmits<{ (event: 'save', bindings: ShortcutBindings): void; (event: 'close'): void }>()

const local = ref<ShortcutBindings>(clone(props.bindings))
const recordingId = ref('')
const recordingIndex = ref(0)
const error = ref('')

const groups: Array<'通用' | '任务' | '视图' | '导航'> = ['通用', '任务', '视图', '导航']

function clone(source: ShortcutBindings): ShortcutBindings {
  return Object.fromEntries(Object.entries(source).map(([key, value]) => [key, [...value]]))
}

function actionsByGroup(group: string) {
  return DEFAULT_SHORTCUTS.filter((action) => action.group === group)
}

function startRecording(id: string, index: number) {
  recordingId.value = id
  recordingIndex.value = index
  error.value = ''
}

function reset() {
  local.value = defaultBindings()
  recordingId.value = ''
  error.value = ''
}

function save() {
  emit('save', clone(local.value))
}

function onKeydown(event: KeyboardEvent) {
  if (!recordingId.value) return
  event.preventDefault()
  event.stopPropagation()
  if (event.key === 'Escape') {
    recordingId.value = ''
    return
  }
  const combo = keyEventToCombo(event)
  if (!combo) return
  const id = recordingId.value
  if (hasConflict(local.value, id, combo)) {
    error.value = `${comboLabel(combo, props.isMac)} 已被其他操作占用`
    return
  }
  const keys = [...(local.value[id] || [])]
  keys[recordingIndex.value] = combo
  local.value = { ...local.value, [id]: keys }
  recordingId.value = ''
  error.value = ''
}

onMounted(() => window.addEventListener('keydown', onKeydown, true))
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown, true))
</script>
