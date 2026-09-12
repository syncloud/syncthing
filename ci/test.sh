#!/bin/bash -ex

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}/..

SPEC=$1
DISTRO=$2
APP=$3
ARCH=$4

APP_ARCHIVE_PATH=$(realpath $(cat package.name))
cd test
./deps.sh
py.test -x -s ${SPEC} \
    --distro=${DISTRO} \
    --domain=${DISTRO}.com \
    --app-archive-path=${APP_ARCHIVE_PATH} \
    --device-host=${APP}.${DISTRO}.com \
    --app=${APP} \
    --arch=${ARCH}
