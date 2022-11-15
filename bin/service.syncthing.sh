#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

if [[ -z "$1" ]]; then
    echo "usage $0 [start|stop]"
    exit 1
fi

case $1 in
start)
    echo 204800 /proc/sys/fs/inotify/max_user_watches
    exec ${DIR}/syncthing -home /var/snap/syncthing/current/config/syncthing
    ;;
*)
    echo "not valid command"
    exit 1
    ;;
esac
