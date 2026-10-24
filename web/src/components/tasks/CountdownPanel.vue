<template>
  <section class="tw-countdown">
    <header class="tw-countdown-head">
      <div class="tw-countdown-title-wrap">
        <button class="tw-countdown-title" @click="viewMenuOpen = !viewMenuOpen">
          <span>{{ archived ? '已归档' : '倒数纪念日' }}</span>
          <TaskIcon name="chevron" :size="13" />
        </button>
        <div v-if="viewMenuOpen" class="tw-countdown-view-menu">
          <button :class="{ active: !archived }" @click="switchArchived(false)">记录中</button>
          <button :class="{ active: archived }" @click="switchArchived(true)">已归档</button>
        </div>
      </div>
      <div class="tw-countdown-head-actions">
        <button v-if="!archived" class="tw-icon-button" title="添加倒数日" @click="openCreate"><TaskIcon name="plus" :size="20" /></button>
        <button class="tw-icon-button" title="刷新" @click="load"><TaskIcon name="refresh" :size="17" /></button>
      </div>
    </header>

    <div class="tw-countdown-tabs">
      <button v-for="tab in tabs" :key="tab.value" :class="{ active: filter === tab.value }" @click="filter = tab.value">{{ tab.label }}</button>
    </div>

    <div v-if="loading" class="tw-countdown-loading"><a-spin /></div>
    <div v-else-if="!filteredItems.length" class="tw-countdown-empty">
      <div class="tw-countdown-empty-icon"><TaskIcon name="countdown" :size="36" /></div>
      <h3>{{ archived ? '没有已归档的倒数日' : '记录值得期待的日子' }}</h3>
      <p>{{ archived ? '归档后的倒数日会出现在这里。' : '生日、纪念日、节日，都可以在这里倒数。' }}</p>
      <button v-if="!archived" class="tw-primary-button" @click="openCreate">新建倒数日</button>
    </div>
    <div v-else class="tw-countdown-grid">
      <article
        v-for="item in filteredItems"
        :key="item.id"
        class="tw-countdown-card"
        :class="[`style-${item.style}`, `type-${item.type}`, { pinned: item.pinned, past: item.state === 'past', 'has-image': !!item.backgroundUrl, 'has-preset': !!item.background && !item.backgroundUrl, dragging: draggingId === item.id, 'drag-over': dragOverId === item.id && draggingId !== item.id }]"
        :style="cardStyle(item)"
        :draggable="!archived && filter === 'all'"
        role="button"
        tabindex="0"
        @click="onCardClick(item)"
        @keydown.enter="onCardClick(item)"
        @dragstart="startDrag(item, $event)"
        @dragover.prevent="dragOverId = item.id"
        @dragleave="dragOverId = 0"
        @drop.prevent="dropOn(item)"
        @dragend="endDrag"
      >
        <div class="tw-countdown-card-pin" v-if="item.pinned"><TaskIcon name="flag" :size="13" /></div>
        <header>
          <span class="tw-countdown-icon" :style="{ backgroundColor: item.color }">{{ item.icon || '⏳' }}</span>
          <strong>{{ item.name }}</strong>
        </header>
        <div class="tw-countdown-number" :class="item.state">
          <template v-if="item.state === 'today'">今天</template>
          <template v-else>{{ countdownNumber(item) }}<small v-if="item.daysOption === 'hour'">小时</small></template>
        </div>
        <p class="tw-countdown-subtitle">
          <template v-if="item.state === 'today'">{{ formatDate(item.occurrenceDate, item.dateDisplayFormat) }}</template>
          <template v-else-if="item.state === 'future'">距离 {{ formatDate(item.occurrenceDate, item.dateDisplayFormat) }} 还有</template>
          <template v-else>距离 {{ formatDate(item.date, item.dateDisplayFormat) }} 已经</template>
        </p>
        <p v-if="item.type === 'birthday' && item.showAge && item.age" class="tw-countdown-age">{{ item.age }} 岁</p>
        <p v-if="item.calendar === 'lunar'" class="tw-countdown-lunar-label">农历 {{ lunarLabel(item) }}</p>
        <footer v-if="!archived" class="tw-countdown-card-actions">
          <button class="tw-icon-button" :title="item.pinned ? '取消置顶' : '置顶'" @click.stop="togglePin(item)"><TaskIcon name="flag" :size="14" /></button>
          <button class="tw-icon-button" title="编辑" @click.stop="openEdit(item)"><TaskIcon name="edit" :size="14" /></button>
          <button class="tw-icon-button" title="备注" @click.stop="openNote(item)"><TaskIcon name="note" :size="14" /></button>
          <button class="tw-icon-button" title="归档" @click.stop="archiveItem(item)"><TaskIcon name="folder" :size="14" /></button>
          <button class="tw-icon-button danger" title="删除" @click.stop="deleteItem(item)"><TaskIcon name="trash" :size="14" /></button>
        </footer>
        <footer v-else class="tw-countdown-card-actions">
          <button class="tw-icon-button" title="恢复" @click.stop="restoreItem(item)"><TaskIcon name="restore" :size="14" /></button>
          <button class="tw-icon-button danger" title="删除" @click.stop="deleteItem(item)"><TaskIcon name="trash" :size="14" /></button>
        </footer>
      </article>
    </div>

    <div v-if="detailItem" class="tw-dialog-scrim" @click.self="detailItem = null">
      <div class="tw-dialog tw-countdown-detail" role="dialog" aria-modal="true">
        <header class="tw-dialog-head">
          <h2>{{ detailItem.name }}</h2>
          <button class="tw-icon-button" title="关闭" @click="detailItem = null"><TaskIcon name="close" :size="16" /></button>
        </header>
        <div class="tw-countdown-detail-body" :class="{ 'has-image': !!detailItem.backgroundUrl, 'has-preset': !!detailItem.background && !detailItem.backgroundUrl }" :style="cardStyle(detailItem)">
          <div class="tw-countdown-detail-icon" :style="{ backgroundColor: detailItem.color }">{{ detailItem.icon || '⏳' }}</div>
          <div class="tw-countdown-detail-number" :class="detailItem.state">
            <template v-if="detailItem.state === 'today'">今天</template>
            <template v-else>{{ countdownNumber(detailItem) }}<small v-if="detailItem.daysOption === 'hour'">小时</small></template>
          </div>
          <p class="tw-countdown-detail-date">
            <template v-if="detailItem.state === 'today'">{{ formatDate(detailItem.occurrenceDate, detailItem.dateDisplayFormat) }}</template>
            <template v-else-if="detailItem.state === 'future'">距离 {{ formatDate(detailItem.occurrenceDate, detailItem.dateDisplayFormat) }} 还有</template>
            <template v-else>距离 {{ formatDate(detailItem.date, detailItem.dateDisplayFormat) }} 已经</template>
          </p>
          <p v-if="detailItem.calendar === 'lunar'" class="tw-countdown-detail-lunar">农历 {{ lunarLabel(detailItem) }}<span v-if="detailItem.lunarLeap"> · 闰月</span></p>
          <p v-if="detailItem.type === 'birthday' && detailItem.showAge && detailItem.age && detailItem.calendar === 'solar'" class="tw-countdown-detail-age">{{ detailItem.age }} 岁</p>
          <div v-if="detailItem.remark" class="tw-countdown-detail-note">{{ detailItem.remark }}</div>
          <div class="tw-countdown-detail-reminders">
            <span>{{ reminderSummary(detailItem) }}</span>
            <small>{{ detailItem.reminderTime || '09:00' }}</small>
          </div>
        </div>
        <footer class="tw-dialog-foot tw-countdown-detail-foot">
          <button class="tw-dialog-cancel" @click="detailItem = null">关闭</button>
          <button v-if="!archived" class="tw-ghost-button" @click="editFromDetail">编辑</button>
          <button v-if="!archived" class="tw-danger-link" @click="archiveFromDetail">归档</button>
          <button v-else class="tw-ghost-button" @click="restoreFromDetail">恢复</button>
          <button class="tw-danger-link" @click="deleteFromDetail">删除</button>
        </footer>
      </div>
    </div>

    <div v-if="dialogOpen" class="tw-dialog-scrim" @click.self="dialogOpen = false">
      <div class="tw-dialog tw-countdown-dialog" role="dialog" aria-modal="true">
        <header class="tw-dialog-head">
          <h2>{{ editingId ? '编辑倒数日' : '添加倒数日' }}</h2>
          <button class="tw-icon-button" title="关闭" @click="dialogOpen = false"><TaskIcon name="close" :size="16" /></button>
        </header>
        <div class="tw-dialog-body tw-countdown-form">
          <div class="tw-countdown-form-top">
            <button class="tw-countdown-icon-editor" :style="{ backgroundColor: form.color }" @click="cycleIcon">{{ form.icon }}</button>
            <input v-model="form.name" class="tw-dialog-input" maxlength="64" placeholder="名称" />
          </div>
          <div class="tw-countdown-type-row">
            <button v-for="item in typeOptions" :key="item.value" class="tw-countdown-type" :class="{ active: form.type === item.value }" @click="form.type = item.value">{{ item.label }}</button>
          </div>
          <div class="tw-countdown-presets">
            <span>快速添加</span>
            <button v-for="preset in festivalPresets" :key="preset.name" class="tw-countdown-preset" @click="applyPreset(preset)">{{ preset.icon }} {{ preset.name }}</button>
            <button v-for="preset in lunarFestivalPresets" :key="preset.name" class="tw-countdown-preset lunar" @click="applyLunarPreset(preset)">{{ preset.icon }} {{ preset.name }}</button>
            <button class="tw-countdown-preset weekend" @click="applyWeekend">🏖️ 周末</button>
          </div>
          <div class="tw-countdown-calendar-switch">
            <span>历法</span>
            <button :class="{ active: form.calendar === 'solar' }" @click="setCalendar('solar')">公历</button>
            <button :class="{ active: form.calendar === 'lunar' }" @click="setCalendar('lunar')">农历</button>
          </div>
          <div v-if="form.calendar === 'solar'" class="tw-countdown-form-grid">
            <label class="tw-countdown-field"><span>日期</span><a-date-picker v-model="form.date" class="tw-date-control" value-format="YYYY-MM-DD" format="YYYY-MM-DD" /></label>
            <label class="tw-countdown-field"><span>重复</span><select v-model="form.repeat" class="tw-field-select"><option value="none">不重复</option><option value="yearly">每年</option><option value="monthly">每月</option><option value="weekly">每周</option><option value="weekend">每个周末</option></select></label>
          </div>
          <div v-else class="tw-countdown-form-grid lunar">
            <label class="tw-countdown-field"><span>农历月份</span><select v-model.number="form.lunarMonth" class="tw-field-select"><option v-for="month in 12" :key="month" :value="month">{{ lunarMonthLabel(month) }}</option></select></label>
            <label class="tw-countdown-field"><span>农历日期</span><select v-model.number="form.lunarDay" class="tw-field-select"><option v-for="day in 30" :key="day" :value="day">{{ lunarDayLabel(day) }}</option></select></label>
            <label class="tw-countdown-check"><input v-model="form.lunarLeap" type="checkbox" /><span>闰月</span></label>
            <label v-if="form.type === 'birthday'" class="tw-countdown-field"><span>出生年份</span><input v-model.number="form.lunarYear" type="number" min="1900" max="2100" /></label>
            <label class="tw-countdown-field"><span>重复</span><select v-model="form.repeat" class="tw-field-select"><option value="yearly">每年</option><option value="none">不重复</option></select></label>
          </div>
          <div class="tw-countdown-form-grid">
            <label class="tw-countdown-field"><span>显示格式</span><select v-model="form.dateDisplayFormat" class="tw-field-select"><option value="day">标准</option><option value="full">完整日期</option></select></label>
            <label class="tw-countdown-field"><span>显示单位</span><select v-model="form.daysOption" class="tw-field-select"><option value="day">按天</option><option value="hour">按小时</option></select></label>
            <label v-if="form.type === 'birthday'" class="tw-countdown-check"><input v-model="form.showAge" type="checkbox" /><span>显示年龄</span></label>
            <label v-else class="tw-countdown-check"><input v-model="form.ignoreYear" type="checkbox" /><span>忽略年份</span></label>
          </div>
          <div class="tw-countdown-form-section">
            <span>提醒</span>
            <div class="tw-countdown-checks">
              <label v-for="offset in reminderOptions" :key="offset.value" class="tw-countdown-check"><input v-model="form.reminderOffsets" type="checkbox" :value="offset.value" /><span>{{ offset.label }}</span></label>
            </div>
            <div class="tw-countdown-reminder-time">
              <span>提醒时间</span>
              <a-time-picker v-model="form.reminderTime" class="tw-date-control" format="HH:mm" />
            </div>
          </div>
          <div class="tw-countdown-form-section">
            <span>背景</span>
            <div class="tw-countdown-backgrounds">
              <button v-for="background in backgroundPresets" :key="background.value" class="tw-countdown-background" :class="{ active: form.background === background.value && !backgroundPreview }" :style="background.style" :title="background.label" @click="selectBackground(background.value)">{{ background.label }}</button>
            </div>
            <div class="tw-countdown-background-upload">
              <img v-if="backgroundPreview" :src="backgroundPreview" alt="背景预览" />
              <button type="button" class="tw-ghost-button" @click="backgroundInput?.click()">{{ backgroundPreview ? '更换图片' : '上传图片' }}</button>
              <button v-if="backgroundPreview" type="button" class="tw-ghost-button" @click="clearBackground">移除图片</button>
              <input ref="backgroundInput" type="file" accept="image/jpeg,image/png,image/webp,image/gif" hidden @change="onBackgroundFile" />
              <small>JPG / PNG / WEBP / GIF，≤ 2MB</small>
            </div>
          </div>
          <div class="tw-countdown-form-section">
            <span>样式</span>
            <div class="tw-countdown-style-row">
              <button v-for="style in styleOptions" :key="style.value" class="tw-countdown-style" :class="{ active: form.style === style.value }" @click="form.style = style.value">{{ style.label }}</button>
            </div>
            <div class="tw-countdown-colors">
              <button v-for="color in colors" :key="color" class="tw-countdown-color" :class="{ active: form.color === color }" :style="{ backgroundColor: color }" @click="form.color = color" />
            </div>
          </div>
          <label class="tw-countdown-field"><span>备注</span><textarea v-model="form.remark" maxlength="2000" rows="3" placeholder="记下这个日子的意义…" /></label>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="dialogOpen = false">取消</button>
          <button class="tw-dialog-ok" :disabled="saving || !form.name.trim() || !form.date" @click="save">{{ saving ? '保存中…' : '保存' }}</button>
        </footer>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { Message, Modal } from '@arco-design/web-vue'
