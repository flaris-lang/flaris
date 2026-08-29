#!/bin/bash
# test_connect.sh - drives tests/test_connect.fls (libs/Connect.fls).
#
# The same .fls is both ends: `serve` runs the Connect peer, no argument runs
# the tests. They must be separate processes - the Http client blocks its fiber,
# so a call into a server in the same VM deadlocks. Run from the library repo
# root:
#
#   VM=/path/to/flarisvm bash tests/test_connect.sh

BASE="http://127.0.0.1:8418"

VM="${VM:-./flarisvm}"
VMBIN="${VM%% *}"
if [ ! -x "$VMBIN" ]; then VM="./flaris"; VMBIN="$VM"; fi
if [ ! -x "$VMBIN" ]; then echo "no flarisvm/flaris binary - run make first"; exit 1; fi

$VM ./tests/test_connect.fls serve --libs='./libs' >/tmp/flaris_connect_srv.log 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT

for i in $(seq 1 60); do
    curl -s -o /dev/null "$BASE/healthz" && break
    sleep 0.1
done

if ! curl -s -o /dev/null "$BASE/healthz"; then
    echo "[FAIL] the Connect peer never came up on $BASE"
    cat /tmp/flaris_connect_srv.log
    exit 1
fi

$VM ./tests/test_connect.fls --libs='./libs'
RC=$?

kill $SRV 2>/dev/null
exit $RC
