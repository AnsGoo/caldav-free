<template>
  <section class="tw-habits">
    <header class="tw-habits-head">
      <div class="tw-habits-title">
        <button class="tw-habits-view-switch" @click="archived = !archived; load()">
          {{ archived ? '已归档习惯' : '习惯' }}
          <TaskIcon name="chevron" :size="12" />
        </button>
      </div>
      <div class="tw-habits-actions">
        <button class="tw-icon-button" :title="displayType === 'card' ? '列表视图' : '卡片视图'" @click="toggleDisplayType">
          <TaskIcon :name="displayType === 'card' ? 'list' : 'board'" :size="18" />
        </button>
        <button v-if="!archived" class="tw-icon-button" title="添加习惯" @click="openCreate">
          <TaskIcon name="plus" :size="20" />
        </button>
        <button class="tw-icon-button" title="设置与导出" @click="settingsOpen = true">
          <TaskIcon name="more" :size="18" />
        </button>
      </div>
    </header>

    <div class="tw-habit-week">
      <div v-for="day in weekDays" :key="day.stamp" class="tw-habit-week-day" :class="{ today: day.isToday }">
        <span>{{ day.weekday }}</span>
        <strong>{{ day.day }}</strong>
        <button class="tw-habit-week-dot" :class="{ done: weekDoneCount(day.stamp) > 0 }" title="本周打卡">
          <TaskIcon v-if="weekDoneCount(day.stamp) > 0" name="check" :size="11" />
        </button>
      </div>
    </div>

    <div v-if="loading" class="tw-habit-loading"><a-spin /></div>
    <div v-else-if="!habits.length" class="tw-habit-empty">
      <div class="tw-habit-empty-icon"><TaskIcon name="habit" :size="42" /></div>
      <h3>{{ archived ? '还没有归档的习惯' : '来一起养成习惯吧' }}</h3>
      <p>{{ archived ? '归档的习惯会出现在这里。' : '坚持让我们闪闪发光' }}</p>
      <button v-if="!archived" class="tw-primary-button" @click="openCreate">新建习惯</button>
    </div>
    <div v-else class="tw-habit-content" :class="{ 'card-mode': displayType === 'card', 'with-detail': selectedHabit }">
      <div class="tw-habit-list">
        <section v-for="group in habitGroups" :key="group.key" class="tw-habit-group">
          <header v-if="group.label" class="tw-habit-group-head">{{ group.label }}</header>
          <div class="tw-habit-items">
            <article
              v-for="habit in group.habits"
              :key="habit.id"
              class="tw-habit-item"
              :class="{ selected: selectedHabitId === habit.id, dragging: draggingHabitId === habit.id, 'drag-over': dragOverHabitId === habit.id && draggingHabitId !== habit.id }"
              :draggable="!archived && !preferences.groupByCompleted"
              @click="openDetail(habit)"
              @dragstart="startHabitDrag(habit, $event)"
              @dragover.prevent="dragOverHabitId = habit.id"
              @dragleave="dragOverHabitId = 0"
              @drop.prevent="dropHabit(habit)"
              @dragend="draggingHabitId = 0; dragOverHabitId = 0"
            >
              <div class="tw-habit-icon" :style="{ backgroundColor: habit.color || '#97E38B' }">{{ habit.icon || '😊' }}</div>
              <div class="tw-habit-info">
                <strong>{{ habit.name }}</strong>
                <div class="tw-habit-meta">
                  <span><TaskIcon name="habit" :size="12" /> 总 {{ habit.totalCheckIns }} 天</span>
                  <span class="streak"><TaskIcon name="flag" :size="12" /> 连续 {{ habit.currentStreak }} 天</span>
                </div>
              </div>
              <div class="tw-habit-days">
                <button
                  v-for="day in weekDays"
                  :key="day.stamp"
                  class="tw-habit-day"
                  :class="{ done: isDone(habit.id, day.stamp), partial: isPartial(habit.id, day.stamp), today: day.isToday }"
                  :title="`${day.dateLabel} ${checkinValue(habit.id, day.stamp)}/${habit.goal}`"
                  @click.stop="startCheckin(habit, day.stamp)"
                >
                  <TaskIcon v-if="isDone(habit.id, day.stamp) && habit.style !== 'icon'" name="check" :size="11" />
                  <span v-else-if="isDone(habit.id, day.stamp)" class="tw-habit-day-emoji">{{ habit.icon || '✓' }}</span>
                  <span v-else-if="isPartial(habit.id, day.stamp)">{{ checkinValue(habit.id, day.stamp) }}</span>
                </button>
              </div>
            </article>
          </div>
        </section>
      </div>

      <aside v-if="selectedHabit && detail" class="tw-habit-detail">
        <header class="tw-habit-detail-head">
          <div class="tw-habit-detail-title">
            <span class="tw-habit-detail-icon" :style="{ backgroundColor: selectedHabit.color }">{{ selectedHabit.icon }}</span>
            <strong>{{ selectedHabit.name }}</strong>
          </div>
          <div class="tw-habit-detail-actions">
            <button v-if="archived" class="tw-icon-button" title="恢复习惯" @click="restoreHabit"><TaskIcon name="restore" :size="16" /></button>
            <button v-else class="tw-icon-button" title="编辑习惯" @click="openEdit(selectedHabit)"><TaskIcon name="edit" :size="16" /></button>
            <button v-if="!archived" class="tw-icon-button" :title="selectedHabit.style === 'icon' ? '打卡样式：习惯图标' : '打卡样式：对勾'" @click="toggleHabitStyle">
              <TaskIcon :name="selectedHabit.style === 'icon' ? 'habit' : 'check'" :size="16" />
            </button>
            <button v-if="!archived" class="tw-icon-button" title="归档习惯" @click="archiveHabit"><TaskIcon name="folder" :size="16" /></button>
            <button class="tw-icon-button danger" title="删除习惯" @click="confirmDeleteHabit"><TaskIcon name="trash" :size="16" /></button>
            <button class="tw-icon-button" title="关闭详情" @click="closeDetail"><TaskIcon name="close" :size="16" /></button>
          </div>
        </header>

        <div v-if="detail.habit.targetDays > 0" class="tw-habit-target">
          <div>
            <span>坚持目标</span>
            <strong>{{ detail.stats.targetProgress }}/{{ detail.habit.targetDays }} 天</strong>
          </div>
          <div class="tw-habit-target-bar"><i :style="{ width: `${Math.min(100, detail.stats.targetProgress / detail.habit.targetDays * 100)}%` }" /></div>
          <small v-if="detail.stats.completedCycles">已完成 {{ detail.stats.completedCycles }} 轮</small>
        </div>

        <div class="tw-habit-stat-grid">
          <article><span>月打卡</span><strong>{{ detail.stats.monthCheckinDays }}<small>天</small></strong></article>
          <article><span>总打卡</span><strong>{{ detail.stats.totalCheckinDays }}<small>天</small></strong></article>
          <article><span>月完成率</span><strong>{{ Math.round(detail.stats.monthCompletionRate) }}<small>%</small></strong></article>
          <article><span>当前连续</span><strong>{{ detail.stats.currentStreak }}<small>天</small></strong></article>
          <article><span>月完成量</span><strong>{{ detail.stats.monthCompletionCount }}<small>次</small></strong></article>
          <article><span>总完成量</span><strong>{{ detail.stats.totalCompletionCount }}<small>次</small></strong></article>
        </div>

        <div class="tw-habit-calendar">
          <header>
            <button class="tw-icon-button" title="上个月" @click="shiftMonth(-1)"><TaskIcon name="chevron" :size="14" style="transform: rotate(180deg)" /></button>
            <strong>{{ monthTitle }}</strong>
            <button class="tw-icon-button" title="下个月" @click="shiftMonth(1)"><TaskIcon name="chevron" :size="14" /></button>
          </header>
          <div class="tw-habit-calendar-week">
            <span v-for="label in ['日', '一', '二', '三', '四', '五', '六']" :key="label">{{ label }}</span>
          </div>
          <div class="tw-habit-calendar-grid">
            <button
              v-for="cell in calendarCells"
              :key="cell.stamp"
              class="tw-habit-calendar-day"
              :class="{ muted: !cell.currentMonth, done: cell.done, partial: cell.partial, today: cell.isToday, future: cell.future }"
              :title="cell.dateLabel"
              @click="!cell.future && startCheckin(selectedHabit, cell.stamp)"
            >
              <span v-if="cell.done && selectedHabit.style === 'icon'" class="tw-habit-day-emoji">{{ selectedHabit.icon }}</span>
              <template v-else>{{ cell.day }}</template>
            </button>
          </div>
        </div>

        <div class="tw-habit-chart">
          <header>每日完成量 <small>({{ selectedHabit.unit === 'Count' ? '次' : selectedHabit.unit }})</small></header>
          <div class="tw-habit-chart-bars">
            <div v-for="item in detail.stats.daily" :key="item.date" class="tw-habit-chart-bar" :title="`${item.date} ${item.value}`">
              <i :style="{ height: `${chartHeight(item.value)}%` }" />
            </div>
          </div>
        </div>

        <div class="tw-habit-records">
          <header>
            <strong>{{ detailMonth }} 打卡日志</strong>
            <button v-if="!archived" class="tw-ghost-button" @click="logComposerOpen = !logComposerOpen">{{ logComposerOpen ? '取消' : '写日志' }}</button>
          </header>
          <div v-if="logComposerOpen" class="tw-habit-log-form">
            <textarea v-model="logContent" rows="2" maxlength="1000" placeholder="记录今天的感受…" />
            <button class="tw-primary-button" :disabled="!logContent.trim()" @click="saveLog">保存</button>
          </div>
          <div v-if="!detail.records.length" class="tw-habit-log-empty">这个月没有写打卡日志哦</div>
          <article v-for="record in detail.records" :key="record.id" class="tw-habit-log">
            <span class="tw-habit-log-emoji">{{ record.emoji || '📝' }}</span>
            <div v-if="editingLogId === record.id" class="tw-habit-log-edit">
              <textarea v-model="editingLogContent" rows="2" maxlength="1000" />
              <div class="tw-habit-log-edit-actions">
                <button class="tw-primary-button" :disabled="!editingLogContent.trim()" @click="saveLogEdit(record)">保存</button>
                <button class="tw-ghost-button" @click="cancelLogEdit">取消</button>
              </div>
            </div>
            <div v-else>
              <strong>{{ formatStamp(record.stamp) }}</strong>
              <p>{{ record.content }}</p>
            </div>
            <button v-if="editingLogId !== record.id" class="tw-icon-button" title="编辑日志" @click="startLogEdit(record)"><TaskIcon name="edit" :size="13" /></button>
            <button v-if="editingLogId !== record.id" class="tw-icon-button" title="删除日志" @click="deleteLog(record)"><TaskIcon name="trash" :size="13" /></button>
          </article>
        </div>
      </aside>
    </div>

    <div v-if="dialogOpen" class="tw-dialog-scrim" @click.self="dialogOpen = false">
      <div class="tw-dialog tw-habit-dialog" role="dialog" aria-modal="true">
        <header class="tw-dialog-head">
          <h2>{{ editingHabitId ? '编辑习惯' : '添加习惯' }}</h2>
          <button class="tw-icon-button" title="关闭" @click="dialogOpen = false"><TaskIcon name="close" :size="16" /></button>
        </header>
        <div class="tw-dialog-body tw-habit-form">
          <div class="tw-habit-form-title">
            <button class="tw-habit-icon-picker" :style="{ backgroundColor: form.color }" @click="cycleIcon">{{ form.icon }}</button>
            <input v-model="form.name" class="tw-dialog-input" maxlength="100" placeholder="每天进步一点点" />
          </div>
          <div class="tw-emoji-row">
            <button v-for="emoji in emojis" :key="emoji" :class="{ active: form.icon === emoji }" @click="form.icon = emoji">{{ emoji }}</button>
            <button v-for="color in colors" :key="color" class="tw-color-dot" :class="{ active: form.color === color }" :style="{ background: color }" @click="form.color = color" />
          </div>

          <label class="tw-modal-label">
            频率
            <div class="tw-habit-frequency">
              <select v-model="form.frequencyType" class="tw-field-select">
                <option value="daily">按天</option>
                <option value="weekly">按周</option>
                <option value="interval">按时间间隔</option>
              </select>
              <div v-if="form.frequencyType === 'daily'" class="tw-habit-weekday-picks">
                <button v-for="(label, index) in ['日', '一', '二', '三', '四', '五', '六']" :key="label" :class="{ active: form.weekdays.includes(index) }" @click="toggleWeekday(index)">{{ label }}</button>
              </div>
              <div v-else-if="form.frequencyType === 'weekly'" class="tw-habit-inline-field">
                每周
                <input v-model.number="form.daysPerWeek" type="number" min="1" max="7" class="tw-dialog-input" />
                天
              </div>
              <div v-else class="tw-habit-inline-field">
                每
                <input v-model.number="form.interval" type="number" min="1" max="365" class="tw-dialog-input" />
                天
              </div>
            </div>
          </label>

          <label class="tw-modal-label">
            目标
            <div class="tw-habit-goal-row">
              <select v-model="form.goalMode" class="tw-field-select">
                <option value="completion">当天完成打卡</option>
                <option value="quantity">当天完成一定量</option>
              </select>
              <template v-if="form.goalMode === 'quantity'">
                <input v-model.number="form.goal" type="number" min="1" step="1" class="tw-dialog-input" />
                <span>次/天</span>
              </template>
            </div>
          </label>

          <label class="tw-modal-label">开始日期
            <input v-model="form.startDate" type="date" class="tw-dialog-input" />
          </label>

          <label class="tw-modal-label">坚持天数
            <div class="tw-habit-goal-row">
              <select v-model="form.durationMode" class="tw-field-select">
                <option value="forever">永远</option>
                <option value="days">指定天数</option>
              </select>
              <input v-if="form.durationMode === 'days'" v-model.number="form.targetDays" type="number" min="1" class="tw-dialog-input" />
              <span v-if="form.durationMode === 'days'">天</span>
            </div>
          </label>

          <label class="tw-modal-label">所属分组
            <select v-model.number="form.sectionId" class="tw-field-select">
              <option :value="0">其他</option>
              <option v-for="section in sections" :key="section.id" :value="section.id">{{ section.name }}</option>
            </select>
          </label>

          <label class="tw-modal-label">打卡样式
            <select v-model="form.style" class="tw-field-select">
              <option value="check">对勾</option>
              <option value="icon">习惯图标</option>
            </select>
          </label>

          <label class="tw-modal-label">提醒
            <div class="tw-habit-reminders">
              <div v-for="(_, index) in form.reminders" :key="index" class="tw-habit-reminder">
                <input v-model="form.reminders[index]" type="time" class="tw-dialog-input" />
                <button class="tw-icon-button" title="删除提醒" @click.prevent="form.reminders.splice(index, 1)"><TaskIcon name="close" :size="12" /></button>
              </div>
              <button class="tw-habit-reminder-add" type="button" @click="form.reminders.push('10:00')">+ 添加提醒</button>
            </div>
          </label>

          <label class="tw-check-label"><input v-model="form.recordEnable" type="checkbox" /> 自动弹出打卡日志</label>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="dialogOpen = false">取消</button>
          <button class="tw-dialog-ok" :disabled="busy || !form.name.trim()" @click="saveHabit">{{ busy ? '保存中…' : '保存' }}</button>
        </footer>
      </div>
    </div>

    <HabitLogDialog v-if="logTarget" :habit="logTarget.habit" :stamp="logTarget.stamp" @saved="onLogSaved" @close="logTarget = null" />

    <div v-if="checkinDialog" class="tw-dialog-scrim" @click.self="checkinDialog = null">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true">
        <header class="tw-dialog-head"><h2>记录打卡</h2></header>
        <div class="tw-dialog-body">
          <p class="tw-modal-note">{{ checkinDialog.habit.name }} · 目标 {{ checkinDialog.habit.goal }} 次</p>
          <input v-model.number="checkinDialog.value" type="number" min="0" step="1" class="tw-dialog-input" />
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="checkinDialog = null">取消</button>
          <button class="tw-dialog-ok" @click="saveCheckin">保存</button>
        </footer>
      </div>
    </div>

    <div v-if="settingsOpen" class="tw-dialog-scrim" @click.self="settingsOpen = false">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true">
        <header class="tw-dialog-head"><h2>习惯设置</h2><button class="tw-icon-button" @click="settingsOpen = false"><TaskIcon name="close" :size="16" /></button></header>
        <div class="tw-dialog-body tw-habit-settings">
          <label class="tw-habit-setting-row"><span>在“今天”“最近 7 天”中显示</span><a-switch v-model="preferences.showInToday" /></label>
          <label class="tw-habit-setting-row"><span>在日历中显示</span><a-switch v-model="preferences.showInCalendar" /></label>
          <label class="tw-habit-setting-row"><span>按完成状态分类显示</span><a-switch v-model="preferences.groupByCompleted" /></label>
          <div class="tw-habit-setting-row"><span>显示方式</span>
            <select v-model="preferences.displayType" class="tw-field-select" @change="savePreferences">
              <option value="list">列表</option>
              <option value="card">卡片</option>
            </select>
          </div>
          <div class="tw-habit-section-manage">
            <strong>习惯分组</strong>
            <div v-for="section in sections" :key="section.id" class="tw-habit-section-row">
              <input class="tw-dialog-input" :value="section.name" maxlength="30" @change="renameSection(section, $event)" />
              <button class="tw-icon-button" title="删除分组" @click="removeSection(section)"><TaskIcon name="trash" :size="13" /></button>
            </div>
            <div class="tw-habit-section-row">
              <input v-model="newSectionName" class="tw-dialog-input" maxlength="30" placeholder="新分组名称" @keydown.enter="addSection" />
              <button class="tw-ghost-button" :disabled="!newSectionName.trim()" @click="addSection">添加</button>
            </div>
          </div>
          <p class="tw-modal-note">开启“按完成状态分类显示”后，未打卡的习惯会聚合展示在列表上方。</p>
        </div>
        <footer class="tw-dialog-foot">
          <a class="tw-dialog-cancel" href="/api/admin/habits/export" target="_blank">导出</a>
          <button class="tw-dialog-ok" @click="savePreferences(); settingsOpen = false">完成</button>
        </footer>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { Message } from '@arco-design/web-vue'
