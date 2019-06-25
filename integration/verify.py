import json
import os
import sys
from os import listdir
from os.path import dirname, join, exists, abspath, isdir
import time
from subprocess import check_output
import pytest
import shutil

from syncloudlib.integration.loop import loop_device_add, loop_device_cleanup
from syncloudlib.integration.ssh import run_scp, run_ssh
from syncloudlib.integration.installer import local_install, wait_for_installer, wait_for_rest, local_remove
from syncloudlib.integration.hosts import add_host_alias

import requests

DIR = dirname(__file__)
TMP_DIR = '/tmp/syncloud'


@pytest.fixture(scope="session")
def module_setup(request, device_host, data_dir, platform_data_dir, app_dir, device, log_dir):
    request.addfinalizer(lambda: module_teardown(device_host, data_dir, platform_data_dir, app_dir, device, log_dir))


def module_teardown(device_host, data_dir, platform_data_dir, app_dir, device, log_dir):
    platform_log_dir = join(log_dir, 'platform_log')
    os.mkdir(platform_log_dir)
    run_scp('root@{0}:{1}/log/* {2}'.format(device_host, platform_data_dir, platform_log_dir), throw=False)
    
    app_log_dir  = join(log_dir, 'syncthing_log')
    os.mkdir(app_log_dir )
    device.scp_from_device('{0}/log/*.log'.format(data_dir), app_log_dir, throw=False)

    device.run_ssh('mkdir {0}'.format(TMP_DIR))
    device.run_ssh('ls -la {0} > {1}/app.data.ls.log'.format(data_dir, TMP_DIR), throw=False)
    device.run_ssh('ls -la {0}/syncthing/config > {1}/config.ls.log'.format(data_dir, TMP_DIR), throw=False)
    device.run_ssh('{0}/syncthing/syncthing --help > {1}/syncthing.help.log 2>&1'.format(app_dir, TMP_DIR), throw=False)
    device.run_ssh('{0}/syncthing/syncthing -version > {1}/syncthing.version.log 2>&1'.format(app_dir, TMP_DIR), throw=False)
    device.run_ssh('top -bn 1 -w 500 -c > {0}/top.log'.format(TMP_DIR), throw=False)
    device.run_ssh('ps auxfw > {0}/ps.log'.format(TMP_DIR), throw=False)
    device.run_ssh('systemctl status snap.syncthing.syncthing > {0}/syncthing.status.log'.format(TMP_DIR), throw=False)
    device.run_ssh('netstat -nlp > {0}/netstat.log'.format(TMP_DIR), throw=False)
    device.run_ssh('journalctl | tail -500 > {0}/journalctl.log'.format(TMP_DIR), throw=False)
    device.run_ssh('tail -500 /var/log/syslog > {0}/syslog.log'.format(TMP_DIR), throw=False)
    device.run_ssh('tail -500 /var/log/messages > {0}/messages.log'.format(TMP_DIR), throw=False)    
    device.run_ssh('ls -la /snap > {0}/snap.ls.log'.format(TMP_DIR), throw=False)    
    device.run_ssh('ls -la /snap/syncthing > {0}/snap.syncthing.ls.log'.format(TMP_DIR), throw=False)    
    device.run_ssh('ls -la /var/snap > {0}/var.snap.ls.log'.format(TMP_DIR), throw=False)    
    device.run_ssh('ls -la /var/snap/syncthing > {0}/var.snap.syncthing.ls.log'.format(TMP_DIR), throw=False)    
    device.run_ssh('ls -la /var/snap/syncthing/common > {0}/var.snap.syncthing.common.ls.log'.format(TMP_DIR), throw=False)    
    device.run_ssh('ls -la /var/snap/syncthing/common/config > {0}/var.snap.syncthing.common.config.ls.log'.format(TMP_DIR), throw=False)    
    device.run_ssh('ls -la /var/snap/syncthing/common/config/syncthing > {0}/var.snap.syncthing.common.config.syncthing.ls.log'.format(TMP_DIR), throw=False)    
    device.run_ssh('ls -la /data > {0}/data.ls.log'.format(TMP_DIR), throw=False)    
    device.run_ssh('ls -la /data/syncthing > {0}/data.syncthing.ls.log'.format(TMP_DIR), throw=False)    
    
    device.scp_from_device('{0}/*.log'.format(TMP_DIR), app_log_dir, throw=False)
    

@pytest.fixture(scope='function')
def syncloud_session(device_host, device_user, device_password):
    session = requests.session()
    session.post('https://{0}/rest/login'.format(device_host), data={'name': device_user, 'password': device_password}, verify=False)
    return session


@pytest.fixture(scope='function')
def syncthing_session(app_domain, device_user, device_password):
    session = requests.session()
    response = session.get('https://{0}'.format(app_domain), auth=(device_user, device_password), allow_redirects=False, verify=False)
    print(response.text.encode("UTF-8"))
    print(response.headers)
    assert response.status_code == 200, response.text
    return session


def test_start(module_setup, device, device_host, app, log_dir):
    shutil.rmtree(log_dir, ignore_errors=True)
    os.mkdir(log_dir)
    add_host_alias(app, device_host)
    print(check_output('date', shell=True))
    device.run_ssh('date', retries=20)


def test_activate_device(device):
    response = device.activate()
    assert response.status_code == 200, response.text


def test_install(app_archive_path, device_host, device_password):
    local_install(device_host, device_password, app_archive_path)


def test_wrong_auth(app_domain, device_user):
    session = requests.session()
    response = session.get('https://{0}'.format(app_domain), auth=(device_user, 'wrongpass'), allow_redirects=False, verify=False)
    print(response.text.encode("UTF-8"))
    print(response.headers)
    assert response.status_code != 200, response.text


def test_resource(syncthing_session, app_domain):
    response = syncthing_session.get('https://{0}'.format(app_domain), verify=False)
    assert response.status_code == 200, response.text


def test_remove(device_session, device_host):
    response = device_session.get('https://{0}/rest/remove?app_id=syncthing'.format(device_host),
                                    allow_redirects=False, verify=False)
    assert response.status_code == 200, response.text
    wait_for_installer(device_session, device_host)


def test_reinstall(app_archive_path, device_host, device_password):
    local_install(device_host, device_password, app_archive_path)
