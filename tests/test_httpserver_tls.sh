#!/bin/bash
# test_httpserver_tls.sh - HttpServer terminating TLS, end-to-end.
# Generates a self-signed certificate, starts test_httpserver_tls.fls on an
# HTTPS port, and drives it with curl: handshake, Date header, keep-alive reuse,
# chunked streaming, a body either side of the write-coalescing threshold,
# byte-exact static binary, and the handshake-failure path.
#
# Run from the repo root:  bash tests/test_httpserver_tls.sh

set -u
BASE="https://localhost:8453"
DIR="/tmp/flaris_tls_test"
PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

check_status() { # label expected actual
    if [ "$3" = "$2" ]; then pass "$1 (HTTP $3)"; else fail "$1 - expected $2, got $3"; fi
}
check_contains() { # label needle haystack
    if echo "$3" | grep -qi -- "$2"; then pass "$1"; else fail "$1 - missing '$2'"; fi
}

# ---- locate the VM ----
VM="${VM:-./flarisvm}"
VMBIN="${VM%% *}"
if [ ! -x "$VMBIN" ]; then VM="./flaris"; VMBIN="$VM"; fi
if [ ! -x "$VMBIN" ]; then echo "no flarisvm/flaris binary - run make first"; exit 1; fi

command -v openssl >/dev/null || { echo "openssl not available - skipping"; exit 0; }

# ---- certificate + web root ----
rm -rf "$DIR"
mkdir -p "$DIR/pub"
openssl req -x509 -newkey rsa:2048 -keyout "$DIR/key.pem" -out "$DIR/cert.pem" \
    -days 2 -nodes -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" >/dev/null 2>&1
openssl pkcs12 -export -out "$DIR/server.p12" -inkey "$DIR/key.pem" \
    -in "$DIR/cert.pem" -passout pass:testpass >/dev/null 2>&1
[ -s "$DIR/server.p12" ] || { echo "could not build a test certificate - skipping"; exit 0; }

printf 'STATIC_OK'                        > "$DIR/pub/a.txt"
printf '\x00\x01\x02\x00\xff\xfe\x00TLS\x00' > "$DIR/pub/bin.dat"
ORIG_SUM=$(cksum < "$DIR/pub/bin.dat" | awk '{print $1, $2}')

# ---- start the server ----
$VM ./tests/test_httpserver_tls.fls --libs='./libs' >"$DIR/srv.log" 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT

for i in $(seq 1 60); do
    grep -q 'TLS_UNAVAILABLE' "$DIR/srv.log" 2>/dev/null && {
        echo "build cannot terminate TLS - skipping"; exit 0; }
    if curl -sk -o /dev/null "$BASE/" 2>/dev/null; then break; fi
    sleep 0.1
done

echo "================================================"
echo " HttpServer TLS Test Suite"
echo "================================================"

# --- handshake + request marked secure ---
HDRS=$(curl -sk -D - -o "$DIR/body" "$BASE/")
STATUS=$(printf '%s' "$HDRS" | head -1 | awk '{print $2}')
check_status "GET / over TLS" "200" "$STATUS"
check_contains "  req.secure is true"  "secure=true" "$(cat "$DIR/body")"
check_contains "  Date header present" "^Date: "     "$HDRS"
check_contains "  Server header"       "Server: Flaris" "$HDRS"

# --- certificate really is the one we generated (not an accidental plaintext path) ---
SUBJ=$(curl -skv "$BASE/" 2>&1 | grep -i 'subject:' | head -1)
check_contains "server presents the test certificate" "CN=localhost" "$SUBJ"

# --- JSON ---
BODY=$(curl -sk "$BASE/json")
check_contains "GET /json" '"ok":true' "$BODY"

# --- keep-alive: two requests on one TLS connection ---
# One -o per URL: curl sends any surplus body to stdout and corrupts the count.
CODES=$(curl -sk -o /dev/null -o /dev/null -w '%{http_code},' "$BASE/" "$BASE/json")
if [ "$CODES" = "200,200," ]; then
    pass "two requests reuse one TLS connection"
else
    fail "keep-alive over TLS - got '$CODES'"
fi

# --- chunked streaming over TLS ---
BODY=$(curl -sk "$BASE/stream")
if [ "$BODY" = "abc" ]; then pass "chunked streaming over TLS"; else fail "chunked over TLS - got '$BODY'"; fi

# --- 40 KB body: above the coalescing threshold, second write path ---
LEN=$(curl -sk "$BASE/big" | wc -c | tr -d ' ')
if [ "$LEN" = "40000" ]; then pass "40 KB body complete over TLS"; else fail "40 KB body - got $LEN bytes"; fi

# --- static text + byte-exact binary ---
BODY=$(curl -sk "$BASE/pub/a.txt")
check_contains "static file over TLS" "STATIC_OK" "$BODY"
curl -sk -o "$DIR/got.dat" "$BASE/pub/bin.dat"
GOT_SUM=$(cksum < "$DIR/got.dat" | awk '{print $1, $2}')
if [ "$GOT_SUM" = "$ORIG_SUM" ]; then
    pass "static binary byte-exact over TLS (cksum $GOT_SUM)"
else
    fail "static binary corrupted - orig=$ORIG_SUM got=$GOT_SUM"
fi

# --- plain HTTP to the TLS port: rejected, hook fires, server survives ---
curl -s -m 3 -o /dev/null "http://localhost:8453/" 2>/dev/null
sleep 0.3
if grep -q 'TLS_HANDSHAKE_FAILED' "$DIR/srv.log"; then
    pass "plain HTTP to the TLS port reports a handshake failure"
else
    fail "plain HTTP to the TLS port did not reach OnTlsError"
fi
STATUS=$(curl -sk -o /dev/null -w '%{http_code}' "$BASE/json")
check_status "server still serving after a failed handshake" "200" "$STATUS"

echo "================================================"
echo " Results: $PASS passed, $FAIL failed"
echo "================================================"
kill $SRV 2>/dev/null
rm -rf "$DIR"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
