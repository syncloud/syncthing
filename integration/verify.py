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
from syncloudlib.integration.installer import local_install, wait_for_sam, wait_for_rest, local_remove, get_platform_data_dir, get_data_dir, get_app_dir, get_service_prefix, get_ssh_env_vars

import requests

SYNCLOUD_INFO = 'syncloud.info'
DEVICE_USER = 'user'
DEVICE_PASSWORD = 'password'
DEFAULT_DEVICE_PASSWORD = 'syncloud'
LOGS_SSH_PASSWORD = DEFAULT_DEVICE_PASSWORD
DIR = dirname(__file__)
LOG_DIR = join(DIR, 'log')
APP='syncthing'
TMP_DIR = '/tmp/syncloud'


@pytest.fixture(scope="session")
def platform_data_dir():
    return get_platform_data_dir('snapd')
        
@pytest.fixture(scope="session")
def data_dir():
    return get_data_dir('snapd', APP)
         

@pytest.fixture(scope="session")
def app_dir():
    return get_app_dir('snapd', APP)


@pytest.fixture(scope="session")
def service_prefix():
    return get_service_prefix('snapd')


@pytest.fixture(scope="session")
def ssh_env_vars():
    return get_ssh_env_vars('snapd', APP)


@pytest.fixture(scope="session")
def module_setup(request, device_host, data_dir, platform_data_dir, app_dir, service_prefix):
    request.addfinalizer(lambda: module_teardown(device_host, data_dir, platform_data_dir, app_dir, service_prefix))


def module_teardown(device_host, data_dir, platform_data_dir, app_dir, service_prefix):
    platform_log_dir = join(LOG_DIR, 'platform_log')
    os.mkdir(platform_log_dir)
    run_scp('root@{0}:{1}/log/* {2}'.format(device_host, platform_data_dir, platform_log_dir), password=LOGS_SSH_PASSWORD, throw=False)
    
    app_log_dir  = join(LOG_DIR, 'syncthing_log')
    os.mkdir(app_log_dir )
    run_scp('root@{0}:{1}/log/*.log {2}'.format(device_host, data_dir, app_log_dir), password=LOGS_SSH_PASSWORD, throw=False)

    run_ssh(device_host, 'mkdir {0}'.format(TMP_DIR), password=LOGS_SSH_PASSWORD)
    run_ssh(device_host, 'ls -la {0} > {1}/app.data.ls.log'.format(data_dir, TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)
    run_ssh(device_host, 'ls -la {0}/syncthing/config > {1}/config.ls.log'.format(data_dir, TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)
    run_ssh(device_host, '{0}/syncthing/syncthing --help > {1}/syncthing.help.log'.format(app_dir, TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)
    run_ssh(device_host, 'top -bn 1 -w 500 -c > {0}/top.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)
    run_ssh(device_host, 'ps auxfw > {0}/ps.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)
    run_ssh(device_host, 'systemctl status {0}syncthing.syncthing > {1}/syncthing.status.log'.format(service_prefix, TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)
    run_ssh(device_host, 'netstat -nlp > {0}/netstat.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)
    run_ssh(device_host, 'journalctl | tail -500 > {0}/journalctl.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)
    run_ssh(device_host, 'tail -500 /var/log/syslog > {0}/syslog.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)
    run_ssh(device_host, 'tail -500 /var/log/messages > {0}/messages.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)    
    run_ssh(device_host, 'ls -la /snap > {0}/snap.ls.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)    
    run_ssh(device_host, 'ls -la /snap/syncthing > {0}/snap.syncthing.ls.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)    
    run_ssh(device_host, 'ls -la /var/snap > {0}/var.snap.ls.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)    
    run_ssh(device_host, 'ls -la /var/snap/syncthing > {0}/var.snap.syncthing.ls.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)    
    run_ssh(device_host, 'ls -la /var/snap/syncthing/common > {0}/var.snap.syncthing.common.ls.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)    
    run_ssh(device_host, 'ls -la /var/snap/syncthing/common/config > {0}/var.snap.syncthing.common.config.ls.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)    
    run_ssh(device_host, 'ls -la /var/snap/syncthing/common/config/syncthing > {0}/var.snap.syncthing.common.config.syncthing.ls.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)    
    run_ssh(device_host, 'ls -la /data > {0}/data.ls.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)    
    run_ssh(device_host, 'ls -la /data/syncthing > {0}/data.syncthing.ls.log'.format(TMP_DIR), password=LOGS_SSH_PASSWORD, throw=False)    
    run_scp('root@{0}:{1}/*.log {2}'.format(device_host, TMP_DIR, app_log_dir), password=LOGS_SSH_PASSWORD, throw=False)
    

@pytest.fixture(scope='function')
def syncloud_session(device_host):
    session = requests.session()
    session.post('https://{0}/rest/login'.format(device_host), data={'name': DEVICE_USER, 'password': DEVICE_PASSWORD}, verify=False)
    return session


@pytest.fixture(scope='function')
def syncthing_session(user_domain):
    session = requests.session()
    response = session.get('https://{0}'.format(user_domain), auth=(DEVICE_USER, DEVICE_PASSWORD), allow_redirects=False, verify=False)
    print(response.text.encode("UTF-8"))
    print(response.headers)
    assert response.status_code == 200, response.text
    return session


def test_start(module_setup):
    shutil.rmtree(LOG_DIR, ignore_errors=True)
    os.mkdir(LOG_DIR)


def test_activate_device(auth, device_host):
    email, password, domain, release = auth

    response = requests.post('http://{0}:81/rest/activate'.format(device_host),
                             data={'main_domain': SYNCLOUD_INFO, 'redirect_email': email, 'redirect_password': password,
                                   'user_domain': domain, 'device_username': DEVICE_USER, 'device_password': DEVICE_PASSWORD}, verify=False)
    assert response.status_code == 200, response.text
    global LOGS_SSH_PASSWORD
    LOGS_SSH_PASSWORD = DEVICE_PASSWORD


def test_install(app_archive_path, device_host):
    local_install(device_host, DEVICE_PASSWORD, app_archive_path, 'snapd')


def test_wrong_auth(user_domain):
    session = requests.session()
    response = session.get('https://{0}'.format(user_domain), auth=(DEVICE_USER, 'wrongpass'), allow_redirects=False, verify=False)
    print(response.text.encode("UTF-8"))
    print(response.headers)
    assert response.status_code != 200, response.text


def test_resource(syncthing_session, user_domain):
    response = syncthing_session.get('https://{0}'.format(user_domain), verify=False)
    assert response.status_code == 200, response.text


def test_remove(syncloud_session, device_host):
    response = syncloud_session.get('https://{0}/rest/remove?app_id=syncthing'.format(device_host),
                                    allow_redirects=False, verify=False)
    assert response.status_code == 200, response.text
    wait_for_sam(syncloud_session, device_host)


def test_reinstall(app_archive_path, device_host):
    local_install(device_host, DEVICE_PASSWORD, app_archive_path, 'snapd')
