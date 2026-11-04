<script setup lang="ts">
import { currentUser } from '../lib/api';
import { homeFor } from '../lib/access';
</script>

<template>
  <section class="panel access-state" role="status">
    <span class="metric-icon orange"><i class="pi pi-lock" aria-hidden="true"></i></span>
    <h1>Bạn chưa có quyền truy cập</h1>
    <p>Phân hệ này dành cho vai trò được cấp quyền. Bạn có thể tiếp tục ở không gian làm việc của mình.</p>
    <RouterLink :to="homeFor(currentUser?.role)" class="access-home">Về không gian làm việc <i class="pi pi-arrow-right"></i></RouterLink>
  </section>
</template>
