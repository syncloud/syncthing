import logging
from os.path import join
from subprocess import check_output

from syncloudlib import fs, linux, gen, logger
from syncloudlib.application import paths, storage

APP_NAME = 'syncthing'
USER_NAME = APP_NAME
SYNCTHING_PORT = 1085


class Installer:
    def __init__(self):
        if not logger.factory_instance:
            logger.init(logging.DEBUG, True)

        self.log = logger.get_logger('{0}_installer'.format(APP_NAME))
        self.app_dir = paths.get_app_dir(APP_NAME)
        self.app_data_dir = paths.get_data_dir(APP_NAME)
        
    def install(self):

        check_output('echo 204800 /proc/sys/fs/inotify/max_user_watches', shell=True)

        home_folder = join('/home', USER_NAME)
        linux.useradd(USER_NAME, home_folder=home_folder)

        storage.init_storage(APP_NAME, USER_NAME)

        templates_path = join(self.app_dir, 'config')
        config_path = join(self.app_data_dir, 'config')

        variables = {
            'app_dir': self.app_dir,
            'app_data_dir': self.app_data_dir,
            'syncthing_port': SYNCTHING_PORT
        }
        gen.generate_files(templates_path, config_path, variables)

        fs.makepath(join(self.app_data_dir, 'log'))
        fs.makepath(join(self.app_data_dir, 'nginx'))
        
        fs.chownpath(self.app_data_dir, USER_NAME, recursive=True)

    def post_refresh(self):
        self.install()