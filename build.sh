#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}

VERSION=$1

cd ${DIR}/build/syncthing-src
go run build.go -version v${VERSION} tar
tar xf syncthing-linux-*-v${VERSION}.tar.gz

ls -la

mv syncthing-linux-*-v${VERSION} ${DIR}/build/syncthing

${DIR}/build/syncthing/syncthing --help || true