import type { CountdownDraft, CountdownItem, CountdownRepeat, CountdownType } from '../../types'
import { createCountdown, deleteCountdown, deleteCountdownBackground, fetchCountdowns, reorderCountdowns, updateCountdown, uploadCountdownBackground } from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'

const tabs: Array<{ value: 'all' | CountdownType; label: string }> = [
  { value: 'all', label: '所有' },
  { value: 'anniversary', label: '纪念日' },
  { value: 'countdown', label: '倒数日' },
  { value: 'birthday', label: '生日' },
  { value: 'festival', label: '节日' },
]
const typeOptions = tabs.filter((tab) => tab.value !== 'all') as Array<{ value: CountdownType; label: string }>
const styleOptions = [
  { value: 'normal', label: '简约' },
  { value: 'soft', label: '柔和' },
  { value: 'color', label: '彩色' },
  { value: 'outline', label: '描边' },
] as const
const reminderOptions = [
  { value: 0, label: '当天' },
  { value: 1, label: '提前 1 天' },
  { value: 3, label: '提前 3 天' },
  { value: 7, label: '提前 7 天' },
]
const colors = ['#92D0FF', '#FDB368', '#FF8F9C', '#B58BFF', '#97E38B', '#5ED4C5', '#F4C95D', '#A2A8B8']
const backgroundPresets = [
  { value: '', label: '无', style: {} },
  { value: 'aurora', label: '极光', style: { background: 'linear-gradient(135deg, #e0c3fc, #8ec5fc)' } },
  { value: 'sunset', label: '晚霞', style: { background: 'linear-gradient(135deg, #ffecd2, #fcb69f)' } },
  { value: 'mint', label: '薄荷', style: { background: 'linear-gradient(135deg, #d4fc79, #96e6a1)' } },
  { value: 'rose', label: '玫瑰', style: { background: 'linear-gradient(135deg, #fbc2eb, #a6c1ee)' } },
]
const festivalPresets = [
  { name: '元旦', month: 1, day: 1, icon: '🎊', color: '#92D0FF' },
  { name: '情人节', month: 2, day: 14, icon: '❤️', color: '#FF8F9C' },
  { name: '劳动节', month: 5, day: 1, icon: '🌱', color: '#97E38B' },
  { name: '儿童节', month: 6, day: 1, icon: '🎈', color: '#F4C95D' },
  { name: '国庆节', month: 10, day: 1, icon: '🇨🇳', color: '#FF8F9C' },
  { name: '圣诞节', month: 12, day: 25, icon: '🎄', color: '#97E38B' },
]
const lunarFestivalPresets = [
  { name: '春节', lunarMonth: 1, lunarDay: 1, icon: '🧧', color: '#FF8F9C' },
  { name: '元宵节', lunarMonth: 1, lunarDay: 15, icon: '🏮', color: '#FDB368' },
  { name: '端午节', lunarMonth: 5, lunarDay: 5, icon: '🐉', color: '#97E38B' },
  { name: '中秋节', lunarMonth: 8, lunarDay: 15, icon: '🌕', color: '#F4C95D' },
  { name: '重阳节', lunarMonth: 9, lunarDay: 9, icon: '🍁', color: '#B58BFF' },
]
const lunarMonths = ['正月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '冬月', '腊月']
const lunarDays = ['初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十', '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十', '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十']
const emojis = ['⏳', '🎂', '🎉', '💍', '🏖️', '🎓', '🏆', '❤️', '🌸', '📅']

const items = ref<CountdownItem[]>([])
const loading = ref(true)
const archived = ref(false)
const filter = ref<'all' | CountdownType>('all')
const viewMenuOpen = ref(false)
const draggingId = ref(0)
const dragOverId = ref(0)
const suppressClick = ref(false)
const dialogOpen = ref(false)
const detailItem = ref<CountdownItem | null>(null)
const backgroundInput = ref<HTMLInputElement | null>(null)
const backgroundFile = ref<File | null>(null)
const backgroundPreview = ref('')
const backgroundHad = ref(false)
const removeBackground = ref(false)
let previewObjectURL = ''
const editingId = ref(0)
const saving = ref(false)
const form = reactive({
  name: '',
  type: 'countdown' as CountdownType,
  date: '',
  calendar: 'solar' as 'solar' | 'lunar',
  lunarMonth: 1,
  lunarDay: 1,
  lunarLeap: false,
  icon: '⏳',
  color: colors[0],
  style: 'normal' as 'normal' | 'color' | 'soft' | 'outline',
  background: '',
  remark: '',
  repeat: 'none' as CountdownRepeat,
  ignoreYear: false,
  showAge: false,
  dateDisplayFormat: 'day' as 'day' | 'full',
  reminderOffsets: [0, 3] as number[],
  reminderTime: '09:00',
  lunarYear: new Date().getFullYear() - 30,
  daysOption: 'day' as 'day' | 'hour',
})
const filteredItems = computed(() => filter.value === 'all' ? items.value : items.value.filter((item) => item.type === filter.value))

function dateInput(date: Date) {
  const pad = (value: number) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

function stampDate(value: string) {
  return Number(value.replaceAll('-', ''))
}

function reminderSummary(item: CountdownItem) {
  const offsets = parseReminders(item.reminders)
  if (!offsets.length) return '未设置提醒'
  const labels: Record<number, string> = { 0: '当天', 1: '提前 1 天', 3: '提前 3 天', 7: '提前 7 天' }
  return offsets.map((offset) => labels[offset] || `提前 ${offset} 天`).join('、')
}

function editFromDetail() {
  if (!detailItem.value) return
  const item = detailItem.value
  detailItem.value = null
  openEdit(item)
}

async function archiveFromDetail() {
  if (!detailItem.value) return
  const item = detailItem.value
  detailItem.value = null
  await archiveItem(item)
}

async function restoreFromDetail() {
  if (!detailItem.value) return
  const item = detailItem.value
  detailItem.value = null
  await restoreItem(item)
}

function deleteFromDetail() {
  if (!detailItem.value) return
  const item = detailItem.value
  detailItem.value = null
  deleteItem(item)
}

function formatDate(stamp: number, display: 'day' | 'full' = 'day') {
  const raw = String(stamp).padStart(8, '0')
  if (raw.length !== 8) return ''
  if (display === 'full') return `${raw.slice(0, 4)}-${raw.slice(4, 6)}-${raw.slice(6, 8)}`
  return `${raw.slice(0, 4)}年${Number(raw.slice(4, 6))}月${Number(raw.slice(6, 8))}日`
}

function parseReminders(raw: string) {
  try {
    const values = JSON.parse(raw || '[]') as unknown
    return Array.isArray(values) ? values.map(Number).filter((value) => Number.isFinite(value)) : []
  } catch {
    return []
  }
}

function countdownNumber(item: CountdownItem) {
  return item.daysOption === 'hour' ? item.hours : item.days
}

function cardStyle(item: CountdownItem) {
  const style: Record<string, string> = {}
  if (item.backgroundUrl) {
    style.backgroundImage = `url("${item.backgroundUrl}")`
    style.backgroundSize = 'cover'
    style.backgroundPosition = 'center'
    return style
  }
  const background = backgroundPresets.find((preset) => preset.value === item.background)
  if (background?.style.background) style.background = background.style.background
  if (item.style === 'color') {
    style.backgroundColor = item.color
    style.borderColor = item.color
  } else if (item.style === 'soft') {
    style.backgroundColor = `${item.color}22`
    style.borderColor = `${item.color}55`
  } else if (item.style === 'outline') {
    style.borderColor = item.color
  }
  return Object.keys(style).length ? style : undefined
}

function startDrag(item: CountdownItem, event: DragEvent) {
  if (archived.value || filter.value !== 'all') return
  draggingId.value = item.id
  dragOverId.value = 0
  suppressClick.value = true
  event.dataTransfer?.setData('text/plain', String(item.id))
}

function endDrag() {
  draggingId.value = 0
  dragOverId.value = 0
  setTimeout(() => { suppressClick.value = false }, 80)
}

async function dropOn(target: CountdownItem) {
  const sourceId = draggingId.value
  if (!sourceId || sourceId === target.id) {
    endDrag()
    return
  }
  const from = items.value.findIndex((item) => item.id === sourceId)
  const to = items.value.findIndex((item) => item.id === target.id)
  if (from < 0 || to < 0) {
    endDrag()
    return
  }
  const next = [...items.value]
  const [moved] = next.splice(from, 1)
  next.splice(to, 0, moved)
  items.value = next
  try {
    await reorderCountdowns(next.map((item) => item.id))
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存排序失败')
    await load()
  } finally {
    endDrag()
  }
}

function onCardClick(item: CountdownItem) {
  if (suppressClick.value) return
  detailItem.value = item
}

async function load() {
  loading.value = true
  try {
    const data = await fetchCountdowns(archived.value)
    items.value = data.countdowns
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载倒数日失败')
  } finally {
    loading.value = false
  }
}

function switchArchived(value: boolean) {
  archived.value = value
  viewMenuOpen.value = false
  filter.value = 'all'
  void load()
}

function resetForm() {
  form.name = ''
  form.type = 'countdown'
  form.date = dateInput(new Date(Date.now() + 10 * 86400000))
  form.calendar = 'solar'
  form.lunarMonth = 1
  form.lunarDay = 1
  form.lunarLeap = false
  form.icon = '⏳'
  form.color = colors[0]
  form.style = 'normal'
  form.background = ''
  form.remark = ''
  form.repeat = 'none'
  form.ignoreYear = false
  form.showAge = false
  form.dateDisplayFormat = 'day'
  form.reminderOffsets = [0, 3]
  form.reminderTime = '09:00'
  form.lunarYear = new Date().getFullYear() - 30
  form.daysOption = 'day'
  backgroundFile.value = null
  backgroundPreview.value = ''
  backgroundHad.value = false
  removeBackground.value = false
  revokePreview()
}

function openCreate() {
  editingId.value = 0
  resetForm()
  dialogOpen.value = true
}

function openEdit(item: CountdownItem) {
  editingId.value = item.id
  form.name = item.name
  form.type = item.type
  form.date = `${String(item.date).slice(0, 4)}-${String(item.date).slice(4, 6)}-${String(item.date).slice(6, 8)}`
  form.calendar = item.calendar || 'solar'
  form.lunarMonth = item.lunarMonth || 1
  form.lunarDay = item.lunarDay || 1
  form.lunarLeap = item.lunarLeap || false
  form.icon = item.icon
  form.color = item.color
  form.style = item.style
  form.background = item.background
  form.remark = item.remark
  form.repeat = item.repeat
  form.ignoreYear = item.ignoreYear
  form.showAge = item.showAge
  form.dateDisplayFormat = item.dateDisplayFormat
  form.reminderOffsets = parseReminders(item.reminders)
  form.reminderTime = item.reminderTime || '09:00'
  form.lunarYear = item.lunarYear || new Date().getFullYear() - 30
  form.daysOption = item.daysOption === 'hour' ? 'hour' : 'day'
  backgroundFile.value = null
  backgroundPreview.value = item.backgroundUrl || ''
  backgroundHad.value = !!item.backgroundUrl
  removeBackground.value = false
  dialogOpen.value = true
}

function openNote(item: CountdownItem) {
  openEdit(item)
}

function setCalendar(calendar: 'solar' | 'lunar') {
  form.calendar = calendar
  if (calendar === 'lunar') {
    form.repeat = 'yearly'
    if (form.type === 'birthday' && !form.lunarYear) form.lunarYear = new Date().getFullYear() - 30
  }
}

function selectBackground(value: string) {
  form.background = value
  backgroundFile.value = null
  backgroundPreview.value = ''
  revokePreview()
  if (backgroundHad.value) removeBackground.value = true
}

function revokePreview() {
  if (previewObjectURL) {
    URL.revokeObjectURL(previewObjectURL)
    previewObjectURL = ''
  }
}

function onBackgroundFile(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  if (!file.type.startsWith('image/')) {
    Message.error('请选择图片文件')
    input.value = ''
    return
  }
  if (file.size > 2 * 1024 * 1024) {
    Message.error('背景图片不能超过 2MB')
    input.value = ''
    return
  }
  revokePreview()
  previewObjectURL = URL.createObjectURL(file)
  backgroundFile.value = file
  backgroundPreview.value = previewObjectURL
  input.value = ''
}

function clearBackground() {
  backgroundFile.value = null
  backgroundPreview.value = ''
  revokePreview()
  if (backgroundHad.value) removeBackground.value = true
}

function lunarMonthLabel(month: number) {
  return lunarMonths[month - 1] || ''
}

function lunarDayLabel(day: number) {
  return lunarDays[day - 1] || ''
}

function lunarLabel(item: CountdownItem) {
  return `${lunarMonthLabel(item.lunarMonth)}${lunarDayLabel(item.lunarDay)}`
}

function nextFestivalDate(month: number, day: number) {
  const now = new Date()
  let date = new Date(now.getFullYear(), month - 1, day)
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  if (date < today) date = new Date(now.getFullYear() + 1, month - 1, day)
  return dateInput(date)
}

function applyPreset(preset: { name: string; month: number; day: number; icon: string; color: string }) {
  form.name = preset.name
  form.type = 'festival'
  form.date = nextFestivalDate(preset.month, preset.day)
  form.repeat = 'yearly'
  form.icon = preset.icon
  form.color = preset.color
  form.calendar = 'solar'
}

function applyLunarPreset(preset: { name: string; lunarMonth: number; lunarDay: number; icon: string; color: string }) {
  form.name = preset.name
  form.type = 'festival'
  form.calendar = 'lunar'
  form.lunarMonth = preset.lunarMonth
  form.lunarDay = preset.lunarDay
  form.lunarLeap = false
  form.date = dateInput(new Date())
  form.repeat = 'yearly'
  form.icon = preset.icon
  form.color = preset.color
}

function applyWeekend() {
  const now = new Date()
  const day = now.getDay()
  const offset = day === 0 || day === 6 ? 0 : 6 - day
  const date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset)
  form.name = '周末'
  form.type = 'festival'
  form.date = dateInput(date)
  form.repeat = 'weekend'
  form.icon = '🏖️'
  form.color = '#92D0FF'
  form.calendar = 'solar'
}

function cycleIcon() {
  const index = emojis.indexOf(form.icon)
  form.icon = emojis[(index + 1) % emojis.length]
}

function payload(): CountdownDraft {
  return {
    name: form.name.trim(),
    type: form.type,
    date: stampDate(form.date),
    calendar: form.calendar,
    lunarMonth: form.lunarMonth,
    lunarDay: form.lunarDay,
    lunarLeap: form.lunarLeap,
    lunarYear: form.lunarYear,
    daysOption: form.daysOption,
    icon: form.icon,
    color: form.color,
    style: form.style,
    background: form.background,
    remark: form.remark,
    reminders: JSON.stringify([...form.reminderOffsets].sort((a, b) => a - b)),
    reminderTime: form.reminderTime || '09:00',
    repeat: form.repeat,
    ignoreYear: form.ignoreYear,
    showAge: form.showAge,
    dateDisplayFormat: form.dateDisplayFormat,
    status: 0,
    pinned: false,
  }
}

async function save() {
  if (!form.name.trim() || !form.date) return
  saving.value = true
  let savedID = editingId.value
  try {
    if (editingId.value) {
      const { status: _status, pinned: _pinned, ...patch } = payload()
      const saved = await updateCountdown(editingId.value, patch)
      savedID = saved.countdown.id
    } else {
      const saved = await createCountdown(payload())
      savedID = saved.countdown.id
    }
    if (backgroundFile.value) {
      try {
        await uploadCountdownBackground(savedID, backgroundFile.value)
      } catch (error) {
        Message.error(error instanceof Error ? error.message : '背景图片上传失败')
      }
    } else if (removeBackground.value && savedID) {
      try {
        await deleteCountdownBackground(savedID)
      } catch (error) {
        Message.error(error instanceof Error ? error.message : '背景图片移除失败')
      }
    }
    dialogOpen.value = false
    backgroundFile.value = null
    revokePreview()
    Message.success(editingId.value ? '倒数日已更新' : '倒数日已添加')
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存倒数日失败')
  } finally {
    saving.value = false
  }
}

async function togglePin(item: CountdownItem) {
  try {
    await updateCountdown(item.id, { pinned: !item.pinned })
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '更新置顶失败')
  }
}

async function archiveItem(item: CountdownItem) {
  try {
    await updateCountdown(item.id, { status: 1 })
    Message.success('已归档')
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '归档失败')
  }
}

async function restoreItem(item: CountdownItem) {
  try {
    await updateCountdown(item.id, { status: 0 })
    Message.success('已恢复')
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '恢复失败')
  }
}

function deleteItem(item: CountdownItem) {
  Modal.confirm({
    title: '删除倒数日',
    content: `确定删除「${item.name}」吗？`,
    okText: '删除',
    cancelText: '取消',
    okButtonProps: { status: 'danger' },
    async onOk() {
      try {
        await deleteCountdown(item.id)
        Message.success('已删除')
        await load()
      } catch (error) {
        Message.error(error instanceof Error ? error.message : '删除失败')
      }
    },
  })
}

let refreshTimer: ReturnType<typeof setInterval> | undefined
onMounted(() => {
  void load()
  refreshTimer = setInterval(() => { void load() }, 60000)
})
onBeforeUnmount(() => {
  if (refreshTimer) clearInterval(refreshTimer)
  revokePreview()
})
</script>
