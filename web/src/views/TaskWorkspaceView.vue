<template>
  <div class="tw-root" :data-theme="theme">
    <aside class="tw-rail">
      <button class="tw-rail-brand" title="任务" @click="sidebarOpen = !sidebarOpen">
        <svg viewBox="0 0 32 32" width="26" height="26" aria-hidden="true">
          <rect x="2" y="2" width="28" height="28" rx="9" fill="currentColor" />
          <path d="m9.5 16.5 4.2 4.3 8.8-9.6" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </button>
      <nav class="tw-rail-nav">
        <button class="tw-rail-button" :class="{ active: mode === 'list' }" title="清单" @click="switchMode('list')">
          <TaskIcon name="list" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: mode === 'board' }" title="看板" @click="openModePage('board')">
          <TaskIcon name="board" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: mode === 'calendar' }" title="日历" @click="openModePage('calendar')">
          <TaskIcon name="calendar" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: view === 'matrix' }" title="四象限" @click="selectView('matrix')">
          <TaskIcon name="matrix" :size="20" />
        </button>
        <button class="tw-rail-button" :class="{ active: view === 'focus' }" title="专注" @click="selectView('focus')">
          <TaskIcon name="clock" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: view === 'habit' }" title="习惯" @click="selectView('habit')">
          <TaskIcon name="habit" :size="20" />
        </button>
        <button class="tw-rail-button" :class="{ active: view === 'countdown' }" title="倒数纪念日" @click="selectView('countdown')">
          <TaskIcon name="countdown" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: view === 'stats' }" title="统计" @click="openStats">
          <TaskIcon name="chart" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: view === 'ai' }" title="AI 助手" @click="openAI">
          <TaskIcon name="sparkles" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: searchOpen }" title="搜索" @click="toggleSearch">
          <TaskIcon name="search" :size="21" />
        </button>
      </nav>
      <div class="tw-rail-foot">
        <button
          class="tw-rail-button"
          :class="{ active: remindersEnabled }"
          title="提醒设置"
          @click="reminderSettingsOpen = true"
        >
          <TaskIcon name="bell" :size="20" />
        </button>
        <button class="tw-rail-button" :title="theme === 'dark' ? '切换到浅色' : '切换到深色'" @click="toggleTheme">
          <TaskIcon :name="theme === 'dark' ? 'sun' : 'moon'" :size="20" />
        </button>
        <router-link class="tw-rail-button" to="/" title="管理后台">
          <TaskIcon name="settings" :size="20" />
        </router-link>
      </div>
    </aside>

    <TaskSidebar
      v-if="view !== 'matrix' && view !== 'habit' && view !== 'focus' && view !== 'countdown'"
      :lists="lists"
      :shared-lists="sharedLists"
      :folders="folders"
      :filters="filters"
      :tag-counts="tagCounts"
      :counts="counts"
      :view="view"
      :active-list-id="activeListId"
      :active-filter-id="activeFilterId"
      :active-shared-list-id="activeSharedListId"
      :unread-notifications="unreadNotifications"
      :active-tag="activeTag"
      :user-name="auth.user?.username || ''"
      :display-name="auth.user?.displayName || ''"
      :open="sidebarOpen"
      @select-view="selectView"
      @select-list="selectList"
      @select-filter="selectFilter"
      @select-shared="selectSharedList"
      @share-list="openShareList"
      @create-list="createList"
      @edit-list="openEditList"
      @delete-list="confirmDeleteList"
      @create-folder="openCreateFolder"
      @edit-folder="openEditFolder"
      @delete-folder="confirmDeleteFolder"
      @create-filter="openCreateFilter"
      @edit-filter="openEditFilter"
      @delete-filter="confirmDeleteFilter"
      @select-tag="selectTag"
      @manage-tags="openTagManager"
      @open-reminders="reminderSettingsOpen = true"
      @open-notifications="notificationDialogOpen = true"
      @close="sidebarOpen = false"
      @logout="handleLogout"
    />

    <div v-if="sidebarOpen" class="tw-scrim" @click="sidebarOpen = false" />

    <main class="tw-main">
      <header v-if="view !== 'matrix' && view !== 'habit' && view !== 'focus' && view !== 'countdown'" class="tw-toolbar">
        <button class="tw-icon-button tw-menu-button" title="打开侧栏" @click="sidebarOpen = true">
          <TaskIcon name="list" :size="20" />
        </button>
        <div class="tw-heading">
          <span class="tw-heading-icon"><TaskIcon :name="headingIcon" :size="19" /></span>
          <h1>{{ heading }}</h1>
          <span v-if="headingCount" class="tw-heading-count">{{ headingCount }}</span>
        </div>
        <div class="tw-toolbar-actions">
          <button
            v-if="mode === 'calendar' && view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai'"
            class="tw-ghost-button tw-new-event-button"
            @click="openEventCreator"
          >
            <TaskIcon name="plus" :size="15" />
            新建日程
          </button>
          <div v-if="view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared'" class="tw-mode-switch" role="group" aria-label="视图模式">
            <button :class="{ active: mode === 'list' }" title="清单" @click="switchMode('list')">
              <TaskIcon name="list" :size="16" />
            </button>
            <button :class="{ active: mode === 'board' }" title="看板" @click="switchMode('board')">
              <TaskIcon name="board" :size="16" />
            </button>
            <button :class="{ active: mode === 'calendar' }" title="日历" @click="switchMode('calendar')">
              <TaskIcon name="calendar" :size="16" />
            </button>
          </div>
          <button
            v-if="view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared' && view !== 'completed' && mode === 'list'"
            class="tw-icon-button"
            :class="{ active: manualSort }"
            :title="manualSort ? '关闭手动排序' : '手动排序（拖拽调整顺序）'"
            @click="toggleManualSort"
          >
            <TaskIcon name="sort" :size="18" />
          </button>
          <button
            v-if="view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared' && mode === 'list'"
            class="tw-icon-button"
            :class="{ active: selectionMode }"
            :title="selectionMode ? '退出多选' : '多选任务'"
            @click="toggleSelection"
          >
            <TaskIcon name="select" :size="18" />
          </button>
          <button v-if="view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared'" class="tw-icon-button" title="搜索" @click="toggleSearch">
            <TaskIcon name="search" :size="18" />
          </button>
        </div>
      </header>

      <div v-if="searchOpen && view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared' && view !== 'matrix' && view !== 'habit' && view !== 'focus' && view !== 'countdown'" class="tw-search-bar">
        <TaskIcon name="search" :size="17" />
        <input
          ref="searchInputEl"
          v-model="searchInput"
          class="tw-search-input"
          placeholder="搜索任务标题与备注"
          @keydown.esc="closeSearch"
        />
        <button class="tw-icon-button" title="关闭搜索" @click="closeSearch">
          <TaskIcon name="close" :size="15" />
        </button>
      </div>

      <HabitPanel v-if="view === 'habit'" :focus-habit-id="habitFocusId" @open-detail="onHabitDetailOpened" @close-detail="onHabitDetailClosed" />
      <FocusStatsPanel v-else-if="view === 'focus' && focusStatsPage" @back="router.push('/tasks/focus')" />
      <FocusPanel v-else-if="view === 'focus'" :tasks="tasks" />
      <CountdownPanel v-else-if="view === 'countdown'" />
      <TaskMatrixPanel
        v-else-if="view === 'matrix'"
        :tasks="matrixTasks"
        :rule="matrixRule"
        :views="matrixViews"
        :active-view-id="activeMatrixViewId"
        :custom-rules="matrixCustomRules"
        :show-completed="matrixShowCompleted"
        :manual-sort="matrixManualSort"
        :selection-mode="matrixSelectionMode"
        :selected-ids="matrixSelectedIds"
        :lists="lists"
        :tags="tags"
        :assignees="matrixAssignees"
        @open="openTask"
        @toggle="toggleTask"
        @move="moveTaskToQuadrant"
        @move-custom="moveTaskToCustomQuadrant"
        @move-sorted="moveTaskCrossQuadrant"
        @change-rule="setMatrixRule"
        @select-view="selectMatrixView"
        @create-view="openMatrixViewDialog"
        @manage-views="matrixViewManagerOpen = true"
        @edit-rules="openMatrixRules"
        @toggle-completed="toggleMatrixCompleted"
        @toggle-manual-sort="toggleMatrixManualSort"
        @reorder="onMatrixReorder"
        @toggle-selection="toggleMatrixSelection"
        @toggle-select="toggleMatrixSelect"
        @clear-selection="clearMatrixSelection"
        @batch-move="batchMoveMatrix"
        @quick-add="quickAddMatrixTask"
      />
      <div v-else class="tw-scroll">
        <div class="tw-content">
          <div v-if="mode !== 'calendar' && view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && (view !== 'shared' || sharedEditable)" class="tw-quick-add">
            <TaskIcon name="plus" :size="18" />
            <input
              ref="quickInputEl"
              v-model="quickText"
              class="tw-quick-input"
              :placeholder="`添加任务至“${quickTargetName}”`"
              maxlength="500"
              @keydown.enter="onQuickEnter"
            />
            <button v-if="quickText.trim()" class="tw-quick-submit" :disabled="quickBusy" @click="submitQuick">
              <TaskIcon name="check" :size="16" />
            </button>
          </div>

          <div v-if="hint && mode !== 'calendar' && view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && (view !== 'shared' || sharedEditable)" class="tw-quick-hint">
            <span v-if="hint.date" class="tw-hint-chip">{{ hint.date }}</span>
            <span v-if="hint.time" class="tw-hint-chip">{{ hint.time }}</span>
            <span v-for="tag in hint.tags" :key="tag" class="tw-hint-chip">#{{ tag }}</span>
            <span v-if="hint.priority" class="tw-hint-chip">优先级 {{ hint.priority }}</span>
            <span class="tw-hint-tip">回车添加</span>
          </div>

          <HabitTodayStrip v-if="(view === 'today' || view === 'next7') && mode !== 'calendar'" />

          <HabitTodayStrip v-if="mode === 'calendar'" source="calendar" />

          <div v-if="loading" class="tw-loading">
            <a-spin />
          </div>

          <TaskSummaryPanel
            v-else-if="view === 'summary'"
            :lists="lists"
            :tags="tagCounts"
          />

          <TaskStatsPanel
            v-else-if="view === 'stats'"
            @open-list="selectList"
            @select-tag="selectTagFromStats"
          />

          <TaskAIPanel v-else-if="view === 'ai'" @tasks-changed="handleAITasksChanged" />

          <template v-else-if="view === 'trash'">
            <div class="tw-trash-bar">
              <span>{{ tasks.length }} 个已删除任务</span>
              <button v-if="tasks.length" class="tw-danger-link" @click="confirmEmptyTrash">
                <TaskIcon name="trash" :size="14" />
                清空垃圾桶
              </button>
            </div>
            <div class="tw-group-body">
              <TaskRow
                v-for="task in tasks"
                :key="task.id"
                :task="task"
                :selected="false"
                :show-list="true"
                trash-mode
                @restore="restoreOne"
                @purge="confirmPurgeTask"
              />
            </div>
            <div v-if="!tasks.length" class="tw-empty">
              <div class="tw-empty-art">
                <svg viewBox="0 0 96 96" width="96" height="96" aria-hidden="true">
                  <path d="M28 30h40l-3 50H31l-3-50Z" fill="none" stroke="currentColor" stroke-width="2" />
                  <path d="M22 30h52M40 30v-6h16v6M42 42v24M54 42v24" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
                </svg>
              </div>
              <h2>垃圾桶是空的</h2>
              <p>删除的任务会先放在这里，可以随时恢复。</p>
            </div>
          </template>

          <template v-else-if="mode === 'list'">
            <section v-for="group in groups" :key="group.key" class="tw-group">
              <header v-if="group.key !== 'manual'" class="tw-group-head" @click="toggleGroup(group.key)">
                <span class="tw-group-caret" :class="{ collapsed: collapsed.has(group.key) }">
                  <TaskIcon name="chevron" :size="13" />
                </span>
                <span class="tw-group-title" :class="`tone-${group.tone || 'normal'}`">{{ group.label }}</span>
                <span class="tw-group-count">{{ group.tasks.length }}</span>
                <button
                  v-if="group.key === 'overdue'"
                  class="tw-group-action"
                  @click.stop="postponeOverdue"
                >
                  顺延到今天
                </button>
              </header>
              <div v-show="!collapsed.has(group.key)" class="tw-group-body">
                <p v-if="group.key === 'manual' && manualSort" class="tw-sort-hint">拖动任务调整顺序</p>
                <TaskRow
                  v-for="task in group.tasks"
                  :key="task.id"
                  :task="task"
                  :tag-colors="tagColorMap"
                  :selected="selectionMode ? selectedIds.has(task.id) : selectedId === task.id"
                  :selectable="selectionMode"
                  :show-list="!activeListId"
                  :draggable="manualSort && !selectionMode && !task.completed"
                  :drag-target="dragOverId === task.id"
                  @toggle="toggleTask"
                  @open="openTask"
                  @remove="confirmRemoveTask"
                  @select="toggleSelect"
                  @dragstart="onRowDragStart(task, $event)"
                  @dragover.prevent="onRowDragOver(task)"
                  @drop.prevent="onRowDrop(task)"
                  @dragend="onRowDragEnd"
                />
              </div>
            </section>

            <div v-if="!tasks.length" class="tw-empty">
              <div class="tw-empty-art">
                <svg viewBox="0 0 96 96" width="96" height="96" aria-hidden="true">
                  <rect x="14" y="12" width="68" height="72" rx="14" fill="none" stroke="currentColor" stroke-width="2" />
                  <path d="M28 34h28M28 48h22M28 62h30" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
                  <circle cx="68" cy="24" r="10" fill="var(--tw-accent)" />
                  <path d="m63.5 24 3.2 3.2 6-6.4" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              </div>
              <h2>这里还没有任务</h2>
              <p>{{ emptyHint }}</p>
              <button class="tw-primary-button" @click="focusQuick">添加第一个任务</button>
            </div>
          </template>

          <TaskCalendar
            v-else-if="mode === 'calendar'"
            :tasks="filteredTasks"
            :cursor="cursor"
            :view-mode="calendarView"
            :reload-key="calendarReload"
            @open="openTask"
            @open-event="openCalendarEvent"
            @open-habit="openHabitFromCalendar"
            @calendars="calendarSources = $event"
            :focus="calendarFocus"
            @reschedule-task="rescheduleTask"
            @reschedule-event="rescheduleEvent"
            @focus-opened="clearCalendarFocus"
            @create="createFromCalendar"
            @change-view="calendarView = $event"
            @prev="stepCalendar(-1)"
            @next="stepCalendar(1)"
            @today="cursor = new Date()"
          />

          <template v-else>
            <div class="tw-board">
              <section
                v-for="column in boardColumns"
                :key="column.list.id"
                class="tw-board-column"
                @dragover.prevent
                @drop="dropOnList(column.list.id)"
              >
                <header class="tw-board-head">
                  <span class="tw-list-dot" :style="{ background: column.list.color || '#4772fa' }" />
                  <strong>{{ column.list.name }}</strong>
                  <span class="tw-board-count">{{ column.tasks.length }}</span>
                  <button class="tw-icon-button" title="在此清单添加任务" @click="addToColumn(column.list.id)">
                    <TaskIcon name="plus" :size="15" />
                  </button>
                </header>
                <div class="tw-board-body">
                  <article
                    v-for="task in column.tasks"
                    :key="task.id"
                    class="tw-board-card"
                    :class="{ done: task.completed }"
                    draggable="true"
                    @dragstart="dragId = task.id"
                    @dragend="dragId = 0"
                    @click="openTask(task)"
                  >
                    <div class="tw-board-card-head">
                      <span v-if="task.priority" class="tw-priority-dot" :style="{ background: priorityColor(task.priority) }" />
                      <span class="tw-board-card-title">{{ task.title }}</span>
                    </div>
                    <div v-if="task.tags.length || task.due" class="tw-board-card-meta">
                      <span
                        v-for="tag in task.tags.slice(0, 2)"
                        :key="tag"
                        :style="{ color: tagColor(tag, tagColorMap[tag]), background: tagTint(tagColor(tag, tagColorMap[tag])) }"
                      >#{{ tag }}</span>
                      <span v-if="task.due">{{ formatDue(task) }}</span>
                    </div>
                    <button class="tw-board-check" :class="{ checked: task.completed }" @click.stop="toggleTask(task)">
                      <TaskIcon name="check" :size="12" />
                    </button>
                  </article>
                  <p v-if="!column.tasks.length" class="tw-board-empty">拖动任务到这里，或点击 + 新建</p>
                </div>
              </section>
            </div>
          </template>
        </div>
      </div>
    </main>

    <TaskDetail
      v-if="selectedTask"
      :task="selectedTask"
      :lists="detailLists"
      :members="taskMembers"
      :tag-colors="tagColorMap"
      :readonly="sharedReadonly"
      :list-locked="view === 'shared'"
      @close="selectedId = 0"
      @changed="onTaskChanged"
      @deleted="onTaskDeleted"
      @remove="confirmRemoveTask"
    />

    <div v-if="selectionMode" class="tw-batch-bar">
      <span class="tw-batch-count">已选 {{ selectedIds.size }} 项</span>
      <div class="tw-batch-actions">
        <button :disabled="!selectedIds.size" @click="batchComplete">完成</button>
        <button :disabled="!selectedIds.size" @click="openMoveDialog">移动到</button>
        <button class="tw-batch-danger" :disabled="!selectedIds.size" @click="confirmBatchDelete">删除</button>
        <button @click="clearSelection">取消</button>
      </div>
    </div>

    <div v-if="moveDialogOpen" class="tw-dialog-scrim" @click.self="moveDialogOpen = false">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true" aria-label="移动到清单">
        <header class="tw-dialog-head">
          <h2>移动到清单</h2>
          <button class="tw-icon-button" title="关闭" @click="moveDialogOpen = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body tw-move-list">
          <button
            v-for="list in lists"
            :key="list.id"
            class="tw-move-option"
            :class="{ active: moveTargetId === list.id }"
            @click="moveTargetId = list.id"
          >
            <span class="tw-list-dot" :style="{ background: list.color || '#4772fa' }" />
            <span>{{ list.name }}</span>
            <TaskIcon v-if="moveTargetId === list.id" name="check" :size="14" />
          </button>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="moveDialogOpen = false">取消</button>
          <button class="tw-dialog-ok" :disabled="!moveTargetId || batchBusy" @click="batchMove">移动</button>
        </footer>
      </div>
    </div>

    <div v-if="folderVisible" class="tw-dialog-scrim" @click.self="folderVisible = false">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true" @keydown.esc="folderVisible = false">
        <header class="tw-dialog-head">
          <h2>{{ folderForm.id ? '编辑文件夹' : '新建文件夹' }}</h2>
          <button class="tw-icon-button" title="关闭" @click="folderVisible = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body">
          <label class="tw-modal-label">
            名称
            <input
              v-model="folderForm.name"
              class="tw-dialog-input"
              maxlength="40"
              placeholder="例如：工作项目"
              @keydown.enter="saveFolder"
            />
          </label>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="folderVisible = false">取消</button>
          <button class="tw-dialog-ok" :disabled="folderBusy" @click="saveFolder">{{ folderBusy ? '保存中…' : '保存' }}</button>
        </footer>
      </div>
    </div>

    <div v-if="filterVisible" class="tw-dialog-scrim" @click.self="filterVisible = false">
      <div class="tw-dialog tw-dialog-filter" role="dialog" aria-modal="true" @keydown.esc="filterVisible = false">
        <header class="tw-dialog-head">
          <h2>{{ filterForm.id ? '编辑过滤器' : '新建过滤器' }}</h2>
          <button class="tw-icon-button" title="关闭" @click="filterVisible = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body tw-filter-form">
          <label class="tw-modal-label">
            名称
            <input v-model="filterForm.name" class="tw-dialog-input" maxlength="60" placeholder="例如：本周高优工作" />
          </label>
          <div class="tw-filter-grid">
            <label class="tw-modal-label">
              关键词
              <input v-model="filterForm.conditions.keyword" class="tw-dialog-input" maxlength="100" placeholder="标题或备注" />
            </label>
            <label class="tw-modal-label">
              状态
              <select v-model="filterForm.conditions.status" class="tw-field-select">
                <option value="open">未完成</option>
                <option value="completed">已完成</option>
                <option value="all">全部</option>
              </select>
            </label>
            <label class="tw-modal-label">
              日期
              <select v-model="filterForm.conditions.date" class="tw-field-select">
                <option value="any">不限</option>
                <option value="today">今天</option>
                <option value="next7">最近 7 天</option>
                <option value="overdue">已逾期</option>
                <option value="none">无日期</option>
              </select>
            </label>
            <label class="tw-modal-label">
              标签匹配
              <select v-model="filterForm.conditions.tagMode" class="tw-field-select">
                <option value="any">任一标签</option>
                <option value="all">全部标签</option>
              </select>
            </label>
          </div>

          <div class="tw-filter-block">
            <span>清单</span>
            <div class="tw-filter-chips">
              <button
                v-for="list in lists"
                :key="list.id"
                class="tw-filter-chip"
                :class="{ active: filterForm.conditions.listIds.includes(list.id) }"
                @click="toggleFilterValue('listIds', list.id)"
              >
                <i :style="{ background: list.color || '#4772fa' }" />
                {{ list.name }}
              </button>
            </div>
          </div>

          <div class="tw-filter-block">
            <span>优先级</span>
            <div class="tw-filter-chips">
              <button
                v-for="priority in PRIORITIES"
                :key="priority.value"
                class="tw-filter-chip"
                :class="{ active: filterForm.conditions.priorities.includes(priority.value) }"
                @click="toggleFilterValue('priorities', priority.value)"
              >
                <i :style="{ background: priority.color }" />
                {{ priority.short }}优先级
              </button>
            </div>
          </div>

          <div class="tw-filter-block">
            <span>标签</span>
            <div v-if="tagCounts.length" class="tw-filter-chips">
              <button
                v-for="tag in tagCounts"
                :key="tag.name"
                class="tw-filter-chip"
                :class="{ active: filterForm.conditions.tags.includes(tag.name) }"
                :style="{ '--tag-color': tagColor(tag.name, tag.color), '--tag-tint': tagTint(tagColor(tag.name, tag.color)) }"
                @click="toggleFilterTag(tag.name)"
              >
                #{{ tag.name }}
              </button>
            </div>
            <p v-else class="tw-filter-empty">还没有标签，可以先在任务里添加。</p>
          </div>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="filterVisible = false">取消</button>
          <button class="tw-dialog-ok" :disabled="filterBusy" @click="saveFilter">{{ filterBusy ? '保存中…' : '保存' }}</button>
        </footer>
      </div>
    </div>

    <div v-if="tagManagerVisible" class="tw-dialog-scrim" @click.self="tagManagerVisible = false">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true" @keydown.esc="tagManagerVisible = false">
        <header class="tw-dialog-head">
          <h2>管理标签</h2>
          <button class="tw-icon-button" title="关闭" @click="tagManagerVisible = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body tw-tag-manager">
          <div v-for="tag in tagCounts" :key="tag.name" class="tw-tag-row">
            <template v-if="editingTag === tag.name">
              <input
                v-model="editingTagName"
                class="tw-dialog-input"
                maxlength="30"
                @keydown.enter="saveTagRename(tag)"
                @keydown.esc="cancelRenameTag"
              />
              <button class="tw-icon-button" title="保存" :disabled="tagBusy" @click="saveTagRename(tag)">
                <TaskIcon name="check" :size="15" />
              </button>
              <button class="tw-icon-button" title="取消" @click="cancelRenameTag">
                <TaskIcon name="close" :size="15" />
              </button>
            </template>
            <template v-else>
              <label class="tw-tag-color" :style="{ background: tagColor(tag.name, tag.color) }" title="设置标签颜色">
                <input
                  type="color"
                  :value="tagColor(tag.name, tag.color)"
                  @input="changeTagColor(tag, ($event.target as HTMLInputElement).value)"
                />
              </label>
              <span class="tw-tag-row-name">#{{ tag.name }}</span>
              <small>{{ tag.count }}</small>
              <button class="tw-icon-button" title="重命名" @click="startRenameTag(tag)">
                <TaskIcon name="edit" :size="14" />
              </button>
              <button class="tw-icon-button" title="删除标签" @click="confirmDeleteTag(tag)">
                <TaskIcon name="trash" :size="14" />
              </button>
            </template>
          </div>
          <p v-if="!tagCounts.length" class="tw-filter-empty">暂无标签。</p>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="tagManagerVisible = false">关闭</button>
        </footer>
      </div>
    </div>

    <div v-if="editVisible" class="tw-dialog-scrim" @click.self="editVisible = false">
      <div class="tw-dialog" role="dialog" aria-modal="true" aria-label="编辑清单" @keydown.esc="editVisible = false">
        <header class="tw-dialog-head">
          <h2>编辑清单</h2>
          <button class="tw-icon-button" title="关闭" @click="editVisible = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body">
          <label class="tw-modal-label">
            名称
            <input
              ref="editNameInput"
              v-model="editForm.name"
              class="tw-dialog-input"
              maxlength="40"
              placeholder="清单名称"
              @keydown.enter="saveList"
            />
          </label>
          <div class="tw-modal-label">
            颜色
            <div class="tw-color-row">
              <button
                v-for="color in LIST_COLORS"
                :key="color"
                class="tw-color-swatch"
                :class="{ active: editForm.color === color }"
                :style="{ background: color }"
                @click="editForm.color = color"
              />
            </div>
          </div>
          <label class="tw-modal-label">
            文件夹
            <select v-model.number="editForm.folderId" class="tw-field-select">
              <option :value="0">根目录</option>
              <option v-for="folder in folders" :key="folder.id" :value="folder.id">{{ folder.name }}</option>
            </select>
          </label>
          <p class="tw-modal-note">删除清单会把其中的任务移动到收集箱。</p>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="editVisible = false">取消</button>
          <button class="tw-dialog-ok" :disabled="editBusy" @click="saveList">{{ editBusy ? '保存中…' : '保存' }}</button>
        </footer>
      </div>
    </div>

    <div v-if="confirmDialog.open" class="tw-dialog-scrim" @click.self="closeConfirm">
      <div class="tw-dialog tw-dialog-sm" role="alertdialog" aria-modal="true" @keydown.esc="closeConfirm">
        <header class="tw-dialog-head">
          <h2>{{ confirmDialog.title }}</h2>
          <button class="tw-icon-button" title="关闭" @click="closeConfirm">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body">
          <p class="tw-dialog-message">{{ confirmDialog.message }}</p>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="closeConfirm">取消</button>
          <button class="tw-dialog-ok tw-dialog-danger" :disabled="confirmBusy" @click="runConfirm">
            {{ confirmBusy ? '处理中…' : '删除' }}
          </button>
        </footer>
      </div>
    </div>

    <MatrixRulesDialog
      v-if="matrixRulesDialogOpen && activeMatrixView"
      :key="activeMatrixView.id"
      :view="activeMatrixView"
      :lists="lists"
      :tags="tags"
      :assignees="matrixAssignees"
      :tasks="matrixTasks"
      @saved="onMatrixRulesSaved"
      @close="matrixRulesDialogOpen = false"
    />

    <MatrixViewManagerDialog
      v-if="matrixViewManagerOpen"
      :views="matrixViews"
      @changed="onMatrixViewsChanged"
      @edit-rules="openMatrixRulesFor"
      @close="matrixViewManagerOpen = false"
    />

    <div v-if="matrixViewDialogOpen" class="tw-dialog-scrim" @click.self="matrixViewDialogOpen = false">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true" aria-label="新建四象限视图" @keydown.esc="matrixViewDialogOpen = false">
        <header class="tw-dialog-head">
          <h2>新建四象限视图</h2>
          <button class="tw-icon-button" title="关闭" @click="matrixViewDialogOpen = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body">
          <label class="tw-modal-label">
            视图名称
            <input v-model="matrixViewName" class="tw-dialog-input" maxlength="60" @keydown.enter="saveMatrixView" />
          </label>
          <label class="tw-field">
            <span>规则</span>
            <select v-model="matrixViewMode" class="tw-field-select">
              <option value="simple">按优先级</option>
              <option value="complex">优先级 + 日期</option>
              <option value="custom">自定义规则</option>
            </select>
          </label>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="matrixViewDialogOpen = false">取消</button>
          <button class="tw-dialog-ok" :disabled="matrixViewBusy || !matrixViewName.trim()" @click="saveMatrixView">
            {{ matrixViewBusy ? '创建中…' : '创建' }}
          </button>
        </footer>
      </div>
    </div>

    <NotificationDialog
      v-if="notificationDialogOpen"
      @changed="unreadNotifications = $event"
      @open="openNotification"
      @close="notificationDialogOpen = false"
    />

    <TaskListShareDialog
      v-if="shareDialogOpen && sharingList"
      :list="sharingList"
      @changed="onSharesChanged"
      @close="shareDialogOpen = false"
    />

    <CalendarEventDialog
      v-if="eventDialogOpen"
      :event="editingEvent"
      :calendars="calendarSources"
      :default-date="cursor"
      @saved="onEventSaved"
      @close="eventDialogOpen = false"
    />

    <ReminderSettingsDialog
      v-if="reminderSettingsOpen"
      :browser-enabled="remindersEnabled"
      @toggle-browser="toggleReminders"
      @close="reminderSettingsOpen = false"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Message } from '@arco-design/web-vue'
