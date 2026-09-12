import json
import pytest
import requests
from subprocess import check_output
from syncloudlib.integration.hosts import add_host_alias
from syncloudlib.integration.installer import local_install
from syncloudlib.http import wait_for_rest

TMP_DIR = '/tmp/syncloud'
HOME_DIR = '/var/snap/syncthing/current/config/syncthing'
GUI_SOCKET = '/var/snap/syncthing/current/gui.sock'
FOLDER_ID = 'data'
PROBE_DIR = 'syncthing/upgrade-probe'
PROBE_FILE = PROBE_DIR + '/probe.txt'
PROBE_BODY = 'pre-upgrade-probe'
BEFORE = {}


@pytest.fixture(scope="session")
def module_setup(request, device, artifact_dir):
    def module_teardown():
        device.run_ssh('mkdir -p {0}'.format(TMP_DIR), throw=False)
        device.run_ssh('journalctl > {0}/refresh.journalctl.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la {0} > {1}/home.ls.log 2>&1'.format(HOME_DIR, TMP_DIR), throw=False)
        device.scp_from_device('{0}/*'.format(TMP_DIR), artifact_dir, throw=False)
        check_output('chmod -R a+r {0}'.format(artifact_dir), shell=True)

    request.addfinalizer(module_teardown)


def api_key(device):
    config = device.run_ssh('cat {0}/config.xml'.format(HOME_DIR))
    start = config.index('<apikey>') + len('<apikey>')
    return config[start:config.index('</apikey>')].strip()


def curl_target(device):
    if 'missing' in device.run_ssh('[ -S {0} ] && echo present || echo missing'.format(GUI_SOCKET)):
        return '', 'http://localhost:1085'
    return '--unix-socket {0}'.format(GUI_SOCKET), 'http://localhost'


def curl(device, path, method=''):
    socket_arg, base = curl_target(device)
    return device.run_ssh("curl -s {0} {1} -H X-API-Key:{2} '{3}/rest/{4}'".format(
        method, socket_arg, api_key(device), base, path))


def api(device, path):
    return json.loads(curl(device, path))


def wait_for_idle(device):
    for _ in range(60):
        status = api(device, 'db/status?folder={0}'.format(FOLDER_ID))
        if status['state'] == 'idle':
            return status
        device.run_ssh('sleep 2', throw=False)
    return api(device, 'db/status?folder={0}'.format(FOLDER_ID))


def from_leveldb():
    return BEFORE['version'].startswith('v1.')


def test_start(module_setup, app, device_host, domain, device, settle):
    add_host_alias(app, device_host, domain)
    device.activated()
    settle(device)
    device.run_ssh('mkdir -p {0}'.format(TMP_DIR), throw=False)


def test_pre_upgrade_write_probe(device):
    device.run_ssh('mkdir -p /data/{0}'.format(PROBE_DIR))
    device.run_ssh('echo {0} > /data/{1}'.format(PROBE_BODY, PROBE_FILE))
    device.run_ssh('head -c 1048576 /dev/urandom > /data/{0}/probe.bin'.format(PROBE_DIR))
    curl(device, 'db/scan?folder={0}'.format(FOLDER_ID), method='-X POST')

    status = wait_for_idle(device)
    assert status['localFiles'] > 0, status

    indexed = api(device, 'db/file?folder={0}&file={1}'.format(FOLDER_ID, PROBE_FILE))
    assert not indexed['local'].get('deleted', False), indexed

    BEFORE['version'] = api(device, 'system/version')['version']
    BEFORE['id'] = api(device, 'system/status')['myID']
    BEFORE['files'] = status['localFiles']
    BEFORE['bytes'] = status['localBytes']
    print('before upgrade: {0}'.format(BEFORE))


def test_upgrade(device_host, device_password, app_archive_path, app_domain):
    local_install(device_host, device_password, app_archive_path)
    wait_for_rest(requests.session(), "https://{0}".format(app_domain), 200, 100)


def test_sqlite_database_present(device):
    listing = device.run_ssh('ls {0}'.format(HOME_DIR))
    assert 'index-v2' in listing, listing
    if from_leveldb():
        assert 'index-v0.14.0.db-migrated' in listing, listing


def test_no_panic_after_upgrade(device):
    log = device.run_ssh('journalctl -u snap.syncthing.syncthing --no-pager | tail -1000')
    assert 'panic' not in log, log
    if from_leveldb():
        assert 'Migration complete' in log, log


def test_device_id_survived(device):
    assert api(device, 'system/status')['myID'] == BEFORE['id']


def test_folder_index_survived(device):
    status = wait_for_idle(device)
    print('after upgrade: {0}'.format(status))
    assert status['state'] == 'idle', status
    assert status['errors'] == 0, status
    assert status['localFiles'] == BEFORE['files'], status
    assert status['localBytes'] == BEFORE['bytes'], status


def test_probe_file_still_indexed(device):
    indexed = api(device, 'db/file?folder={0}&file={1}'.format(FOLDER_ID, PROBE_FILE))
    assert not indexed['local'].get('deleted', False), indexed


def test_probe_file_still_on_disk(device):
    assert PROBE_BODY in device.run_ssh('cat /data/{0}'.format(PROBE_FILE))
