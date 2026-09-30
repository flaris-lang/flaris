#!/bin/bash
# test_modem.sh - Test suite for Modem.fls, with no modem.
#
# Self-contained: starts tests/fake_modem.py on a pseudo-terminal, hands the
# VM the tty it created, and cleans up. Run from the library repo root:
#
#   VM=/path/to/flarisvm bash tests/test_modem.sh
#
# No --unsafe: a serial port is ordinary sandboxed I/O.

VM="${VM:-./flarisvm}"
VMBIN="${VM%% *}"
if [ ! -x "$VMBIN" ]; then VM="./flaris"; VMBIN="$VM"; fi
if [ ! -x "$VMBIN" ]; then echo "no flarisvm/flaris binary - set VM=/path/to/flarisvm"; exit 1; fi

PTYLOG=$(mktemp -t flaris_fake_modem)

python3 ./tests/fake_modem.py >"$PTYLOG" 2>&1 &
MODEM=$!
trap 'kill $MODEM 2>/dev/null; wait $MODEM 2>/dev/null; rm -f "$PTYLOG"' EXIT

# The first line it prints is the tty it created.
PORT=""
for _ in $(seq 1 50); do
    PORT=$(head -1 "$PTYLOG" 2>/dev/null)
    [ -n "$PORT" ] && break
    sleep 0.1
done

if [ -z "$PORT" ] || [ ! -e "$PORT" ]; then
    echo "fake_modem.py did not come up:"
    cat "$PTYLOG"
    exit 1
fi

$VM ./tests/test_modem.fls --libs='./libs' "$PORT"
RC=$?

if [ "$RC" -ne 0 ]; then
    echo ""
    echo "fake_modem.py output:"
    cat "$PTYLOG"
fi
exit $RC