import { auth, logout } from '../auth'
import type { CalendarEvent, CalendarSource, MatrixQuadrantKey, MatrixRuleMode, MatrixView, SavedFilter, SharedTaskList, TaskCounts, TaskFilterConditions, TaskFolder, TaskItem, TaskList, TaskListMember, TaskTagCount, TaskWorkspaceData } from '../types'
import {
  batchTasks,
  createSavedFilter,
  createTask,
  createTaskFolder,
  createMatrixView,
  createTaskList,
  deleteSavedFilter,
  deleteTask,
  deleteTaskFolder,
  deleteTaskList,
  deleteTaskTag,
  emptyTaskTrash,
  fetchCalendarEvents,
  fetchNotifications,
  fetchSharedTasks,
  fetchTaskListMembers,
  fetchTaskReminders,
  fetchTaskWorkspace,
  purgeTask,
  renameTaskTag,
  reorderTasks,
  restoreTask,
  setTaskTagColor,
  updateCalendarEvent,
  updateMatrixView,
  updateSavedFilter,
  updateTask,
  updateTaskFolder,
  updateTaskList,
  type TaskView,
} from '../tasks-api'
import {
  LIST_COLORS,
  PRIORITIES,
  dayKey,
  formatDue,
  groupTasks,
  isOverdue,
  quickHint,
  reminderInstant,
  startOfToday,
  taskReminderOffsets,
} from '../tasks-utils'
import { blankTaskForMatrix, normalizeMatrixRules, planComplexDrop, planMatrixDrop } from '../matrix-utils'
import { tagColor, tagTint } from '../tag-colors'
import TaskSidebar from '../components/tasks/TaskSidebar.vue'
import TaskRow from '../components/tasks/TaskRow.vue'
import TaskDetail from '../components/tasks/TaskDetail.vue'
import TaskCalendar from '../components/tasks/TaskCalendar.vue'
import TaskMatrixPanel from '../components/tasks/TaskMatrixPanel.vue'
import HabitPanel from '../components/tasks/HabitPanel.vue'
import FocusPanel from '../components/tasks/FocusPanel.vue'
import FocusStatsPanel from '../components/tasks/FocusStatsPanel.vue'
import CountdownPanel from '../components/tasks/CountdownPanel.vue'
import HabitTodayStrip from '../components/tasks/HabitTodayStrip.vue'
import MatrixViewManagerDialog from '../components/tasks/MatrixViewManagerDialog.vue'
import MatrixRulesDialog from '../components/tasks/MatrixRulesDialog.vue'
import TaskStatsPanel from '../components/tasks/TaskStatsPanel.vue'
import TaskSummaryPanel from '../components/tasks/TaskSummaryPanel.vue'
import TaskAIPanel from '../components/tasks/TaskAIPanel.vue'
import CalendarEventDialog from '../components/tasks/CalendarEventDialog.vue'
import NotificationDialog from '../components/tasks/NotificationDialog.vue'
import TaskListShareDialog from '../components/tasks/TaskListShareDialog.vue'
import ReminderSettingsDialog from '../components/tasks/ReminderSettingsDialog.vue'
import TaskIcon from '../components/tasks/TaskIcon.vue'