import type { HabitCheckin, HabitDetail, HabitFrequency, HabitItem, HabitListData, HabitPreference, HabitRecord, HabitSection } from '../../types'
import {
  createHabit,
  createHabitRecord,
  createHabitSection,
  deleteHabit,
  deleteHabitRecord,
  deleteHabitSection,
  fetchHabitDetail,
  fetchHabits,
  reorderHabits,
  saveHabitPreferences,
  toggleHabitCheckin,
  updateHabit,
  updateHabitRecord,
  updateHabitSection,
} from '../../tasks-api'
import TaskIcon from './TaskIcon.vue'
import HabitLogDialog from './HabitLogDialog.vue'

const loading = ref(true)
const habits = ref<HabitItem[]>([])
const sections = ref<HabitSection[]>([])
const checkins = ref<Record<string, HabitCheckin[]>>({})
const preferences = ref<HabitPreference>({ showInToday: true, showInCalendar: true, groupByCompleted: false, displayType: 'list', sortType: 'custom', defaultSectionId: 0 })
const archived = ref(false)
const settingsOpen = ref(false)
const selectedHabitId = ref(0)
const detail = ref<HabitDetail | null>(null)
const detailMonth = ref(new Date().toISOString().slice(0, 7))
const dialogOpen = ref(false)
const editingHabitId = ref(0)
const busy = ref(false)
const checkinDialog = ref<{ habit: HabitItem; stamp: number; value: number } | null>(null)
const logComposerOpen = ref(false)
const logContent = ref('')
const logTarget = ref<{ habit: HabitItem; stamp: number } | null>(null)
const editingLogId = ref(0)
const editingLogContent = ref('')
const newSectionName = ref('')
const draggingHabitId = ref(0)
const dragOverHabitId = ref(0)

