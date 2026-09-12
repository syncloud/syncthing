#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

sysctl -w fs.inotify.max_user_watches=204800

exec ${DIR}/syncthing --home ${SNAP_DATA}/config/syncthing serve
