import os
import time
from os.path import dirname, join
from subprocess import check_output

import pytest
import requests
from syncloudlib.http import wait_for_rest
from syncloudlib.integration.hosts import add_host_alias
from syncloudlib.integration.installer import local_install

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
        device.run_ssh('ls -la {0}/config/syncthing > {1}/config.ls.log'.format(snap_data_dir, TMP_DIR), throw=False)
        device.run_ssh('{0}/syncthing --version > {1}/syncthing.version.log 2>&1'.format(app_dir, TMP_DIR), throw=False)
        device.run_ssh('top -bn 1 -w 500 -c > {0}/top.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ps auxfw > {0}/ps.log'.format(TMP_DIR), throw=False)
        device.run_ssh('systemctl status snap.syncthing.syncthing > {0}/syncthing.status.log'.format(TMP_DIR), throw=False)
        print(device.run_ssh('systemctl --no-pager --full status snap.syncthing.syncthing snap.syncthing.nginx', throw=False))
        print(device.run_ssh('journalctl --no-pager -u snap.syncthing.syncthing -n 60', throw=False))
        print(device.run_ssh('journalctl --no-pager -u snap.syncthing.nginx -n 60', throw=False))
        print(device.run_ssh('ls -la /var/snap/syncthing/current /var/snap/syncthing/common', throw=False))
        device.run_ssh('netstat -nlp > {0}/netstat.log'.format(TMP_DIR), throw=False)
        device.run_ssh('journalctl | tail -500 > {0}/journalctl.log'.format(TMP_DIR), throw=False)
        device.run_ssh('tail -500 /var/log/syslog > {0}/syslog.log'.format(TMP_DIR), throw=False)
        device.run_ssh('tail -500 /var/log/messages > {0}/messages.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /snap > {0}/snap.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /snap/syncthing > {0}/snap.syncthing.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /var/snap > {0}/var.snap.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /var/snap/syncthing > {0}/var.snap.syncthing.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /var/snap/syncthing/common > {0}/var.snap.syncthing.common.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /var/snap/syncthing/current/config/syncthing > {0}/home.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /data > {0}/data.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /data/syncthing > {0}/data.syncthing.ls.log'.format(TMP_DIR), throw=False)

        app_log_dir = join(artifact_dir, 'log')
        os.mkdir(app_log_dir)
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


def test_start(module_setup, device, device_host, app, domain, settle):
    add_host_alias(app, device_host, domain)
    device.run_ssh('date', retries=100, throw=True)
    settle(device)


def test_activate_device(device):
    response = device.activate_custom()
    assert response.status_code == 200, response.text


def test_install(app_archive_path, device_host, device_password, device_session, app_domain):
    local_install(device_host, device_password, app_archive_path)
    wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 200, 100)


def test_resource(syncthing_session, app_domain):
    response = syncthing_session.get('https://{0}'.format(app_domain), verify=False)
    assert response.status_code == 200, response.text


def test_gui_socket_stays_owned_by_syncthing(device, app_domain):
    socket = '/var/snap/syncthing/current/gui.sock'
    device.run_ssh('chown root:root {0} && chmod 0755 {0}'.format(socket))

    owner = ''
    for _ in range(30):
        owner = device.run_ssh('stat -c %U {0}'.format(socket)).strip()
        if owner == 'syncthing':
            break
        time.sleep(1)
    assert owner == 'syncthing', owner

    wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 200, 100)


def test_starting_page_while_syncthing_is_not_listening(device, app_domain):
    device.run_ssh('snap stop syncthing.syncthing')
    device.run_ssh('rm -f /var/snap/syncthing/current/gui.sock')
    device.run_ssh('snap restart syncthing.nginx')

    try:
        wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 503, 60)
        response = requests.get('https://{0}'.format(app_domain), verify=False)
        assert response.status_code == 503, response.text
        assert 'Syncthing is starting' in response.text, response.text
    finally:
        device.run_ssh('snap start syncthing.syncthing')

    wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 200, 100)


def test_remove(device, app):
    response = device.app_remove(app)
    assert response.status_code == 200, response.text


def test_reinstall(app_archive_path, device_host, device_password, app_domain):
    local_install(device_host, device_password, app_archive_path)
    wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 200, 100)