type Mode = 'list' | 'board' | 'calendar'

const route = useRoute()
const router = useRouter()

const lists = ref<TaskList[]>([])
const sharedLists = ref<SharedTaskList[]>([])
const folders = ref<TaskFolder[]>([])
const filters = ref<SavedFilter[]>([])
const tasks = ref<TaskItem[]>([])
const tags = ref<string[]>([])
const tagCounts = ref<TaskTagCount[]>([])
const tagColorMap = computed<Record<string, string>>(() =>
  Object.fromEntries(tagCounts.value.map((tag) => [tag.name, tag.color])),
)
const counts = reactive<TaskCounts>({ all: 0, today: 0, next7: 0, inbox: 0, completed: 0, trash: 0 })
const inboxId = ref(0)

const view = ref<TaskView>('all')
const focusStatsPage = computed(() => route.name === 'tasks-focus-stats')
const activeListId = ref(0)
const activeFilterId = ref(0)
const activeSharedListId = ref(0)
const activeTag = ref('')
const mode = ref<Mode>('list')
const query = ref('')
const searchOpen = ref(false)
const searchInput = ref('')
const selectedId = ref(0)
const loading = ref(true)
const sidebarOpen = ref(false)
const quickText = ref('')
const quickBusy = ref(false)
const quickListId = ref(0)
const cursor = ref(new Date())
const calendarView = ref<'month' | 'week' | 'day' | 'agenda'>('month')
const calendarSources = ref<CalendarSource[]>([])
const calendarReload = ref(0)
const eventDialogOpen = ref(false)
const editingEvent = ref<CalendarEvent | null>(null)
const calendarFocus = ref<{ calendarId: number; href: string; occurrence: string } | null>(null)
const matrixRule = ref<MatrixRuleMode>('simple')
const matrixViews = ref<MatrixView[]>([])
const activeMatrixViewId = ref(0)
const matrixViewDialogOpen = ref(false)
const matrixViewName = ref('')
const matrixViewMode = ref<MatrixRuleMode>('simple')
const matrixViewManagerOpen = ref(false)
const matrixRulesDialogOpen = ref(false)
const matrixShowCompleted = ref(true)
const matrixManualSort = ref(false)
const matrixSelectionMode = ref(false)
const matrixSelectedIds = ref(new Set<number>())
try {
  matrixShowCompleted.value = localStorage.getItem('caldav-matrix-show-completed') !== '0'
  matrixManualSort.value = localStorage.getItem('caldav-matrix-manual-sort') === '1'
} catch {
  /* ignore */
}
const matrixViewBusy = ref(false)
const theme = ref<'dark' | 'light'>('dark')
const collapsed = ref(new Set<string>())
const dragId = ref(0)
const manualSort = ref(false)
const selectionMode = ref(false)
const selectedIds = ref(new Set<number>())
const dragTaskId = ref(0)
const dragOverId = ref(0)
const moveDialogOpen = ref(false)
const moveTargetId = ref(0)
const batchBusy = ref(false)
const remindersEnabled = ref(false)
const reminderSettingsOpen = ref(false)
const notificationDialogOpen = ref(false)
const unreadNotifications = ref(0)
const reminderTasks = ref<TaskItem[]>([])
const NOTIFY_KEY = 'caldav-task-notified'
let reminderTimer: ReturnType<typeof setInterval> | undefined
let notificationTimer: ReturnType<typeof setInterval> | undefined
let notificationSource: EventSource | null = null

