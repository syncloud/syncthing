from os.path import dirname, join
from subprocess import check_output

import pytest
from selenium.webdriver.common.by import By
from syncloudlib.integration.hosts import add_host_alias

DIR = dirname(__file__)
TMP_DIR = '/tmp/syncloud/ui'


@pytest.fixture(scope="session")
def module_setup(request, device, artifact_dir, ui_mode):
    def module_teardown():
        device.activated()
        device.run_ssh('mkdir -p {0}'.format(TMP_DIR), throw=False)
        device.run_ssh('journalctl > {0}/journalctl.ui.{1}.log'.format(TMP_DIR, ui_mode), throw=False)
        device.run_ssh('cp /var/log/syslog {0}/syslog.ui.{1}.log'.format(TMP_DIR, ui_mode), throw=False)
        device.scp_from_device('{0}/*'.format(TMP_DIR), join(artifact_dir, 'log'))
        check_output('chmod -R a+r {0}'.format(artifact_dir), shell=True)

    request.addfinalizer(module_teardown)


def test_start(module_setup, app, device_host, domain):
    add_host_alias(app, device_host, domain)


def test_login(selenium, device_user, device_password):
    selenium.open_app()

    selenium.find_by_id("user").send_keys(device_user)
    selenium.find_by_id("password").send_keys(device_password)
    selenium.screenshot('login')
    selenium.find_by_xpath("//button[@type='submit']").click()
    assert not selenium.exists_by(By.XPATH, "//span[text()='GUI Authentication: Set User and Password']")
    assert not selenium.exists_by(By.XPATH, "//span[text()='Automatic Crash Reporting']")
    selenium.find_by(By.XPATH, "//h3[text()='This Device']")
    selenium.screenshot('index')


def test_teardown(driver):
    driver.quit()
