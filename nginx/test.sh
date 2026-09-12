#!/bin/sh -ex

DIR=$( cd "$( dirname "$0" )" && pwd )
${DIR}/../build/snap/nginx/bin/nginx.sh -version
