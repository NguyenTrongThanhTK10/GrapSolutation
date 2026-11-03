<script setup lang="ts">
import { onMounted, onUnmounted, watch, ref } from 'vue';
import L from 'leaflet';
import type { Data, Point } from '../lib/types';
const props = defineProps<{ drivers?: Data[]; pickup?: Point; dropoff?: Point; compact?: boolean }>();
const host = ref<HTMLElement>(); let map: L.Map | undefined; let markers: L.LayerGroup | undefined; let observer: ResizeObserver | undefined; const tileError = ref(false);
function tooltip(text: string) { const el = document.createElement('span'); el.textContent = text; return el; }
function render() {
 if (!map || !markers) return; markers.clearLayers(); const bounds: L.LatLngTuple[] = [];
 for (const driver of props.drivers ?? []) { if (!driver.latitude || !driver.longitude) continue; const point: L.LatLngTuple = [driver.latitude, driver.longitude]; bounds.push(point); const icon = L.divIcon({ className: '', html: `<div class="map-driver ${driver.healthy ? 'healthy' : 'stale'}"><i class="pi ${driver.serviceTypeCode === 'BIKE' ? 'pi-directions' : 'pi-car'}"></i></div>`, iconSize: [34, 34], iconAnchor: [17, 17] }); const marker = L.marker(point, { icon }); marker.bindTooltip(tooltip(driver.name + (driver.healthy ? ' · Vị trí mới' : ' · Vị trí cũ'))); markers.addLayer(marker); }
 for (const [p, type] of [[props.pickup, 'pickup'], [props.dropoff, 'dropoff']] as const) if (p) { bounds.push([p.latitude, p.longitude]); const marker = L.marker([p.latitude, p.longitude], { icon: L.divIcon({ className: '', html: `<div class="map-pin ${type}"><i class="pi ${type === 'pickup' ? 'pi-circle-fill' : 'pi-map-marker'}"></i></div>`, iconSize: [32, 32], iconAnchor: [16, 16] }) }); marker.bindTooltip(tooltip(p.address)); markers.addLayer(marker); }
 if (props.pickup && props.dropoff) markers.addLayer(L.polyline([[props.pickup.latitude, props.pickup.longitude], [props.dropoff.latitude, props.dropoff.longitude]], { color: '#159367', weight: 3, dashArray: '7 8', opacity: .6 }));
 if (bounds.length > 1 && (props.pickup || props.dropoff)) map.fitBounds(bounds, { padding: [45, 45], maxZoom: 14 });
}
onMounted(() => { if (!host.value) return; map = L.map(host.value, { zoomControl: false, scrollWheelZoom: false }).setView([10.788, 106.699], 13); const tile = L.tileLayer(import.meta.env.VITE_MAP_TILE_URL ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>', maxZoom: 19 }); tile.on('tileerror', () => { tileError.value = true; }); tile.on('tileload', () => { tileError.value = false; }); tile.addTo(map); L.control.zoom({ position: 'bottomright' }).addTo(map); markers = L.layerGroup().addTo(map); render(); observer = new ResizeObserver(() => map?.invalidateSize()); observer.observe(host.value); });
watch(() => [props.drivers, props.pickup, props.dropoff], render, { deep: true }); onUnmounted(() => { observer?.disconnect(); map?.remove(); });
</script>
<template><div class="map-wrap" :class="{ compact }"><div ref="host" class="leaflet-host" aria-label="Bản đồ khu vực hoạt động TP. Hồ Chí Minh"></div><span v-if="tileError" class="map-offline"><i class="pi pi-wifi"></i> Không tải được nền bản đồ</span><div class="map-location"><i class="pi pi-map-marker"></i> TP. Hồ Chí Minh <span>Vùng pilot</span></div><div v-if="pickup && dropoff" class="map-route-note">Đường nối minh họa điểm đón/đến</div></div></template>
