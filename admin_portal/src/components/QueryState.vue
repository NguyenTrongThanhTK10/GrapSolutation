<script setup lang="ts">
import Button from 'primevue/button';
defineProps<{ loading?: boolean; error?: string; empty?: boolean }>(); defineEmits(['retry']);
</script>
<template><div v-if="loading" class="query-state" role="status"><i class="pi pi-spin pi-spinner"></i><span>Đang tải dữ liệu…</span></div><div v-else-if="error" class="query-state error" role="alert"><i class="pi pi-exclamation-circle"></i><strong>{{ error }}</strong><Button label="Thử lại" icon="pi pi-refresh" severity="secondary" size="small" @click="$emit('retry')"/></div><div v-else-if="empty" class="query-state"><i class="pi pi-inbox"></i><strong>Chưa có dữ liệu</strong><span>Dữ liệu mới sẽ xuất hiện tại đây.</span></div></template>
