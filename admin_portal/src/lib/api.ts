import { ref } from 'vue';
import type { Data, User } from './types';
const stored = sessionStorage.getItem('grap.session');
let tokens: Data | null = null;
try { tokens = stored ? JSON.parse(stored) : null; } catch { sessionStorage.removeItem('grap.session'); }
export const currentUser = ref<User | null>(tokens?.user ?? null);
export class ApiError extends Error { constructor(public code: string, message: string, public status: number, public traceId?: string) { super(message); } }
let refreshFlight: Promise<void> | undefined;
const pending = new Map<string, string>();
const base = import.meta.env.VITE_API_BASE_URL ?? '';
export function setSession(session: Data | null) { tokens = session; currentUser.value = session?.user ?? null; pending.clear(); if (session) sessionStorage.setItem('grap.session', JSON.stringify(session)); else sessionStorage.removeItem('grap.session'); }
async function refresh() {
  if (!refreshFlight) refreshFlight = (async () => { const response = await fetch(base + '/api/v1/auth/token/refresh', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken: tokens?.refreshToken }) }); if (!response.ok) { setSession(null); throw new ApiError('SESSION_EXPIRED', 'Phiên đã hết hạn. Vui lòng đăng nhập lại.', 401); } const session = await response.json(); tokens = session; currentUser.value = session.user; sessionStorage.setItem('grap.session', JSON.stringify(session)); })().finally(() => { refreshFlight = undefined; });
  return refreshFlight;
}
export async function api<T = Data>(path: string, options: { method?: string; body?: unknown; idempotent?: boolean; signal?: AbortSignal } = {}): Promise<T> {
  const method = options.method ?? 'GET'; const payload = options.body === undefined ? undefined : JSON.stringify(options.body); const intent = currentUser.value?.id + method + path + payload;
  let key: string | undefined;
  if (options.idempotent) { key = pending.get(intent) ?? crypto.randomUUID(); pending.set(intent, key); }
  const run = () => fetch(base + '/api/v1' + path, { method, body: payload, signal: options.signal, headers: { 'Content-Type': 'application/json', ...(tokens?.accessToken ? { Authorization: 'Bearer ' + tokens.accessToken } : {}), ...(key ? { 'Idempotency-Key': key } : {}) } });
  let response: Response;
  try { response = await run(); if (response.status === 401 && tokens?.refreshToken && !path.startsWith('/auth/')) { await refresh(); response = await run(); } }
  catch (error) { if (error instanceof ApiError || error instanceof DOMException && error.name === 'AbortError') throw error; throw new ApiError('NETWORK_ERROR', 'Không kết nối được máy chủ. Giữ nguyên thao tác và thử lại khi có mạng.', 0); }
  const data = await response.json().catch(() => ({}));
  if (response.status < 500 && data.code !== 'OPERATION_IN_PROGRESS') pending.delete(intent);
  if (!response.ok) throw new ApiError(data.code ?? 'REQUEST_FAILED', data.title ?? (response.status === 403 ? 'Tài khoản hiện tại không có quyền truy cập phân hệ này.' : 'Không thể xử lý yêu cầu.'), response.status, data.traceId);
  return data as T;
}
export async function login(userId: string) { setSession(await api('/auth/development', { method: 'POST', body: { userId, deviceId: 'web-' + crypto.randomUUID() } })); }
export async function logout() { try { await api('/auth/logout', { method: 'POST' }); } finally { setSession(null); } }
export async function accessToken() { if (tokens && new Date(tokens.expiresAt).getTime() < Date.now() + 30_000) await refresh(); return tokens?.accessToken ?? ''; }
export function downloadCsv(filename: string, rows: Data[], columns: Record<string, string>) {
  const cell = (v: unknown) => { let s = String(v ?? ''); if (/^[=+@\-\t\r]/.test(s)) s = "'" + s; return '"' + s.replaceAll('"', '""') + '"'; };
  const content = '\uFEFF' + [Object.values(columns).map(cell).join(','), ...rows.map(row => Object.keys(columns).map(key => cell(row[key])).join(','))].join('\r\n');
  const url = URL.createObjectURL(new Blob([content], { type: 'text/csv;charset=utf-8;' })); const link = document.createElement('a'); link.href = url; link.download = filename; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
}