const quickInputEl = ref<HTMLInputElement | null>(null)
const searchInputEl = ref<HTMLInputElement | null>(null)
const editNameInput = ref<HTMLInputElement | null>(null)

const editVisible = ref(false)
const editBusy = ref(false)
const editForm = reactive({ id: 0, name: '', color: LIST_COLORS[0], folderId: 0 })
const folderVisible = ref(false)
const folderBusy = ref(false)
const folderForm = reactive({ id: 0, name: '' })
const filterVisible = ref(false)
const filterBusy = ref(false)
const filterForm = reactive<{ id: number; name: string; color: string; conditions: TaskFilterConditions }>({
  id: 0,
  name: '',
  color: LIST_COLORS[0],
  conditions: { listIds: [], tags: [], tagMode: 'any', priorities: [], status: 'open', date: 'any', keyword: '' },
})
const sharingList = ref<TaskList | null>(null)
const shareDialogOpen = ref(false)
const tagManagerVisible = ref(false)
const tagBusy = ref(false)
const editingTag = ref('')
const editingTagName = ref('')
const confirmBusy = ref(false)
const confirmDialog = reactive<{ open: boolean; title: string; message: string; action: (() => Promise<void> | void) | null }>({
  open: false,
  title: '',
  message: '',
  action: null,
})

let searchTimer: ReturnType<typeof setTimeout> | undefined
let initialized = false
let refreshTimer: ReturnType<typeof setTimeout> | undefined

const smartLabels: Record<string, string> = {
  all: '所有',
  today: '今天',
  next7: '最近 7 天',
  inbox: '收集箱',
  completed: '已完成',
  trash: '垃圾桶',
  stats: '统计',
  summary: '摘要',
  ai: 'AI 助手',
  filter: '过滤器',
  list: '清单',
}

const activeFilter = computed(() => filters.value.find((item) => item.id === activeFilterId.value))

const activeSharedList = computed(() => sharedLists.value.find((item) => item.listId === activeSharedListId.value))
const sharedEditable = computed(() => view.value === 'shared' && activeSharedList.value?.role === 'editor')
const sharedReadonly = computed(() => view.value === 'shared' && !sharedEditable.value)
const heading = computed(() => {
  if (view.value === 'matrix') return '四象限'
  if (view.value === 'habit') return '习惯'
  if (view.value === 'focus') return '专注'
  if (view.value === 'countdown') return '倒数纪念日'
  if (view.value === 'shared') return activeSharedList.value?.name || '共享清单'
  if (view.value === 'list') {
    const list = lists.value.find((item) => item.id === activeListId.value)
    return list?.name || '清单'
  }
  if (view.value === 'filter') return activeFilter.value?.name || '过滤器'
  return smartLabels[view.value] || '任务'
})

const headingIcon = computed(() => {
  if (view.value === 'list') return 'inbox'
  if (view.value === 'today') return 'today'
  if (view.value === 'next7') return 'next7'
  if (view.value === 'inbox') return 'inbox'
  if (view.value === 'completed') return 'check'
  if (view.value === 'trash') return 'trash'
  if (view.value === 'habit') return 'habit'
  if (view.value === 'focus') return 'clock'
  if (view.value === 'countdown') return 'countdown'
  if (view.value === 'filter') return 'filter'
  return 'list'
})

const filteredTasks = computed(() => {
  if (!activeTag.value) return tasks.value
  return tasks.value.filter((task) => task.tags.includes(activeTag.value))
})

const openInView = computed(() => filteredTasks.value.filter((task) => !task.completed).length)
const headingCount = computed(() => {
  if (view.value === 'trash') return tasks.value.length
  if (view.value === 'stats' || view.value === 'summary' || view.value === 'ai' || view.value === 'focus' || view.value === 'countdown') return 0
  return openInView.value
})
const manualOpenTasks = computed(() =>
  filteredTasks.value
    .filter((task) => !task.completed)
    .slice()
    .sort((a, b) => a.order - b.order || a.id - b.id),
)
const groups = computed(() => {
  if (view.value === 'trash') return []
  if (manualSort.value && view.value !== 'completed') {
    const out = []
    if (manualOpenTasks.value.length) out.push({ key: 'manual', label: '', tasks: manualOpenTasks.value, tone: undefined })
    const done = filteredTasks.value.filter((task) => task.completed)
    if (done.length) out.push({ key: 'done', label: '已完成', tasks: done, tone: 'done' as const })
    return out
  }
  return groupTasks(filteredTasks.value, view.value === 'shared' ? 'all' : view.value)
})
const selectedTask = computed(() => tasks.value.find((task) => task.id === selectedId.value))
const taskMembers = ref<TaskListMember[]>([])
watch(
  () => [selectedTask.value?.id, selectedTask.value?.listId],
  () => {
    const task = selectedTask.value
    if (!task) {
      taskMembers.value = []
      return
    }
    void fetchTaskListMembers(task.listId)
      .then((result) => { taskMembers.value = result.members })
      .catch(() => { taskMembers.value = [] })
  },
)
const detailLists = computed<TaskList[]>(() => {
  const shared = view.value === 'shared' ? activeSharedList.value : undefined
  if (!shared || lists.value.some((list) => list.id === shared.listId)) return lists.value
  return [
    ...lists.value,
    {
      id: shared.listId,
      folderId: 0,
      name: shared.name,
      color: shared.color,
      order: 0,
      isInbox: false,
      count: shared.count,
    },
  ]
})

const quickTargetList = computed(() => {
  const id = quickListId.value || (view.value === 'list' || view.value === 'inbox' ? activeListId.value : inboxId.value) || inboxId.value
  return lists.value.find((list) => list.id === id)
})
const quickTargetName = computed(() => {
  if (view.value === 'shared' && activeSharedList.value) return activeSharedList.value.name
  return quickTargetList.value?.name || '收集箱'
})
const hint = computed(() => quickHint(quickText.value))

const emptyHint = computed(() => {
  if (query.value) return `没有找到“${query.value}”相关的任务。`
  if (activeTag.value) return `还没有带 #${activeTag.value} 标签的任务。`
  if (view.value === 'filter') return '当前过滤器没有匹配的任务，可以调整条件或新建任务。'
  return '按 N 或点击上方输入框，快速记下一件事。'
})

const boardColumns = computed(() => {
  const base = view.value === 'completed' ? filteredTasks.value.filter((task) => task.completed) : filteredTasks.value.filter((task) => !task.completed)
  return lists.value.map((list) => ({
    list,
    tasks: base.filter((task) => task.listId === list.id),
  }))
})

function priorityColor(priority: number) {
  return PRIORITIES.find((item) => item.value === priority)?.color || '#4772fa'
}

