<script setup lang="ts">
import { statuses } from '../lib/types';
defineProps<{ status: string; label?: string }>();
</script>
<template><span class="status-badge" :class="'tone-' + (statuses[status]?.tone ?? 'secondary')"><span class="status-dot"></span>{{ label ?? statuses[status]?.label ?? status }}</span></template>
