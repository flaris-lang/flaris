# bench/lib.sh - shared helpers for the benchmark runners.
#
# Sourced by run_bench.sh and run_bench_realworld.sh. Owns runtime discovery,
# the median-of-N timing harness, peak-memory measurement, and host
# description. Every runtime is optional: a missing one is reported and its
# rows are left out of the report rather than aborting the run.
#
# Timing contract: each benchmark program prints two lines to stdout,
#   result: <integer>
#   elapsed: <milliseconds>
# measured inside the program, so process startup is never counted. Peak
# memory, by contrast, is measured from outside and does include the runtime's
# own baseline - see the methodology notes the runners emit.

# Numeric formatting must not follow the host locale, or ratios come out with
# decimal commas in some regions and points in others.
export LC_ALL=C

RUNS="${RUNS:-3}"

# Resolve a compiled lane's binary. Toolchains disagree about whether a
# suffixless -o target gains a .exe on Windows - and they disagree with each
# other - so accept whichever name actually landed instead of predicting it. A
# lane that cannot be resolved skips itself silently, which costs the whole
# comparison its baseline, so the miss is reported.
bin_path() {   # bin_path <basename> -> prints the runnable path, or nothing
    if   [[ -x "./$1"     ]]; then printf '%s' "./$1"
    elif [[ -x "./$1.exe" ]]; then printf '%s' "./$1.exe"
    else warn "$1: built binary not found (lane skipped)"
    fi
}

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[bench]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

runs_phrase() {
    if [[ "$RUNS" == "1" ]]; then echo "a single run"; else echo "the median of $RUNS runs"; fi
}

# Resolve one runtime: honour an explicit env override, else take the first
# candidate found on PATH. Sets the named variable to "" when nothing is found.
resolve_tool() {   # resolve_tool <VARNAME> <candidate...>
    local var="$1"; shift
    local current="${!var:-}"
    if [[ -n "$current" ]]; then
        if have "$current" || [[ -x "$current" ]]; then return 0; fi
        warn "$var=$current is not executable - ignoring"
    fi
    local c
    for c in "$@"; do
        if have "$c"; then printf -v "$var" '%s' "$c"; return 0; fi
    done
    printf -v "$var" '%s' ""
    return 1
}

resolve_all_tools() {
    resolve_tool FLARISVM flarisvm || true
    resolve_tool CC       clang cc gcc          || true
    resolve_tool GO       go                    || true
    resolve_tool NIM      nim                   || true
    resolve_tool PYTHON   python3 python        || true
    resolve_tool LUA      lua lua5.4 lua5.3     || true
    resolve_tool LUAJIT   luajit                || true
    resolve_tool NODE     node nodejs           || true
    resolve_tool QJS      qjs quickjs           || true
    detect_time_tool

    if [[ -z "$FLARISVM" ]]; then
        warn "flarisvm not found on PATH. Install it from https://www.flaris-lang.org"
        warn "or point at a build with FLARISVM=/path/to/flarisvm"
        return 1
    fi
}

report_missing_tools() {
    local missing=()
    [[ -z "$CC"     ]] && missing+=("C (clang/gcc)")
    [[ -z "$GO"     ]] && missing+=("Go")
    [[ -z "$NIM"    ]] && missing+=("Nim")
    [[ -z "$PYTHON" ]] && missing+=("Python 3")
    [[ -z "$LUA"    ]] && missing+=("Lua")
    [[ -z "$LUAJIT" ]] && missing+=("LuaJIT")
    [[ -z "$NODE"   ]] && missing+=("Node")
    [[ -z "$QJS"    ]] && missing+=("QuickJS")
    if (( ${#missing[@]} )); then
        warn "not installed, skipping: ${missing[*]}"
    fi
    [[ -z "$TIME_TOOL_MODE" ]] && \
        warn "no external time(1) found - peak memory columns will be omitted"
    return 0
}

# ── peak memory ──────────────────────────────────────────────────────────────
# GNU time reports max RSS in KB via %M; BSD/macOS time -l reports it in bytes
# on a labelled line. Anything else means no memory measurement at all.
detect_time_tool() {
    TIME_TOOL_MODE=""
    if /usr/bin/time -f '%M' true >/dev/null 2>&1; then
        TIME_TOOL_MODE=gnu
    elif /usr/bin/time -l true >/dev/null 2>&1; then
        TIME_TOOL_MODE=bsd
    fi
}

# Extract peak RSS in KB from whatever the detected time(1) wrote.
parse_rss_kb() {   # parse_rss_kb <file>
    local f="$1"
    [[ -s "$f" ]] || return 1
    case "$TIME_TOOL_MODE" in
      gnu) grep -oE '^[0-9]+$' "$f" | tail -1 ;;
      bsd) awk '/maximum resident set size/{printf "%d\n", $1/1024; exit}' "$f" ;;
      *)   return 1 ;;
    esac
}

