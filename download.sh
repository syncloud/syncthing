#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

VERSION=1.16.1
DOWNLOAD_URL=https://github.com/syncloud/3rdparty/releases/download/1
ARCH=$(uname -m)
rm -rf ${DIR}/build
BUILD_DIR=${DIR}/build
mkdir -p ${BUILD_DIR}

cd $BUILD_DIR

wget --progress=dot:giga ${DOWNLOAD_URL}/python3-${ARCH}.tar.gz
tar xf python3-${ARCH}.tar.gz
mv python3 python

wget --progress=dot:giga ${DOWNLOAD_URL}/nginx-${ARCH}.tar.gz
tar xf nginx-${ARCH}.tar.gz

wget https://github.com/syncthing/syncthing/archive/v${SYNCTHING_VERSION}.tar.gz
tar xf v${SYNCTHING_VERSION}.tar.gz
mv syncthing-${SYNCTHING_VERSION} syncthing