const emojis = ['😊', '📚', '🏃', '💧', '🧘', '🌱', '🎯', '✍️', '🌙', '🍎', '💪', '🎨']
const colors = ['#97E38B', '#FFB84D', '#FF7B7B', '#7B9CFF', '#B58BFF', '#5ED4C5', '#F28BC5', '#A2A8B8']
const form = reactive({
  name: '', icon: '😊', color: colors[0], frequencyType: 'daily' as 'daily' | 'weekly' | 'interval',
  weekdays: [0, 1, 2, 3, 4, 5, 6] as number[], daysPerWeek: 2, interval: 2,
  goalMode: 'completion' as 'completion' | 'quantity', goal: 1,
  startDate: new Date().toISOString().slice(0, 10), durationMode: 'forever' as 'forever' | 'days', targetDays: 30,
  sectionId: 0, reminders: [] as string[], recordEnable: false, style: 'check' as 'check' | 'icon',
})

const selectedHabit = computed(() => habits.value.find((habit) => habit.id === selectedHabitId.value) || null)
const displayType = computed<'list' | 'card'>(() => preferences.value.displayType === 'card' ? 'card' : 'list')

const weekDays = computed(() => {
  const today = new Date()
  const start = new Date(today)
  start.setDate(today.getDate() - today.getDay())
  return Array.from({ length: 7 }, (_, index) => {
    const date = new Date(start)
    date.setDate(start.getDate() + index)
    return {
      stamp: stampOf(date),
      weekday: ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][index],
      day: date.getDate(),
      dateLabel: date.toLocaleDateString('zh-CN'),
      isToday: stampOf(date) === stampOf(today),
    }
  })
})

