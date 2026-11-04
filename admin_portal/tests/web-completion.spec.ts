import { test, expect, type Page, type APIResponse } from '@playwright/test';

// Read-only scenarios share a staff session so the complete suite respects the
// real development-login limiter (15 requests per minute per IP).
const sessions = new Map<string, unknown>();
async function loginAs(page: Page, role: string, route = '/') {
  if (!sessions.has(role)) {
    const response = await page.request.post('http://127.0.0.1:5080/api/v1/auth/development', {
      data: { userId: 'staff-' + role, deviceId: 'web-completion-' + crypto.randomUUID() },
    });
    expect(response.ok(), `Development login returned ${response.status()}: ${await response.text()}`).toBeTruthy();
    sessions.set(role, await response.json());
  }
  await page.addInitScript(session => sessionStorage.setItem('grap.session', JSON.stringify(session)), sessions.get(role));
  await page.goto(route);
}

for (const role of ['OperationsAdmin', 'Dispatcher', 'DriverReviewer', 'SupportAgent', 'FinanceOperator', 'FinanceApprover', 'SecurityAdmin']) {
  test(`${role} opens dashboard and profile without forbidden requests`, async ({ page }) => {
    const failures: string[] = [];
    page.on('response', r => { if (r.url().includes('/api/v1/admin/') && r.status() >= 400) failures.push(r.url()); });
    await loginAs(page, role);
    await expect(page.locator('.welcome-banner')).toBeVisible();
    await expect(page.locator('.query-state.error')).toHaveCount(0);
    if (role === 'OperationsAdmin') await expect(page.locator('.nav-item[href="/finance"]')).toHaveCount(0);
    if (role === 'DriverReviewer') await expect(page.locator('.nav-item[href="/rides"]')).toHaveCount(0);
    if (role === 'SecurityAdmin') await expect(page.locator('.nav-item[href="/drivers"]')).toHaveCount(0);
    await page.locator('.nav-item[href="/settings"]').click();
    await expect(page.getByRole('heading', { name: 'Hồ sơ nhân sự' })).toBeVisible();
    await expect(page.locator('.query-state.error')).toHaveCount(0);
    expect(failures).toEqual([]);
  });
}

test('direct link to an unavailable module explains access and offers a working return', async ({ page }) => {
  await loginAs(page, 'OperationsAdmin', '/finance');
  await expect(page.getByRole('heading', { name: 'Bạn chưa có quyền truy cập' })).toBeVisible();
  await page.getByRole('link', { name: 'Về không gian làm việc' }).click();
  await expect(page.locator('.welcome-banner')).toBeVisible();
});

test('changing a filter during the first request eventually shows the latest filter', async ({ page }) => {
  let release!: () => void;
  const held = new Promise<void>(resolve => { release = resolve; });
  let started!: () => void;
  const firstRequest = new Promise<void>(resolve => { started = resolve; });
  let count = 0;
  await page.route(url => url.pathname === '/api/v1/admin/drivers', async route => {
    const response = await route.fetch();
    if (++count === 1) { started(); await held; }
    await route.fulfill({ response });
  });
  await loginAs(page, 'OperationsAdmin', '/drivers');
  await firstRequest;
  await page.getByRole('textbox', { name: 'Tìm tài xế' }).fill('khong-co-tai-xe-' + crypto.randomUUID());
  // Let the public search debounce expire while the original HTTP response is held.
  await page.waitForTimeout(450);
  release();
  await expect(page.getByText('Không có tài xế phù hợp.')).toBeVisible();
  expect(count).toBeGreaterThanOrEqual(2);
});

