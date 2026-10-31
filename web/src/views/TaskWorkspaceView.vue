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
        <button class="tw-rail-button" :class="{ active: view === 'focus' }" title="专注" @click="selectView('focus')">
          <TaskIcon name="clock" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: view === 'habit' }" title="习惯" @click="selectView('habit')">
          <TaskIcon name="habit" :size="20" />
        </button>
        <button class="tw-rail-button" :class="{ active: view === 'countdown' }" title="倒数纪念日" @click="selectView('countdown')">
          <TaskIcon name="countdown" :size="21" />
        </button>
        <button class="tw-rail-button" :class="{ active: view === 'notes' }" title="笔记" @click="selectView('notes')">
          <TaskIcon name="note" :size="20" />
        </button>
        <button class="tw-rail-button" :class="{ active: view === 'summary' }" title="摘要" @click="selectView('summary')">
          <TaskIcon name="summary" :size="20" />
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
        <button class="tw-rail-button tw-rail-notice" title="通知" @click="notificationDialogOpen = true">
          <TaskIcon name="notice" :size="20" />
          <span v-if="unreadNotifications" class="tw-rail-badge">{{ unreadNotifications > 99 ? '99+' : unreadNotifications }}</span>
        </button>
        <button class="tw-rail-button" :title="`主题：${themeLabel}`" @click="themeDialogOpen = true">
          <TaskIcon name="palette" :size="20" />
        </button>
        <button class="tw-rail-button" :title="isDarkTheme(theme) ? '切换到浅色' : '切换到深色'" @click="toggleTheme">
          <TaskIcon :name="isDarkTheme(theme) ? 'sun' : 'moon'" :size="20" />
        </button>
        <router-link class="tw-rail-button" to="/dashboard" title="管理后台">
          <TaskIcon name="settings" :size="20" />
        </router-link>
        <div class="tw-rail-account">
          <button class="tw-rail-button" :title="auth.user?.displayName || auth.user?.username || '账户'" @click="accountMenuOpen = !accountMenuOpen">
            <TaskIcon name="user" :size="20" />
          </button>
          <template v-if="accountMenuOpen">
            <div class="tw-rail-account-scrim" @click="accountMenuOpen = false" />
            <div class="tw-rail-account-menu">
              <strong>{{ auth.user?.displayName || auth.user?.username || '账户' }}</strong>
              <small>{{ auth.user?.username }}</small>
              <button class="tw-rail-logout" @click="handleLogout">
                <TaskIcon name="logout" :size="15" />
                退出登录
              </button>
            </div>
          </template>
        </div>
      </div>
    </aside>

    <TaskSidebar
      v-if="view !== 'matrix' && view !== 'habit' && view !== 'focus' && view !== 'countdown' && view !== 'notes'"
      :lists="lists"
      :shared-lists="sharedLists"
      :shared-notes="sharedNotes"
      :folders="taskFolders"
      :filters="filters"
      :tag-counts="tagCounts"
      :counts="counts"
      :view="view"
      :active-list-id="activeListId"
      :active-filter-id="activeFilterId"
      :active-shared-list-id="activeSharedListId"
      :active-shared-note-id="sharedNote?.task.id || 0"
      :unread-notifications="unreadNotifications"
      :active-tag="activeTag"
      :open="sidebarOpen"
      @select-view="selectView"
      @select-list="selectList"
      @select-filter="selectFilter"
      @select-shared="selectSharedList"
      @select-shared-note="selectSharedNote"
      @share-list="openShareList"
      @create-list="createList"
      @create-note="createNote"
      @edit-list="openEditList"
      @delete-list="confirmDeleteList"
      @pin-list="toggleListPin"
      @copy-list="openCopyList"
      @edit-folder="openEditFolder"
      @delete-folder="confirmDeleteFolder"
      @create-filter="openCreateFilter"
      @edit-filter="openEditFilter"
      @delete-filter="confirmDeleteFilter"
      @pin-filter="toggleFilterPin"
      @reorder-filters="reorderSidebarFilters"
      @reorder-lists="reorderSidebarLists"
      @reorder-folders="reorderSidebarFolders"
      @select-tag="selectTag"
      @manage-tags="openTagManager"
      @open-notifications="notificationDialogOpen = true"
      @close="sidebarOpen = false"
      @logout="handleLogout"
    />

    <div v-if="sidebarOpen" class="tw-scrim" @click="sidebarOpen = false" />

    <main class="tw-main">
      <header v-if="view !== 'habit' && view !== 'focus' && view !== 'countdown' && view !== 'notes'" class="tw-toolbar">
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
          <div v-if="view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared' && !noteView" class="tw-mode-switch" role="group" aria-label="视图模式">
            <button :class="{ active: mode === 'list' && view !== 'matrix' }" title="清单" @click="switchMode('list')">
              <TaskIcon name="list" :size="16" />
            </button>
            <button :class="{ active: mode === 'board' && view !== 'matrix' }" title="看板" @click="switchMode('board')">
              <TaskIcon name="board" :size="16" />
            </button>
            <button :class="{ active: mode === 'calendar' && view !== 'matrix' }" title="日历" @click="switchMode('calendar')">
              <TaskIcon name="calendar" :size="16" />
            </button>
            <button :class="{ active: mode === 'timeline' && view !== 'matrix' }" title="时间线" @click="switchMode('timeline')">
              <TaskIcon name="timeline" :size="16" />
            </button>
            <button :class="{ active: view === 'matrix' }" title="矩阵" @click="selectView('matrix')">
              <TaskIcon name="matrix" :size="16" />
            </button>
          </div>
          <button
            v-if="view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared' && view !== 'matrix' && !noteView && mode !== 'calendar'"
            class="tw-icon-button"
            :class="{ active: splitView }"
            :title="splitView ? '关闭日历并列显示' : '任务与日历并列显示'"
            @click="toggleSplitView"
          >
            <TaskIcon name="calendar" :size="18" />
          </button>
          <button
            v-if="view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared' && view !== 'matrix' && view !== 'completed' && mode === 'list'"
            class="tw-icon-button"
            :class="{ active: manualSort }"
            :title="manualSort ? '关闭手动排序' : '手动排序（拖拽调整顺序）'"
            @click="toggleManualSort"
          >
            <TaskIcon name="sort" :size="18" />
          </button>
          <button
            v-if="view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared' && view !== 'matrix' && mode === 'list'"
            class="tw-icon-button"
            :class="{ active: selectionMode }"
            :title="selectionMode ? '退出多选' : '多选任务'"
            @click="toggleSelection"
          >
            <TaskIcon name="select" :size="18" />
          </button>
          <button v-if="view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared' && view !== 'matrix'" class="tw-icon-button" title="搜索" @click="toggleSearch">
            <TaskIcon name="search" :size="18" />
          </button>
        </div>
      </header>

      <div v-if="searchOpen && view !== 'stats' && view !== 'summary' && view !== 'ai' && view !== 'shared' && view !== 'matrix' && view !== 'habit' && view !== 'focus' && view !== 'countdown' && view !== 'notes'" class="tw-search-bar">
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
      <NotesPanel
        v-else-if="view === 'notes'"
        :notes="noteTasks"
        :lists="lists"
        :folders="noteFolders"
        :shared-notes="sharedNotes"
        :shared-lists="sharedLists"
        :active-shared-list-id="activeSharedListId"
        :own-notes-count="notesTotal"
        :readonly="sharedReadonly"
        :tag-colors="tagColorMap"
        :selected-id="selectedId"
        @open="openTask"
        @pin="toggleTaskPin"
        @remove="confirmRemoveTask"
        @open-shared="selectSharedNote"
        @select-shared-list="selectSharedNoteList"
        @reload="loadWorkspace(true)"
      />
      <TaskMatrixPanel
        v-else-if="view === 'matrix'"
        :tasks="matrixTasks"
        :rule="matrixRule"
        :views="matrixViews"
        :active-view-id="activeMatrixViewId"
        :custom-rules="matrixCustomRules"
        :lists="lists"
        :tags="tags"
        :assignees="matrixAssignees"
        @open="openTask"
        @toggle="toggleTask"
        @move="moveTaskToQuadrant"
        @move-custom="moveTaskToCustomQuadrant"
        @select-view="selectMatrixView"
        @create-view="openMatrixViewDialog"
        @manage-views="matrixViewManagerOpen = true"
        @edit-rules="openMatrixRules"
        @quick-add="quickAddMatrixTask"
      />
      <div v-else class="tw-main-body" :class="{ 'is-split': splitView && mode !== 'calendar' }">
      <div class="tw-scroll" :class="{ 'tw-scroll-calendar': mode === 'calendar', 'tw-scroll-timeline': mode === 'timeline' }">
        <div
          class="tw-content"
          :class="{
            'tw-content-calendar': mode === 'calendar',
            'tw-content-board': mode === 'board' && !['trash', 'stats', 'summary', 'ai'].includes(view),
            'tw-content-timeline': mode === 'timeline',
            'tw-content-fill': view === 'summary' || view === 'ai',
          }"
        >
          <div v-if="mode !== 'calendar' && mode !== 'timeline' && view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && (view !== 'shared' || sharedEditable)" class="tw-quick-add">
            <TaskIcon name="plus" :size="18" />
            <input
              ref="quickInputEl"
              v-model="quickText"
              class="tw-quick-input"
              :placeholder="`${noteView ? '添加笔记至' : '添加任务至'}“${quickTargetName}”`"
              maxlength="500"
              @keydown.enter="onQuickEnter"
            />
            <button v-if="!noteView" class="tw-icon-button tw-quick-template" title="从模板创建任务" @click="openTaskTemplates"><TaskIcon name="copy" :size="16" /></button>
            <button v-if="quickText.trim()" class="tw-quick-submit" :disabled="quickBusy" @click="submitQuick">
              <TaskIcon name="check" :size="16" />
            </button>
          </div>

          <div v-if="hint && !noteView && mode !== 'calendar' && mode !== 'timeline' && view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai' && (view !== 'shared' || sharedEditable)" class="tw-quick-hint">
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
            <div v-if="noteView" class="tw-note-grid">
              <NoteCard
                v-for="task in noteTasks"
                :key="task.id"
                :task="task"
                :selected="selectedId === task.id"
                :readonly="sharedReadonly"
                :tag-colors="tagColorMap"
                @open="openTask"
                @pin="toggleTaskPin"
                @remove="confirmRemoveTask"
              />
              <div v-if="!noteTasks.length" class="tw-empty tw-note-empty">
                <div class="tw-empty-art">
                  <svg viewBox="0 0 96 96" width="96" height="96" aria-hidden="true">
                    <rect x="20" y="14" width="56" height="68" rx="12" fill="none" stroke="currentColor" stroke-width="2" />
                    <path d="M32 34h32M32 46h26M32 58h20" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
                  </svg>
                </div>
                <h2>没有笔记</h2>
                <p>在这里记录灵感与时光。</p>
                <button class="tw-primary-button" @click="focusQuick">写第一条笔记</button>
              </div>
            </div>
            <template v-else>
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
                  @pin="toggleTaskPin"
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
          </template>

          <TaskTimeline
            v-else-if="mode === 'timeline'"
            :tasks="timelineTasks"
            :lists="lists.filter((list) => list.kind !== 'NOTE')"
            :zoom="timelineZoom"
            :color-by="timelineColor"
            :tag-colors="tagColorMap"
            @open="openTask"
            @create="createFromTimeline"
            @reschedule="rescheduleTask"
            @change-zoom="setTimelineZoom"
            @change-color="setTimelineColor"
          />

          <TaskCalendar
            v-else-if="mode === 'calendar'"
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
            @occurrence-changed="onOccurrenceChanged"
            @create="createFromCalendar"
            @change-view="calendarView = $event"
            @prev="stepCalendar(-1)"
            @next="stepCalendar(1)"
            @today="cursor = new Date()"
          />

          <template v-else>
            <div class="tw-board" :class="{ 'tw-board-sections': singleListBoard }">
              <section
                v-for="column in boardColumns"
                :key="column.key"
                class="tw-board-column"
                :draggable="singleListBoard && column.sectionId > 0"
                @dragstart="startSectionDrag(column, $event)"
                @dragend="sectionDragId = 0"
                @dragover.prevent
                @drop="onColumnDrop(column)"
              >
                <header class="tw-board-head" @dragover.prevent @drop.stop.prevent="dropSection(column)">
                  <span class="tw-list-dot" :style="{ background: column.color }" />
                  <template v-if="sectionRenameId === column.sectionId && column.sectionId > 0">
                    <input
                      ref="sectionRenameInput"
                      v-model="sectionRenameName"
                      class="tw-board-rename"
                      maxlength="40"
                      @click.stop
                      @keydown.enter.prevent="saveSectionRename"
                      @keydown.esc.prevent="sectionRenameId = 0"
                      @blur="saveSectionRename"
                    />
                  </template>
                  <strong v-else>{{ column.name }}</strong>
                  <span class="tw-board-count">{{ column.tasks.length }}</span>
                  <button class="tw-icon-button" title="在此分组添加任务" @click="addToColumn(column)">
                    <TaskIcon name="plus" :size="15" />
                  </button>
                  <div v-if="singleListBoard" class="tw-board-col-action">
                    <button class="tw-icon-button" title="分组菜单" @click.stop="toggleSectionMenu(column.sectionId)">
                      <TaskIcon name="more" :size="15" />
                    </button>
                    <div v-if="sectionMenuId === column.sectionId" class="tw-board-col-menu" @click.stop>
                      <button v-if="column.sectionId > 0" @click="startSectionRename(column)">重命名</button>
                      <button @click="addSectionNear(column, 'left')">在左侧添加分组</button>
                      <button @click="addSectionNear(column, 'right')">在右侧添加分组</button>
                      <button v-if="column.sectionId > 0" class="danger" @click="openDeleteSection(column)">删除</button>
                    </div>
                  </div>
                </header>
                <div class="tw-board-body" @dragover.prevent @drop="onColumnDrop(column)">
                  <article
                    v-for="task in column.tasks"
                    :key="task.id"
                    class="tw-board-card"
                    :class="{ done: task.completed }"
                    draggable="true"
                    @dragstart="startTaskDrag(task, $event)"
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
                  <p v-if="!column.tasks.length" class="tw-board-empty">
                    {{ singleListBoard ? '拖动任务到这个分组，或点击 + 新建' : '拖动任务到这里，或点击 + 新建' }}
                  </p>
                </div>
              </section>
              <button v-if="singleListBoard" class="tw-board-add-col" @click="addSection(null)">
                <TaskIcon name="plus" :size="15" />
                新分组
              </button>
            </div>
          </template>
        </div>
      </div>
      <aside
        v-if="splitView && mode !== 'calendar' && !noteView && !selectedTask && view !== 'trash' && view !== 'stats' && view !== 'summary' && view !== 'ai'"
        class="tw-split-calendar"
        :style="{ width: `${splitWidth}px` }"
      >
        <div class="tw-split-resizer" title="拖动调整宽度" @pointerdown="startSplitResize"></div>
        <TaskCalendar
          :cursor="splitCursor"
          :view-mode="splitViewMode"
          :reload-key="calendarReload"
          @open="openTask"
          @open-event="openCalendarEvent"
          @open-habit="openHabitFromCalendar"
          @calendars="calendarSources = $event"
          @reschedule-task="rescheduleTask"
          @reschedule-event="rescheduleEvent"
          @occurrence-changed="onOccurrenceChanged"
          @create="createFromCalendar"
          @change-view="splitViewMode = $event"
          @prev="stepSplitCalendar(-1)"
          @next="stepSplitCalendar(1)"
          @today="splitCursor = new Date()"
        />
      </aside>
      </div>
    </main>

    <NoteDetail
      v-if="selectedTask && selectedTask.kind === 'NOTE'"
      :key="selectedTask.id"
      :task="selectedTask"
      :lists="detailLists"
      :readonly="sharedNote ? sharedNote.role === 'viewer' : sharedReadonly"
      :shareable="!sharedNote"
      :move-locked="!!sharedNote"
      :tag-colors="tagColorMap"
      @close="closeTaskDetail"
      @changed="onTaskChanged"
      @pin="toggleTaskPin"
      @remove="confirmRemoveTask"
      @share="openNoteShare"
    />

    <TaskDetail
      v-else-if="selectedTask"
      :task="selectedTask"
      :lists="detailLists"
      :members="taskMembers"
      :tag-colors="tagColorMap"
      :subtasks="selectedSubtasks"
      :readonly="sharedReadonly"
      :list-locked="view === 'shared'"
      @close="selectedId = 0"
      @changed="onTaskChanged"
      @deleted="onTaskDeleted"
      @remove="confirmRemoveTask"
      @save-template="saveTaskAsTemplate"
      @create-subtask="createSubtask"
      @toggle-subtask="toggleSubtask"
      @open-subtask="openSubtask"
      @remove-subtask="confirmRemoveTask"
    />

    <TaskTemplateDialog
      :open="taskTemplatesOpen"
      :templates="taskTemplates"
      :busy="taskTemplateBusy"
      @close="taskTemplatesOpen = false"
      @apply="applyTaskTemplate"
      @delete="removeTaskTemplate"
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
            v-for="list in moveTargetLists"
            :key="list.id"
            class="tw-move-option"
            :class="{ active: moveTargetId === list.id }"
            @click="moveTargetId = list.id"
          >
            <span class="tw-list-dot" :style="{ background: list.color || '#4772fa' }" />
            <span>{{ list.name }}</span>
            <TaskIcon v-if="moveTargetId === list.id" name="check" :size="14" />
          </button>
          <p v-if="!moveTargetLists.length" class="tw-dialog-hint">任务和笔记不能混合移动。</p>
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
          <h2>编辑文件夹</h2>
          <button class="tw-icon-button" title="关闭" @click="folderVisible = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body">
          <div class="tw-modal-label">
            名称
            <a-input
              v-model="folderForm.name"
              class="tw-dialog-input"
              :max-length="40"
              placeholder="例如：工作项目"
              @keydown.enter="saveFolder"
            />
          </div>
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
          <div class="tw-modal-label">
            名称
            <a-input v-model="filterForm.name" class="tw-dialog-input" :max-length="60" placeholder="例如：本周高优工作" />
          </div>
          <div class="tw-filter-grid">
            <div class="tw-modal-label">
              关键词
              <a-input v-model="filterForm.conditions.keyword" class="tw-dialog-input" :max-length="100" placeholder="标题或备注" />
            </div>
            <div class="tw-modal-label">
              状态
              <a-select v-model="filterForm.conditions.status" class="tw-field-select">
                <a-option value="open">未完成</a-option>
                <a-option value="completed">已完成</a-option>
                <a-option value="all">全部</a-option>
              </a-select>
            </div>
            <div class="tw-modal-label">
              日期
              <a-select v-model="filterForm.conditions.date" class="tw-field-select">
                <a-option value="any">不限</a-option>
                <a-option value="today">今天</a-option>
                <a-option value="tomorrow">明天</a-option>
                <a-option value="next7">最近 7 天</a-option>
                <a-option value="overdue">已逾期</a-option>
                <a-option value="none">无日期</a-option>
                <a-option value="yesterday">昨天</a-option>
                <a-option value="thisWeek">本周</a-option>
                <a-option value="lastWeek">上周</a-option>
                <a-option value="thisMonth">本月</a-option>
                <a-option value="lastMonth">上月</a-option>
                <a-option value="range">时间段</a-option>
              </a-select>
            </div>
            <div v-if="filterForm.conditions.date === 'range'" class="tw-modal-label tw-modal-span">
              时间段
              <span class="tw-range-row">
                <a-date-picker
                  v-model="filterForm.conditions.dateFrom"
                  class="tw-date-control"
                  value-format="YYYY-MM-DD"
                  placeholder="开始日期"
                  allow-clear
                />
                <span class="tw-range-sep">至</span>
                <a-date-picker
                  v-model="filterForm.conditions.dateTo"
                  class="tw-date-control"
                  value-format="YYYY-MM-DD"
                  placeholder="结束日期"
                  allow-clear
                />
              </span>
            </div>
            <div class="tw-modal-label">
              标签匹配
              <a-select v-model="filterForm.conditions.tagMode" class="tw-field-select">
                <a-option value="any">任一标签</a-option>
                <a-option value="all">全部标签</a-option>
              </a-select>
            </div>
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
              <a-input
                v-model="editingTagName"
                class="tw-dialog-input"
                :max-length="30"
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
          <div class="tw-modal-label">
            名称
            <a-input
              ref="editNameInput"
              v-model="editForm.name"
              class="tw-dialog-input"
              :max-length="40"
              placeholder="清单名称"
              @keydown.enter="saveList"
            />
          </div>
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
          <div class="tw-modal-label">
            文件夹
            <a-select v-model.number="editForm.folderId" class="tw-field-select">
              <a-option :value="0">根目录</a-option>
              <a-option v-for="folder in editFolderOptions" :key="folder.id" :value="folder.id">{{ folder.name }}</a-option>
            </a-select>
          </div>
          <p class="tw-modal-note">
            {{ editingList?.kind === 'NOTE' ? '删除笔记清单会把其中的笔记移动到其他笔记清单。' : '删除清单会把其中的任务移动到收集箱。' }}
          </p>
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
      :default-mode="matrixDefaultRule"
      @change-default-mode="setDefaultMatrixRule"
      @changed="onMatrixViewsChanged"
      @edit-rules="openMatrixRulesFor"
      @close="matrixViewManagerOpen = false"
    />

    <div v-if="matrixViewDialogOpen" class="tw-dialog-scrim" @click.self="matrixViewDialogOpen = false">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true" aria-label="新建矩阵视图" @keydown.esc="matrixViewDialogOpen = false">
        <header class="tw-dialog-head">
          <h2>新建矩阵视图</h2>
          <button class="tw-icon-button" title="关闭" @click="matrixViewDialogOpen = false">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body">
          <div class="tw-modal-label">
            视图名称
            <a-input v-model="matrixViewName" class="tw-dialog-input" :max-length="60" @keydown.enter="saveMatrixView" />
          </div>
          <div class="tw-field">
            <span>规则</span>
            <a-select v-model="matrixViewMode" class="tw-field-select">
              <a-option value="simple">按优先级</a-option>
              <a-option value="complex">优先级 + 日期</a-option>
              <a-option value="custom">自定义规则</a-option>
            </a-select>
          </div>
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
      @task-completed="onNotificationTaskCompleted"
      @close="notificationDialogOpen = false"
    />

    <TaskListShareDialog
      v-if="shareDialogOpen && sharingList"
      :list="sharingList"
      @changed="onSharesChanged"
      @close="shareDialogOpen = false"
    />

    <NoteShareDialog
      v-if="noteShareTarget"
      :task="noteShareTarget"
      @close="noteShareTarget = null"
    />

    <CalendarEventDialog
      v-if="eventDialogOpen"
      :event="editingEvent"
      :calendars="calendarSources"
      :default-date="cursor"
      @saved="onEventSaved"
      @close="eventDialogOpen = false"
    />

    <div v-if="sectionDeleteTarget" class="tw-dialog-scrim" @click.self="sectionDeleteTarget = null">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true" aria-label="删除分组">
        <header class="tw-dialog-head">
          <h2>删除分组</h2>
          <button class="tw-icon-button" title="关闭" @click="sectionDeleteTarget = null">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body tw-section-delete">
          <p class="tw-dialog-hint">「{{ sectionDeleteTarget.name }}」中的任务如何处理？</p>
          <a-radio-group v-model="sectionDeleteStrategy" direction="vertical" class="tw-choice-group">
            <a-radio value="move">移动任务到</a-radio>
            <a-radio value="delete">删除分组和其中的任务</a-radio>
          </a-radio-group>
          <a-select v-if="sectionDeleteStrategy === 'move'" v-model.number="sectionDeleteMoveTo" class="tw-field-select">
            <a-option :value="0">未分组</a-option>
            <a-option
              v-for="section in activeSections.filter((item) => item.id !== sectionDeleteTarget?.sectionId)"
              :key="section.id"
              :value="section.id"
            >
              {{ section.name }}
            </a-option>
          </a-select>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="sectionDeleteTarget = null">取消</button>
          <button class="tw-dialog-ok tw-danger-button" @click="confirmDeleteSection">删除</button>
        </footer>
      </div>
    </div>

    <div v-if="copyListTarget" class="tw-dialog-scrim" @click.self="copyListTarget = null">
      <div class="tw-dialog tw-dialog-sm" role="dialog" aria-modal="true" aria-label="复制清单">
        <header class="tw-dialog-head">
          <h2>复制清单</h2>
          <button class="tw-icon-button" title="关闭" @click="copyListTarget = null">
            <TaskIcon name="close" :size="16" />
          </button>
        </header>
        <div class="tw-dialog-body tw-copy-list">
          <div class="tw-modal-label">
            名称
            <a-input v-model="copyListName" class="tw-dialog-input" :max-length="40" />
          </div>
          <p class="tw-dialog-hint">请选择复制范围</p>
          <a-radio-group v-model="copyListMode" direction="vertical" class="tw-choice-group">
            <a-radio value="open">只复制未完成任务</a-radio>
            <a-radio value="keep">复制全部任务，保留已完成状态</a-radio>
            <a-radio value="all">复制全部任务，不保留已完成状态</a-radio>
          </a-radio-group>
        </div>
        <footer class="tw-dialog-foot">
          <button class="tw-dialog-cancel" @click="copyListTarget = null">取消</button>
          <button class="tw-dialog-ok" :disabled="copyBusy" @click="confirmCopyList">
            {{ copyBusy ? '复制中…' : '确认' }}
          </button>
        </footer>
      </div>
    </div>

    <ThemePicker
      v-if="themeDialogOpen"
      :model-value="theme"
      @select="applyTheme"
      @close="themeDialogOpen = false"
    />

    <ShortcutHelp
      v-if="shortcutHelpOpen"
      :bindings="shortcutBindings"
      :is-mac="isMac"
      @save="onShortcutSave"
      @close="shortcutHelpOpen = false"
    />

    <CommandPalette
      v-if="commandOpen"
      :commands="paletteCommands"
      :hint="isMac ? '⌘ K' : 'Ctrl K'"
      @run="runPalette"
      @close="commandOpen = false"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Message } from '@arco-design/web-vue'