async function loadWorkspace(silent = false) {
  if (!silent) loading.value = true
  try {
    const data: TaskWorkspaceData = await fetchTaskWorkspace({
      view: view.value === 'shared' || view.value === 'matrix' || view.value === 'habit' || view.value === 'focus' || view.value === 'countdown' ? 'all' : view.value,
      listId: view.value === 'shared' ? undefined : activeListId.value || undefined,
      filterId: activeFilterId.value || undefined,
      q: query.value || undefined,
    })
    lists.value = data.lists
    sharedLists.value = data.sharedLists || []
    matrixViews.value = data.matrixViews || []
    if (matrixViews.value.length) {
      if (!activeMatrixViewId.value || !matrixViews.value.some((view) => view.id === activeMatrixViewId.value)) {
        const saved = Number(localStorage.getItem('caldav-matrix-view') || 0)
        const found = matrixViews.value.find((view) => view.id === saved)
        if (found) {
          activeMatrixViewId.value = found.id
          matrixRule.value = found.mode
        } else {
          activeMatrixViewId.value = 0
        }
      } else {
        const active = matrixViews.value.find((view) => view.id === activeMatrixViewId.value)
        if (active) matrixRule.value = active.mode
      }
    }
    folders.value = data.folders
    filters.value = data.filters
    tasks.value = data.tasks
    if (view.value === 'shared' && activeSharedListId.value) {
      const shared = await fetchSharedTasks(activeSharedListId.value)
      tasks.value = shared.tasks
      sharedLists.value = sharedLists.value.map((item) =>
        item.listId === shared.list.listId
          ? { ...item, role: shared.list.role, count: shared.list.count, name: shared.list.name, color: shared.list.color }
          : item,
      )
    } else if (view.value === 'shared') {
      tasks.value = []
    }
    tags.value = data.tags
    tagCounts.value = data.tagCounts
    inboxId.value = data.inbox
    Object.assign(counts, data.counts)
    if (view.value === 'trash' && mode.value !== 'list') mode.value = 'list'
    if (selectedId.value && !tasks.value.some((task) => task.id === selectedId.value)) {
      selectedId.value = 0
    }
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载任务失败')
  } finally {
    loading.value = false
  }
}

async function refreshSharedView() {
  if (view.value !== 'shared' || !activeSharedListId.value) return
  try {
    const shared = await fetchSharedTasks(activeSharedListId.value)
    tasks.value = shared.tasks
    sharedLists.value = sharedLists.value.map((item) =>
      item.listId === shared.list.listId
        ? { ...item, role: shared.list.role, count: shared.list.count, name: shared.list.name, color: shared.list.color }
        : item,
    )
    if (selectedId.value && !shared.tasks.some((task) => task.id === selectedId.value)) selectedId.value = 0
  } catch {
    /* shared role refresh is best-effort */
  }
}

function onVisibilityChange() {
  if (document.visibilityState === 'visible' && view.value === 'shared') void refreshSharedView()
}

function scheduleRefresh() {
  if (refreshTimer) clearTimeout(refreshTimer)
  refreshTimer = setTimeout(() => {
    void loadWorkspace(true)
  }, 250)
}

function taskRoutePath() {
  if (view.value === 'list') return activeListId.value ? `/tasks/list/${activeListId.value}` : '/tasks'
  if (view.value === 'filter') return activeFilterId.value ? `/tasks/filter/${activeFilterId.value}` : '/tasks'
  if (view.value === 'shared') return activeSharedListId.value ? `/tasks/shared/${activeSharedListId.value}` : '/tasks'
  if (view.value === 'all' && mode.value === 'calendar') return '/tasks/calendar'
  if (view.value === 'all' && mode.value === 'board') return '/tasks/board'
  if (view.value === 'habit' && route.params.habitId) return `/tasks/habit/${route.params.habitId}`
  if (view.value === 'focus' && route.name === 'tasks-focus-stats') return '/tasks/focus/stats'
  return view.value === 'all' ? '/tasks' : `/tasks/${view.value}`
}

function syncURL() {
  const path = taskRoutePath()
  const next: Record<string, string> = {}
  const dedicatedMode = view.value === 'all' && (mode.value === 'calendar' || mode.value === 'board')
  if (!dedicatedMode && mode.value !== 'list') next.mode = mode.value
  if (selectedId.value) next.task = String(selectedId.value)
  if (query.value) next.q = query.value
  if (calendarFocus.value) {
    next.calendar = String(calendarFocus.value.calendarId)
    next.event = calendarFocus.value.href
    if (calendarFocus.value.occurrence) next.occurrence = calendarFocus.value.occurrence
  }
  const current = route.query
  const sameQuery = Object.keys(next).every((key) => current[key] === next[key]) && Object.keys(current).length === Object.keys(next).length
  const currentMode = typeof current.mode === 'string' ? current.mode : (typeof route.meta.mode === 'string' ? route.meta.mode : 'list')
  const targetMode = next.mode || (dedicatedMode ? mode.value : 'list')
  const identityChanged = route.path !== path || currentMode !== targetMode
  if (!identityChanged) {
    if (!sameQuery) void router.replace({ path, query: next })
    return
  }
  const target = { path, query: next }
  if (initialized) void router.push(target)
  else void router.replace(target)
}

function selectView(nextView: string) {
  view.value = nextView as TaskView
  activeListId.value = 0
  activeSharedListId.value = 0
  activeTag.value = ''
  selectedId.value = 0
  sidebarOpen.value = false
  clearSelection()
  if (view.value === 'trash' || view.value === 'stats' || view.value === 'summary' || view.value === 'ai' || view.value === 'matrix' || view.value === 'habit' || view.value === 'focus' || view.value === 'countdown') {
    mode.value = 'list'
    manualSort.value = false
  }
  syncURL()
}

function selectList(id: number) {
  view.value = 'list'
  activeListId.value = id
  activeFilterId.value = 0
  activeTag.value = ''
  selectedId.value = 0
  sidebarOpen.value = false
  clearSelection()
  syncURL()
}

function selectFilter(id: number) {
  view.value = 'filter'
  activeFilterId.value = id
  activeListId.value = 0
  activeTag.value = ''
  selectedId.value = 0
  sidebarOpen.value = false
  clearSelection()
  syncURL()
}

function selectSharedList(listId: number) {
  view.value = 'shared'
  activeSharedListId.value = listId
  activeListId.value = 0
  activeFilterId.value = 0
  activeTag.value = ''
  selectedId.value = 0
  mode.value = 'list'
  sidebarOpen.value = false
  clearSelection()
  syncURL()
  void loadWorkspace(true)
}

function openShareList(list: TaskList) {
  sharingList.value = list
  shareDialogOpen.value = true
}

function onSharesChanged() {
  void loadWorkspace(true)
}

function selectTag(tag: string) {
  activeTag.value = tag
  sidebarOpen.value = false
}

function selectTagFromStats(tag: string) {
  selectView('all')
  activeTag.value = tag
}

function resetWorkspaceToAll() {
  view.value = 'all'
  activeListId.value = 0
  activeFilterId.value = 0
  activeSharedListId.value = 0
  activeTag.value = ''
  selectedId.value = 0
  sidebarOpen.value = false
  clearSelection()
}

function switchMode(next: Mode) {
  if (view.value === 'trash' || view.value === 'shared') return
  if (view.value === 'stats' || view.value === 'summary' || view.value === 'ai' || view.value === 'matrix' || view.value === 'habit' || view.value === 'focus' || view.value === 'countdown') resetWorkspaceToAll()
  clearSelection()
  mode.value = next
  if (next === 'calendar') {
    cursor.value = new Date()
  }
  syncURL()
}

function openModePage(next: Mode) {
  if (view.value !== 'all') resetWorkspaceToAll()
  mode.value = next
  if (next === 'calendar') cursor.value = new Date()
  syncURL()
}

function toggleGroup(key: string) {
  const next = new Set(collapsed.value)
  if (next.has(key)) next.delete(key)
  else next.add(key)
  collapsed.value = next
  try {
    localStorage.setItem('caldav-task-collapsed', JSON.stringify([...next]))
  } catch {
    /* ignore */
  }
}

function openTask(task: TaskItem) {
  if (selectionMode.value) {
    toggleSelect(task)
    return
  }
  if (view.value === 'trash') return
  selectedId.value = task.id
  syncURL()
}

async function toggleTask(task: TaskItem) {
  if (sharedReadonly.value) {
    Message.info('共享清单为只读')
    return
  }
  const target = !task.completed
  task.completed = target
  try {
    const { task: updated } = await updateTask(task.id, { completed: target })
    replaceTask(updated)
    if (target && !updated.completed && updated.recurrence) {
      Message.info(`已完成本次，下次 ${formatDue(updated)}`)
    }
    scheduleRefresh()
    void checkReminders()
  } catch (error) {
    task.completed = !target
    Message.error(error instanceof Error ? error.message : '更新任务失败')
  }
}

function onQuickEnter(event: KeyboardEvent) {
  if (event.isComposing) return
  event.preventDefault()
  void submitQuick()
}

async function submitQuick() {
  const text = quickText.value.trim()
  if (!text || quickBusy.value) return
  quickBusy.value = true
  try {
    const { task } = await createTask({
      text,
      listId: view.value === 'shared' ? activeSharedList.value?.listId : quickTargetList.value?.id,
    })
    quickText.value = ''
    quickListId.value = 0
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建任务失败')
  } finally {
    quickBusy.value = false
    quickInputEl.value?.focus()
  }
}

function createFromCalendar(payload: { date: string; title: string }) {
  void (async () => {
    try {
      const { task } = await createTask({
        title: payload.title,
        listId: quickTargetList.value?.id,
        due: `${payload.date}T00:00:00`,
        allDay: true,
      })
      await loadWorkspace(true)
      selectedId.value = task.id
    } catch (error) {
      Message.error(error instanceof Error ? error.message : '创建任务失败')
    }
  })()
}

function addToColumn(listId: number) {
  quickListId.value = listId
  quickInputEl.value?.scrollIntoView({ block: 'center', behavior: 'smooth' })
  quickInputEl.value?.focus()
}

function focusQuick() {
  mode.value = 'list'
  requestAnimationFrame(() => quickInputEl.value?.focus())
}

async function createList(name: string) {
  try {
    const color = LIST_COLORS[lists.value.length % LIST_COLORS.length]
    await createTaskList(name, color)
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建清单失败')
  }
}

function openEditList(list: TaskList) {
  editForm.id = list.id
  editForm.name = list.name
  editForm.color = list.color || LIST_COLORS[0]
  editForm.folderId = list.folderId || 0
  editVisible.value = true
  requestAnimationFrame(() => editNameInput.value?.focus())
}

async function saveList() {
  const name = editForm.name.trim()
  if (!name) {
    Message.warning('清单名称不能为空')
    return
  }
  editBusy.value = true
  try {
    await updateTaskList(editForm.id, { name, color: editForm.color, folderId: editForm.folderId })
    editVisible.value = false
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存清单失败')
  } finally {
    editBusy.value = false
  }
}

function askConfirm(title: string, message: string, action: () => Promise<void> | void) {
  confirmDialog.title = title
  confirmDialog.message = message
  confirmDialog.action = action
  confirmDialog.open = true
}

function closeConfirm() {
  confirmDialog.open = false
  confirmDialog.action = null
  confirmBusy.value = false
}

async function runConfirm() {
  if (!confirmDialog.action) return
  confirmBusy.value = true
  try {
    await confirmDialog.action()
    closeConfirm()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '操作失败')
    confirmBusy.value = false
  }
}

function confirmDeleteList(list: TaskList) {
  askConfirm('删除清单', `确定删除「${list.name}」吗？其中的任务会移动到收集箱。`, async () => {
    await deleteTaskList(list.id)
    if (activeListId.value === list.id) selectView('all')
    await loadWorkspace(true)
  })
}

function replaceTask(updated: TaskItem) {
  const index = tasks.value.findIndex((task) => task.id === updated.id)
  if (index >= 0) tasks.value[index] = updated
}

