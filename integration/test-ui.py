import os
import shutil
from os.path import dirname, join, exists
import time
import pytest
from selenium import webdriver
from selenium.common.exceptions import WebDriverException
from selenium.webdriver.common.by import By
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.firefox.firefox_binary import FirefoxBinary
from selenium.webdriver.support.ui import WebDriverWait
from syncloudlib.integration.hosts import add_host_alias
from syncloudlib.integration.screenshots import screenshots
from subprocess import check_output

DIR = dirname(__file__)
screenshot_dir = join(DIR, 'screenshot')
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


def test_start(module_setup, app, device_host):
    if not exists(screenshot_dir):
        os.mkdir(screenshot_dir)

    add_host_alias(app, device_host)


def test_login(driver, app_domain, ui_mode, device_user, device_password):

    driver.get("https://{0}:{1}@{2}".format(device_user, device_password, app_domain))
    time.sleep(10)
    screenshots(driver, screenshot_dir, 'login-' + ui_mode)
