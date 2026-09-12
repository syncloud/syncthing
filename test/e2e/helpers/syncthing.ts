import { Page, Locator, expect } from '@playwright/test'

const user = process.env.PLAYWRIGHT_DEVICE_USER ?? 'user'
const password = process.env.PLAYWRIGHT_DEVICE_PASSWORD ?? 'Password1'

const probePaths = ['/rest/noauth/health', '/rest/svc/lang', '/rest/system/status', '/rest/system/config']

async function dump(page: Page, label: string) {
  console.log(`[${label}] url=${page.url()}`)
  console.log(`[${label}] title=${await page.title().catch(() => '?')}`)
  for (const path of probePaths) {
    const result = await page
      .evaluate(async (p) => {
        try {
          const r = await fetch(p, { credentials: 'same-origin' })
          return `${r.status} ${(await r.text()).slice(0, 200)}`
        } catch (err) {
          return `fetch error: ${String(err)}`
        }
      }, path)
      .catch((err) => `evaluate failed: ${String(err)}`)
    console.log(`[${label}] ${path} (no csrf header) -> ${result}`)
  }
  console.log(`[${label}] login form count=${await loginForm(page).count()}`)
  const html = await page.content().catch(() => '')
  console.log(`[${label}] html=\n${html.slice(0, 8000)}`)
}

function loginForm(page: Page): Locator {
  return page.locator('form[ng-submit="authenticatePassword()"]')
}

function dashboardLocator(page: Page): Locator {
  return page.getByRole('heading', { name: 'This Device' }).or(page.locator('#device-this'))
}

export async function login(page: Page) {
  await page.goto('/')
  const form = loginForm(page)
  const username = form.locator('#user')

  try {
    await expect(username.or(dashboardLocator(page)).first()).toBeVisible()
  } catch (e) {
    await dump(page, 'neither-login-nor-dashboard')
    throw e
  }

  if (await username.isVisible()) {
    await username.fill(user)
    await form.locator('#password').fill(password)
    await form.locator('#submit').click()
  }
  await expectAtDashboard(page)
}

export async function expectAtDashboard(page: Page) {
  try {
    await expect(dashboardLocator(page).first()).toBeVisible()
  } catch (e) {
    await dump(page, 'dashboard-not-found')
    throw e
  }
}

function settingsModal(page: Page): Locator {
  return page.locator('.modal', { has: page.locator('#DeviceName') })
}

export async function openSettings(page: Page) {
  const deviceName = page.locator('#DeviceName')
  const actions = page
    .locator('li.action-menu')
    .filter({ has: page.locator('a[ng-click="showSettings()"]') })

  for (let attempt = 0; attempt < 3; attempt++) {
    if (await deviceName.isVisible().catch(() => false)) {
      return
    }
    const toggle = actions.locator('a.dropdown-toggle')
    const item = actions.locator('a[ng-click="showSettings()"]')
    try {
      await toggle.click()
      await expect(item).toBeVisible({ timeout: 5_000 })
      await item.click()
      await expect(deviceName).toBeVisible({ timeout: 10_000 })
      return
    } catch {
      await page.keyboard.press('Escape').catch(() => undefined)
    }
  }

  await dump(page, 'settings-not-reachable')
  throw new Error('settings modal did not open after 3 attempts')
}

export async function setDeviceName(page: Page, name: string) {
  await openSettings(page)
  await page.locator('#DeviceName').fill(name)
  await settingsModal(page).locator('.modal-footer button.btn-primary').click()
  await expect(page.locator('#DeviceName')).toBeHidden()
}

export async function expectDeviceName(page: Page, name: string) {
  await expect(page).toHaveTitle(new RegExp(`^${name} \\| Syncthing$`))
  await openSettings(page)
  await expect(page.locator('#DeviceName')).toHaveValue(name)
}