function onTaskChanged(updated: TaskItem) {
  replaceTask(updated)
  scheduleRefresh()
}

function onTaskDeleted(id: number) {
  tasks.value = tasks.value.filter((task) => task.id !== id)
  if (selectedId.value === id) selectedId.value = 0
  scheduleRefresh()
}

function confirmRemoveTask(task: TaskItem) {
  if (sharedReadonly.value) {
    Message.info('共享清单为只读')
    return
  }
  askConfirm('删除任务', `确定删除「${task.title}」吗？`, async () => {
    await deleteTask(task.id)
    onTaskDeleted(task.id)
  })
}

async function postponeOverdue() {
  const overdue = filteredTasks.value.filter((task) => !task.completed && isOverdue(task))
  if (!overdue.length) return
  const today = dayKey(startOfToday())
  const now = Date.now()
  try {
    await Promise.all(
      overdue.map((task) => {
        if (task.allDay) return updateTask(task.id, { due: `${today}T00:00:00`, allDay: true })
        const original = new Date(task.due as string)
        let due = new Date(`${today}T${String(original.getHours()).padStart(2, '0')}:${String(original.getMinutes()).padStart(2, '0')}:00`)
        // A time that already passed today would stay overdue; move it to the
        // end of the day so "顺延到今天" actually clears the overdue group.
        if (due.getTime() <= now) {
          due = new Date(`${today}T23:59:00`)
        }
        return updateTask(task.id, { due: due.toISOString() })
      }),
    )
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '顺延失败')
  }
}

function dropOnList(listId: number) {
  const id = dragId.value
  dragId.value = 0
  if (!id) return
  const task = tasks.value.find((item) => item.id === id)
  if (!task || task.listId === listId) return
  const previous = task.listId
  task.listId = listId
  void updateTask(id, { listId }).then(({ task: updated }) => {
    replaceTask(updated)
    scheduleRefresh()
  }).catch((error) => {
    task.listId = previous
    Message.error(error instanceof Error ? error.message : '移动任务失败')
  })
}

function stepCalendar(delta: number) {
  const date = cursor.value
  if (calendarView.value === 'month') {
    cursor.value = new Date(date.getFullYear(), date.getMonth() + delta, 1)
  } else if (calendarView.value === 'week') {
    cursor.value = new Date(date.getFullYear(), date.getMonth(), date.getDate() + delta * 7)
  } else if (calendarView.value === 'day') {
    cursor.value = new Date(date.getFullYear(), date.getMonth(), date.getDate() + delta)
  } else {
    cursor.value = new Date(date.getFullYear(), date.getMonth(), date.getDate() + delta * 30)
  }
}

function openHabitFromCalendar(id: number) {
  selectView('habit')
  void router.replace({ path: `/tasks/habit/${id}` })
}

function onHabitDetailOpened(id: number) {
  if (view.value !== 'habit') return
  if (String(route.params.habitId || '') !== String(id)) void router.replace({ path: `/tasks/habit/${id}` })
}

function onHabitDetailClosed() {
  if (view.value === 'habit' && route.params.habitId) void router.replace({ path: '/tasks/habit' })
}

function openCalendarEvent(event: CalendarEvent) {
  editingEvent.value = event
  eventDialogOpen.value = true
}

function clearCalendarFocus() {
  calendarFocus.value = null
}

function openEventCreator() {
  if (!calendarSources.value.length) {
    Message.warning('没有可用的日历，请先在管理后台创建日历')
    return
  }
  editingEvent.value = null
  eventDialogOpen.value = true
}

function onEventSaved() {
  calendarReload.value += 1
}

async function rescheduleTask(payload: { task: TaskItem; due: string; allDay: boolean }) {
  try {
    const { task } = await updateTask(payload.task.id, { due: payload.due, allDay: payload.allDay })
    replaceTask(task)
    Message.success('任务已改期')
    scheduleRefresh()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '改期失败')
  }
}

async function rescheduleEvent(payload: { event: CalendarEvent; start: string; end: string; allDay: boolean }) {
  const { event } = payload
  try {
    await updateCalendarEvent(event.calendarId, event.href, {
      summary: event.summary,
      location: event.location,
      description: event.description,
      start: payload.start,
      end: payload.end,
      allDay: payload.allDay,
      rrule: event.rrule,
    })
    calendarReload.value += 1
    Message.success(event.recurring ? '重复日程已整体改期' : '日程已改期')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '日程改期失败')
  }
}

const habitFocusId = computed(() => Number(route.params.habitId) || 0)

const matrixTasks = computed(() =>
  matrixShowCompleted.value ? filteredTasks.value : filteredTasks.value.filter((task) => !task.completed),
)
const activeMatrixView = computed(() => matrixViews.value.find((item) => item.id === activeMatrixViewId.value))
const matrixCustomRules = computed(() => activeMatrixView.value?.rules)
const matrixAssignees = computed(() =>
  Array.from(new Set(tasks.value.map((task) => task.assignee).filter(Boolean))).sort((a, b) => a.localeCompare(b, 'zh')),
)

function clearMatrixSelection() {
  matrixSelectedIds.value = new Set()
}

function toggleMatrixSelection() {
  matrixSelectionMode.value = !matrixSelectionMode.value
  clearMatrixSelection()
}

function toggleMatrixSelect(task: TaskItem) {
  const next = new Set(matrixSelectedIds.value)
  if (next.has(task.id)) next.delete(task.id)
  else next.add(task.id)
  matrixSelectedIds.value = next
}

function matrixPatchForTask(task: TaskItem, quadrant: MatrixQuadrantKey) {
  if (matrixRule.value === 'custom') {
    return planMatrixDrop(task, normalizeMatrixRules(matrixCustomRules.value), quadrant)
  }
  if (matrixRule.value === 'complex') return planComplexDrop(task, quadrant)
  return { priority: quadrant === 'q1' ? 3 : quadrant === 'q2' ? 2 : quadrant === 'q3' ? 1 : 0 }
}

async function batchMoveMatrix(quadrant: string) {
  const target = quadrant as MatrixQuadrantKey
  const selected = matrixTasks.value.filter((task) => matrixSelectedIds.value.has(task.id))
  if (!selected.length) return
  const plans = selected.map((task) => ({ task, patch: matrixPatchForTask(task, target) }))
  const valid = plans.filter((item): item is { task: TaskItem; patch: NonNullable<typeof item.patch> } => item.patch !== null)
  let updated = 0
  let failed = plans.length - valid.length
  await Promise.all(valid.map(async ({ task, patch }) => {
    try {
      const { task: next } = await updateTask(task.id, patch)
      replaceTask(next)
      updated += 1
    } catch {
      failed += 1
    }
  }))
  if (updated) Message.success(`已移动 ${updated} 个任务`)
  if (failed) Message.warning(`${failed} 个任务未能移动`)
  clearMatrixSelection()
  await loadWorkspace(true)
}

async function quickAddMatrixTask(payload: { quadrant: string; title: string }) {
  const title = payload.title.trim()
  const target = payload.quadrant as MatrixQuadrantKey
  if (!title) return
  const shell = blankTaskForMatrix(title)
  let patch: { priority?: number; due?: string; listId?: number; tags?: string[]; assignee?: string } | null = null
  if (matrixRule.value === 'custom') {
    patch = planMatrixDrop(shell, normalizeMatrixRules(matrixCustomRules.value), target)
    if (patch === null) {
      Message.warning('目标象限条件无法自动满足')
      return
    }
  } else if (matrixRule.value === 'complex') {
    patch = planComplexDrop(shell, target)
  } else {
    patch = { priority: target === 'q1' ? 3 : target === 'q2' ? 2 : target === 'q3' ? 1 : 0 }
  }
  try {
    await createTask({ title, ...patch })
    await loadWorkspace(true)
    Message.success('任务已添加')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建任务失败')
  }
}

function toggleMatrixCompleted() {
  clearMatrixSelection()
  matrixShowCompleted.value = !matrixShowCompleted.value
  try {
    localStorage.setItem('caldav-matrix-show-completed', matrixShowCompleted.value ? '1' : '0')
  } catch {
    /* ignore */
  }
}

function toggleMatrixManualSort() {
  clearMatrixSelection()
  matrixManualSort.value = !matrixManualSort.value
  try {
    localStorage.setItem('caldav-matrix-manual-sort', matrixManualSort.value ? '1' : '0')
  } catch {
    /* ignore */
  }
}

async function applyMatrixOrder(ids: number[]) {
  ids.forEach((id, index) => {
    const task = tasks.value.find((item) => item.id === id)
    if (task) task.order = index + 1
  })
  try {
    await reorderTasks(ids)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '排序保存失败')
    void loadWorkspace(true)
  }
}

async function onMatrixReorder(ids: number[]) {
  await applyMatrixOrder(ids)
}

function openMatrixRules() {
  if (!activeMatrixViewId.value) return
  matrixRulesDialogOpen.value = true
}

function openMatrixRulesFor(view: MatrixView) {
  matrixViewManagerOpen.value = false
  selectMatrixView(view.id)
  matrixRule.value = 'custom'
  matrixRulesDialogOpen.value = true
}

function onMatrixRulesSaved(view: MatrixView) {
  matrixViews.value = matrixViews.value.map((item) => item.id === view.id ? view : item)
  matrixRule.value = 'custom'
  matrixRulesDialogOpen.value = false
  Message.success('自定义规则已保存')
}

async function setMatrixRule(rule: MatrixRuleMode) {
  clearMatrixSelection()
  matrixRule.value = rule
  try {
    localStorage.setItem('caldav-matrix-rule', rule)
  } catch {
    /* ignore */
  }
  if (!activeMatrixViewId.value) return
  const hadRules = Boolean(activeMatrixView.value?.rules)
  try {
    const { view } = await updateMatrixView(activeMatrixViewId.value, { mode: rule })
    matrixViews.value = matrixViews.value.map((item) => item.id === view.id ? view : item)
    if (rule === 'custom' && !hadRules) matrixRulesDialogOpen.value = true
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存四象限规则失败')
  }
}

function selectMatrixView(id: number) {
  clearMatrixSelection()
  activeMatrixViewId.value = id
  const view = matrixViews.value.find((item) => item.id === id)
  matrixRule.value = view?.mode || 'simple'
  try {
    localStorage.setItem('caldav-matrix-view', String(id))
  } catch {
    /* ignore */
  }
}

function onMatrixViewsChanged(views: MatrixView[]) {
  matrixViews.value = views
  if (activeMatrixViewId.value && !views.some((view) => view.id === activeMatrixViewId.value)) {
    selectMatrixView(0)
  } else {
    const active = views.find((view) => view.id === activeMatrixViewId.value)
    if (active) matrixRule.value = active.mode
  }
}

function openMatrixViewDialog() {
  matrixViewName.value = `四象限视图 ${matrixViews.value.length + 1}`
  matrixViewMode.value = matrixRule.value
  matrixViewBusy.value = false
  matrixViewDialogOpen.value = true
}

