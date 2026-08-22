#!/bin/bash
# test_router_static.sh - static file serving + CORS, end-to-end.
# Sets up a web root, starts test_router_static.fls, drives it with curl, and
# verifies path-safety, MIME types, index fallback, binary byte-exactness, and
# that CORS response headers are actually emitted by the builtin server.
#
# Run from the repo root:  bash tests/test_router_static.sh

set -u
BASE="http://localhost:8091"
ROOT="/tmp/flaris_static_test"
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

# ---- build the web root ----
rm -rf "$ROOT"
mkdir -p "$ROOT/sub"
printf '<!doctype html><h1>INDEX_ROOT</h1>' > "$ROOT/index.html"
printf 'body{color:CSS_MARKER}'             > "$ROOT/app.css"
printf '{"data":"JSON_MARKER"}'             > "$ROOT/data.json"
printf '<!doctype html><h1>SUB_PAGE</h1>'   > "$ROOT/sub/page.html"
# Binary file with embedded NUL bytes (exercises block body + exact length).
printf '\x00\x01\x02\x00\xff\xfe\x00PNGDATA\x00' > "$ROOT/bin.dat"
# Files that must never be served, and a symlink escaping the root.
printf 'SECRET_TOKEN=hunter2' > "$ROOT/.env"
mkdir -p "$ROOT/.git" && printf 'GIT_SECRET' > "$ROOT/.git/config"
mkdir -p "$ROOT/.well-known" && printf 'WELLKNOWN_OK' > "$ROOT/.well-known/probe.txt"
printf 'OUTSIDE_THE_ROOT' > "/tmp/flaris_static_outside.txt"
ln -sf /tmp/flaris_static_outside.txt "$ROOT/escape.txt"
ln -sf /tmp "$ROOT/escapedir"
ORIG_SUM=$(cksum < "$ROOT/bin.dat" | awk '{print $1, $2}')

# ---- start the server ----
$VM --unsafe ./tests/test_router_static.fls --libs='./libs' >/tmp/flaris_static_srv.log 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT

# wait for it to listen
for i in $(seq 1 50); do
    if curl -s -o /dev/null "$BASE/api/ping"; then break; fi
    sleep 0.1
done

echo "================================================"
echo " Router Static + CORS Test Suite"
echo "================================================"

# --- static: regular file + MIME + cache header ---
HDRS=$(curl -s -D - -o /tmp/fs_body "$BASE/static/app.css")
STATUS=$(printf '%s' "$HDRS" | head -1 | awk '{print $2}')
check_status "GET /static/app.css" "200" "$STATUS"
check_contains "  content-type css"   "Content-Type: text/css" "$HDRS"
check_contains "  cache-control set"  "Cache-Control: public, max-age=60" "$HDRS"
check_contains "  css body"           "CSS_MARKER" "$(cat /tmp/fs_body)"

# --- static: directory -> index ---
BODY=$(curl -s "$BASE/static/")
check_contains "GET /static/ -> index.html" "INDEX_ROOT" "$BODY"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/static")
check_status "GET /static (no slash) -> index" "200" "$STATUS"

# --- static: nested file ---
BODY=$(curl -s "$BASE/static/sub/page.html")
check_contains "GET /static/sub/page.html" "SUB_PAGE" "$BODY"

# --- static: json MIME ---
HDRS=$(curl -s -D - -o /dev/null "$BASE/static/data.json")
check_contains "GET /static/data.json content-type" "Content-Type: application/json" "$HDRS"

# --- static: missing -> 404 ---
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/static/nope.js")
check_status "GET /static/nope.js" "404" "$STATUS"

# --- path traversal -> 403 (--path-as-is keeps the .. literal) ---
STATUS=$(curl -s --path-as-is -o /dev/null -w '%{http_code}' "$BASE/static/../test_router_static.fls")
check_status "GET /static/../ traversal blocked" "403" "$STATUS"
STATUS=$(curl -s --path-as-is -o /dev/null -w '%{http_code}' "$BASE/static/../../etc/passwd")
check_status "GET /static/../../etc/passwd blocked" "403" "$STATUS"

# --- binary byte-exactness (NUL bytes preserved by block body + exact length) ---
curl -s -o /tmp/fs_bin "$BASE/static/bin.dat"
GOT_SUM=$(cksum < /tmp/fs_bin | awk '{print $1, $2}')
if [ "$GOT_SUM" = "$ORIG_SUM" ]; then
    pass "GET /static/bin.dat byte-exact (cksum $GOT_SUM)"
else
    fail "GET /static/bin.dat corrupted - orig=$ORIG_SUM got=$GOT_SUM"
fi

# --- exposure: dotfiles, symlinks ---
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/static/.env")
check_status "GET /static/.env blocked" "404" "$STATUS"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/static/.git/config")
check_status "GET /static/.git/config blocked" "404" "$STATUS"
BODY=$(curl -s "$BASE/static/.well-known/probe.txt")
check_contains ".well-known still reachable" "WELLKNOWN_OK" "$BODY"

STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/static/escape.txt")
check_status "symlink out of the root blocked" "404" "$STATUS"
BODY=$(curl -s "$BASE/static/escape.txt")
if echo "$BODY" | grep -q 'OUTSIDE_THE_ROOT'; then
    fail "symlink target was disclosed"
else
    pass "symlink target not disclosed"
fi
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/static/escapedir/flaris_static_outside.txt")
check_status "symlinked directory not traversed" "404" "$STATUS"

# --- CORS: headers emitted on a normal response ---
HDRS=$(curl -s -D - -o /dev/null -H "Origin: https://app.example.com" "$BASE/api/ping")
check_contains "CORS Allow-Origin on GET"  "Access-Control-Allow-Origin: https://app.example.com" "$HDRS"
check_contains "CORS Allow-Credentials"    "Access-Control-Allow-Credentials: true" "$HDRS"
check_contains "CORS Expose-Headers"       "Access-Control-Expose-Headers: X-Total-Count" "$HDRS"

# --- CORS: preflight ---
RESP=$(curl -s -D - -o /dev/null -X OPTIONS "$BASE/api/ping" \
    -H "Origin: https://app.example.com" -H "Access-Control-Request-Method: GET")
STATUS=$(printf '%s' "$RESP" | head -1 | awk '{print $2}')
check_status "OPTIONS /api/ping preflight" "204" "$STATUS"
check_contains "  preflight Allow-Methods" "Access-Control-Allow-Methods" "$RESP"

echo "================================================"
echo " Results: $PASS passed, $FAIL failed"
echo "================================================"
kill $SRV 2>/dev/null
rm -rf "$ROOT" /tmp/fs_body /tmp/fs_bin /tmp/flaris_static_outside.txt
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
