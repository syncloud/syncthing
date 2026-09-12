#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )
SOCKET=${SNAP_DATA}/gui.sock

echo 204800 > /proc/sys/fs/inotify/max_user_watches || echo "cannot raise inotify watch limit" >&2

(
    for i in $(seq 1 300); do
        if [ -S ${SOCKET} ]; then
            chown syncthing ${SOCKET} && chmod 0600 ${SOCKET}
            exit 0
        fi
        sleep 1
    done
    echo "gui socket never appeared, nginx will not be able to reach it" >&2
) &

exec ${DIR}/syncthing \
    --home ${SNAP_DATA}/config/syncthing \
    serve \
    --gui-address unix://${SOCKET} \
    --no-browser
