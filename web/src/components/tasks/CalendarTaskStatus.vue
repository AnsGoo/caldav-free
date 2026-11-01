<template>
  <span v-if="task?.virtual || task?.postponed" class="tw-cal-status">
    <span v-if="task?.virtual" class="tw-cal-status-ico" title="重复实例" aria-label="重复实例">
      <TaskIcon name="repeat" :size="size" />
    </span>
    <span v-if="task?.postponed" class="tw-cal-status-ico postponed" title="已顺延" aria-label="已顺延">
      <TaskIcon name="clock" :size="size" />
    </span>
  </span>
</template>

<script setup lang="ts">
import type { TaskItem } from '../../types'
import TaskIcon from './TaskIcon.vue'

withDefaults(defineProps<{ task?: TaskItem; size?: number }>(), { size: 11 })
</script>
