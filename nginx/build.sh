#!/bin/bash -xe

DIR=$( cd "$( dirname "$0" )" && pwd )
ARCH=$(uname -m)
BUILD_DIR=${DIR}/../build/snap

${DIR}/../ci/apt.sh wget ca-certificates

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}
${DIR}/../ci/download.sh https://github.com/syncloud/3rdparty/releases/download/nginx/nginx-${ARCH}.tar.gz nginx.tar.gz
tar xf nginx.tar.gz
rm -f nginx.tar.gz
