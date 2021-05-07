#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}

VERSION=$1
DOWNLOAD_URL=https://github.com/syncloud/3rdparty/releases/download/1

${DIR}/build/python/bin/pip install -r ${DIR}/requirements.txt

cd syncthing
go run build.go -version v${VERSION} tar
tar xf syncthing-linux-*-v${VERSION}.tar.gz 
mv syncthing-linux-*-v${VERSION} ${DIR}/build/syncthing 

${DIR}/build/syncthing/syncthing --help || true
