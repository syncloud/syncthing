#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

if [[ -z "$1" ]]; then
    echo "usage $0 [start|stop]"
    exit 1
fi

. /var/snap/syncthing/current/config/syncthing.env


case $1 in
start)
    /bin/rm -f /var/snap/syncthing/common/web.socket
    ${DIR}/nginx/sbin/nginx -t -c /var/snap/syncthing/current/config/nginx.conf -p ${DIR}/nginx -g 'error_log /var/snap/syncthing/common/log/nginx_error.log warn;'
    timeout 60 /bin/bash -c 'until echo > /dev/tcp/localhost/'$SYNCTHING_PORT'; do sleep 10; done'
    exec ${DIR}/nginx/sbin/nginx -c /var/snap/syncthing/current/config/nginx.conf -p ${DIR}/nginx -g 'error_log /var/snap/syncthing/commom/log/nginx_error.log warn;'
    ;;
reload)
    ${DIR}/nginx/sbin/nginx -c /var/snap/syncthing/current/config/nginx.conf -s reload -p ${DIR}/nginx
    ;;
stop)
    ${DIR}/nginx/sbin/nginx -c /var/snap/syncthing/current/config/nginx.conf -s stop -p ${DIR}/nginx
    ;;
*)
    echo "not valid command"
    exit 1
    ;;
esac
