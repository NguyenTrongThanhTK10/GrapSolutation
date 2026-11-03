import { onMounted, onUnmounted, ref, shallowRef } from 'vue';
export function useQuery<T>(query: () => Promise<T>, interval = 0) {
  const data = shallowRef<T | null>(null), loading = ref(true), error = ref(''); let disposed = false, timer: ReturnType<typeof setInterval> | undefined; let flight: Promise<void> | null = null;
  const refresh = () => { if (flight) return flight; flight = (async () => { try { const result = await query(); if (!disposed) { data.value = result; error.value = ''; } } catch (e) { if (!disposed) error.value = e instanceof Error ? e.message : 'Không thể tải dữ liệu'; } finally { if (!disposed) loading.value = false; flight = null; } })(); return flight; };
  onMounted(() => { void refresh(); if (interval) timer = setInterval(() => { if (!document.hidden) void refresh(); }, interval); }); onUnmounted(() => { disposed = true; if (timer) clearInterval(timer); });
  return { data, loading, error, refresh };
}
