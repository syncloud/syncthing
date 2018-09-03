from os.path import dirname, join, abspath, isdir
from os import listdir
import sys


from os import environ
from os.path import isfile
import shutil
import uuid
from subprocess import check_output

import logging
from syncloud_app import logger
from syncloud_platform.application import api
from syncloud_platform.gaplib import fs, linux, gen
from syncloudlib.application import paths, urls, storage, users


APP_NAME = 'syncthing'
USER_NAME = APP_NAME

class SyncthingInstaller:
    def __init__(self):
        if not logger.factory_instance:
            logger.init(logging.DEBUG, True)

        self.log = logger.get_logger('{0}_installer'.format(APP_NAME))
        self.app_dir = paths.get_app_dir(APP_NAME)
        self.app_data_dir = paths.get_data_dir(APP_NAME)

        
    def install(self):

        linux.fix_locale()

        home_folder = join('/home', USER_NAME)
        linux.useradd(USER_NAME, home_folder=home_folder)

        storage.init_storage(APP_NAME, USER_NAME)

        templates_path = join(self.app_dir, 'config.templates')
        config_path = join(self.app_data_dir, 'config')
        
    
        variables = {
            'app_dir': self.app_dir,
            'app_data_dir': self.app_data_dir
        }
        gen.generate_files(templates_path, config_path, variables)

        
        fs.makepath(join(self.app_data_dir, 'log'))
        fs.makepath(join(self.app_data_dir, 'nginx'))
        
        fs.chownpath(self.app_data_dir, USER_NAME, recursive=True)
