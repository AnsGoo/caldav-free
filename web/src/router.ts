import { createRouter, createWebHistory } from 'vue-router'
import { auth } from './auth'

// The public habit share page is served from /share/ while the admin SPA
// normally lives under /admin/. Both use the same built assets.
const routerBase = window.location.pathname.startsWith('/share/') ? '/share/' : import.meta.env.BASE_URL

const router = createRouter({
  history: createWebHistory(routerBase),
  scrollBehavior: () => ({ top: 0 }),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('./views/LoginView.vue'),
      meta: { public: true },
    },
    {
      path: '/',
      name: 'dashboard',
      component: () => import('./views/DashboardView.vue'),
    },
    {
      path: '/habit/:token',
      name: 'habit-share',
      component: () => import('./views/HabitShareView.vue'),
      meta: { public: true, share: true },
    },
    {
      path: '/share/habit/:token',
      component: () => import('./views/HabitShareView.vue'),
      meta: { public: true, share: true },
    },
    ...taskWorkspaceRoutes(),
    {
      path: '/users',
      name: 'users',
      component: () => import('./views/UsersView.vue'),
    },
    {
      path: '/users/:id',
      name: 'user',
      component: () => import('./views/UserDetailView.vue'),
    },
    {
      path: '/calendars/:id',
      name: 'calendar',
      component: () => import('./views/CalendarView.vue'),
    },
    {
      path: '/calendars/:id/events/:name/edit',
      name: 'event-edit',
      component: () => import('./views/EventEditView.vue'),
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      component: () => import('./views/NotFoundView.vue'),
    },
  ],
})

router.beforeEach((to) => {
  if (to.meta.share) return true
  if (to.meta.public) {
    if (auth.user) return { name: 'dashboard' }
    return true
  }
  if (!auth.user) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  return true
})

export default router


function taskWorkspaceRoutes() {
  const component = () => import('./views/TaskWorkspaceView.vue')
  return [
    { path: '/tasks', name: 'tasks', component, meta: { view: 'all' } },
    { path: '/tasks/today', name: 'tasks-today', component, meta: { view: 'today' } },
    { path: '/tasks/next7', name: 'tasks-next7', component, meta: { view: 'next7' } },
    { path: '/tasks/inbox', name: 'tasks-inbox', component, meta: { view: 'inbox' } },
    { path: '/tasks/completed', name: 'tasks-completed', component, meta: { view: 'completed' } },
    { path: '/tasks/trash', name: 'tasks-trash', component, meta: { view: 'trash' } },
    { path: '/tasks/matrix', name: 'tasks-matrix', component, meta: { view: 'matrix' } },
    { path: '/tasks/habit', name: 'tasks-habit', component, meta: { view: 'habit' } },
    { path: '/tasks/habit/:habitId', name: 'tasks-habit-detail', component, meta: { view: 'habit' } },
    { path: '/tasks/focus', name: 'tasks-focus', component, meta: { view: 'focus' } },
    { path: '/tasks/stats', name: 'tasks-stats', component, meta: { view: 'stats' } },
    { path: '/tasks/summary', name: 'tasks-summary', component, meta: { view: 'summary' } },
    { path: '/tasks/ai', name: 'tasks-ai', component, meta: { view: 'ai' } },
    { path: '/tasks/calendar', name: 'tasks-calendar', component, meta: { view: 'all', mode: 'calendar' } },
    { path: '/tasks/board', name: 'tasks-board', component, meta: { view: 'all', mode: 'board' } },
    { path: '/tasks/list/:listId', name: 'tasks-list', component, meta: { view: 'list' } },
    { path: '/tasks/filter/:filterId', name: 'tasks-filter', component, meta: { view: 'filter' } },
    { path: '/tasks/shared/:sharedId', name: 'tasks-shared', component, meta: { view: 'shared' } },
  ]
}
