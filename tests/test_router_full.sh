#!/bin/bash
# test_router_full.sh - Full test suite for Router.fls
#
# Self-contained: starts test_router_full.fls, waits for it to listen, drives it
# with curl, and stops it again. Run from the library repo root:
#
#   VM=/path/to/flarisvm bash tests/test_router_full.sh

BASE="http://localhost:8087"
PASS=0
FAIL=0

# ---- locate the VM and start the server ----
VM="${VM:-./flarisvm}"
VMBIN="${VM%% *}"
if [ ! -x "$VMBIN" ]; then VM="./flaris"; VMBIN="$VM"; fi
if [ ! -x "$VMBIN" ]; then echo "no flarisvm/flaris binary - run make first"; exit 1; fi

$VM --unsafe ./tests/test_router_full.fls --libs='./libs' >/tmp/flaris_router_full_srv.log 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT

for i in $(seq 1 60); do
    curl -s -o /dev/null "$BASE/" && break
    sleep 0.1
done

# ---- helpers ----

check() {
    local label="$1"
    local expected_status="$2"
    local actual_status="$3"
    local body="$4"

    if [ "$actual_status" = "$expected_status" ]; then
        echo "[PASS] $label (HTTP $actual_status)"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $label - expected HTTP $expected_status, got HTTP $actual_status"
        echo "       Body: $body"
        FAIL=$((FAIL + 1))
    fi
}

check_body() {
    local label="$1"
    local expected="$2"
    local actual="$3"

    if echo "$actual" | grep -q "$expected"; then
        echo "[PASS] $label (body contains '$expected')"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $label - expected body to contain '$expected'"
        echo "       Body: $actual"
        FAIL=$((FAIL + 1))
    fi
}

# ---- tests ----

echo "================================================"
echo " Router Full Test Suite"
echo "================================================"
echo ""

# --- Health (public, no auth) ---
echo "--- Public Routes ---"

RESP=$(curl -s -w "\n%{http_code}" "$BASE/health")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "GET /health" "200" "$STATUS" "$BODY"
check_body "GET /health body" "ok" "$BODY"

# --- CORS preflight ---
echo ""
echo "--- CORS ---"

RESP=$(curl -s -w "\n%{http_code}" -X OPTIONS "$BASE/api/users" \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: GET")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "OPTIONS /api/users (preflight)" "204" "$STATUS" "$BODY"

# --- Login ---
echo ""
echo "--- Auth ---"

RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "POST /auth/login" "200" "$STATUS" "$BODY"
check_body "POST /auth/login has token" "token" "$BODY"

TOKEN=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)

# Login with invalid JSON
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d 'not-json')
STATUS=$(echo "$RESP" | tail -1)
check "POST /auth/login invalid JSON" "400" "$STATUS"

# Login with missing field
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d '{}')
STATUS=$(echo "$RESP" | tail -1)
check "POST /auth/login missing username" "400" "$STATUS"

# --- JWT protected routes ---
echo ""
echo "--- JWT Protected Routes ---"

# No token
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/users")
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/users no token" "401" "$STATUS"

# Bad token
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/users" \
  -H "Authorization: Bearer invalid.token.here")
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/users bad token" "401" "$STATUS"

# Malformed Authorization header
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/users" \
  -H "Authorization: NotBearer xyz")
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/users malformed auth header" "401" "$STATUS"

# Valid token - GET /api/users
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/users" \
  -H "Authorization: Bearer $TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "GET /api/users with token" "200" "$STATUS" "$BODY"
check_body "GET /api/users body has Alice" "Alice" "$BODY"

# GET /api/users/:id
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/users/42" \
  -H "Authorization: Bearer $TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "GET /api/users/42" "200" "$STATUS" "$BODY"
check_body "GET /api/users/42 has id" "42" "$BODY"

# GET /api/me
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/me" \
  -H "Authorization: Bearer $TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "GET /api/me" "200" "$STATUS" "$BODY"
check_body "GET /api/me has user alice" "alice" "$BODY"

# POST /api/users
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Charlie"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "POST /api/users" "201" "$STATUS" "$BODY"
check_body "POST /api/users has Charlie" "Charlie" "$BODY"

# POST /api/users invalid JSON
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d 'bad json')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/users invalid JSON" "400" "$STATUS"

# PUT /api/users/:id
RESP=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/api/users/5" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "PUT /api/users/5" "200" "$STATUS" "$BODY"
check_body "PUT /api/users/5 updated" "true" "$BODY"

# DELETE /api/users/:id
RESP=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE/api/users/7" \
  -H "Authorization: Bearer $TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "DELETE /api/users/7" "200" "$STATUS" "$BODY"
check_body "DELETE /api/users/7 deleted" "true" "$BODY"

# 404
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/unknown" \
  -H "Authorization: Bearer $TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "GET /api/unknown 404" "404" "$STATUS" "$BODY"
check_body "404 body has error" "not found" "$BODY"

# ---- summary ----
echo ""
echo "================================================"
echo " Results: $PASS passed, $FAIL failed"
echo "================================================"

if [ "$FAIL" -eq 0 ]; then
    echo " All tests passed."
    exit 0
else
    exit 1
fi
