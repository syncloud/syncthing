#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}

NAME=$1
ARCH=$(uname -m)
CPU_ARCH=$(dpkg-architecture -q DEB_HOST_ARCH_CPU)
SYNCTHING_VERSION=1.16.1
VERSION=$2
DOWNLOAD_URL=https://github.com/syncloud/3rdparty/releases/download/1

rm -rf ${DIR}/build
BUILD_DIR=${DIR}/build/${NAME}
mkdir -p ${BUILD_DIR}
mkdir ${BUILD_DIR}/lib

${BUILD_DIR}/python/bin/pip install -r ${DIR}/requirements.txt

cd syncthing
go run build.go -version v${SYNCTHING_VERSION} tar
tar xf syncthing-linux-${CPU_ARCH}-v${SYNCTHING_VERSION}.tar.gz 
mv syncthing-linux-${CPU_ARCH}-v${SYNCTHING_VERSION} ${BUILD_DIR}/syncthing 

cd $DIR

${BUILD_DIR}/syncthing/syncthing --help || true

cp -r ${DIR}/bin ${BUILD_DIR}
cp -r ${DIR}/hooks ${BUILD_DIR}
cp -r ${DIR}/config ${BUILD_DIR}/config.templates

mkdir ${BUILD_DIR}/META
echo ${NAME} >> ${BUILD_DIR}/META/app
echo ${VERSION} >> ${BUILD_DIR}/META/version

echo "snapping"
SNAP_DIR=${DIR}/build/snap
ARCH=$(dpkg-architecture -q DEB_HOST_ARCH)
rm -rf ${DIR}/*.snap
mkdir ${SNAP_DIR}
cp -r ${BUILD_DIR}/* ${SNAP_DIR}/
cp -r ${DIR}/snap/meta ${SNAP_DIR}/
cp ${DIR}/snap/snap.yaml ${SNAP_DIR}/meta/snap.yaml
echo "version: $VERSION" >> ${SNAP_DIR}/meta/snap.yaml
echo "architectures:" >> ${SNAP_DIR}/meta/snap.yaml
echo "- ${ARCH}" >> ${SNAP_DIR}/meta/snap.yaml
PACKAGE=${NAME}_${VERSION}_${ARCH}.snap
echo ${PACKAGE} > package.name
mksquashfs ${SNAP_DIR} ${DIR}/${PACKAGE} -noappend -comp xz -no-xattrs -all-root
