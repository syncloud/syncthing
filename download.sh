#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

VERSION=$1
ARCH=$(uname -m)

apt update
apt -y install wget

cd ${DIR}/build/app
wget -c --progress=dot:giga https://github.com/syncloud/3rdparty/releases/download/nginx/nginx-${ARCH}.tar.gz
tar xf nginx-${ARCH}.tar.gz

cd ${DIR}/build
wget https://github.com/syncthing/syncthing/archive/v${VERSION}.tar.gz
tar xf v${VERSION}.tar.gz
mv syncthing-${VERSION} syncthing-src
