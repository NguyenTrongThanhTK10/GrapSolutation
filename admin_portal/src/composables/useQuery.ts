import { onMounted, onUnmounted, ref, shallowRef } from 'vue';
export function useQuery<T>(query: () => Promise<T>, interval = 0) {
  const data = shallowRef<T | null>(null), loading = ref(true), error = ref('');
  let disposed = false, timer: ReturnType<typeof setInterval> | undefined, revision = 0;
  let flight: Promise<void> | null = null;
  // An explicit refresh invalidates an older request and queues the latest filters.
  // Polling shares the current request instead of continually invalidating it.
  const refresh = (): Promise<void> => {
    const requested = ++revision;
    loading.value = true;
    if (flight) return flight;
    flight = (async () => {
      let running = requested;
      do {
        running = revision;
        try {
          const result = await query();
          if (!disposed && running === revision) { data.value = result; error.value = ''; }
        } catch (e) {
          if (!disposed && running === revision) error.value = e instanceof Error ? e.message : 'Không thể tải dữ liệu';
        }
      } while (!disposed && running !== revision);
    })().finally(() => { if (!disposed) loading.value = false; flight = null; });
    return flight;
  };
  onMounted(() => { void refresh(); if (interval) timer = setInterval(() => { if (!document.hidden && !flight) void refresh(); }, interval); });
  onUnmounted(() => { disposed = true; if (timer) clearInterval(timer); });
  return { data, loading, error, refresh };
}
