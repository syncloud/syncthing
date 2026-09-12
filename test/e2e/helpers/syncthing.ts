import { Page, expect } from '@playwright/test'

const user = process.env.PLAYWRIGHT_DEVICE_USER ?? 'user'
const password = process.env.PLAYWRIGHT_DEVICE_PASSWORD ?? 'Password1'

export async function login(page: Page) {
  await page.goto('/')
  const username = page.locator('#user')
  if (await username.isVisible().catch(() => false)) {
    await username.fill(user)
    await page.locator('#password').fill(password)
    await page.locator('#submit').click()
  }
  await expectAtDashboard(page)
}

export async function expectAtDashboard(page: Page) {
  await expect(page.locator('#device-this')).toBeVisible()
}

export async function openSettings(page: Page) {
  await page.locator('.action-menu > a.dropdown-toggle').click()
  await page.locator('.action-menu .dropdown-menu').getByText('Settings', { exact: true }).click()
  await expect(page.locator('#DeviceName')).toBeVisible()
}

export async function setDeviceName(page: Page, name: string) {
  await openSettings(page)
  await page.locator('#DeviceName').fill(name)
  await page.locator('#settings .modal-footer button.btn-primary').click()
  await expect(page.locator('#settings')).toBeHidden()
}

export async function expectDeviceName(page: Page, name: string) {
  await expect(page).toHaveTitle(new RegExp(`^${name} \\| Syncthing$`))
  await openSettings(page)
  await expect(page.locator('#DeviceName')).toHaveValue(name)
}
