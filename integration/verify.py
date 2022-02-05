import os
import shutil
from os.path import dirname, join
from subprocess import check_output

import pytest
import requests
from syncloudlib.integration.hosts import add_host_alias
from syncloudlib.integration.installer import local_install, wait_for_installer

DIR = dirname(__file__)
TMP_DIR = '/tmp/syncloud'


@pytest.fixture(scope="session")
def module_setup(request, device, data_dir, platform_data_dir, app_dir, artifact_dir, snap_data_dir):

    def module_teardown():
        platform_log_dir = join(artifact_dir, 'platform_log')
        os.mkdir(platform_log_dir)
        device.scp_from_device('{0}/log/*'.format(platform_data_dir), platform_log_dir)

        device.run_ssh('mkdir {0}'.format(TMP_DIR), throw=False)
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

        app_log_dir = join(artifact_dir, 'log')
        os.mkdir(app_log_dir)
        device.scp_from_device('{0}/log/*.log'.format(data_dir), app_log_dir, throw=False)
        device.scp_from_device('{0}/*.log'.format(TMP_DIR), app_log_dir, throw=False)
        check_output('chmod -R a+r {0}'.format(artifact_dir), shell=True)

    request.addfinalizer(module_teardown)


@pytest.fixture(scope='function')
def syncthing_session(app_domain, device_user, device_password):
    session = requests.session()
    response = session.get('https://{0}'.format(app_domain), auth=(device_user, device_password), allow_redirects=False, verify=False)
    print(response.text.encode("UTF-8"))
    print(response.headers)
    assert response.status_code == 200, response.text
    return session


def test_start(module_setup, device, device_host, app, log_dir, domain):
    add_host_alias(app, device_host, domain)
    device.run_ssh('date', retries=100, throw=True)



def test_activate_device(device):
    response = device.activate_custom()
    assert response.status_code == 200, response.text


def test_install(app_archive_path, device_host, device_password, device_session):
    local_install(device_host, device_password, app_archive_path)
    wait_for_installer(device_session, device_host)


def test_wrong_auth(app_domain, device_user):
    session = requests.session()
    response = session.get('https://{0}'.format(app_domain), auth=(device_user, 'wrongpass'), allow_redirects=False,
                           verify=False)
    print(response.text.encode("UTF-8"))
    print(response.headers)
    assert response.status_code != 200, response.text


def test_resource(syncthing_session, app_domain):
    response = syncthing_session.get('https://{0}'.format(app_domain), verify=False)
    assert response.status_code == 200, response.text


def test_remove(device, app):
    response = device.app_remove(app)
    assert response.status_code == 200, response.text


def test_reinstall(app_archive_path, device_host, device_password):
    local_install(device_host, device_password, app_archive_path)
