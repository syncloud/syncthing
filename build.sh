#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}


export TMPDIR=/tmp
export TMP=/tmp

NAME=syncthing
CPU_ARCH=$(dpkg-architecture -q DEB_HOST_ARCH_CPU)
ARCH=$(dpkg-architecture -q DEB_HOST_ARCH)
SYNCTHING_VERSION=0.14.49
VERSION=$1

rm -rf ${DIR}/build
BUILD_DIR=${DIR}/build/${NAME}
mkdir -p ${BUILD_DIR}
mkdir ${BUILD_DIR}/lib

wget https://github.com/syncthing/syncthing/releases/download/v${SYNCTHING_VERSION}/syncthing-linux-${CPU_ARCH}-v${SYNCTHING_VERSION}.tar.gz
tar xf syncthing-linux-${CPU_ARCH}-v${SYNCTHING_VERSION}.tar.gz
mv syncthing-linux-${CPU_ARCH}-v${SYNCTHING_VERSION} ${BUILD_DIR}/syncthing

${BUILD_DIR}/syncthing/syncthing --help || true

DOWNLOAD_URL=http://artifact.syncloud.org/3rdparty

coin --to ${BUILD_DIR}/lib py https://pypi.python.org/packages/3c/3a/ce5fe9623d93d442d9fc8b0fbf5ccb16298826782f4e5c6d85a007a5d5de/syncloud-lib-39.tar.gz#md5=6f276666c88bc63d856b82da07f7c846

cp -r ${DIR}/bin ${BUILD_DIR}
cp -r ${DIR}/hooks ${BUILD_DIR}
cp -r ${DIR}/config ${BUILD_DIR}/config.templates

mkdir ${BUILD_DIR}/META
echo ${NAME} >> ${BUILD_DIR}/META/app
echo ${VERSION} >> ${BUILD_DIR}/META/version

echo "snapping"
SNAP_DIR=${DIR}/build/snap
rm -rf ${DIR}/*.snap
mkdir ${SNAP_DIR}
cp -r ${BUILD_DIR}/* ${SNAP_DIR}/
cp -r ${DIR}/snap/meta ${SNAP_DIR}/
cp ${DIR}/snap/snap.yaml ${SNAP_DIR}/meta/snap.yaml
echo "version: $VERSION" >> ${SNAP_DIR}/meta/snap.yaml
echo "architectures:" >> ${SNAP_DIR}/meta/snap.yaml
echo "- ${ARCH}" >> ${SNAP_DIR}/meta/snap.yaml

mksquashfs ${SNAP_DIR} ${DIR}/${NAME}_${VERSION}_${ARCH}.snap -noappend -comp xz -no-xattrs -all-root
