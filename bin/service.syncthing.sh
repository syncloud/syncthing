#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

exec ${DIR}/syncthing \
    --home ${SNAP_DATA}/config/syncthing \
    serve \
    --gui-address unix://${SNAP_DATA}/gui.sock \
    --no-browser
