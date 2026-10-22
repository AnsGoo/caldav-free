<template>
  <AdminLayout title="编辑事件" subtitle="直接编辑 RFC 5545 iCalendar 数据">
    <template #actions>
      <a-button @click="router.push(`/calendars/${route.params.id}`)">
        <template #icon><IconLeft /></template>
        返回日历
      </a-button>
    </template>

    <a-spin :loading="loading" class="page-spin">
      <template v-if="detail">
        <nav class="breadcrumb">
          <router-link to="/users">用户</router-link>
          <span>/</span>
          <router-link :to="`/calendars/${route.params.id}`">日历 #{{ route.params.id }}</router-link>
          <span>/</span>
          <span>{{ route.params.name }}</span>
        </nav>

        <section class="event-edit-layout">
          <a-card :bordered="false" class="panel">
            <div class="panel-head">
              <div>
                <p class="eyebrow">Raw iCalendar</p>
                <h2>编辑事件</h2>
              </div>
              <a-tag>{{ detail.event.componentType }}</a-tag>
            </div>
            <a-alert type="info" class="edit-alert">
              保存时会重新校验 UID、组件类型、时区与时间范围，并生成新的 ETag。适合高级修改。
            </a-alert>
            <a-textarea v-model="data" class="code-area" :auto-size="{ minRows: 20, maxRows: 32 }" spellcheck="false" />
            <div class="form-actions">
              <a-button @click="router.push(`/calendars/${route.params.id}`)">取消</a-button>
              <a-button type="primary" :loading="saving" @click="save">保存事件</a-button>
            </div>
          </a-card>

          <aside class="stack">
            <a-card :bordered="false" class="panel">
              <p class="eyebrow">Metadata</p>
              <h2>对象信息</h2>
              <dl class="facts">
                <div><dt>文件名</dt><dd class="mono">{{ detail.event.href }}</dd></div>
                <div><dt>UID</dt><dd class="mono">{{ detail.event.uid }}</dd></div>
                <div><dt>组件</dt><dd>{{ detail.event.componentType }}</dd></div>
                <div><dt>标题</dt><dd>{{ detail.event.summary }}</dd></div>
                <div><dt>大小</dt><dd>{{ detail.event.size }} bytes</dd></div>
              </dl>
            </a-card>
          </aside>
        </section>
      </template>
    </a-spin>
  </AdminLayout>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Message } from '@arco-design/web-vue'
import { IconLeft } from '@arco-design/web-vue/es/icon'
import AdminLayout from '../layouts/AdminLayout.vue'
import { api } from '../api'
import type { EventDetailData } from '../types'

const route = useRoute()
const router = useRouter()
const loading = ref(true)
const saving = ref(false)
const detail = ref<EventDetailData | null>(null)
const data = ref('')

async function load() {
  loading.value = true
  try {
    const name = encodeURIComponent(String(route.params.name))
    detail.value = await api<EventDetailData>(`/calendars/${route.params.id}/events/${name}`)
    data.value = detail.value.data
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '加载失败')
  } finally {
    loading.value = false
  }
}

async function save() {
  saving.value = true
  try {
    const name = encodeURIComponent(String(route.params.name))
    const result = await api<EventDetailData>(`/calendars/${route.params.id}/events/${name}`, {
      method: 'PUT',
      body: JSON.stringify({ data: data.value }),
    })
    detail.value = result
    data.value = result.data
    Message.success('事件已保存')
  } catch (error) {
    Message.error(error instanceof Error ? error.message : '保存失败')
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>
