<template>
  <div class="tw-md-editor" :class="{ 'is-readonly': readonly }">
    <div v-if="!readonly && editor" class="tw-md-toolbar" role="toolbar" aria-label="Markdown 格式">
      <button title="加粗" :class="{ active: editor.isActive('bold') }" @mousedown.prevent @click="run((c) => c.toggleBold())"><b>B</b></button>
      <button title="斜体" :class="{ active: editor.isActive('italic') }" @mousedown.prevent @click="run((c) => c.toggleItalic())"><i>I</i></button>
      <button title="删除线" :class="{ active: editor.isActive('strike') }" @mousedown.prevent @click="run((c) => c.toggleStrike())"><s>S</s></button>
      <button title="行内代码" :class="{ active: editor.isActive('code') }" @mousedown.prevent @click="run((c) => c.toggleCode())">&lt;/&gt;</button>
      <span class="tw-md-sep" />
      <button title="二级标题" :class="{ active: editor.isActive('heading', { level: 2 }) }" @mousedown.prevent @click="run((c) => c.toggleHeading({ level: 2 }))">H2</button>
      <button title="引用" :class="{ active: editor.isActive('blockquote') }" @mousedown.prevent @click="run((c) => c.toggleBlockquote())">“”</button>
      <button title="无序列表" :class="{ active: editor.isActive('bulletList') }" @mousedown.prevent @click="run((c) => c.toggleBulletList())">•</button>
      <button title="有序列表" :class="{ active: editor.isActive('orderedList') }" @mousedown.prevent @click="run((c) => c.toggleOrderedList())">1.</button>
      <button title="复选框" :class="{ active: editor.isActive('taskList') }" @mousedown.prevent @click="run((c) => c.toggleTaskList())">☑</button>
      <button title="代码块" :class="{ active: editor.isActive('codeBlock') }" @mousedown.prevent @click="run((c) => c.toggleCodeBlock())">&lt;/&gt;块</button>
      <span class="tw-md-sep" />
      <button title="插入链接" :class="{ active: editor.isActive('link') }" @mousedown.prevent @click="insertLink"><TaskIcon name="link" :size="14" /></button>
      <button title="表格" @mousedown.prevent @click="run((c) => c.insertTable({ rows: 3, cols: 3, withHeaderRow: true }))">▦</button>
      <button title="清除格式" @mousedown.prevent @click="run((c) => c.unsetAllMarks().clearNodes())">Tx</button>
      <button title="撤销" @mousedown.prevent @click="run((c) => c.undo())">↶</button>
      <button title="重做" @mousedown.prevent @click="run((c) => c.redo())">↷</button>
    </div>
    <EditorContent :editor="editor" class="tw-md-content" />
  </div>
</template>

<script setup lang="ts">
import { watch } from 'vue'
import { EditorContent, useEditor } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import Link from '@tiptap/extension-link'
import TaskList from '@tiptap/extension-task-list'
import TaskItem from '@tiptap/extension-task-item'
import Table from '@tiptap/extension-table'
import TableRow from '@tiptap/extension-table-row'
import TableHeader from '@tiptap/extension-table-header'
import TableCell from '@tiptap/extension-table-cell'
import Placeholder from '@tiptap/extension-placeholder'
import { Markdown } from 'tiptap-markdown'
import TaskIcon from './TaskIcon.vue'

const props = defineProps<{
  modelValue: string
  placeholder?: string
  readonly?: boolean
}>()

const emit = defineEmits<{ (event: 'update:modelValue', value: string): void }>()

let lastValue = props.modelValue

const editor = useEditor({
  content: props.modelValue,
  editable: !props.readonly,
  extensions: [
    StarterKit,
    Link.configure({
      openOnClick: false,
      autolink: true,
      linkOnPaste: true,
      HTMLAttributes: { target: '_blank', rel: 'noopener noreferrer' },
    }),
    TaskList,
    TaskItem.configure({ nested: true }),
    Table.configure({ resizable: true }),
    TableRow,
    TableHeader,
    TableCell,
    Placeholder.configure({ placeholder: () => props.placeholder || '用 Markdown 记录你的想法…' }),
    Markdown.configure({
      html: false,
      tightLists: true,
      linkify: true,
      breaks: false,
      transformPastedText: true,
      transformCopiedText: true,
    }),
  ],
  editorProps: {
    attributes: { class: 'tw-md-wysiwyg' },
  },
  onUpdate: ({ editor: current }) => {
    const markdown = current.storage.markdown.getMarkdown() as string
    lastValue = markdown
    emit('update:modelValue', markdown)
  },
})

function run(action: (chain: any) => any) {
  if (!editor.value) return
  action(editor.value.chain().focus()).run()
}

function insertLink() {
  if (!editor.value) return
  const raw = window.prompt('链接地址')
  if (!raw) return
  const value = raw.trim()
  const lower = value.toLowerCase()
  if (!value || lower.startsWith('javascript:') || lower.startsWith('data:') || lower.startsWith('vbscript:')) {
    window.alert('链接必须以 http(s)://、mailto:、/ 或 # 开头')
    return
  }
  const href = value.startsWith('#') || value.startsWith('/') || /^(https?:\/\/|mailto:|tel:)/i.test(value) ? value : `https://${value}`
  const chain = editor.value.chain().focus()
  if (editor.value.state.selection.empty) {
    chain.insertContent(`<a href="${href.replace(/"/g, '&quot;')}" target="_blank" rel="noopener noreferrer">${href.replace(/</g, '&lt;')}</a>`).run()
  } else {
    chain.setLink({ href }).run()
  }
}

watch(
  () => props.modelValue,
  (value) => {
    if (!editor.value || value === lastValue) return
    lastValue = value
    editor.value.commands.setContent(value, false)
  },
)

watch(
  () => props.readonly,
  (readonly) => editor.value?.setEditable(!readonly),
)
</script>