# ── timing harness ───────────────────────────────────────────────────────────
# Results live in $BENCH_TMP, keyed <bench>_<lang>. Callers must set BENCH_TMP.

run_one() {   # run_one <bench> <lang> <cmd...> - records median of $RUNS
    local bench="$1" lang="$2"; shift 2
    [[ -n "${1:-}" ]] || { warn "$bench/$lang: no runtime, skipped"; return 0; }
    local out="$BENCH_TMP/${bench}_${lang}.out"
    local times="$BENCH_TMP/${bench}_${lang}.times"
    local mems="$BENCH_TMP/${bench}_${lang}.mems"
    rm -f "$times" "$mems"
    local i
    for (( i=0; i<RUNS; i++ )); do
        local tmp="$BENCH_TMP/${bench}_${lang}_run${i}.out"
        local err="$BENCH_TMP/${bench}_${lang}_run${i}.err"
        local ok=0
        case "$TIME_TOOL_MODE" in
          gnu) /usr/bin/time -f '%M' -o "$err" "$@" >"$tmp" 2>/dev/null && ok=1 ;;
          bsd) /usr/bin/time -l "$@" >"$tmp" 2>"$err" && ok=1 ;;
          *)   "$@" >"$tmp" 2>"$err" && ok=1 ;;
        esac
        if (( ok )); then
            local t
            t=$(grep -oE 'elapsed: *[0-9]+' "$tmp" | grep -oE '[0-9]+$' || true)
            [[ -n "$t" ]] && echo "$t" >> "$times"
            local m
            m=$(parse_rss_kb "$err" || true)
            [[ -n "$m" ]] && echo "$m" >> "$mems"
            cp "$tmp" "$out"
        fi
    done
    if [[ ! -f "$times" ]]; then
        warn "$bench/$lang failed"
        return 0
    fi
    local mid
    mid=$(sort -n "$times" | awk -v n="$(wc -l < "$times")" 'NR==int((n+2)/2){print}')
    grep -v '^elapsed:' "$out" > "${out}.tmp" && mv "${out}.tmp" "$out"
    echo "elapsed: $mid" >> "$out"
    if [[ -s "$mems" ]]; then
        local midm
        midm=$(sort -n "$mems" | awk -v n="$(wc -l < "$mems")" 'NR==int((n+2)/2){print}')
        echo "$midm" > "$BENCH_TMP/${bench}_${lang}.rss"
    fi
}

get_ms() {    # get_ms <bench> <lang> - milliseconds, or N/A
    local f="$BENCH_TMP/${1}_${2}.out"
    [[ -f "$f" ]] || { echo "N/A"; return; }
    grep -oE 'elapsed: *[0-9]+' "$f" | grep -oE '[0-9]+$' || echo "N/A"
}

get_mb() {    # get_mb <bench> <lang> - peak RSS in MB, or N/A
    local f="$BENCH_TMP/${1}_${2}.rss"
    [[ -s "$f" ]] || { echo "N/A"; return; }
    awk '{printf "%.1f", $1/1024}' "$f"
}

get_result() {  # get_result <bench> <lang> - the cross-checked answer, or ERR
    local f="$BENCH_TMP/${1}_${2}.out"
    [[ -f "$f" ]] || { echo "ERR"; return; }
    grep -oE 'result: *[0-9]+' "$f" | grep -oE '[0-9]+$' || echo "ERR"
}

ratio() {   # ratio <ms> <base_ms> - formatted "N.Nx", or N/A
    local ms="$1" base="$2"
    if [[ "$ms" == "N/A" || "$base" == "N/A" || "$base" == "0" ]]; then
        echo "N/A"; return
    fi
    awk -v a="$ms" -v b="$base" 'BEGIN{printf "%.1fx", a/b}'
}

min_ms() {  # min_ms <bench> <langs...> - fastest recorded time
    local bench="$1"; shift
    local min="" l ms
    for l in "$@"; do
        ms=$(get_ms "$bench" "$l")
        [[ "$ms" == "N/A" ]] && continue
        if [[ -z "$min" || "$ms" -lt "$min" ]]; then min="$ms"; fi
    done
    echo "${min:-N/A}"
}

