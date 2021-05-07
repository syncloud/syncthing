#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [[ -z "$2" ]]; then
    echo "usage $0 app version"
    exit 1
fi

NAME=$1
DEB_ARCH=$(dpkg-architecture -q DEB_HOST_ARCH)
VERSION=$2
BUILD_DIR=${DIR}/build/app
mkdir $BUILD_DIR

mv ${DIR}/build/python ${BUILD_DIR}
mv ${DIR}/build/nginx ${BUILD_DIR}
#mv ${DIR}/build/bin ${BUILD_DIR}
mv ${DIR}/build/home-assistant ${BUILD_DIR}
mv ${DIR}/build/ldap-auth-sh ${BUILD_DIR}

cp -r ${DIR}/bin ${BUILD_DIR}/bin
cp -r ${DIR}/config ${BUILD_DIR}/config.templates
cp -r ${DIR}/hooks ${BUILD_DIR}

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
echo "- ${DEB_ARCH}" >> ${SNAP_DIR}/meta/snap.yaml

PACKAGE=${NAME}_${VERSION}_${DEB_ARCH}.snap
echo ${PACKAGE} > ${DIR}/package.name
mksquashfs ${SNAP_DIR} ${DIR}/${PACKAGE} -noappend -comp xz -no-xattrs -all-root

mkdir ${DIR}/artifact
cp ${DIR}/${PACKAGE} ${DIR}/artifact
