#!/bin/bash -xe

DIR=$( cd "$( dirname "$0" )" && pwd )
${DIR}/../build/snap/syncthing --version
