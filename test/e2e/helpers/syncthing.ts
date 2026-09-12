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
    console.log(`[${label}] ${path} -> ${result}`)
  }
  console.log(`[${label}] #user count=${await page.locator('#user').count()}`)
  console.log(`[${label}] #submit count=${await page.locator('#submit').count()}`)
  const html = await page.content().catch(() => '')
  console.log(`[${label}] html=\n${html.slice(0, 8000)}`)
}

function dashboardLocator(page: Page): Locator {
  return page.getByRole('heading', { name: 'This Device' }).or(page.locator('#device-this'))
}

export async function login(page: Page) {
  await page.goto('/')
  const username = page.locator('#user')

  try {
    await expect(username.or(dashboardLocator(page)).first()).toBeVisible()
  } catch (e) {
    await dump(page, 'neither-login-nor-dashboard')
    throw e
  }

  if (await username.isVisible()) {
    await username.fill(user)
    await page.locator('#password').fill(password)
    await page.locator('#submit').click()
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
  if (await deviceName.isVisible().catch(() => false)) {
    return
  }
  try {
    await page.locator('.action-menu > a.dropdown-toggle').click()
    await page.locator('.action-menu .dropdown-menu').getByText('Settings', { exact: true }).click()
    await expect(deviceName).toBeVisible()
  } catch (e) {
    await dump(page, 'settings-not-reachable')
    throw e
  }
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
