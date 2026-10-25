<template>
  <AdminLayout title="页面不存在">
    <a-card :bordered="false" class="panel">
      <a-result status="404" title="页面不存在" subtitle="请检查地址，或返回首页。">
        <template #extra>
          <a-button type="primary" @click="$router.push('/')">返回首页</a-button>
        </template>
      </a-result>
    </a-card>
  </AdminLayout>
</template>

<script setup lang="ts">
import AdminLayout from '../layouts/AdminLayout.vue'
</script>