async function saveMatrixView() {
  const name = matrixViewName.value.trim()
  if (!name || matrixViewBusy.value) return
  matrixViewBusy.value = true
  try {
    const { view } = await createMatrixView(name, matrixViewMode.value)
    matrixViews.value = [...matrixViews.value, view]
    selectMatrixView(view.id)
    matrixViewDialogOpen.value = false
    if (view.mode === 'custom') matrixRulesDialogOpen.value = true
    Message.success('四象限视图已创建')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建四象限视图失败')
  } finally {
    matrixViewBusy.value = false
  }
}

async function moveTaskToCustomQuadrant(payload: { task: TaskItem; quadrant: MatrixQuadrantKey }) {
  const rules = normalizeMatrixRules(matrixCustomRules.value)
  const patch = planMatrixDrop(payload.task, rules, payload.quadrant)
  if (patch === null) {
    Message.warning('目标象限条件无法通过拖拽自动满足')
    return
  }
  if (Object.keys(patch).length === 0) {
    Message.info('任务已符合目标象限条件')
    return
  }
  try {
    const { task } = await updateTask(payload.task.id, patch)
    replaceTask(task)
    Message.success('已按目标象限规则调整任务')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '自动调整任务条件失败')
  }
}

async function moveTaskCrossQuadrant(payload: { task: TaskItem; quadrant: MatrixQuadrantKey; orderedIds: number[] }) {
  let patch: { priority?: number; due?: string; listId?: number; tags?: string[]; assignee?: string } | null = null
  if (matrixRule.value === 'custom') {
    patch = planMatrixDrop(payload.task, normalizeMatrixRules(matrixCustomRules.value), payload.quadrant)
    if (patch === null) {
      Message.warning('目标象限条件无法通过拖拽自动满足')
      return
    }
  } else if (matrixRule.value === 'complex') {
    patch = planComplexDrop(payload.task, payload.quadrant)
  } else {
    patch = { priority: payload.quadrant === 'q1' ? 3 : payload.quadrant === 'q2' ? 2 : payload.quadrant === 'q3' ? 1 : 0 }
  }
  try {
    const { task } = await updateTask(payload.task.id, patch)
    replaceTask(task)
    await applyMatrixOrder(payload.orderedIds)
    Message.success('已移动到对应象限')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '移动任务失败')
  }
}

async function moveTaskToQuadrant(payload: { task: TaskItem; priority: number }) {
  try {
    const { task } = await updateTask(payload.task.id, { priority: payload.priority })
    replaceTask(task)
    Message.success('已移动到对应象限')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '移动任务失败')
  }
}

function openStats() {
  selectView('stats')
  sidebarOpen.value = false
}

function openAI() {
  selectView('ai')
  sidebarOpen.value = false
}

function handleAITasksChanged() {
  void loadWorkspace(true)
}

function toggleSearch() {
  if (view.value === 'stats' || view.value === 'summary' || view.value === 'ai') selectView('all')
  searchOpen.value = !searchOpen.value
  if (searchOpen.value) {
    requestAnimationFrame(() => searchInputEl.value?.focus())
  } else {
    closeSearch()
  }
}

function closeSearch() {
  searchOpen.value = false
  searchInput.value = ''
  query.value = ''
  syncURL()
}

function applyTheme(next: 'dark' | 'light') {
  theme.value = next
  document.documentElement.dataset.theme = next
  try {
    localStorage.setItem('caldav-task-theme', next)
  } catch {
    /* ignore */
  }
}

function toggleTheme() {
  applyTheme(theme.value === 'dark' ? 'light' : 'dark')
}

async function handleLogout() {
  try {
    await logout()
    void router.push('/login')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '退出失败')
  }
}

function onKeydown(event: KeyboardEvent) {
  const target = event.target as HTMLElement | null
  const typing = target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable)
  if (typing) return
  if (event.key === 'n' || event.key === 'N') {
    if (view.value === 'trash') return
    event.preventDefault()
    if (mode.value === 'calendar') mode.value = 'list'
    requestAnimationFrame(() => quickInputEl.value?.focus())
  }
  if (event.key === 'Escape') {
    selectedId.value = 0
  }
}

function emptyConditions(): TaskFilterConditions {
  return { listIds: [], tags: [], tagMode: 'any', priorities: [], status: 'open', date: 'any', keyword: '' }
}

function openCreateFolder() {
  folderForm.id = 0
  folderForm.name = ''
  folderVisible.value = true
}

function openEditFolder(folder: TaskFolder) {
  folderForm.id = folder.id
  folderForm.name = folder.name
  folderVisible.value = true
}

async function saveFolder() {
  const name = folderForm.name.trim()
  if (!name) {
    Message.warning('文件夹名称不能为空')
    return
  }
  folderBusy.value = true
  try {
    if (folderForm.id) await updateTaskFolder(folderForm.id, { name })
    else await createTaskFolder(name)
    folderVisible.value = false
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存文件夹失败')
  } finally {
    folderBusy.value = false
  }
}

function confirmDeleteFolder(folder: TaskFolder) {
  askConfirm('删除文件夹', `删除「${folder.name}」后，其中的清单会回到根目录。`, async () => {
    await deleteTaskFolder(folder.id)
    await loadWorkspace(true)
  })
}

function openCreateFilter() {
  filterForm.id = 0
  filterForm.name = ''
  filterForm.color = LIST_COLORS[0]
  filterForm.conditions = emptyConditions()
  filterVisible.value = true
}

function openEditFilter(filter: SavedFilter) {
  filterForm.id = filter.id
  filterForm.name = filter.name
  filterForm.color = filter.color || LIST_COLORS[0]
  const cond = filter.conditions || emptyConditions()
  filterForm.conditions = {
    listIds: [...(cond.listIds || [])],
    tags: [...(cond.tags || [])],
    tagMode: cond.tagMode || 'any',
    priorities: [...(cond.priorities || [])],
    status: cond.status || 'open',
    date: cond.date || 'any',
    keyword: cond.keyword || '',
  }
  filterVisible.value = true
}

function toggleFilterValue(kind: 'listIds' | 'priorities', value: number) {
  const list = filterForm.conditions[kind] as number[]
  const index = list.indexOf(value)
  if (index >= 0) list.splice(index, 1)
  else list.push(value)
}

function toggleFilterTag(tag: string) {
  const list = filterForm.conditions.tags
  const index = list.indexOf(tag)
  if (index >= 0) list.splice(index, 1)
  else list.push(tag)
}

async function saveFilter() {
  const name = filterForm.name.trim()
  if (!name) {
    Message.warning('过滤器名称不能为空')
    return
  }
  filterBusy.value = true
  try {
    const payload = {
      name,
      color: filterForm.color,
      conditions: {
        ...filterForm.conditions,
        keyword: filterForm.conditions.keyword.trim(),
      },
    }
    const result = filterForm.id
      ? await updateSavedFilter(filterForm.id, payload)
      : await createSavedFilter(payload)
    filterVisible.value = false
    await loadWorkspace(true)
    if (filterForm.id && activeFilterId.value === filterForm.id) {
      await loadWorkspace()
    } else if (!filterForm.id) {
      selectFilter(result.filter.id)
    }
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存过滤器失败')
  } finally {
    filterBusy.value = false
  }
}

function confirmDeleteFilter(filter: SavedFilter) {
  askConfirm('删除过滤器', `确定删除「${filter.name}」吗？`, async () => {
    await deleteSavedFilter(filter.id)
    if (activeFilterId.value === filter.id) selectView('all')
    await loadWorkspace(true)
  })
}

function openTagManager() {
  editingTag.value = ''
  editingTagName.value = ''
  tagManagerVisible.value = true
}

function startRenameTag(tag: TaskTagCount) {
  editingTag.value = tag.name
  editingTagName.value = tag.name
}

function cancelRenameTag() {
  editingTag.value = ''
  editingTagName.value = ''
}

async function saveTagRename(tag: TaskTagCount) {
  const name = editingTagName.value.trim().replace(/^#/, '')
  if (!name || name === tag.name) {
    cancelRenameTag()
    return
  }
  tagBusy.value = true
  try {
    await renameTaskTag(tag.name, name)
    if (activeTag.value === tag.name) activeTag.value = name
    cancelRenameTag()
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '重命名标签失败')
  } finally {
    tagBusy.value = false
  }
}

async function changeTagColor(tag: TaskTagCount, color: string) {
  const previous = tag.color
  tag.color = color
  try {
    const result = await setTaskTagColor(tag.name, color)
    tagCounts.value = result.tags
  } catch (error) {
    tag.color = previous
    Message.error(error instanceof Error ? error.message : '设置标签颜色失败')
  }
}

function confirmDeleteTag(tag: TaskTagCount) {
  askConfirm('删除标签', `从所有任务中移除「#${tag.name}」？`, async () => {
    await deleteTaskTag(tag.name)
    if (activeTag.value === tag.name) activeTag.value = ''
    await loadWorkspace(true)
  })
}

function toggleManualSort() {
  manualSort.value = !manualSort.value
  if (manualSort.value) clearSelection()
  try {
    localStorage.setItem('caldav-task-sort', manualSort.value ? 'manual' : 'default')
  } catch {
    /* ignore */
  }
}

function toggleSelection() {
  selectionMode.value = !selectionMode.value
  selectedIds.value = new Set()
  if (selectionMode.value) {
    manualSort.value = false
    selectedId.value = 0
  }
}

function toggleSelect(task: TaskItem) {
  const next = new Set(selectedIds.value)
  if (next.has(task.id)) next.delete(task.id)
  else next.add(task.id)
  selectedIds.value = next
}

function clearSelection() {
  selectionMode.value = false
  selectedIds.value = new Set()
}

async function runBatch(action: 'complete' | 'uncomplete' | 'move' | 'delete', listId?: number) {
  const ids = [...selectedIds.value]
  if (!ids.length) return
  batchBusy.value = true
  try {
    const { updated } = await batchTasks(ids, action, listId)
    Message.success(`已处理 ${updated} 个任务`)
    clearSelection()
    moveDialogOpen.value = false
    await loadWorkspace(true)
    void checkReminders()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '批量操作失败')
  } finally {
    batchBusy.value = false
  }
}

function batchComplete() {
  void runBatch('complete')
}

function openMoveDialog() {
  moveTargetId.value = activeListId.value || inboxId.value
  moveDialogOpen.value = true
}

function batchMove() {
  if (!moveTargetId.value) return
  void runBatch('move', moveTargetId.value)
}

function confirmBatchDelete() {
  askConfirm('删除所选任务', `确定把选中的 ${selectedIds.value.size} 个任务移到垃圾桶吗？`, async () => {
    await runBatch('delete')
  })
}

function restoreOne(task: TaskItem) {
  void (async () => {
    try {
      await restoreTask(task.id)
      Message.success('任务已恢复')
      await loadWorkspace(true)
    } catch (error) {
      Message.error(error instanceof Error ? error.message : '恢复失败')
    }
  })()
}