check_bench() {  # check_bench <bench> <langs...> - warn on any disagreement
    local bench="$1"; shift
    local ref="" lang val
    for lang in "$@"; do
        val=$(get_result "$bench" "$lang")
        [[ "$val" == "ERR" ]] && continue
        if [[ -z "$ref" ]]; then ref="$val"
        elif [[ "$val" != "$ref" ]]; then
            warn "$bench: $lang got $val but expected $ref"
        fi
    done
    log "  $bench: result=${ref:-none}"
}

# Emit one markdown result table, rows sorted fastest-first. Languages with no
# recorded time (not installed, or the run failed) are left out entirely. The
# peak-memory column appears only when an external time(1) was available.
emit_table() {  # emit_table <bench> <base_ms> <col_label> <mark_fastest:0|1> <langs...>
    local bench="$1" base="$2" col="$3" mark_fastest="$4"; shift 4
    local memcol="" memsep=""
    if [[ -n "$TIME_TOOL_MODE" ]]; then memcol=" peak RSS (MB) |"; memsep=" ------------: |"; fi
    echo "| Language | time (ms) | $col |$memcol"
    echo "| -------- | --------: | ----: |$memsep"
    local l ms
    for l in "$@"; do
        ms=$(get_ms "$bench" "$l")
        [[ "$ms" == "N/A" ]] && continue
        printf '%s\t%s\n' "$ms" "$l"
    done | sort -n | while IFS=$'\t' read -r ms l; do
        local mark="" memcell=""
        [[ "$mark_fastest" == "1" && "$ms" == "$base" ]] && mark=" **fastest**"
        [[ -n "$TIME_TOOL_MODE" ]] && memcell=" $(get_mb "$bench" "$l") |"
        printf '| %s (%s) | %s | %s%s |%s\n' \
            "$(lang_name "$l")" "$(lang_detail "$l")" "$ms" "$(ratio "$ms" "$base")" \
            "$mark" "$memcell"
    done
    echo ""
}

lang_name() { case "$1" in
                c)    echo "C" ;;          go)     echo "Go" ;;
                nim)  echo "Nim" ;;        py)     echo "Python 3" ;;
                lua)  echo "Lua 5.4" ;;    luajit) echo "LuaJIT 2.1" ;;
                js)   echo "QuickJS" ;;    node)   echo "Node/V8" ;;
                fls)  echo "Flaris" ;;     flsj)   echo "Flaris JIT" ;;
                *)    echo "$1" ;;
              esac; }

lang_detail() { case "$1" in
                  c)    echo "clang -O2" ;;         go)     echo "go build" ;;
                  nim)  echo "-d:release -O3" ;;    py)     echo "CPython" ;;
                  lua)  echo "interpreted" ;;       luajit) echo "tracing JIT" ;;
                  js)   echo "interpreted" ;;       node)   echo "V8" ;;
                  fls)  echo "bytecode VM" ;;       flsj)   echo "bytecode VM --jit" ;;
                  *)    echo "" ;;
                esac; }

# ── host description ─────────────────────────────────────────────────────────

cpu_name() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sysctl -n machdep.cpu.brand_string 2>/dev/null && return
    elif [[ -r /proc/cpuinfo ]]; then
        awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo && return
    fi
    uname -p 2>/dev/null || echo "unknown"
}

os_name() {
    case "$(uname -s)" in
        Darwin) echo "macOS $(sw_vers -productVersion 2>/dev/null || uname -r)" ;;
        Linux)  ( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}" ) || echo "Linux" ;;
        *)      echo "$(uname -s) $(uname -r)" ;;
    esac
}

# Filename-safe host tag, e.g. "apple-m2-arm64", used to name result snapshots.
machine_slug() {
    local cpu; cpu=$(cpu_name)
    printf '%s-%s' "$cpu" "$(uname -m)" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/\(r\)|\(tm\)|cpu|processor//g; s/@.*$//; s/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

flaris_version() {
    [[ -n "$FLARISVM" ]] || { echo "unknown"; return; }
    "$FLARISVM" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 \
        || echo "unknown"
}

tool_version() {  # tool_version <cmd> <version-args...>
    local cmd="$1"; shift
    [[ -n "$cmd" ]] || { echo "not installed"; return; }
    "$cmd" "$@" 2>&1 | head -1
}
