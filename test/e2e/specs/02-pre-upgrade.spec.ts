import { test } from '@playwright/test'
import { shoot } from '../helpers/screenshot'
import { login, setDeviceName, expectDeviceName } from '../helpers/syncthing'

const deviceName = 'pre-upgrade-device'

test.describe('syncthing pre-upgrade', () => {
  test('change device name through the settings UI', async ({ page }, testInfo) => {
    await login(page)
    await setDeviceName(page, deviceName)
    await shoot(page, testInfo, 'pre-upgrade-saved')
    await page.reload()
    await login(page)
    await expectDeviceName(page, deviceName)
    await shoot(page, testInfo, 'pre-upgrade-verified')
  })
})
