#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

echo 204800 > /proc/sys/fs/inotify/max_user_watches || echo "cannot raise inotify watch limit" >&2

exec ${DIR}/syncthing \
    --home ${SNAP_DATA}/config/syncthing \
    serve \
    --gui-address unix://${SNAP_DATA}/gui.sock \
    --no-browser
