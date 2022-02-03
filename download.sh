#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

VERSION=$1
ARCH=$(uname -m)
rm -rf ${DIR}/build
BUILD_DIR=${DIR}/build
mkdir -p ${BUILD_DIR}

apt update
apt -y install wget

cd $BUILD_DIR

wget -c --progress=dot:giga https://github.com/syncloud/3rdparty/releases/download/nginx/nginx-${ARCH}.tar.gz
tar xf nginx-${ARCH}.tar.gz
mv nginx ${BUILD_DIR}

wget https://github.com/syncthing/syncthing/archive/v${VERSION}.tar.gz
tar xf v${VERSION}.tar.gz
mv syncthing-${VERSION} syncthing-src
