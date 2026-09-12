#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

/bin/rm -f ${SNAP_COMMON}/web.socket
timeout 300 /bin/bash -c 'until [ -S '${SNAP_DATA}'/gui.sock ]; do sleep 1; done'
exec ${DIR}/nginx/bin/nginx.sh -c ${SNAP_DATA}/config/nginx.conf -p ${DIR}/nginx -e stderr
