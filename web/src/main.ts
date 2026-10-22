import { createApp } from 'vue'
import ArcoVue from '@arco-design/web-vue'
import '@arco-design/web-vue/dist/arco.css'
import App from './App.vue'
import router from './router'
import { bootstrapAuth } from './auth'
import { setUnauthorizedHandler } from './api'
import './styles.css'

setUnauthorizedHandler(() => {
  if (router.currentRoute.value.name !== 'login') {
    router.push({ name: 'login' })
  }
})

await bootstrapAuth()

createApp(App).use(ArcoVue).use(router).mount('#app')
