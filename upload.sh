#!/bin/bash -ex

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

app=syncthing
branch=$1
build_number=$2
FILE_NAME=$3

bucket=apps.syncloud.org

if [ "${branch}" == "master" ] || [ "${branch}" == "stable" ] ; then
  
  s3cmd put ${FILE_NAME} s3://${bucket}/apps/${FILE_NAME}
  
  if [ "${branch}" == "stable" ]; then
    branch=rc
  fi

  printf ${build_number} > ${app}.version
  s3cmd put ${app}.version s3://${bucket}/releases/${branch}/${app}.version

fi