test('ride links update an already open list and a failed detail does not show the previous timeline', async ({ page }) => {
  await loginAs(page, 'Dispatcher', '/rides');
  await page.locator('.ride-code').first().click();
  await expect(page.locator('.timeline-item').first()).toBeVisible();
  await page.getByRole('dialog').getByRole('button', { name: 'Close', exact: true }).click();
  await page.route('**/api/v1/rides/missing-ride**', route => route.fulfill({ status: 404, json: { title: 'Không tìm thấy chuyến kiểm thử.' } }));
  // Change only the query through Vue Router, retaining the mounted list component.
  await page.evaluate(async () => {
    // The app's global search uses router navigation; use the app router exposed on its root.
    const root = document.querySelector('#app') as unknown as { __vue_app__: { config: { globalProperties: { $router: { push(path: string): Promise<void> } } } } };
    await root.__vue_app__.config.globalProperties.$router.push('/rides?id=missing-ride');
  });
  await expect(page.getByRole('dialog').getByText('Không tìm thấy chuyến kiểm thử.')).toBeVisible();
  await expect(page.locator('.timeline-item')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Hủy theo yêu cầu hỗ trợ' })).toHaveCount(0);
});

test('support offers valid transitions and keeps closed conversations read only', async ({ page }) => {
  const tickets = [
    { id: 'ui-open', subject: 'Phiếu mới cần tiếp nhận', status: 'OPEN', priority: 'NORMAL', requesterName: 'Khách kiểm thử', createdAt: new Date().toISOString(), version: 1 },
    { id: 'ui-closed', subject: 'Phiếu đã đóng để tra cứu', status: 'CLOSED', priority: 'NORMAL', requesterName: 'Khách kiểm thử', createdAt: new Date().toISOString(), version: 1 },
  ];
  await page.route(url => url.pathname === '/api/v1/admin/support/tickets', route => {
    const status = new URL(route.request().url()).searchParams.get('status');
    return route.fulfill({ json: { items: tickets.filter(t => !status || t.status === status) } });
  });
  await page.route('**/api/v1/support/tickets/ui-*', route => route.fulfill({ json: {
    ticket: tickets.find(t => route.request().url().endsWith(t.id)),
    messages: [{ id: 'message', authorId: 'customer', body: 'Nội dung hội thoại được lưu lại.', createdAt: new Date().toISOString() }],
  } }));
  await loginAs(page, 'SupportAgent', '/support');
  await page.getByText('Phiếu mới cần tiếp nhận', { exact: true }).click();
  await page.getByRole('dialog').locator('.ticket-transition .p-select').click();
  await expect(page.getByRole('option', { name: 'Tiếp nhận xử lý' })).toBeVisible();
  await expect(page.getByRole('option')).toHaveCount(1);
  await page.keyboard.press('Escape');
  await page.getByRole('dialog').getByRole('button', { name: 'Close', exact: true }).click();
  await page.getByRole('combobox', { name: 'Lọc trạng thái yêu cầu' }).click();
  await page.getByRole('option', { name: 'Đã đóng', exact: true }).click();
  await expect(page.getByText('Phiếu mới cần tiếp nhận', { exact: true })).toHaveCount(0);
  await page.getByText('Phiếu đã đóng để tra cứu', { exact: true }).click();
  await expect(page.getByRole('dialog').getByText('Nội dung hội thoại được lưu lại.')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Gửi phản hồi' })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Lưu trạng thái' })).toHaveCount(0);
});

