import { test } from '@playwright/test'
import { shoot } from '../helpers/screenshot'
import { login } from '../helpers/syncthing'

test.describe('syncthing smoke', () => {
  test('log in and reach the dashboard', async ({ page }, testInfo) => {
    await login(page)
    await shoot(page, testInfo, 'dashboard')
  })
})