const habitGroups = computed(() => {
  const sectionMap = new Map<number, HabitSection>()
  for (const section of sections.value) sectionMap.set(section.id, section)
  const groups = new Map<string, { key: string; label: string; habits: HabitItem[] }>()
  for (const habit of habits.value) {
    let key = `s-${habit.sectionId}`
    let label = sectionMap.get(habit.sectionId)?.name || ''
    if (preferences.value.groupByCompleted) {
      const done = isDone(habit.id, stampOf(new Date()))
      key = done ? 'done' : 'pending'
      label = done ? '已完成' : '待打卡'
    }
    if (!groups.has(key)) groups.set(key, { key, label, habits: [] })
    groups.get(key)!.habits.push(habit)
  }
  return [...groups.values()]
})

const calendarCells = computed(() => {
  const [year, month] = detailMonth.value.split('-').map(Number)
  const first = new Date(year, month - 1, 1)
  const start = new Date(first)
  start.setDate(first.getDate() - first.getDay())
  const today = stampOf(new Date())
  return Array.from({ length: 42 }, (_, index) => {
    const date = new Date(start)
    date.setDate(start.getDate() + index)
    const stamp = stampOf(date)
    const checkin = detail.value?.checkins.find((item) => item.checkinStamp === stamp)
    return {
      stamp,
      day: date.getDate(),
      currentMonth: date.getMonth() === month - 1,
      dateLabel: date.toLocaleDateString('zh-CN'),
      done: isCheckinDone(checkin),
      partial: Boolean(checkin && checkin.value > 0 && !isCheckinDone(checkin)),
      isToday: stamp === today,
      future: stamp > today,
    }
  })
})

