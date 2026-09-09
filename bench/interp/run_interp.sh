#!/usr/bin/env bash
# run_interp.sh - the same six programs written in every interpreted language on
# the box, timed against each other. Flaris runs with its JIT switched off so
# this compares interpreters with interpreters.
#
# Every implementation prints the same "result:" line; the runner cross-checks
# them, so a divergence is reported instead of being silently timed. Runtimes
# that are not installed are skipped and shown as "-".
#
#   ./run_interp.sh                            # whatever is on PATH
#   RUNS=7 ./run_interp.sh                     # more repetitions
#   FLARISVM=/path/to/flarisvm ./run_interp.sh # explicit interpreter
#   BENCHES="matmul dict" ./run_interp.sh      # a subset
set -uo pipefail
cd "$(dirname "$0")"
RUNS=${RUNS:-3}
BENCHES=${BENCHES-"binarytrees matmul dict method strops sortcb"}
# The three integer kernels live in ../kernels and are shared with run_bench.sh.
# Included here too so one table covers every interpreted scenario in the repo.
KERNEL_DIR=../kernels
KERNELS=${KERNELS-"fib sieve collatz"}

# flarisvm on PATH, else a build sitting next to the checkout. Override with
# FLARISVM=... for anything else.
if [ -z "${FLARISVM:-}" ]; then
    if command -v flarisvm >/dev/null; then FLARISVM=$(command -v flarisvm)
    else
        for c in ./flarisvm ../../flarisvm ../flarisvm; do
            [ -x "$c" ] && { FLARISVM=$c; break; }
        done
    fi
fi
FLARISVM=${FLARISVM:-flarisvm}

declare_langs() { echo "flaris lua luau qjs python"; }
cmd_for() { # $1=lang $2=bench $3=dir -> command, empty if unavailable
    local d=${3:-.}
    case "$1" in
        flaris) { command -v "$FLARISVM" >/dev/null 2>&1 || [ -x "$FLARISVM" ]; } &&
                echo "$FLARISVM $d/bench_$2.fls --strip --jit-disable" ;;
        lua)    command -v lua  >/dev/null && echo "lua $d/bench_$2.lua" ;;
        luau)   command -v luau >/dev/null && [ -f "$d/bench_$2.luau" ] && echo "luau $d/bench_$2.luau" ;;
        qjs)    command -v qjs  >/dev/null && echo "qjs $d/bench_$2.js" ;;
        python) command -v python3 >/dev/null && echo "python3 $d/bench_$2.py" ;;
    esac
}

run_row() { # $1=bench $2=dir
    printf '%-13s' "$1"
    local expected="" mismatch=""
    for l in $(declare_langs); do
        c=$(cmd_for "$l" "$1" "$2")
        if [ -z "$c" ]; then printf '%9s' "-"; continue; fi
        lo=""; res=""
        for _ in $(seq 1 "$RUNS"); do
            out=$($c 2>/dev/null)
            t=$(printf '%s\n' "$out" | sed -nE 's/.*elapsed: *([0-9]+).*/\1/p' | tail -1)
            r=$(printf '%s\n' "$out" | sed -nE 's/.*result: *([-0-9]+).*/\1/p' | tail -1)
            [ -n "$r" ] && res=$r
            if [ -n "$t" ] && { [ -z "$lo" ] || [ "$t" -lt "$lo" ]; }; then lo=$t; fi
        done
        if [ -z "$lo" ]; then printf '%9s' "err"; continue; fi
        if [ -z "$expected" ]; then expected=$res
        elif [ -n "$res" ] && [ "$res" != "$expected" ]; then mismatch="$mismatch $l=$res"; fi
        printf '%9s' "$lo"
    done
    printf '   %s' "$expected"
    [ -n "$mismatch" ] && printf '  MISMATCH:%s' "$mismatch"
    printf '\n'
}

# Report exactly what was measured: a benchmark whose toolchain is unstated is
# not reproducible, and `flarisvm` on PATH is easily an older install than the
# build you meant to test.
echo "Toolchain"
if command -v "$FLARISVM" >/dev/null 2>&1 || [ -x "$FLARISVM" ]; then
    fpath=$(command -v "$FLARISVM" 2>/dev/null || echo "$FLARISVM")
    printf '  %-8s %s (%s)\n' flaris "$fpath" "$("$FLARISVM" --version 2>&1 | head -1)"
else
    printf '  %-8s not found\n' flaris
fi
command -v lua     >/dev/null && printf '  %-8s %s (%s)\n' lua    "$(command -v lua)"     "$(lua -v 2>&1 | head -1)"
command -v luau    >/dev/null && printf '  %-8s %s\n'      luau   "$(command -v luau)"
command -v qjs     >/dev/null && printf '  %-8s %s (%s)\n' qjs    "$(command -v qjs)"     "$(qjs -h 2>&1 | head -1)"
command -v python3 >/dev/null && printf '  %-8s %s (%s)\n' python "$(command -v python3)" "$(python3 --version 2>&1)"
echo

printf '%-13s' "scenario"; for l in $(declare_langs); do printf '%9s' "$l"; done; printf '   %s\n' "result"
printf '%-13s' "-------"; for l in $(declare_langs); do printf '%9s' "-------"; done; printf '   %s\n' "------"

for b in $KERNELS; do
    [ -f "$KERNEL_DIR/bench_$b.fls" ] && run_row "$b" "$KERNEL_DIR"
done
for b in $BENCHES; do run_row "$b" "."; done

echo
echo "milliseconds, minimum of $RUNS runs. A '-' means that runtime is not installed."
echo "The result column is the value every implementation must agree on."