import { auth, logout } from '../auth'
import type { CalendarEvent, CalendarSource, MatrixQuadrantKey, MatrixRuleMode, MatrixView, SavedFilter, SharedNote, SharedTaskList, TaskCounts, TaskFilterConditions, TaskFolder, TaskItem, TaskList, TaskListMember, TaskSection, TaskTagCount, TaskTemplate, TaskWorkspaceData } from '../types'
import {
  batchTasks,
  copyTaskList,
  createSavedFilter,
  createTask,
  createTaskSection,
  deleteTaskSection,
  updateTaskSection,
  createMatrixView,
  createTaskList,
  createTaskTemplate,
  deleteSavedFilter,
  deleteTask,
  deleteTaskFolder,
  deleteTaskList,
  deleteTaskTag,
  deleteTaskTemplate,
  emptyTaskTrash,
  fetchCalendarEvents,
  fetchNotifications,
  fetchSharedTasks,
  fetchTaskListMembers,
  fetchTaskReminders,
  fetchTaskTemplates,
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
import TaskTemplateDialog from '../components/tasks/TaskTemplateDialog.vue'
import TaskCalendar from '../components/tasks/TaskCalendar.vue'
import TaskTimeline from '../components/tasks/TaskTimeline.vue'
import NoteCard from '../components/tasks/NoteCard.vue'
import NoteDetail from '../components/tasks/NoteDetail.vue'
import NoteShareDialog from '../components/tasks/NoteShareDialog.vue'
import TaskMatrixPanel from '../components/tasks/TaskMatrixPanel.vue'
import HabitPanel from '../components/tasks/HabitPanel.vue'
import FocusPanel from '../components/tasks/FocusPanel.vue'
import FocusStatsPanel from '../components/tasks/FocusStatsPanel.vue'
import CountdownPanel from '../components/tasks/CountdownPanel.vue'
import NotesPanel from '../components/tasks/NotesPanel.vue'
import HabitTodayStrip from '../components/tasks/HabitTodayStrip.vue'
import MatrixViewManagerDialog from '../components/tasks/MatrixViewManagerDialog.vue'
import MatrixRulesDialog from '../components/tasks/MatrixRulesDialog.vue'
import TaskStatsPanel from '../components/tasks/TaskStatsPanel.vue'
import TaskSummaryPanel from '../components/tasks/TaskSummaryPanel.vue'
import TaskAIPanel from '../components/tasks/TaskAIPanel.vue'
import CalendarEventDialog from '../components/tasks/CalendarEventDialog.vue'
import NotificationDialog from '../components/tasks/NotificationDialog.vue'
import TaskListShareDialog from '../components/tasks/TaskListShareDialog.vue'
import ThemePicker from '../components/tasks/ThemePicker.vue'
import ShortcutHelp from '../components/tasks/ShortcutHelp.vue'
import CommandPalette, { type PaletteCommand } from '../components/tasks/CommandPalette.vue'
import {
  comboLabel,
  findAction,
  isMacPlatform,
  isPrefix,
  keyEventToCombo,
  loadBindings,
  saveBindings,
  type ShortcutBindings,
} from '../shortcuts'
import { TASK_THEMES, isDarkTheme, themeById } from '../themes'
import TaskIcon from '../components/tasks/TaskIcon.vue'

type Mode = 'list' | 'board' | 'calendar' | 'timeline'

const route = useRoute()
const router = useRouter()

const lists = ref<TaskList[]>([])
const sharedLists = ref<SharedTaskList[]>([])
const sharedNotes = ref<SharedNote[]>([])
const sharedNote = ref<SharedNote | null>(null)
const noteShareTarget = ref<TaskItem | null>(null)
const folders = ref<TaskFolder[]>([])
const taskFolders = computed(() => folders.value.filter((folder) => folder.kind !== 'NOTE'))
const noteFolders = computed(() => folders.value.filter((folder) => folder.kind === 'NOTE'))
const sections = ref<TaskSection[]>([])
const filters = ref<SavedFilter[]>([])
const tasks = ref<TaskItem[]>([])
const notesTotal = ref(0)
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
const taskTemplatesOpen = ref(false)
const taskTemplates = ref<TaskTemplate[]>([])
const taskTemplateBusy = ref(false)
const quickListId = ref(0)
const cursor = ref(new Date())
const calendarView = ref<'month' | 'week' | '2week' | '3day' | 'day' | 'agenda' | 'year'>('month')
const timelineZoom = ref<'day' | 'week' | 'month'>('week')
const timelineColor = ref<'list' | 'tag' | 'priority' | 'none'>('list')
const splitView = ref(false)
const splitWidth = ref(440)
const splitViewMode = ref<'month' | 'week' | '2week' | '3day' | 'day' | 'agenda' | 'year'>('3day')
const splitCursor = ref(new Date())
const calendarSources = ref<CalendarSource[]>([])
const calendarReload = ref(0)
const eventDialogOpen = ref(false)
const editingEvent = ref<CalendarEvent | null>(null)
const calendarFocus = ref<{ calendarId: number; href: string; occurrence: string } | null>(null)
const matrixDefaultRule = ref<MatrixRuleMode>('simple')
const matrixRule = ref<MatrixRuleMode>('simple')
const matrixViews = ref<MatrixView[]>([])
const activeMatrixViewId = ref(0)
const matrixViewDialogOpen = ref(false)
const matrixViewName = ref('')
const matrixViewMode = ref<MatrixRuleMode>('simple')
const matrixViewManagerOpen = ref(false)
const matrixRulesDialogOpen = ref(false)
try {
  const savedRule = localStorage.getItem('caldav-matrix-rule')
  if (savedRule === 'simple' || savedRule === 'complex' || savedRule === 'custom') {
    matrixDefaultRule.value = savedRule
    matrixRule.value = savedRule
  }
} catch {
  /* ignore */
}
const matrixViewBusy = ref(false)
const theme = ref<string>('default')
const themeDialogOpen = ref(false)
const shortcutHelpOpen = ref(false)
const commandOpen = ref(false)
const shortcutBindings = ref<ShortcutBindings>(loadBindings())
const isMac = isMacPlatform()
let sequenceBuffer = ''
let sequenceTimer: ReturnType<typeof setTimeout> | undefined
const collapsed = ref(new Set<string>())
const dragId = ref(0)
const quickSectionId = ref(0)
const sectionMenuId = ref(-1)
const sectionRenameId = ref(0)
const sectionRenameName = ref('')
const sectionDragId = ref(0)
const sectionDeleteTarget = ref<BoardColumn | null>(null)
const sectionDeleteStrategy = ref<'move' | 'delete'>('move')
const sectionDeleteMoveTo = ref(0)
const copyListTarget = ref<TaskList | null>(null)
const copyListName = ref('')
const copyListMode = ref<'open' | 'all' | 'keep'>('open')
const copyBusy = ref(false)
const manualSort = ref(false)
const selectionMode = ref(false)
const selectedIds = ref(new Set<number>())
const dragTaskId = ref(0)
const dragOverId = ref(0)
const moveDialogOpen = ref(false)
const moveTargetId = ref(0)
const batchBusy = ref(false)
const remindersEnabled = ref(false)
const accountMenuOpen = ref(false)
const notificationDialogOpen = ref(false)
const unreadNotifications = ref(0)
const reminderTasks = ref<TaskItem[]>([])
const NOTIFY_KEY = 'caldav-task-notified'
let reminderTimer: ReturnType<typeof setInterval> | undefined
let notificationTimer: ReturnType<typeof setInterval> | undefined
let notificationSource: EventSource | null = null
let taskStreamSource: EventSource | null = null

const quickInputEl = ref<HTMLInputElement | null>(null)
const sectionRenameInput = ref<HTMLInputElement | HTMLInputElement[] | null>(null)
const searchInputEl = ref<HTMLInputElement | null>(null)
const editNameInput = ref<{ focus?: () => void } | null>(null)

const editVisible = ref(false)
const editBusy = ref(false)
const editForm = reactive({ id: 0, name: '', color: LIST_COLORS[0], folderId: 0 })
const editingList = computed(() => lists.value.find((list) => list.id === editForm.id))
const editFolderOptions = computed(() =>
  folders.value.filter((folder) => (folder.kind === 'NOTE') === (editingList.value?.kind === 'NOTE')),
)
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
const activeList = computed(() => lists.value.find((item) => item.id === activeListId.value))
const activeSharedList = computed(() => sharedLists.value.find((item) => item.listId === activeSharedListId.value))
const notesSharedList = computed(() => (view.value === 'notes' && activeSharedListId.value ? activeSharedList.value : undefined))
const sharedNoteView = computed(() => view.value === 'shared' && activeSharedList.value?.kind === 'NOTE')
const noteView = computed(() => (view.value === 'list' && activeList.value?.kind === 'NOTE') || sharedNoteView.value)
const noteTargetListId = computed(() => (sharedNoteView.value ? activeSharedList.value?.listId || 0 : activeListId.value))
const noteTasks = computed(() =>
  tasks.value
    .filter((task) => task.kind === 'NOTE')
    .filter((task) => !activeTag.value || (task.tags || []).includes(activeTag.value))
    .slice()
    .sort((a, b) => Number(b.pinned) - Number(a.pinned)),
)
const timelineTasks = computed(() => tasks.value.filter((task) => task.kind !== 'NOTE'))

const sharedEditable = computed(() => view.value === 'shared' && activeSharedList.value?.role === 'editor')
const sharedReadonly = computed(() => {
  const shared = notesSharedList.value || (view.value === 'shared' ? activeSharedList.value : undefined)
  return !!shared && shared.role !== 'editor'
})
const heading = computed(() => {
  if (view.value === 'matrix') return '矩阵'
  if (view.value === 'habit') return '习惯'
  if (view.value === 'focus') return '专注'
  if (view.value === 'countdown') return '倒数纪念日'
  if (view.value === 'notes') return '笔记'
  if (sharedNote.value) return sharedNote.value.task.title || '共享笔记'
  if (view.value === 'shared') return activeSharedList.value?.name || '共享清单'
  if (view.value === 'list') {
    const list = lists.value.find((item) => item.id === activeListId.value)
    return list?.name || '清单'
  }
  if (view.value === 'filter') return activeFilter.value?.name || '过滤器'
  return smartLabels[view.value] || '任务'
})

const headingIcon = computed(() => {
  if (sharedNote.value || sharedNoteView.value) return 'note'
  if (view.value === 'list') return activeList.value?.kind === 'NOTE' ? 'note' : 'inbox'
  if (view.value === 'today') return 'today'
  if (view.value === 'next7') return 'next7'
  if (view.value === 'inbox') return 'inbox'
  if (view.value === 'completed') return 'check'
  if (view.value === 'trash') return 'trash'
  if (view.value === 'habit') return 'habit'
  if (view.value === 'focus') return 'clock'
  if (view.value === 'matrix') return 'matrix'
  if (view.value === 'countdown') return 'countdown'
  if (view.value === 'notes') return 'note'
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
const selectedTask = computed(() => {
  if (sharedNote.value && sharedNote.value.task.id === selectedId.value) return sharedNote.value.task
  return tasks.value.find((task) => task.id === selectedId.value)
})
const selectedSubtasks = computed(() => selectedTask.value ? tasks.value.filter((task) => task.parentId === selectedTask.value?.id) : [])
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
  const shared = view.value === 'shared' ? activeSharedList.value : notesSharedList.value
  const extra: TaskList[] = []
  if (shared && !lists.value.some((list) => list.id === shared.listId)) {
    extra.push({
      id: shared.listId,
      folderId: 0,
      name: shared.name,
      color: shared.color,
      kind: shared.kind || 'TASK',
      order: 0,
      pinned: false,
      isInbox: false,
      count: shared.count,
    })
  }
  const note = sharedNote.value
  if (note && !lists.value.some((list) => list.id === note.task.listId) && !extra.some((list) => list.id === note.task.listId)) {
    extra.push({
      id: note.task.listId,
      folderId: 0,
      name: note.task.listName || '笔记',
      color: note.task.listColor || '#4772fa',
      kind: 'NOTE',
      order: 0,
      pinned: false,
      isInbox: false,
      count: 0,
    })
  }
  return extra.length ? [...lists.value, ...extra] : lists.value
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

const singleListBoard = computed(
  () => mode.value === 'board' && view.value === 'list' && activeListId.value > 0 && activeList.value?.kind !== 'NOTE',
)
const activeSections = computed(() =>
  sections.value
    .filter((section) => section.listId === activeListId.value)
    .sort((a, b) => a.order - b.order || a.id - b.id),
)

interface BoardColumn {
  key: string
  name: string
  color: string
  listId: number
  sectionId: number
  isSection: boolean
  tasks: TaskItem[]
}

const boardColumns = computed<BoardColumn[]>(() => {
  const base = (view.value === 'completed'
    ? filteredTasks.value.filter((task) => task.completed)
    : filteredTasks.value.filter((task) => !task.completed)
  ).filter((task) => task.kind !== 'NOTE')
  if (singleListBoard.value) {
    const list = activeList.value
    if (!list) return []
    const columns: BoardColumn[] = [
      {
        key: `section-0`,
        name: '未分组',
        color: list.color || '#4772fa',
        listId: list.id,
        sectionId: 0,
        isSection: true,
        tasks: base.filter((task) => task.listId === list.id && !task.sectionId),
      },
    ]
    for (const section of activeSections.value) {
      columns.push({
        key: `section-${section.id}`,
        name: section.name,
        color: list.color || '#4772fa',
        listId: list.id,
        sectionId: section.id,
        isSection: true,
        tasks: base.filter((task) => task.listId === list.id && task.sectionId === section.id),
      })
    }
    return columns
  }
  return lists.value
    .filter((list) => list.kind !== 'NOTE')
    .map((list) => ({
      key: `list-${list.id}`,
      name: list.name,
      color: list.color || '#4772fa',
      listId: list.id,
      sectionId: -1,
      isSection: false,
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
      // 笔记页由侧栏自行筛选清单，搜索也由笔记页本地完成，这里始终拉取全部笔记。
      listId: view.value === 'shared' || view.value === 'notes' ? undefined : activeListId.value || undefined,
      filterId: activeFilterId.value || undefined,
      q: view.value === 'notes' ? undefined : query.value || undefined,
      // 矩阵不展示已完成任务，直接让后端少查一批数据。
      includeCompleted: view.value === 'matrix' ? false : undefined,
    })
    lists.value = data.lists
    if (view.value === 'list' && lists.value.find((list) => list.id === activeListId.value)?.kind === 'NOTE') {
      mode.value = 'list'
    }
    sharedLists.value = data.sharedLists || []
    sharedNotes.value = data.sharedNotes || []
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
          matrixRule.value = matrixDefaultRule.value
        }
      } else {
        const active = matrixViews.value.find((view) => view.id === activeMatrixViewId.value)
        if (active) matrixRule.value = active.mode
      }
    }
    folders.value = data.folders
    sections.value = data.sections || []
    filters.value = data.filters
    tasks.value = data.tasks
    if (view.value === 'notes') notesTotal.value = data.tasks.length
    if (view.value === 'notes' && activeSharedListId.value) {
      try {
        const shared = await fetchSharedTasks(activeSharedListId.value)
        tasks.value = shared.tasks
        sharedLists.value = sharedLists.value.map((item) =>
          item.listId === shared.list.listId
            ? { ...item, role: shared.list.role, count: shared.list.count, name: shared.list.name, color: shared.list.color, kind: shared.list.kind || item.kind }
            : item,
        )
      } catch {
        activeSharedListId.value = 0
      }
    } else if (view.value === 'shared' && activeSharedListId.value) {
      const shared = await fetchSharedTasks(activeSharedListId.value)
      tasks.value = shared.tasks
      sharedLists.value = sharedLists.value.map((item) =>
        item.listId === shared.list.listId
          ? { ...item, role: shared.list.role, count: shared.list.count, name: shared.list.name, color: shared.list.color, kind: shared.list.kind || item.kind }
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
    const sharedMatch = sharedNotes.value.find((item) => item.task.id === selectedId.value)
    if (sharedMatch) sharedNote.value = sharedMatch
    if (selectedId.value && !sharedMatch && !tasks.value.some((task) => task.id === selectedId.value)) {
      selectedId.value = 0
      if (sharedNote.value && sharedNote.value.task.id !== selectedId.value) sharedNote.value = null
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
        ? { ...item, role: shared.list.role, count: shared.list.count, name: shared.list.name, color: shared.list.color, kind: shared.list.kind || item.kind }
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
  if (view.value === 'all' && mode.value === 'timeline') return '/tasks/timeline'
  if (view.value === 'habit' && route.params.habitId) return `/tasks/habit/${route.params.habitId}`
  if (view.value === 'focus' && route.name === 'tasks-focus-stats') return '/tasks/focus/stats'
  return view.value === 'all' ? '/tasks' : `/tasks/${view.value}`
}

function syncURL() {
  const path = taskRoutePath()
  const next: Record<string, string> = {}
  const dedicatedMode = view.value === 'all' && (mode.value === 'calendar' || mode.value === 'board' || mode.value === 'timeline')
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
  sharedNote.value = null
  view.value = nextView as TaskView
  activeListId.value = 0
  quickSectionId.value = 0
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
  sharedNote.value = null
  view.value = 'list'
  activeListId.value = id
  quickSectionId.value = 0
  const selected = lists.value.find((list) => list.id === id)
  if (selected?.kind === 'NOTE') {
    mode.value = 'list'
    try {
      localStorage.setItem('caldav-last-note-list', String(id))
    } catch {
      /* ignore */
    }
  }
  activeFilterId.value = 0
  activeTag.value = ''
  selectedId.value = 0
  sidebarOpen.value = false
  clearSelection()
  syncURL()
}

function selectFilter(id: number) {
  sharedNote.value = null
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
  sharedNote.value = null
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

function selectSharedNote(note: SharedNote) {
  sharedNote.value = note
  selectedId.value = note.task.id
  sidebarOpen.value = false
  clearSelection()
  syncURL()
}

function closeTaskDetail() {
  selectedId.value = 0
  sharedNote.value = null
}

function openNoteShare(task: TaskItem) {
  noteShareTarget.value = task
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
  sharedNote.value = null
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
  if (noteView.value) next = 'list'
  if (view.value === 'stats' || view.value === 'summary' || view.value === 'ai' || view.value === 'matrix' || view.value === 'habit' || view.value === 'focus' || view.value === 'countdown') resetWorkspaceToAll()
  clearSelection()
  mode.value = next
  if (next === 'calendar') {
    cursor.value = new Date()
  }
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

function selectSharedNoteList(listId: number) {
  activeSharedListId.value = listId
  activeListId.value = 0
  selectedId.value = 0
  sharedNote.value = null
  sidebarOpen.value = false
  clearSelection()
  void loadWorkspace(true)
}

function openTask(task: TaskItem) {
  sharedNote.value = null
  if (selectionMode.value) {
    toggleSelect(task)
    return
  }
  if (view.value === 'trash') return
  const shared = notesSharedList.value
  if (shared && task.listId === shared.listId) {
    sharedNote.value = {
      task,
      role: shared.role,
      ownerId: shared.ownerId,
      ownerUsername: shared.ownerUsername,
      ownerDisplay: shared.ownerDisplay,
    }
  }
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

async function toggleTaskPin(task: TaskItem) {
  if (sharedReadonly.value) {
    Message.info('共享清单为只读')
    return
  }
  const target = !task.pinned
  task.pinned = target
  try {
    const { task: updated } = await updateTask(task.id, { pinned: target })
    if (sharedNote.value?.task.id === updated.id) {
      sharedNote.value = { ...sharedNote.value, task: updated }
    } else {
      replaceTask(updated)
      scheduleRefresh()
    }
    Message.success(target ? '已置顶任务' : '已取消置顶')
  } catch (error) {
    task.pinned = !target
    Message.error(error instanceof Error ? error.message : '更新置顶失败')
  }
}

async function toggleListPin(list: TaskList) {
  try {
    await updateTaskList(list.id, { pinned: !list.pinned })
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '更新清单置顶失败')
  }
}

async function toggleFilterPin(filter: SavedFilter) {
  try {
    await updateSavedFilter(filter.id, { pinned: !filter.pinned })
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '更新过滤器置顶失败')
  }
}

function onQuickEnter(event: KeyboardEvent) {
  if (event.isComposing) return
  event.preventDefault()
  void submitQuick()
}

async function openTaskTemplates() {
  taskTemplateBusy.value = true
  try {
    const data = await fetchTaskTemplates()
    taskTemplates.value = data.templates || []
    taskTemplatesOpen.value = true
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载任务模板失败')
  } finally {
    taskTemplateBusy.value = false
  }
}

async function saveTaskAsTemplate(payload: Record<string, unknown>) {
  const name = String(payload.title || '未命名模板').slice(0, 120)
  try {
    await createTaskTemplate(name, JSON.stringify(payload))
    Message.success('任务已保存为模板')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存模板失败')
  }
}

async function applyTaskTemplate(template: TaskTemplate) {
  if (taskTemplateBusy.value) return
  taskTemplateBusy.value = true
  try {
    const payload = JSON.parse(template.payload) as Record<string, unknown>
    await createTask({
      ...(payload as object),
      title: String(payload.title || template.name),
      listId: Number(payload.listId) || quickTargetList.value?.id,
    })
    taskTemplatesOpen.value = false
    await loadWorkspace(true)
    Message.success('已从模板创建任务')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '从模板创建任务失败')
  } finally {
    taskTemplateBusy.value = false
  }
}

async function removeTaskTemplate(template: TaskTemplate) {
  try {
    await deleteTaskTemplate(template.id)
    taskTemplates.value = taskTemplates.value.filter((item) => item.id !== template.id)
    Message.success('模板已删除')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '删除模板失败')
  }
}

async function createSubtask(title: string) {
  if (!selectedTask.value) return
  try {
    await createTask({ title, parentId: selectedTask.value.id, listId: selectedTask.value.listId })
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建子任务失败')
  }
}

async function toggleSubtask(task: TaskItem) {
  try {
    await updateTask(task.id, { completed: !task.completed })
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '更新子任务失败')
  }
}

function openSubtask(task: TaskItem) {
  selectedId.value = task.id
  syncURL()
}

async function reorderSidebarLists(ids: number[]) {
  try {
    await Promise.all(ids.map((id, index) => updateTaskList(id, { order: index + 1 })))
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存清单排序失败')
  }
}

async function reorderSidebarFilters(ids: number[]) {
  try {
    await Promise.all(ids.map((id, index) => updateSavedFilter(id, { order: index + 1 })))
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存过滤器排序失败')
  }
}

async function reorderSidebarFolders(ids: number[]) {
  try {
    await Promise.all(ids.map((id, index) => updateTaskFolder(id, { order: index + 1 })))
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存文件夹排序失败')
  }
}

async function submitQuick() {
  const text = quickText.value.trim()
  if (!text || quickBusy.value) return
  quickBusy.value = true
  try {
    if (noteView.value) {
      const { task } = await createTask({ title: text, listId: noteTargetListId.value, kind: 'NOTE' })
      quickText.value = ''
      quickListId.value = 0
      quickSectionId.value = 0
      await loadWorkspace(true)
      selectedId.value = task.id
      return
    }
    const { task } = await createTask({
      text,
      listId: view.value === 'shared' ? activeSharedList.value?.listId : quickTargetList.value?.id,
      sectionId: quickSectionId.value || undefined,
    })
    quickText.value = ''
    quickListId.value = 0
    quickSectionId.value = 0
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

function addToColumn(column: BoardColumn) {
  quickListId.value = column.listId
  quickSectionId.value = column.sectionId > 0 ? column.sectionId : 0
  quickInputEl.value?.scrollIntoView({ block: 'center', behavior: 'smooth' })
  quickInputEl.value?.focus()
}

function focusQuick() {
  if (mode.value === 'board') quickSectionId.value = 0
  mode.value = 'list'
  requestAnimationFrame(() => quickInputEl.value?.focus())
}

function startTaskDrag(task: TaskItem, event: DragEvent) {
  dragId.value = task.id
  sectionDragId.value = 0
  event.stopPropagation()
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
}

function startSectionDrag(column: BoardColumn, event: DragEvent) {
  if (!singleListBoard.value || column.sectionId <= 0) return
  sectionDragId.value = column.sectionId
  dragId.value = 0
  event.stopPropagation()
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
}

function onColumnDrop(column: BoardColumn) {
  if (sectionDragId.value) {
    dropSection(column)
    return
  }
  const id = dragId.value
  dragId.value = 0
  if (!id) return
  const task = tasks.value.find((item) => item.id === id)
  if (!task) return
  if (column.isSection) {
    if (task.listId === column.listId && task.sectionId === column.sectionId) return
    const previousList = task.listId
    const previousSection = task.sectionId
    task.listId = column.listId
    task.sectionId = column.sectionId
    void updateTask(task.id, { listId: column.listId, sectionId: column.sectionId })
      .then(({ task: updated }) => {
        replaceTask(updated)
        scheduleRefresh()
      })
      .catch((error) => {
        task.listId = previousList
        task.sectionId = previousSection
        Message.error(error instanceof Error ? error.message : '移动任务失败')
      })
    return
  }
  dropOnList(column.listId)
}

function dropSection(target: BoardColumn) {
  const sourceId = sectionDragId.value
  sectionDragId.value = 0
  if (!sourceId || target.sectionId <= 0 || sourceId === target.sectionId) return
  const list = activeSections.value.slice()
  const from = list.findIndex((section) => section.id === sourceId)
  const to = list.findIndex((section) => section.id === target.sectionId)
  if (from < 0 || to < 0) return
  const [moved] = list.splice(from, 1)
  list.splice(to, 0, moved)
  void reorderSections(list.map((section) => section.id))
}

async function reorderSections(ids: number[]) {
  try {
    await Promise.all(ids.map((id, index) => updateTaskSection(id, { order: index + 1 })))
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存分组排序失败')
  }
}

function nextSectionName() {
  const names = new Set(activeSections.value.map((section) => section.name))
  if (!names.has('新分组')) return '新分组'
  let index = 2
  while (names.has(`新分组 ${index}`)) index += 1
  return `新分组 ${index}`
}

async function addSection(after: BoardColumn | null) {
  if (!activeListId.value) return
  try {
    const { section } = await createTaskSection(activeListId.value, nextSectionName())
    if (after?.sectionId && after.sectionId > 0) {
      const ids = activeSections.value.map((item) => item.id).filter((id) => id !== section.id)
      const index = ids.indexOf(after.sectionId)
      ids.splice(index >= 0 ? index + 1 : ids.length, 0, section.id)
      await reorderSections(ids)
    } else {
      await loadWorkspace(true)
    }
    sectionRenameId.value = section.id
    sectionRenameName.value = section.name
    sectionMenuId.value = -1
    await nextTick()
    focusSectionRename()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建分组失败')
  }
}

async function addSectionNear(column: BoardColumn, side: 'left' | 'right') {
  if (!activeListId.value) return
  try {
    const { section } = await createTaskSection(activeListId.value, nextSectionName())
    const ids = activeSections.value.map((item) => item.id).filter((id) => id !== section.id)
    let index = column.sectionId > 0 ? ids.indexOf(column.sectionId) : -1
    if (column.sectionId <= 0) index = side === 'left' ? 0 : ids.length
    else if (index < 0) index = ids.length
    ids.splice(side === 'left' ? index : index + 1, 0, section.id)
    await reorderSections(ids)
    sectionRenameId.value = section.id
    sectionRenameName.value = section.name
    sectionMenuId.value = -1
    await nextTick()
    focusSectionRename()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建分组失败')
  }
}

function toggleSectionMenu(id: number) {
  sectionMenuId.value = sectionMenuId.value === id ? -1 : id
}

function focusSectionRename(select = false) {
  const raw = sectionRenameInput.value
  const input = Array.isArray(raw) ? raw[0] : raw
  const target = input || (document.querySelector('.tw-board-rename') as HTMLInputElement | null)
  if (!target) return
  target.focus()
  if (select) target.select()
}

async function startSectionRename(column: BoardColumn) {
  sectionRenameId.value = column.sectionId
  sectionRenameName.value = column.name
  sectionMenuId.value = -1
  await nextTick()
  focusSectionRename(true)
}

async function saveSectionRename() {
  const id = sectionRenameId.value
  if (!id) return
  const name = sectionRenameName.value.trim() || '新分组'
  sectionRenameId.value = 0
  try {
    await updateTaskSection(id, { name })
    await loadWorkspace(true)
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '重命名分组失败')
  }
}

function openDeleteSection(column: BoardColumn) {
  sectionDeleteTarget.value = column
  sectionDeleteStrategy.value = 'move'
  const fallback = activeSections.value.find((section) => section.id !== column.sectionId)
  sectionDeleteMoveTo.value = fallback?.id || 0
  sectionMenuId.value = -1
}

async function confirmDeleteSection() {
  const column = sectionDeleteTarget.value
  if (!column) return
  try {
    await deleteTaskSection(
      column.sectionId,
      sectionDeleteStrategy.value,
      sectionDeleteStrategy.value === 'move' ? sectionDeleteMoveTo.value : 0,
    )
    sectionDeleteTarget.value = null
    await loadWorkspace(true)
    void checkReminders()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '删除分组失败')
  }
}

function openCopyList(list: TaskList) {
  copyListTarget.value = list
  copyListName.value = `${list.name} 副本`
  copyListMode.value = 'open'
}

async function confirmCopyList() {
  const list = copyListTarget.value
  if (!list || copyBusy.value) return
  const name = copyListName.value.trim()
  if (!name) {
    Message.warning('清单名称不能为空')
    return
  }
  copyBusy.value = true
  try {
    const { list: copied } = await copyTaskList(list.id, { name, mode: copyListMode.value })
    copyListTarget.value = null
    await loadWorkspace(true)
    selectList(copied.id)
    Message.success('清单已复制')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '复制清单失败')
  } finally {
    copyBusy.value = false
  }
}

async function createList(payload: { name: string; kind: 'TASK' | 'NOTE' }) {
  try {
    const color = LIST_COLORS[lists.value.length % LIST_COLORS.length]
    const { list } = await createTaskList(payload.name, color, 0, payload.kind)
    await loadWorkspace(true)
    if (payload.kind === 'NOTE') {
      selectList(list.id)
      focusQuick()
    }
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建清单失败')
  }
}

async function createNote() {
  let target = lists.value.find((list) => list.kind === 'NOTE' && list.id === activeListId.value)
  if (!target) {
    let saved = 0
    try {
      saved = Number(localStorage.getItem('caldav-last-note-list') || 0)
    } catch {
      /* ignore */
    }
    target = lists.value.find((list) => list.kind === 'NOTE' && list.id === saved && !list.isInbox)
  }
  if (!target) target = lists.value.find((list) => list.kind === 'NOTE' && !list.isInbox)
  if (!target) {
    try {
      const color = LIST_COLORS[lists.value.length % LIST_COLORS.length]
      const { list } = await createTaskList('笔记', color, 0, 'NOTE')
      await loadWorkspace(true)
      target = list
    } catch (error) {
      Message.error(error instanceof Error ? error.message : '创建笔记清单失败')
      return
    }
  }
  if (!target) return
  selectList(target.id)
  focusQuick()
}

function openEditList(list: TaskList) {
  editForm.id = list.id
  editForm.name = list.name
  editForm.color = list.color || LIST_COLORS[0]
  editForm.folderId = list.folderId || 0
  editVisible.value = true
  requestAnimationFrame(() => editNameInput.value?.focus?.())
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
  const message =
    list.kind === 'NOTE'
      ? `确定删除「${list.name}」吗？其中的笔记会移动到其他笔记清单。`
      : `确定删除「${list.name}」吗？其中的任务会移动到收集箱。`
  askConfirm('删除清单', message, async () => {
    await deleteTaskList(list.id)
    await loadWorkspace(true)
    if (activeListId.value === list.id) {
      const fallback = list.kind === 'NOTE' ? lists.value.find((item) => item.kind === 'NOTE') : undefined
      if (fallback) selectList(fallback.id)
      else selectView('all')
    }
  })
}

function replaceTask(updated: TaskItem) {
  const index = tasks.value.findIndex((task) => task.id === updated.id)
  if (index >= 0) tasks.value[index] = updated
}

function onOccurrenceChanged(updated: TaskItem) {
  replaceTask(updated)
  calendarReload.value += 1
  scheduleRefresh()
}

function onTaskChanged(updated: TaskItem) {
  if (sharedNote.value?.task.id === updated.id) {
    sharedNote.value = { ...sharedNote.value, task: updated }
    return
  }
  replaceTask(updated)
  scheduleRefresh()
}

function onTaskDeleted(id: number) {
  tasks.value = tasks.value.filter((task) => task.id !== id)
  if (sharedNote.value?.task.id === id) sharedNote.value = null
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
  switch (calendarView.value) {
    case 'year':
      cursor.value = new Date(date.getFullYear() + delta, date.getMonth(), 1)
      return
    case 'month':
      cursor.value = new Date(date.getFullYear(), date.getMonth() + delta, 1)
      return
    case 'week':
      cursor.value = new Date(date.getFullYear(), date.getMonth(), date.getDate() + delta * 7)
      return
    case '2week':
      cursor.value = new Date(date.getFullYear(), date.getMonth(), date.getDate() + delta * 14)
      return
    case '3day':
      cursor.value = new Date(date.getFullYear(), date.getMonth(), date.getDate() + delta * 3)
      return
    case 'agenda':
      cursor.value = new Date(date.getFullYear(), date.getMonth(), date.getDate() + delta * 30)
      return
    default:
      cursor.value = new Date(date.getFullYear(), date.getMonth(), date.getDate() + delta)
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

async function rescheduleTask(payload: { task: TaskItem; due: string; start?: string; allDay: boolean }) {
  try {
    const { task } = await updateTask(payload.task.id, {
      due: payload.due,
      allDay: payload.allDay,
      ...(payload.start ? { start: payload.start } : {}),
    })
    replaceTask(task)
    Message.success('任务已改期')
    scheduleRefresh()
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '改期失败')
  }
}

function setTimelineZoom(value: 'day' | 'week' | 'month') {
  timelineZoom.value = value
  try {
    localStorage.setItem('caldav-timeline-zoom', value)
  } catch {
    /* ignore */
  }
}

function setTimelineColor(value: 'list' | 'tag' | 'priority' | 'none') {
  timelineColor.value = value
  try {
    localStorage.setItem('caldav-timeline-color', value)
  } catch {
    /* ignore */
  }
}

function createFromTimeline(payload: { title: string; date: string; listId: number }) {
  void (async () => {
    try {
      const { task } = await createTask({
        title: payload.title,
        listId: payload.listId,
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

function toggleSplitView() {
  splitView.value = !splitView.value
  try {
    localStorage.setItem('caldav-split-view', splitView.value ? '1' : '0')
  } catch {
    /* ignore */
  }
}

function stepSplitCalendar(direction: number) {
  const next = new Date(splitCursor.value)
  if (splitViewMode.value === 'month') next.setMonth(next.getMonth() + direction)
  else if (splitViewMode.value === 'year') next.setFullYear(next.getFullYear() + direction)
  else if (splitViewMode.value === 'week') next.setDate(next.getDate() + direction * 7)
  else if (splitViewMode.value === '2week') next.setDate(next.getDate() + direction * 14)
  else if (splitViewMode.value === '3day') next.setDate(next.getDate() + direction * 3)
  else if (splitViewMode.value === 'agenda') next.setDate(next.getDate() + direction * 30)
  else next.setDate(next.getDate() + direction)
  splitCursor.value = next
}

function startSplitResize(event: PointerEvent) {
  const startX = event.clientX
  const startWidth = splitWidth.value
  const move = (moveEvent: PointerEvent) => {
    splitWidth.value = Math.min(720, Math.max(320, startWidth - (moveEvent.clientX - startX)))
  }
  const stop = () => {
    window.removeEventListener('pointermove', move)
    window.removeEventListener('pointerup', stop)
    try {
      localStorage.setItem('caldav-split-width', String(splitWidth.value))
    } catch {
      /* ignore */
    }
  }
  window.addEventListener('pointermove', move)
  window.addEventListener('pointerup', stop, { once: true })
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
  filteredTasks.value.filter((task) => !task.completed),
)
const activeMatrixView = computed(() => matrixViews.value.find((item) => item.id === activeMatrixViewId.value))
const matrixCustomRules = computed(() => activeMatrixView.value?.rules)
const matrixAssignees = computed(() =>
  Array.from(new Set(tasks.value.map((task) => task.assignee).filter(Boolean))).sort((a, b) => a.localeCompare(b, 'zh')),
)

function matrixPatchForTask(task: TaskItem, quadrant: MatrixQuadrantKey) {
  if (matrixRule.value === 'custom') {
    return planMatrixDrop(task, normalizeMatrixRules(matrixCustomRules.value), quadrant)
  }
  if (matrixRule.value === 'complex') return planComplexDrop(task, quadrant)
  return { priority: quadrant === 'q1' ? 3 : quadrant === 'q2' ? 2 : quadrant === 'q3' ? 1 : 0 }
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

function setDefaultMatrixRule(rule: MatrixRuleMode) {
  matrixDefaultRule.value = rule
  try {
    localStorage.setItem('caldav-matrix-rule', rule)
  } catch {
    /* ignore */
  }
  if (activeMatrixViewId.value) return
  matrixRule.value = rule
}

function selectMatrixView(id: number) {
  activeMatrixViewId.value = id
  const view = matrixViews.value.find((item) => item.id === id)
  matrixRule.value = view?.mode || matrixDefaultRule.value
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
  matrixViewName.value = `矩阵视图 ${matrixViews.value.length + 1}`
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
    Message.success('矩阵视图已创建')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '创建矩阵视图失败')
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

function applyTheme(next: string) {
  theme.value = next
  document.documentElement.dataset.theme = isDarkTheme(next) ? 'dark' : 'light'
  try {
    localStorage.setItem('caldav-task-theme', next)
  } catch {
    /* ignore */
  }
}

function toggleTheme() {
  applyTheme(isDarkTheme(theme.value) ? 'default' : 'dark')
}

const themeLabel = computed(() => themeById(theme.value).label)

async function handleLogout() {
  try {
    await logout()
    void router.push('/login')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '退出失败')
  }
}

const paletteCommands = computed<PaletteCommand[]>(() => {
  const keyOf = (id: string) => {
    const combo = (shortcutBindings.value[id] || [])[0]
    return combo ? comboLabel(combo, isMac) : ''
  }
  const rows: PaletteCommand[] = [
    { id: 'new-task', label: '新建任务', group: '操作', keys: [keyOf('newTask')].filter(Boolean) },
    { id: 'new-note', label: '新建笔记', group: '操作', keys: [] },
    { id: 'search', label: '搜索任务', group: '操作', keys: [keyOf('search')].filter(Boolean) },
    { id: 'theme', label: '切换主题', group: '操作', keys: [] },
    { id: 'shortcuts', label: '快捷键', group: '帮助', keys: [keyOf('shortcutHelp')].filter(Boolean) },
    { id: 'nav-all', label: '前往“所有”', group: '导航', keys: [keyOf('navAll')].filter(Boolean) },
    { id: 'nav-today', label: '前往“今天”', group: '导航', keys: [keyOf('navToday')].filter(Boolean) },
    { id: 'nav-next7', label: '前往“最近 7 天”', group: '导航', keys: [keyOf('navNext7')].filter(Boolean) },
    { id: 'nav-inbox', label: '前往“收集箱”', group: '导航', keys: [keyOf('navInbox')].filter(Boolean) },
    { id: 'nav-completed', label: '前往“已完成”', group: '导航', keys: [keyOf('navCompleted')].filter(Boolean) },
    { id: 'nav-summary', label: '前往“摘要”', group: '导航', keys: [keyOf('navSummary')].filter(Boolean) },
    { id: 'nav-trash', label: '前往“垃圾桶”', group: '导航', keys: [keyOf('navTrash')].filter(Boolean) },
    { id: 'nav-matrix', label: '前往“矩阵”', group: '导航', keys: [keyOf('navMatrix')].filter(Boolean) },
    { id: 'nav-habit', label: '前往“习惯”', group: '导航', keys: [keyOf('navHabit')].filter(Boolean) },
    { id: 'nav-focus', label: '前往“专注”', group: '导航', keys: [keyOf('navFocus')].filter(Boolean) },
    { id: 'nav-countdown', label: '前往“倒数纪念日”', group: '导航', keys: [keyOf('navCountdown')].filter(Boolean) },
    { id: 'nav-stats', label: '前往“统计”', group: '导航', keys: [keyOf('navStats')].filter(Boolean) },
    { id: 'mode-list', label: '列表视图', group: '视图', keys: [keyOf('listMode')].filter(Boolean) },
    { id: 'mode-board', label: '看板视图', group: '视图', keys: [keyOf('boardMode')].filter(Boolean) },
    { id: 'mode-calendar', label: '日历视图', group: '视图', keys: [keyOf('calendarMode')].filter(Boolean) },
    { id: 'mode-timeline', label: '时间线视图', group: '视图', keys: [keyOf('timelineMode')].filter(Boolean) },
  ]
  if (selectedTask.value && !selectedTask.value.completed) {
    rows.splice(2, 0, { id: 'complete-selected', label: `完成任务「${selectedTask.value.title}」`, group: '操作', keys: [keyOf('completeTask')].filter(Boolean) })
    rows.splice(3, 0, { id: 'pin-selected', label: `${selectedTask.value.pinned ? '取消置顶' : '置顶'}任务「${selectedTask.value.title}」`, group: '操作', keys: [keyOf('pinTask')].filter(Boolean) })
  }
  return rows
})

function onShortcutSave(next: ShortcutBindings) {
  shortcutBindings.value = next
  saveBindings(next)
  shortcutHelpOpen.value = false
  Message.success('快捷键已保存')
}

function focusQuickAdd() {
  if (view.value === 'trash') return
  if (mode.value === 'calendar') mode.value = 'list'
  requestAnimationFrame(() => quickInputEl.value?.focus())
}

function runPalette(id: string) {
  commandOpen.value = false
  switch (id) {
    case 'new-task':
      return focusQuickAdd()
    case 'new-note':
      void createNote()
      return
    case 'search':
      return toggleSearch()
    case 'theme':
      themeDialogOpen.value = true
      return
    case 'shortcuts':
      shortcutHelpOpen.value = true
      return
    case 'complete-selected':
      if (selectedTask.value) void toggleTask(selectedTask.value)
      return
    case 'pin-selected':
      if (selectedTask.value) void toggleTaskPin(selectedTask.value)
      return
    case 'mode-list':
      return switchMode('list')
    case 'mode-board':
      return switchMode('board')
    case 'mode-calendar':
      return switchMode('calendar')
    case 'mode-timeline':
      return switchMode('timeline')
  }
  if (id.startsWith('nav-')) runShortcut(id.replace('nav-', 'nav').replace(/(^nav)(\w)/, (_, a, b) => a + b.toUpperCase()))
}

function runShortcut(id: string) {
  const task = selectedTask.value
  const taskAction = async (action: () => Promise<unknown>) => {
    if (!task) {
      Message.info('先选择一个任务')
      return
    }
    try {
      await action()
      await loadWorkspace(true)
    } catch (error) {
      Message.error(error instanceof Error ? error.message : '操作失败')
    }
  }
  const setDue = (offset: number) => {
    const date = new Date()
    date.setDate(date.getDate() + offset)
    return taskAction(() => updateTask(task!.id, { due: `${dayKey(date)}T00:00`, allDay: true }))
  }
  switch (id) {
    case 'commandPalette':
      commandOpen.value = true
      return
    case 'shortcutHelp':
      shortcutHelpOpen.value = true
      return
    case 'search':
      return toggleSearch()
    case 'newTask':
      return focusQuickAdd()
    case 'toggleSidebar':
      sidebarOpen.value = !sidebarOpen.value
      return
    case 'pinTask':
      if (task) void toggleTaskPin(task)
      return
    case 'completeTask':
      if (task && !task.completed) void toggleTask(task)
      return
    case 'setToday':
      return setDue(0)
    case 'setTomorrow':
      return setDue(1)
    case 'clearDate':
      return taskAction(() => updateTask(task!.id, { due: '' }))
    case 'priorityNone':
      return taskAction(() => updateTask(task!.id, { priority: 0 }))
    case 'priorityLow':
      return taskAction(() => updateTask(task!.id, { priority: 1 }))
    case 'priorityMedium':
      return taskAction(() => updateTask(task!.id, { priority: 2 }))
    case 'priorityHigh':
      return taskAction(() => updateTask(task!.id, { priority: 3 }))
    case 'listMode':
      return switchMode('list')
    case 'boardMode':
      return switchMode('board')
    case 'calendarMode':
      return switchMode('calendar')
    case 'timelineMode':
      return switchMode('timeline')
    case 'navAll':
      return selectView('all')
    case 'navToday':
      return selectView('today')
    case 'navNext7':
      return selectView('next7')
    case 'navInbox':
      return inboxId.value ? selectList(inboxId.value) : selectView('inbox')
    case 'navCompleted':
      return selectView('completed')
    case 'navSummary':
      return selectView('summary')
    case 'navTrash':
      return selectView('trash')
    case 'navMatrix':
      return selectView('matrix')
    case 'navHabit':
      return selectView('habit')
    case 'navFocus':
      return selectView('focus')
    case 'navCountdown':
      return selectView('countdown')
    case 'navStats':
      return openStats()
    case 'navAI':
      return openAI()
  }
}

function clearSequence() {
  sequenceBuffer = ''
  if (sequenceTimer) {
    clearTimeout(sequenceTimer)
    sequenceTimer = undefined
  }
}

let tabArmedUntil = 0

function onKeydown(event: KeyboardEvent) {
  if (themeDialogOpen.value) {
    if (event.key === 'Escape') themeDialogOpen.value = false
    return
  }
  if (shortcutHelpOpen.value) {
    if (event.key === 'Escape') shortcutHelpOpen.value = false
    return
  }
  if (commandOpen.value) return
  const target = event.target as HTMLElement | null
  const typing = target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable)
  if (typing) return
  if (event.key === 'Escape') {
    clearSequence()
    selectedId.value = 0
    return
  }
  // Tab is kept as a normal focus key; a following key within 900ms can form
  // a Tab-prefixed shortcut such as Tab+N.
  if (event.key === 'Tab') {
    tabArmedUntil = Date.now() + 900
    return
  }
  let combo = keyEventToCombo(event)
  if (!combo) return
  if (Date.now() < tabArmedUntil) {
    combo = `tab+${combo}`
    tabArmedUntil = 0
  }
  const candidate = sequenceBuffer ? `${sequenceBuffer} ${combo}` : combo
  const action = findAction(shortcutBindings.value, candidate)
  if (action) {
    event.preventDefault()
    clearSequence()
    runShortcut(action.id)
    return
  }
  if (isPrefix(shortcutBindings.value, candidate)) {
    event.preventDefault()
    sequenceBuffer = candidate
    if (sequenceTimer) clearTimeout(sequenceTimer)
    sequenceTimer = setTimeout(clearSequence, 900)
    return
  }
  clearSequence()
  const single = findAction(shortcutBindings.value, combo)
  if (single) {
    event.preventDefault()
    runShortcut(single.id)
  }
}

function emptyConditions(): TaskFilterConditions {
  return { listIds: [], tags: [], tagMode: 'any', priorities: [], status: 'open', date: 'any', dateFrom: '', dateTo: '', keyword: '' }
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
    await updateTaskFolder(folderForm.id, { name })
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
    dateFrom: cond.dateFrom || '',
    dateTo: cond.dateTo || '',
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
  if (filterForm.conditions.date === 'range') {
    const { dateFrom, dateTo } = filterForm.conditions
    if (!dateFrom && !dateTo) {
      Message.warning('请选择时间段的起止日期')
      return
    }
    if (dateFrom && dateTo && dateFrom > dateTo) {
      Message.warning('开始日期不能晚于结束日期')
      return
    }
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

const moveTargetLists = computed(() => {
  const selected = tasks.value.filter((task) => selectedIds.value.has(task.id))
  if (!selected.length) return []
  const noteCount = selected.filter((task) => task.kind === 'NOTE').length
  if (noteCount > 0 && noteCount !== selected.length) return []
  const wantNoteLists = noteCount > 0
  return lists.value.filter((list) => (list.kind === 'NOTE') === wantNoteLists)
})

function openMoveDialog() {
  const options = moveTargetLists.value
  moveTargetId.value = options.find((list) => list.id === activeListId.value)?.id || options[0]?.id || 0
  moveDialogOpen.value = true
  if (!options.length) Message.info('任务和笔记不能混合移动')
}

function batchMove() {
  if (!moveTargetId.value) {
    Message.info('请选择目标清单')
    return
  }
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

function startTaskStream() {
  if (typeof EventSource === 'undefined' || taskStreamSource) return
  taskStreamSource = new EventSource('/api/admin/tasks/stream')
  taskStreamSource.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data) as { revision?: string; ready?: boolean }
      if (data.revision) scheduleRefresh()
    } catch {
      /* ignore malformed SSE frames */
    }
  }
}

function onNotificationTaskCompleted() {
  // 通知里完成任务后，背景任务列表/计数需要立即刷新。
  void loadWorkspace(true)
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
  const validViews: TaskView[] = ['all', 'today', 'next7', 'inbox', 'completed', 'trash', 'stats', 'summary', 'ai', 'filter', 'list', 'shared', 'matrix', 'habit', 'focus', 'countdown', 'notes']
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
  mode.value = view.value === 'shared' ? 'list' : (['list', 'board', 'calendar', 'timeline'].includes(nextMode) ? nextMode : 'list') as Mode
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
    if (stored && TASK_THEMES.some((item) => item.id === stored)) theme.value = stored
    else theme.value = window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'default'
    document.documentElement.dataset.theme = isDarkTheme(theme.value) ? 'dark' : 'light'
    const collapsedRaw = localStorage.getItem('caldav-task-collapsed')
    if (collapsedRaw) collapsed.value = new Set(JSON.parse(collapsedRaw) as string[])
    manualSort.value = localStorage.getItem('caldav-task-sort') === 'manual'
    const zoom = localStorage.getItem('caldav-timeline-zoom')
    if (zoom === 'day' || zoom === 'week' || zoom === 'month') timelineZoom.value = zoom
    const color = localStorage.getItem('caldav-timeline-color')
    if (color === 'list' || color === 'tag' || color === 'priority' || color === 'none') timelineColor.value = color
    splitView.value = localStorage.getItem('caldav-split-view') === '1'
    const width = Number(localStorage.getItem('caldav-split-width'))
    if (width >= 320 && width <= 720) splitWidth.value = width
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
  startTaskStream()
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
  clearSequence()
  if (searchTimer) clearTimeout(searchTimer)
  if (refreshTimer) clearTimeout(refreshTimer)
  if (notificationTimer) clearInterval(notificationTimer)
  notificationSource?.close()
  notificationSource = null
  taskStreamSource?.close()
  taskStreamSource = null
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
