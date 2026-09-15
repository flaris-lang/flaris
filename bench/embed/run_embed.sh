#!/usr/bin/env bash
# run_embed.sh - the embedding benchmark: what a C host pays to USE a scripting
# engine, as opposed to how fast the engine runs a loop on its own.
#
#   load  1000 x (create the VM, load the script, run it to completion, ask it
#         one question, tear the VM down).  A plugin host's startup cost.
#   call  create and load once, then call one script function 1,000,000 times.
#         A per-frame update hook's cost.
#
# Every engine runs the same script, and the two results must agree across all
# of them (500500000 and 500000500000) or the lane is dropped rather than
# reported. Engines are optional: anything whose library is not installed is
# skipped, never reported as a zero.
set -uo pipefail
cd "$(dirname "$0")"

RUNS="${RUNS:-3}"
LOAD_CYCLES=1000
CALLS=1000000
EXPECT_LOAD=500500000
EXPECT_CALL=500000500000

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[embed]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $*" >&2; }

FLARIS_TREE="${FLARIS_TREE:-$(cd ../../../flaris-lang 2>/dev/null && pwd)}"
pfx() { brew --prefix "$1" 2>/dev/null; }

# ── build ────────────────────────────────────────────────────────────────────
BUILT=()
build() {  # build <lane> <output> <cc-args...>
    local lane="$1" out="$2"; shift 2
    if cc -O2 -I. "$@" -o "$out" 2>/dev/null; then BUILT+=("$lane")
    else warn "$lane: will not build - lane skipped"; fi
}

log "Building hosts..."
[[ -n "$FLARIS_TREE" && -f "$FLARIS_TREE/libflaris.a" ]] \
    && build flaris host_flaris host_flaris.c -I"$FLARIS_TREE" "$FLARIS_TREE/libflaris.a" \
             -lm -framework Security -framework CoreFoundation \
    || warn "flaris: no libflaris.a (set FLARIS_TREE) - lane skipped"

L=$(pfx lua);      [[ -n "$L" ]] && build lua      host_lua      host_lua.c      -I"$L/include/lua" "$L/lib/liblua.a" -lm
W=$(pfx wren);     [[ -n "$W" ]] && build wren     host_wren     host_wren.c     -I"$W/include" "$W/lib/libwren.a" -lm
Q=$(pfx quickjs);  [[ -n "$Q" ]] && build quickjs  host_quickjs  host_quickjs.c  -I"$Q/include/quickjs" "$Q/lib/quickjs/libquickjs.a" -lm -lpthread
J=$(pfx janet);    [[ -n "$J" ]] && build janet    host_janet    host_janet.c    -I"$J/include" "$J/lib/libjanet.a" -lm -lpthread
D=$(pfx duktape);  [[ -n "$D" ]] && build duktape  host_duktape  host_duktape.c  -I"$D/include" -L"$D/lib" -lduktape -lm
build native host_native host_native.c

# The C# lane needs the shared library and SDK 10 file-based apps.
CS=""
if command -v dotnet >/dev/null && [[ -f "$FLARIS_TREE/libflaris.dylib" ]]; then
    cp -f "$FLARIS_TREE/libflaris.dylib" . 2>/dev/null
    if dotnet publish host_flaris_cs.cs -c Release -o csout_embed -p:PublishAot=false >/dev/null 2>&1; then
        cp -f libflaris.dylib script.fls csout_embed/ 2>/dev/null
        CS=1; BUILT+=("flaris-cs")
    else warn "flaris-cs: dotnet publish failed - lane skipped"; fi
fi
[[ -n "${D:-}" ]] && export DYLD_LIBRARY_PATH="$D/lib:${DYLD_LIBRARY_PATH:-}"
export DYLD_LIBRARY_PATH=".:${DYLD_LIBRARY_PATH:-}"

