import { test } from '@playwright/test'
import { shoot } from '../helpers/screenshot'
import { login, setDeviceName, expectDeviceName } from '../helpers/syncthing'

const preUpgradeName = 'pre-upgrade-device'
const postUpgradeName = 'post-upgrade-device'

test.describe('syncthing post-upgrade', () => {
  test('settings set before the upgrade survived it', async ({ page }, testInfo) => {
    await login(page)
    await expectDeviceName(page, preUpgradeName)
    await shoot(page, testInfo, 'post-upgrade-verified')
  })

  test('settings are still editable after the upgrade', async ({ page }, testInfo) => {
    await login(page)
    await setDeviceName(page, postUpgradeName)
    await page.reload()
    await login(page)
    await expectDeviceName(page, postUpgradeName)
    await shoot(page, testInfo, 'post-upgrade-editable')
  })
})
