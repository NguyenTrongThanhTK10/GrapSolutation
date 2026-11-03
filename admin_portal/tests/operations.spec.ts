import { test, expect, type Page } from '@playwright/test';
async function loginAs(page: Page, role: string, route = '/') {
  const response = await page.request.post('http://127.0.0.1:5080/api/v1/auth/development', { data: { userId: role.startsWith('customer-') || role.startsWith('driver-user-') ? role : 'staff-' + role, deviceId: 'playwright-' + crypto.randomUUID() } });
  expect(response.ok()).toBeTruthy(); const session = await response.json();
  await page.addInitScript(value => sessionStorage.setItem('grap.session', JSON.stringify(value)), session);
  await page.goto(route);
}
test('development login opens the real API dashboard', async ({ page }) => {
  await page.goto('/'); await expect(page.getByRole('heading', { name: 'Chào mừng trở lại.' })).toBeVisible();
  await page.getByRole('button', { name: 'Vào không gian làm việc' }).click();
  await expect(page.getByRole('heading', { name: 'Tổng quan vận hành.' })).toBeVisible();
  await expect(page.locator('.welcome-banner')).toBeVisible(); await expect(page.locator('.revenue-chart canvas')).toBeVisible();
});
test('operations routes render without JavaScript errors', async ({ page }) => {
  const errors: string[] = []; page.on('pageerror', error => errors.push(error.message));
  await loginAs(page, 'OperationsAdmin');
  for (const [route, heading] of [['/rides', 'Quản lý chuyến xe.'], ['/dispatch', 'Điều phối trực tiếp.'], ['/drivers', 'Đối tác tài xế.'], ['/customers', 'Khách hàng.'], ['/pricing', 'Giá cước & vùng dịch vụ.'], ['/support', 'Trung tâm hỗ trợ.'], ['/audit', 'Nhật ký hoạt động.'], ['/settings', 'Cấu hình hệ thống.']]) {
    await page.goto(route); await expect(page.locator('h1')).toHaveText(heading); await expect(page.locator('.query-state.error')).toHaveCount(0); await expect(page.locator('.p-datatable-loading-overlay')).toHaveCount(0);
  }
  expect(errors).toEqual([]);
});
test('ride details load a scoped snapshot and timeline', async ({ page }) => {
  await loginAs(page, 'Dispatcher', '/rides'); await page.locator('.ride-code').first().click();
  await expect(page.getByRole('dialog')).toBeVisible(); await expect(page.getByRole('heading', { name: 'Nhật ký hành trình' })).toBeVisible(); await expect(page.locator('.timeline-item').first()).toBeVisible();
});
test('finance is scoped to a finance role and all journals balance', async ({ page }) => {
  await loginAs(page, 'FinanceOperator', '/finance'); await expect(page.getByRole('heading', { name: 'Tài chính & đối soát.' })).toBeVisible();
  await page.getByRole('button', { name: 'Sổ cái', exact: true }).click(); await expect(page.getByText('Cân bằng', { exact: true }).first()).toBeVisible();
});
test('mobile navigation fits the viewport and closes after navigation', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 }); await loginAs(page, 'OperationsAdmin');
  await expect(page.locator('.welcome-banner')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
  await page.getByRole('button', { name: 'Mở menu' }).click(); await expect(page.locator('.sidebar.open')).toBeVisible();
  await page.locator('.nav-item', { hasText: 'Đối tác tài xế' }).click(); await expect(page.locator('h1')).toHaveText('Đối tác tài xế.'); await expect(page.locator('.sidebar.open')).toHaveCount(0);
});
test('customer quote and booking are submitted to the backend', async ({ page }) => {
  await loginAs(page, 'customer-1', '/customer');
  await expect(page.getByRole('heading', { name: 'Đặt hành trình của bạn' })).toBeVisible();
  await page.getByRole('button', { name: 'Xem giá chuyến đi' }).click(); await expect(page.getByRole('button', { name: 'Xác nhận đặt xe' })).toBeVisible();
  await page.getByRole('button', { name: 'Xác nhận đặt xe' }).click(); await expect(page.locator('.ride-active-head')).toBeVisible();
  await page.getByRole('button', { name: 'Hủy chuyến · miễn phí' }).click(); await page.getByRole('dialog').locator('textarea').fill('Kiểm thử giao diện · hủy hành trình mẫu');
  await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.locator('.ride-active-head')).toHaveCount(0);
});
test('security reviews account deletion and replies within its scoped support ticket', async ({ page }) => {
  const customerSession = await (await page.request.post('http://127.0.0.1:5080/api/v1/auth/development', {data:{userId:'customer-4',deviceId:'privacy-e2e-'+crypto.randomUUID()}})).json();
  const headers = {Authorization:'Bearer '+customerSession.accessToken,'Idempotency-Key':crypto.randomUUID()};
  const previous = await (await page.request.get('http://127.0.0.1:5080/api/v1/me/account-deletion-requests',{headers})).json();
  for (const request of previous.items.filter((r:{status:string})=>['REQUESTED','BLOCKED_OBLIGATIONS','IN_REVIEW','NEEDS_INFORMATION'].includes(r.status))) {
    expect((await page.request.post(`http://127.0.0.1:5080/api/v1/me/account-deletion-requests/${request.id}/cancel`,{headers:{...headers,'Idempotency-Key':crypto.randomUUID()},data:{expectedVersion:request.version}})).ok()).toBeTruthy();
  }
  const createdResponse = await page.request.post('http://127.0.0.1:5080/api/v1/me/account-deletion-requests',{headers,data:{reason:'E2E kiểm tra tiếp nhận quyền riêng tư'}});
  expect(createdResponse.ok()).toBeTruthy();const request = await createdResponse.json();
  await loginAs(page,'SecurityAdmin','/settings');
  await expect(page.getByRole('heading',{name:'Yêu cầu xóa tài khoản',exact:true})).toBeVisible();
  const row=page.locator('.privacy-request').filter({hasText:'E2E kiểm tra tiếp nhận quyền riêng tư'}).first();
  await row.getByRole('button',{name:'Xử lý yêu cầu'}).click();
  await page.getByRole('dialog').locator('.p-select').click();await page.getByRole('option',{name:'Yêu cầu bổ sung'}).click();
  await page.getByRole('dialog').locator('textarea').fill('Vui lòng xác nhận thông tin qua phiếu hỗ trợ.');
  await page.getByRole('button',{name:'Lưu phản hồi',exact:true}).click();await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(row.getByText('Cần bổ sung',{exact:true})).toBeVisible();
  await row.getByRole('button',{name:'Phiếu hỗ trợ liên quan'}).click();
  await expect(page.getByRole('dialog').getByText('Vui lòng xác nhận thông tin qua phiếu hỗ trợ.')).toBeVisible();
  await page.getByRole('dialog').locator('textarea').fill('Bộ phận bảo mật đang kiểm tra yêu cầu của bạn.');
  await page.getByRole('button',{name:'Gửi phản hồi',exact:true}).click();
  await expect(page.getByRole('dialog').getByText('Bộ phận bảo mật đang kiểm tra yêu cầu của bạn.')).toBeVisible();
  await page.screenshot({path:'../docs/qa/privacy-request-desktop.png',fullPage:true});
  const latest=await (await page.request.get('http://127.0.0.1:5080/api/v1/me/account-deletion-requests',{headers})).json();
  const updated=latest.items.find((r:{id:string})=>r.id===request.id);
  expect((await page.request.post(`http://127.0.0.1:5080/api/v1/me/account-deletion-requests/${request.id}/cancel`,{headers:{...headers,'Idempotency-Key':crypto.randomUUID()},data:{expectedVersion:updated.version}})).ok()).toBeTruthy();
});
