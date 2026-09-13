#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )
SOCKET=${SNAP_DATA}/gui.sock

/bin/rm -f ${SOCKET}

echo 204800 > /proc/sys/fs/inotify/max_user_watches || echo "cannot raise inotify watch limit" >&2

(
    while true; do
        if [ -S ${SOCKET} ] && [ "$(stat -c %U ${SOCKET})" != "syncthing" ]; then
            chown syncthing ${SOCKET} && chmod 0600 ${SOCKET}
        fi
        sleep 1
    done
) &

exec ${DIR}/syncthing \
    --home ${SNAP_DATA}/config/syncthing \
    serve \
    --gui-address unix://${SOCKET} \
    --no-browser