const monthTitle = computed(() => {
  const [year, month] = detailMonth.value.split('-').map(Number)
  return `${year}年${month}月`
})

onMounted(load)

async function load() {
  loading.value = true
  try {
    const data: HabitListData = await fetchHabits(archived.value)
    habits.value = data.habits || []
    sections.value = data.sections || []
    preferences.value = data.preferences || preferences.value
    checkins.value = data.checkins || {}
    if (selectedHabitId.value) {
      const exists = habits.value.some((habit) => habit.id === selectedHabitId.value)
      if (exists) await loadDetail(selectedHabitId.value)
      else selectedHabitId.value = 0
    }
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载习惯失败')
  } finally {
    loading.value = false
  }
}

function stampOf(date: Date) {
  return Number(`${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, '0')}${String(date.getDate()).padStart(2, '0')}`)
}

function formatStamp(stamp: number) {
  const value = String(stamp)
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`
}

function checkinFor(habitId: number, stamp: number) {
  return (checkins.value[String(habitId)] || []).find((item) => item.checkinStamp === stamp)
}

function checkinValue(habitId: number, stamp: number) {
  return checkinFor(habitId, stamp)?.value || 0
}

function isCheckinDone(checkin?: HabitCheckin) {
  return Boolean(checkin && (checkin.status === 2 || (checkin.goal > 0 && checkin.value >= checkin.goal)))
}

function isDone(habitId: number, stamp: number) {
  return isCheckinDone(checkinFor(habitId, stamp))
}

function isPartial(habitId: number, stamp: number) {
  const checkin = checkinFor(habitId, stamp)
  return Boolean(checkin && checkin.value > 0 && !isCheckinDone(checkin))
}

function weekDoneCount(stamp: number) {
  return habits.value.filter((habit) => isDone(habit.id, stamp)).length
}

async function toggleDisplayType() {
  preferences.value.displayType = displayType.value === 'card' ? 'list' : 'card'
  await savePreferences()
}

async function savePreferences() {
  try {
    preferences.value = await saveHabitPreferences(preferences.value)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存设置失败')
  }
}

function openCreate() {
  editingHabitId.value = 0
  Object.assign(form, {
    name: '', icon: '😊', color: colors[0], frequencyType: 'daily',
    weekdays: [0, 1, 2, 3, 4, 5, 6], daysPerWeek: 2, interval: 2,
    goalMode: 'completion', goal: 1, startDate: new Date().toISOString().slice(0, 10),
    durationMode: 'forever', targetDays: 30, sectionId: preferences.value.defaultSectionId || 0,
    reminders: [], recordEnable: false, style: 'check',
  })
  dialogOpen.value = true
}

function openEdit(habit: HabitItem) {
  editingHabitId.value = habit.id
  const frequency = parseFrequency(habit.frequency)
  const reminders: string[] = safeParse(habit.reminders, [])
  Object.assign(form, {
    name: habit.name, icon: habit.icon || '😊', color: habit.color || colors[0],
    frequencyType: frequency.type, weekdays: frequency.weekdays?.length ? frequency.weekdays : [0, 1, 2, 3, 4, 5, 6],
    daysPerWeek: frequency.daysPerWeek || 2, interval: frequency.interval || 2,
    goalMode: habit.goal > 1 ? 'quantity' : 'completion', goal: habit.goal || 1,
    startDate: formatStamp(habit.startDate || stampOf(new Date())), durationMode: habit.targetDays > 0 ? 'days' : 'forever',
    targetDays: habit.targetDays || 30, sectionId: habit.sectionId || 0, reminders,
    recordEnable: habit.recordEnable, style: habit.style === 'icon' ? 'icon' : 'check',
  })
  dialogOpen.value = true
}

function parseFrequency(raw: string): HabitFrequency {
  const value = safeParse<HabitFrequency>(raw, { type: 'daily', weekdays: [0, 1, 2, 3, 4, 5, 6] })
  return {
    type: value.type || 'daily',
    weekdays: Array.isArray(value.weekdays) ? value.weekdays : [0, 1, 2, 3, 4, 5, 6],
    daysPerWeek: Number(value.daysPerWeek) || 2,
    interval: Number(value.interval) || 2,
  }
}

function safeParse<T>(raw: string, fallback: T): T {
  try { return JSON.parse(raw) as T } catch { return fallback }
}

function toggleWeekday(index: number) {
  if (form.weekdays.includes(index)) form.weekdays = form.weekdays.filter((day) => day !== index)
  else form.weekdays = [...form.weekdays, index].sort()
}

function cycleIcon() {
  const index = emojis.indexOf(form.icon)
  form.icon = emojis[(index + 1) % emojis.length]
}

async function saveHabit() {
  if (!form.name.trim() || busy.value) return
  const frequency = form.frequencyType === 'daily'
    ? { type: 'daily', weekdays: form.weekdays.length ? form.weekdays : [0, 1, 2, 3, 4, 5, 6] }
    : form.frequencyType === 'weekly'
      ? { type: 'weekly', daysPerWeek: form.daysPerWeek }
      : { type: 'interval', interval: form.interval }
  const start = form.startDate.replaceAll('-', '')
  const payload: Partial<HabitItem> = {
    name: form.name.trim(),
    icon: form.icon,
    color: form.color,
    sectionId: form.sectionId,
    goal: form.goalMode === 'quantity' ? Math.max(1, form.goal) : 1,
    step: 1,
    unit: 'Count',
    frequency: JSON.stringify(frequency),
    reminders: JSON.stringify(form.reminders.filter(Boolean)),
    recordEnable: form.recordEnable,
    startDate: Number(start),
    targetDays: form.durationMode === 'days' ? Math.max(1, form.targetDays) : 0,
    style: form.style,
  }
  busy.value = true
  try {
    if (editingHabitId.value) {
      await updateHabit(editingHabitId.value, payload)
      Message.success('习惯已更新')
    } else {
      const { habit } = await createHabit(payload)
      selectedHabitId.value = habit.id
      Message.success('习惯已创建')
    }
    dialogOpen.value = false
    await load()
    if (selectedHabitId.value) await loadDetail(selectedHabitId.value)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存习惯失败')
  } finally {
    busy.value = false
  }
}

function startCheckin(habit: HabitItem, stamp: number) {
  if (habit.goal > 1) {
    checkinDialog.value = { habit, stamp, value: checkinValue(habit.id, stamp) || habit.step }
    return
  }
  void toggleCheckin(habit, stamp)
}

async function toggleCheckin(habit: HabitItem, stamp: number, value?: number) {
  try {
    await toggleHabitCheckin(habit.id, stamp, value)
    await load()
    if (selectedHabitId.value === habit.id) await loadDetail(habit.id)
    if (habit.recordEnable && isDone(habit.id, stamp)) {
      logTarget.value = { habit, stamp }
    }
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '打卡失败')
  }
}

async function saveCheckin() {
  if (!checkinDialog.value) return
  const { habit, stamp, value } = checkinDialog.value
  checkinDialog.value = null
  await toggleCheckin(habit, stamp, value)
}

async function openDetail(habit: HabitItem) {
  selectedHabitId.value = habit.id
  await loadDetail(habit.id)
}

function closeDetail() {
  selectedHabitId.value = 0
  detail.value = null
}

async function loadDetail(habitId: number) {
  try {
    detail.value = await fetchHabitDetail(habitId, detailMonth.value)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载习惯详情失败')
  }
}

async function shiftMonth(delta: number) {
  const [year, month] = detailMonth.value.split('-').map(Number)
  const date = new Date(year, month - 1 + delta, 1)
  detailMonth.value = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
  if (selectedHabitId.value) await loadDetail(selectedHabitId.value)
}

function chartHeight(value: number) {
  const max = Math.max(selectedHabit.value?.goal || 1, ...(detail.value?.stats.daily.map((item) => item.value) || [0]))
  return max > 0 ? Math.max(3, Math.round(value / max * 100)) : 3
}

function startHabitDrag(habit: HabitItem, event: DragEvent) {
  if (archived.value || preferences.value.groupByCompleted) return
  draggingHabitId.value = habit.id
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', String(habit.id))
  }
}

async function dropHabit(target: HabitItem) {
  const sourceId = draggingHabitId.value
  draggingHabitId.value = 0
  dragOverHabitId.value = 0
  if (!sourceId || sourceId === target.id) return
  const source = habits.value.find((habit) => habit.id === sourceId)
  if (!source || source.sectionId !== target.sectionId) return
  const list = habits.value.slice()
  const from = list.findIndex((habit) => habit.id === sourceId)
  const to = list.findIndex((habit) => habit.id === target.id)
  if (from < 0 || to < 0) return
  const [moved] = list.splice(from, 1)
  list.splice(to, 0, moved)
  list.forEach((habit, index) => { habit.sortOrder = index + 1 })
  habits.value = list
  try {
    await reorderHabits(list.map((habit) => habit.id))
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存排序失败')
    await load()
  }
}

async function toggleHabitStyle() {
  if (!selectedHabit.value) return
  const next = selectedHabit.value.style === 'icon' ? 'check' : 'icon'
  try {
    await updateHabit(selectedHabit.value.id, { ...selectedHabit.value, style: next })
    await load()
    if (selectedHabitId.value) await loadDetail(selectedHabitId.value)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '切换打卡样式失败')
  }
}

async function addSection() {
  const name = newSectionName.value.trim()
  if (!name) return
  try {
    const { section } = await createHabitSection(name)
    sections.value = [...sections.value, section]
    newSectionName.value = ''
    Message.success('分组已添加')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '添加分组失败')
  }
}

async function renameSection(section: HabitSection, event: Event) {
  const name = (event.target as HTMLInputElement).value.trim()
  if (!name || name === section.name) return
  try {
    const result = await updateHabitSection(section.id, { name })
    sections.value = sections.value.map((item) => item.id === result.section.id ? result.section : item)
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '重命名分组失败')
  }
}

async function removeSection(section: HabitSection) {
  if (!window.confirm(`删除分组「${section.name}」？组内习惯会移到“其他”。`)) return
  try {
    await deleteHabitSection(section.id)
    sections.value = sections.value.filter((item) => item.id !== section.id)
    habits.value = habits.value.map((habit) => habit.sectionId === section.id ? { ...habit, sectionId: 0 } : habit)
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '删除分组失败')
  }
}

function startLogEdit(record: HabitRecord) {
  editingLogId.value = record.id
  editingLogContent.value = record.content
}

function cancelLogEdit() {
  editingLogId.value = 0
  editingLogContent.value = ''
}

async function saveLogEdit(record: HabitRecord) {
  if (!selectedHabit.value || !editingLogContent.value.trim()) return
  try {
    await updateHabitRecord(selectedHabit.value.id, record.id, { content: editingLogContent.value.trim() })
    cancelLogEdit()
    await loadDetail(selectedHabit.value.id)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '编辑日志失败')
  }
}

async function archiveHabit() {
  if (!selectedHabit.value) return
  try {
    await updateHabit(selectedHabit.value.id, { ...selectedHabit.value, status: 1 })
    Message.success('习惯已归档')
    closeDetail()
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '归档失败')
  }
}

async function restoreHabit() {
  if (!selectedHabit.value) return
  try {
    await updateHabit(selectedHabit.value.id, { ...selectedHabit.value, status: 0 })
    Message.success('习惯已恢复')
    closeDetail()
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '恢复失败')
  }
}

async function confirmDeleteHabit() {
  if (!selectedHabit.value) return
  if (!window.confirm(`确定删除「${selectedHabit.value.name}」吗？`)) return
  try {
    await deleteHabit(selectedHabit.value.id)
    Message.success('习惯已删除')
    closeDetail()
    await load()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '删除失败')
  }
}

function onLogSaved() {
  logTarget.value = null
  if (selectedHabitId.value) void loadDetail(selectedHabitId.value)
}

async function saveLog() {
  if (!selectedHabit.value || !logContent.value.trim()) return
  try {
    await createHabitRecord(selectedHabit.value.id, { content: logContent.value.trim(), stamp: stampOf(new Date()) })
    logContent.value = ''
    logComposerOpen.value = false
    await loadDetail(selectedHabit.value.id)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存日志失败')
  }
}

async function deleteLog(record: HabitRecord) {
  if (!selectedHabit.value || !window.confirm('删除这条打卡日志？')) return
  try {
    await deleteHabitRecord(selectedHabit.value.id, record.id)
    await loadDetail(selectedHabit.value.id)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '删除日志失败')
  }
}
</script>
