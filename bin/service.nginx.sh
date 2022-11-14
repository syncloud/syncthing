#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

if [[ -z "$1" ]]; then
    echo "usage $0 [start|stop]"
    exit 1
fi

. $SNAP_DATA/config/syncthing.env


case $1 in
start)
    /bin/rm -f ${SNAP_COMMON}/web.socket
    ${DIR}/nginx/sbin/nginx -t -c ${SNAP_DATA}/config/nginx.conf -p ${DIR}/nginx -g 'error_log '${SNAP_COMMON}'/log/nginx_error.log warn;'
    timeout 60 /bin/bash -c 'until echo > /dev/tcp/localhost/'$SYNCTHING_PORT'; do sleep 10; done'
    exec ${DIR}/nginx/sbin/nginx -c ${SNAP_DATA}/config/nginx.conf -p ${DIR}/nginx -g 'error_log '${SNAP_COMMON}'/log/nginx_error.log warn;'
    ;;
reload)
    ${DIR}/nginx/sbin/nginx -c ${SNAP_DATA}/config/nginx.conf -s reload -p ${DIR}/nginx
    ;;
stop)
    ${DIR}/nginx/sbin/nginx -c ${SNAP_DATA}/config/nginx.conf -s stop -p ${DIR}/nginx
    ;;
*)
    echo "not valid command"
    exit 1
    ;;
esac