# ── run ──────────────────────────────────────────────────────────────────────
cmd_for() {  # cmd_for <lane>
    case "$1" in
      flaris)    echo "./host_flaris" ;;
      lua)       echo "./host_lua" ;;
      wren)      echo "./host_wren" ;;
      quickjs)   echo "./host_quickjs" ;;
      janet)     echo "./host_janet" ;;
      duktape)   echo "./host_duktape" ;;
      native)    echo "./host_native" ;;
      flaris-cs) echo "./csout_embed/host_flaris_cs" ;;
    esac
}

label() { case "$1" in
    flaris)    echo "Flaris (C host)" ;;
    flaris-cs) echo "Flaris (C# host, P/Invoke)" ;;
    lua)       echo "Lua 5.5" ;;
    wren)      echo "Wren 0.4" ;;
    quickjs)   echo "QuickJS" ;;
    janet)     echo "Janet" ;;
    duktape)   echo "Duktape 2.7" ;;
    native)    echo "no engine (C call)" ;;
  esac; }

EMBED_TMP=$(mktemp -d)
trap 'rm -rf "$EMBED_TMP"' EXIT

measure() {  # measure <lane> <mode> <expected>
    local lane="$1" mode="$2" expect="$3" c best="" out res ms
    c=$(cmd_for "$lane")
    for ((r = 0; r < RUNS; r++)); do
        out=$("$c" "$mode" 2>/dev/null) || return 1
        res=$(sed -n 's/^result: //p' <<<"$out")
        ms=$(sed -n 's/^elapsed: \([0-9]*\) ms/\1/p' <<<"$out")
        [[ "$res" == "$expect" ]] || { warn "$lane $mode: result $res != $expect - dropped"; return 1; }
        [[ -z "$best" || "$ms" -lt "$best" ]] && best="$ms"
    done
    echo "$best" > "$EMBED_TMP/${lane}_${mode}"
    return 0
}

log "Running (best of $RUNS)..."
for lane in "${BUILT[@]}"; do
    [[ "$lane" == "native" ]] || measure "$lane" load "$EXPECT_LOAD" || true
    measure "$lane" call "$EXPECT_CALL" || true
done

# ── report ───────────────────────────────────────────────────────────────────
# <mult> converts total ms into the per-operation unit: 1000 for microseconds
# per load cycle, 1000000 for nanoseconds per call.
rows() {  # rows <mode> <divisor> <mult>
    local mode="$1" div="$2" mult="$3"
    for lane in "${BUILT[@]}"; do
        local f="$EMBED_TMP/${lane}_${mode}"
        [[ -s "$f" ]] || continue
        local ms; ms=$(cat "$f")
        printf '%s\t%s\t%s\n' "$ms" "$(label "$lane")" \
            "$(awk -v m="$ms" -v d="$div" -v k="$mult" \
                 'BEGIN{ v = m*k/d; if (v < 1) printf "<1"; else printf "%.1f", v }')"
    done | sort -n
}

{
echo "# Embedding benchmark"
echo
echo "What a host pays to *use* an engine, rather than how fast the engine runs a"
echo "loop on its own. Every engine runs the same script; both results are checked"
echo "against a known value, and a lane whose answer disagrees is dropped."
echo
echo "Host: $(uname -sm), $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown). Best of $RUNS."
echo
echo "## 1. Load and run to completion"
echo
echo "$LOAD_CYCLES x (create the VM, load the script, run its top level to"
echo "completion, call one function, tear the VM down). What a plugin host pays"
echo "every time it spins a script up."
echo
echo "| Host | total (ms) | per cycle (us) |"
echo "| ---- | ---------: | -------------: |"
rows load "$LOAD_CYCLES" 1000 | awk -F'\t' '{printf "| %s | %s | %s |\n", $2, $1, $3}'
echo
echo "## 2. Calling a script function"
echo
echo "Create and load once, then call \`Update(i)\` $CALLS times. What a per-frame"
echo "hook pays. The no-engine row is the same function in C, called directly."
echo
echo "| Host | total (ms) | per call (ns) |"
echo "| ---- | ---------: | ------------: |"
rows call "$CALLS" 1000000 | awk -F'\t' '{printf "| %s | %s | %s |\n", $2, $1, $3}'
} | tee results_embed.md

log "Wrote results_embed.md"
