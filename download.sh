#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

VERSION=$1
GO_ARCH=$2
ARCH=$(uname -m)

apt update
apt -y install wget

cd ${DIR}/build/snap
wget -c --progress=dot:giga https://github.com/syncloud/3rdparty/releases/download/nginx/nginx-${ARCH}.tar.gz
tar xf nginx-${ARCH}.tar.gz
rm -rf nginx-${ARCH}.tar.gz

#cd ${DIR}/build
#wget https://github.com/syncthing/syncthing/archive/v${VERSION}.tar.gz
wget https://github.com/syncthing/syncthing/releases/download/v${VERSION}/syncthing-linux-${GO_ARCH}-v${VERSION}.tar.gz
tar xf syncthing-linux-${GO_ARCH}-v${VERSION}.tar.gz
mv syncthing-linux-${GO_ARCH}-v${VERSION}/syncthing syncthing
rm -rf syncthing-linux-${GO_ARCH}-v${VERSION}.tar.gz
rm -rf syncthing-linux-${GO_ARCH}-v${VERSION}

