#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

. ${SNAP_DATA}/config/syncthing.env

/bin/rm -f ${SNAP_COMMON}/web.socket
timeout 60 /bin/bash -c 'until echo > /dev/tcp/localhost/'$SYNCTHING_PORT'; do sleep 10; done'
exec ${DIR}/nginx/sbin/nginx -c ${SNAP_DATA}/config/nginx.conf -p ${DIR}/nginx -e stderr
