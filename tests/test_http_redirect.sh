#!/bin/bash
# test_http_redirect.sh - credential headers must not follow a cross-origin redirect.
#
# Self-contained: starts test_http_redirect.fls (two origins on 18091/18092),
# waits for it to listen, runs the client, and stops the server again. Run from
# the library repo root:
#
#   VM=/path/to/flarisvm bash tests/test_http_redirect.sh
#
# Two processes rather than one: the Http client blocks the scheduler, so a
# client and a server fiber inside one VM deadlock.

VM="${VM:-./flarisvm}"
VMBIN="${VM%% *}"
if [ ! -x "$VMBIN" ]; then VM="./flaris"; VMBIN="$VM"; fi
if [ ! -x "$VMBIN" ]; then VM="flarisvm"; VMBIN=$(command -v flarisvm); fi
if [ -z "$VMBIN" ]; then echo "no flarisvm/flaris binary found"; exit 1; fi

# A server left over from an earlier run keeps its bind (Stream.Listen sets
# SO_REUSEPORT), so the new one would silently share the port with it.
pkill -f 'test_http_redirect.fls' 2>/dev/null
sleep 0.3

$VM ./tests/test_http_redirect.fls --libs='./libs' >/tmp/flaris_http_redirect_srv.log 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT

for i in $(seq 1 60); do
    curl -s -o /dev/null "http://127.0.0.1:18091/landed" && break
    sleep 0.1
done

echo "================================================"
echo " Http redirect credential test"
echo "================================================"

$VM ./tests/test_http_redirect_client.fls --libs='./libs'
RC=$?

kill $SRV 2>/dev/null
exit $RC
