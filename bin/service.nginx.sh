#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

if [[ -z "$1" ]]; then
    echo "usage $0 [start|stop]"
    exit 1
fi

. $SNAP_COMMON/config/syncthing.env


case $1 in
pre-start)
    /bin/rm -f ${SNAP_COMMON}/web.socket
    exec ${DIR}/nginx/sbin/nginx -t -c ${SNAP_COMMON}/config/nginx.conf -p ${DIR}/nginx -g 'error_log '${SNAP_COMMON}'/log/nginx_error.log warn;'
    timeout 600 /bin/bash -c 'until echo > /dev/tcp/localhost/'$SYNCTHING_PORT'; do sleep 2; done'
    ;;
start)
    exec ${DIR}/nginx/sbin/nginx -c ${SNAP_COMMON}/config/nginx.conf -p ${DIR}/nginx -g 'error_log '${SNAP_COMMON}'/log/nginx_error.log warn;'
    ;;
post-start)
    timeout 5 /bin/bash -c 'until [ -S '${SNAP_COMMON}'/web.socket ]; do echo "waiting for ${SNAP_COMMON}/web.socket"; sleep 1; done'
    ;;
reload)
    ${DIR}/nginx/sbin/nginx -c ${SNAP_COMMON}/config/nginx.conf -s reload -p ${DIR}/nginx
    ;;
stop)
    ${DIR}/nginx/sbin/nginx -c ${SNAP_COMMON}/config/nginx.conf -s stop -p ${DIR}/nginx
    ;;
*)
    echo "not valid command"
    exit 1
    ;;
esac