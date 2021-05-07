#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}

NAME=$1
ARCH=$(uname -m)
VERSION=$1
DOWNLOAD_URL=https://github.com/syncloud/3rdparty/releases/download/1

rm -rf ${DIR}/build
BUILD_DIR=${DIR}/build/${NAME}
mkdir -p ${BUILD_DIR}
mkdir ${BUILD_DIR}/lib

${BUILD_DIR}/python/bin/pip install -r ${DIR}/requirements.txt

cd syncthing
go run build.go -version v${VERSION} tar
tar xf syncthing-linux-*-v${VERSION}.tar.gz 
mv syncthing-linux-*-v${VERSION} ${BUILD_DIR}/syncthing 

${BUILD_DIR}/syncthing/syncthing --help || true