function confirmPurgeTask(task: TaskItem) {
  askConfirm('彻底删除任务', `「${task.title}」将被永久删除，无法恢复。`, async () => {
    await purgeTask(task.id)
    await loadWorkspace(true)
  })
}

function confirmEmptyTrash() {
  askConfirm('清空垃圾桶', '垃圾桶中的所有任务都会被永久删除，无法恢复。', async () => {
    await emptyTaskTrash()
    Message.success('垃圾桶已清空')
    await loadWorkspace(true)
  })
}

function onRowDragStart(task: TaskItem, event: DragEvent) {
  if (!manualSort.value || selectionMode.value) return
  dragTaskId.value = task.id
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', String(task.id))
  }
}

function onRowDragOver(task: TaskItem) {
  if (!dragTaskId.value || task.completed || task.id === dragTaskId.value) return
  dragOverId.value = task.id
}

function onRowDragEnd() {
  dragTaskId.value = 0
  dragOverId.value = 0
}

function onRowDrop(target: TaskItem) {
  if (view.value === 'shared') return
  const source = dragTaskId.value
  dragTaskId.value = 0
  dragOverId.value = 0
  if (!source || target.completed || source === target.id) return
  const list = manualOpenTasks.value.slice()
  const from = list.findIndex((task) => task.id === source)
  const to = list.findIndex((task) => task.id === target.id)
  if (from < 0 || to < 0) return
  const [moved] = list.splice(from, 1)
  list.splice(to, 0, moved)
  list.forEach((task, index) => {
    task.order = index + 1
  })
  void reorderTasks(list.map((task) => task.id)).catch((error) => {
    Message.error(error instanceof Error ? error.message : '排序保存失败')
  })
}

function notificationSupported() {
  return typeof window !== 'undefined' && 'Notification' in window
}

function readNotified(): Record<string, number> {
  try {
    const raw = localStorage.getItem(NOTIFY_KEY)
    return raw ? (JSON.parse(raw) as Record<string, number>) : {}
  } catch {
    return {}
  }
}

async function checkReminders() {
  if (!remindersEnabled.value || !notificationSupported()) return
  try {
    const { tasks: candidates } = await fetchTaskReminders()
    reminderTasks.value = candidates
    const now = Date.now()
    const notified = readNotified()
    const next: Record<string, number> = {}
    for (const [key, at] of Object.entries(notified)) {
      if (now - at < 7 * 86400000) next[key] = at
    }
    try {
      const eventData = await fetchCalendarEvents(new Date(now - 60 * 60000), new Date(now + 2 * 86400000))
      for (const event of eventData.events) {
      for (const offset of event.reminders || []) {
        const start = new Date(event.start)
        if (event.allDay) start.setHours(9, 0, 0, 0)
        const at = new Date(start.getTime() - offset * 60000)
        if (now - at.getTime() < 0 || now - at.getTime() >= 5 * 60000) continue
        const key = `event:${event.uid}:${event.start}:${offset}`
        if (next[key]) continue
        next[key] = now
        const body = `${event.summary} · ${event.allDay ? start.toLocaleDateString('zh-CN') : start.toLocaleString('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })}`
        try {
          if (Notification.permission === 'granted') {
            new Notification('日程提醒', { body, tag: `event-${event.uid}-${offset}` })
          } else {
            Message.info(`日程提醒：${body}`)
          }
        } catch {
          Message.info(`日程提醒：${body}`)
        }
      }
      }
    } catch {
      /* event reminders are best-effort */
    }
    for (const task of candidates) {
      for (const offset of taskReminderOffsets(task)) {
        const at = reminderInstant(task, offset)
        if (!at) continue
        const key = `${task.id}:${task.due}:${offset}`
        if (next[key]) continue
        const diff = now - at.getTime()
        if (diff >= 0 && diff < 5 * 60000) {
          next[key] = now
          const body = task.due ? `${task.title} · ${formatDue(task)}` : task.title
          try {
            if (Notification.permission === 'granted') {
              new Notification('任务提醒', { body, tag: `task-${task.id}-${offset}` })
            } else {
              Message.info(`任务提醒：${body}`)
            }
          } catch {
            Message.info(`任务提醒：${body}`)
          }
        }
      }
    }
    localStorage.setItem(NOTIFY_KEY, JSON.stringify(next))
  } catch {
    /* reminder polling is best-effort */
  }
}

function stopReminderTimer() {
  if (reminderTimer) {
    clearInterval(reminderTimer)
    reminderTimer = undefined
  }
}

function startReminderTimer() {
  stopReminderTimer()
  reminderTimer = setInterval(() => {
    void checkReminders()
  }, 30000)
}

async function toggleReminders() {
  if (remindersEnabled.value) {
    remindersEnabled.value = false
    stopReminderTimer()
    try {
      localStorage.setItem('caldav-task-reminders', 'off')
    } catch {
      /* ignore */
    }
    Message.info('已关闭浏览器提醒')
    return
  }
  if (!notificationSupported()) {
    Message.warning('当前浏览器不支持桌面通知')
    return
  }
  if (!window.isSecureContext) {
    Message.warning('浏览器提醒需要 HTTPS 或 localhost 访问')
    return
  }
  let permission = Notification.permission
  if (permission === 'default') permission = await Notification.requestPermission()
  if (permission !== 'granted') {
    Message.warning('未获得通知权限，请在浏览器设置中允许通知')
    return
  }
  remindersEnabled.value = true
  try {
    localStorage.setItem('caldav-task-reminders', 'on')
  } catch {
    /* ignore */
  }
  await checkReminders()
  startReminderTimer()
  Message.success('已开启浏览器提醒，页面保持打开时生效')
}

async function refreshNotifications() {
  try {
    const data = await fetchNotifications()
    unreadNotifications.value = data.unread
  } catch {
    /* notification badge is best-effort */
  }
}

function startNotificationStream() {
  if (typeof EventSource === 'undefined' || notificationSource) return
  notificationSource = new EventSource('/api/admin/notifications/stream')
  notificationSource.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data) as { unread?: number }
      if (typeof data.unread === 'number') unreadNotifications.value = data.unread
    } catch {
      /* ignore malformed SSE frames */
    }
  }
}

async function openNotification(url: string) {
  notificationDialogOpen.value = false
  const target = url.startsWith('/admin/') ? url.slice('/admin'.length) : url
  if (target) {
    await router.push(target)
    hydrateFromRoute()
    await loadWorkspace()
  }
  void refreshNotifications()
}

function routeParamID(value: unknown) {
  const raw = Array.isArray(value) ? value[0] : value
  const id = Number(raw)
  return Number.isFinite(id) && id > 0 ? id : 0
}

function hydrateFromRoute() {
  const q = route.query
  const validViews: TaskView[] = ['all', 'today', 'next7', 'inbox', 'completed', 'trash', 'stats', 'summary', 'ai', 'filter', 'list', 'shared', 'matrix', 'habit', 'focus', 'countdown']
  const queryView = typeof q.view === 'string' && validViews.includes(q.view as TaskView) ? q.view as TaskView : null
  const metaView = typeof route.meta.view === 'string' && validViews.includes(route.meta.view as TaskView) ? route.meta.view as TaskView : null
  view.value = queryView || metaView || 'all'

  const listId = routeParamID(route.params.listId) || (typeof q.list === 'string' ? Number(q.list) : 0)
  if (view.value === 'list' && listId) activeListId.value = listId
  else if (view.value === 'list') view.value = 'all'
  const filterId = routeParamID(route.params.filterId) || (typeof q.filter === 'string' ? Number(q.filter) : 0)
  if (view.value === 'filter' && filterId) activeFilterId.value = filterId
  else if (view.value === 'filter') view.value = 'all'
  const sharedId = routeParamID(route.params.sharedId) || (typeof q.shared === 'string' ? Number(q.shared) : 0)
  if (view.value === 'shared' && sharedId) activeSharedListId.value = sharedId
  else if (view.value === 'shared') view.value = 'all'

  const metaMode = typeof route.meta.mode === 'string' ? route.meta.mode : ''
  const queryMode = typeof q.mode === 'string' ? q.mode : ''
  const nextMode = metaMode || queryMode || 'list'
  mode.value = view.value === 'shared' ? 'list' : (['list', 'board', 'calendar'].includes(nextMode) ? nextMode : 'list') as Mode
  if (view.value === 'trash') mode.value = 'list'
  const focusCalendar = typeof q.calendar === 'string' ? Number(q.calendar) : 0
  const focusEvent = typeof q.event === 'string' ? q.event : ''
  const focusOccurrence = typeof q.occurrence === 'string' ? q.occurrence : ''
  calendarFocus.value = focusCalendar && focusEvent
    ? { calendarId: focusCalendar, href: focusEvent, occurrence: focusOccurrence }
    : null
  const taskId = typeof q.task === 'string' ? Number(q.task) : 0
  if (taskId) selectedId.value = taskId
  if (typeof q.q === 'string') {
    query.value = q.q
    searchInput.value = q.q
    searchOpen.value = Boolean(q.q)
  }
}

onMounted(async () => {
  try {
    const stored = localStorage.getItem('caldav-task-theme')
    if (stored === 'dark' || stored === 'light') theme.value = stored
    else theme.value = window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
    document.documentElement.dataset.theme = theme.value
    const collapsedRaw = localStorage.getItem('caldav-task-collapsed')
    if (collapsedRaw) collapsed.value = new Set(JSON.parse(collapsedRaw) as string[])
    manualSort.value = localStorage.getItem('caldav-task-sort') === 'manual'
    if (localStorage.getItem('caldav-task-reminders') === 'on' && notificationSupported() && Notification.permission === 'granted') {
      remindersEnabled.value = true
    }
  } catch {
    /* ignore */
  }
  hydrateFromRoute()
  syncURL()
  if (remindersEnabled.value) {
    await checkReminders()
    startReminderTimer()
  }
  await loadWorkspace()
  void refreshNotifications()
  startNotificationStream()
  notificationTimer = setInterval(() => {
    void refreshNotifications()
    if (view.value === 'shared') void refreshSharedView()
  }, 60000)
  document.addEventListener('visibilitychange', onVisibilityChange)
  initialized = true
  window.addEventListener('keydown', onKeydown)
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeydown)
  if (searchTimer) clearTimeout(searchTimer)
  if (refreshTimer) clearTimeout(refreshTimer)
  if (notificationTimer) clearInterval(notificationTimer)
  notificationSource?.close()
  notificationSource = null
  document.removeEventListener('visibilitychange', onVisibilityChange)
  stopReminderTimer()
  delete document.documentElement.dataset.theme
})

watch([view, activeListId, activeFilterId, query], () => {
  if (!initialized) return
  void loadWorkspace()
})

watch(() => route.fullPath, () => {
  if (!String(route.name || '').startsWith('tasks')) return
  hydrateFromRoute()
})

watch(selectedId, () => {
  if (initialized) syncURL()
})

watch(searchInput, (value) => {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(() => {
    query.value = value.trim()
    syncURL()
  }, 250)
})
</script>