test('operations screens and a ride dialog fit narrow and landscape viewports', async ({ page }) => {
  test.setTimeout(60000);
  // Reuse the first successful API snapshots while checking layout at multiple
  // sizes, avoiding repeated backend reads solely for viewport changes.
  const snapshots = new Map<string, APIResponse>();
  await page.route('**/api/v1/**', async route => {
    if (route.request().method() !== 'GET') return route.continue();
    const url = route.request().url();
    let response = snapshots.get(url);
    if (!response) {
      response = await route.fetch();
      expect(response.ok(), `Layout snapshot ${url}: ${response.status()}`).toBeTruthy();
      snapshots.set(url, response);
    }
    await route.fulfill({ response });
  });
  await loginAs(page, 'OperationsAdmin');
  await expect(page.locator('.welcome-banner')).toBeVisible();
  await page.locator('.revenue-chart canvas').waitFor();
  await page.waitForTimeout(1100);
  await page.screenshot({ path: '../docs/qa/web-dashboard-desktop.png', fullPage: true, animations: 'disabled' });
  for (const size of [{ width: 320, height: 640 }, { width: 390, height: 844 }, { width: 640, height: 320 }]) {
    await page.setViewportSize(size);
    for (const route of ['/', '/rides', '/drivers', '/customers', '/pricing', '/support', '/audit', '/settings']) {
      await page.getByRole('button', { name: 'Mở menu' }).click();
      await page.locator(`.nav-item[href="${route}"]`).click();
      await expect(page.locator('h1')).toBeVisible();
      await expect(page.locator('.query-state:has(.pi-spinner)')).toHaveCount(0);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${route} at ${size.width}`).toBeTruthy();
    }
  }
  await page.getByRole('button', { name: 'Mở menu' }).click();
  await expect(page.getByRole('button', { name: 'Đóng menu' })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('button', { name: 'Mở menu' })).toBeFocused();
  await expect(page.locator('#main-sidebar')).toHaveAttribute('inert', '');
  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole('button', { name: 'Mở menu' }).click();
  await page.locator('.nav-item[href="/"]').click();
  await expect(page.locator('.welcome-banner')).toBeVisible();
  await page.waitForTimeout(1100);
  await page.screenshot({ path: '../docs/qa/web-dashboard-mobile.png', fullPage: true, animations: 'disabled' });
  await page.getByRole('button', { name: 'Mở menu' }).click();
  await page.locator('.nav-item[href="/rides"]').click();
  await page.locator('.ride-code').first().click();
  const dialog = page.getByRole('dialog'); await expect(page.locator('.timeline-item').first()).toBeVisible();
  const box = await dialog.boundingBox(); expect(box!.x).toBeGreaterThanOrEqual(0); expect(box!.x + box!.width).toBeLessThanOrEqual(390);
  expect(await dialog.evaluate(el => el.scrollWidth <= el.clientWidth)).toBeTruthy();
  await page.screenshot({ path: '../docs/qa/web-ride-mobile.png', fullPage: true, animations: 'disabled' });
});


test('audit pages support returning to previous results and a fresh search', async ({ page }) => {
  await page.route(url => url.pathname === '/api/v1/admin/audit-logs', route => {
    const params = new URL(route.request().url()).searchParams;
    const second = params.has('cursor');
    return route.fulfill({ json: { items: [{ id: second ? 'older' : 'newest', action: second ? 'older.action' : params.get('q') ? 'matching.action' : 'newest.action', actorName: 'Nhân sự', createdAt: new Date().toISOString() }], nextCursor: second ? null : 'older-page' } });
  });
  await loginAs(page, 'SecurityAdmin', '/audit');
  await expect(page.getByText('newest.action', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Tải trang tiếp' }).click();
  await expect(page.getByText('older.action', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Trang trước' }).click();
  await expect(page.getByText('newest.action', { exact: true })).toBeVisible();
  await page.getByRole('textbox', { name: 'Tìm nhật ký' }).fill('matching');
  await page.getByRole('button', { name: 'Tìm nhật ký' }).click();
  await expect(page.getByText('matching.action', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Trang trước' })).toBeDisabled();
});

test('finance tabs and controls fit a 320px viewport', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 });
  await loginAs(page, 'FinanceOperator', '/finance');
  await expect(page.getByRole('button', { name: 'Làm mới', exact: true })).toBeVisible();
  for (const name of ['Khoản thu chuyến', 'Số dư & công nợ', 'Sổ cái', 'Đề nghị nộp tiền']) {
    await page.getByRole('button', { name, exact: true }).click();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), name).toBeTruthy();
  }
  await page.getByRole('button', { name: 'Lập đề nghị nộp công nợ', exact: true }).click();
  const box = await page.getByRole('dialog').boundingBox();
  expect(box!.x).toBeGreaterThanOrEqual(0); expect(box!.x + box!.width).toBeLessThanOrEqual(320);
});
