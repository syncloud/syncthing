#!/bin/bash -xe

DIR=$( cd "$( dirname "$0" )" && pwd )
VERSION=$1
GO_ARCH=$2
BUILD_DIR=${DIR}/../build/snap

${DIR}/../ci/apt.sh wget ca-certificates

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}
${DIR}/../ci/download.sh \
    https://github.com/syncthing/syncthing/releases/download/v${VERSION}/syncthing-linux-${GO_ARCH}-v${VERSION}.tar.gz \
    syncthing.tar.gz
tar xf syncthing.tar.gz
mv syncthing-linux-${GO_ARCH}-v${VERSION}/syncthing syncthing
rm -rf syncthing.tar.gz syncthing-linux-${GO_ARCH}-v${VERSION}
