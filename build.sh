#!/bin/bash -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}

export TMPDIR=/tmp
export TMP=/tmp

NAME=$1
ARCH=$(uname -m)
CPU_ARCH=$(dpkg-architecture -q DEB_HOST_ARCH_CPU)
SYNCTHING_VERSION=1.16.1
VERSION=$2
GO_VERSION=1.11.5

rm -rf ${DIR}/build
BUILD_DIR=${DIR}/build/${NAME}
mkdir -p ${BUILD_DIR}
mkdir ${BUILD_DIR}/lib

GO_ARCH=$CPU_ARCH
if [ ${ARCH} == "armv7l" ]; then
    GO_ARCH=armv6l
fi

DOWNLOAD_URL=http://artifact.syncloud.org/3rdparty
coin --to ${BUILD_DIR} raw ${DOWNLOAD_URL}/nginx-${ARCH}.tar.gz
coin --to ${BUILD_DIR} raw ${DOWNLOAD_URL}/python-${ARCH}.tar.gz
${BUILD_DIR}/python/bin/pip install -r ${DIR}/requirements.txt

mkdir -p syncthing-src/src/github.com/syncthing

#wget https://github.com/cyberb/syncthing/archive/syncloud-build.zip
#unzip syncloud-build.zip
#mv syncthing-syncloud-build syncthing-src/src/github.com/syncthing/syncthing

wget https://github.com/syncthing/syncthing/archive/v${SYNCTHING_VERSION}.tar.gz
tar xf v${SYNCTHING_VERSION}.tar.gz
mv syncthing-${SYNCTHING_VERSION} syncthing-src/src/github.com/syncthing/syncthing

wget https://dl.google.com/go/go$GO_VERSION.linux-$GO_ARCH.tar.gz --progress=dot:giga
tar xf go$GO_VERSION.linux-$GO_ARCH.tar.gz
export GOROOT=$(pwd)/go
export PATH=$PATH:$GOROOT/bin
export GOPATH=$(pwd)/syncthing-src
cd syncthing-src/src/github.com/syncthing/syncthing
#./build.sh assets
GO111MODULE=on go get gopkg.in/ldap.v3
find . -type f -name "*.go" -print0 | xargs -0 sed -i 's#gopkg.in/ldap.v2#gopkg.in/ldap.v3#g'
GO111MODULE=on go mod tidy
GO111MODULE=on go mod vendor
#go run build.go assets
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
