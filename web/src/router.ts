import { createRouter, createWebHistory } from 'vue-router'
import { auth } from './auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
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
