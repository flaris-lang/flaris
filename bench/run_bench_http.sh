#!/usr/bin/env bash
# run_bench_http.sh - compare two builds of the HTTP server, honestly.
#
#   bash bench/run_bench_http.sh                    # measure the current libs
#   bash bench/run_bench_http.sh <other-libs-dir>   # A/B against another build
#
# Wall-clock timing on a busy machine is useless for this: a contended host
# moves these numbers 30%+ between runs of the *same* binary. So the metric here
# is CPU time (user+sys) for a fixed workload, which measures work done rather
# than time elapsed, and the script always measures a noise floor first - the
# spread across repeated runs of one unchanged build. Any A/B difference smaller
# than that floor is not a result.
set -u
cd "$(dirname "$0")/.."

VM="${VM:-flarisvm}"
command -v "$VM" >/dev/null || { echo "no $VM on PATH"; exit 1; }
BENCH=bench/realworld/bench_http.fls
ROUNDS="${ROUNDS:-7}"
OTHER="${1:-}"

cpu() {  # libs-dir -> user+sys seconds
    { /usr/bin/time -p "$VM" --libs="$1" "$BENCH" >/dev/null; } 2>&1 \
        | grep -E '^(user|sys)' | sed 's/[a-z]*  *//' | paste -sd+ - | bc
}

echo "host load: $(uptime | sed 's/.*averages*: //')"
echo "metric: user+sys CPU seconds for a fixed workload, ${ROUNDS} rounds"
echo

A=(); B=()
for i in $(seq 1 "$ROUNDS"); do
    A+=("$(cpu ./libs)")
    [ -n "$OTHER" ] && B+=("$(cpu "$OTHER")")
done

summary() { # label samples...
    local label=$1; shift
    python3 - "$label" "$@" <<'PY'
import sys, statistics as s
label, vals = sys.argv[1], [float(v) for v in sys.argv[2:]]
print("%-14s min=%.2f  median=%.2f  max=%.2f  spread=%.0f%%"
      % (label, min(vals), s.median(vals), max(vals), (max(vals)/min(vals)-1)*100))
PY
}

summary "./libs" "${A[@]}"
if [ -n "$OTHER" ]; then
    summary "$OTHER" "${B[@]}"
    python3 - "${A[*]}" "${B[*]}" <<'PY'
import sys
a = [float(x) for x in sys.argv[1].split()]
b = [float(x) for x in sys.argv[2].split()]
floor = max(max(a)/min(a), max(b)/min(b)) - 1
delta = min(a)/min(b) - 1
print()
print("noise floor (same binary, run to run): %.0f%%" % (floor*100))
print("./libs vs baseline (min vs min):       %+.1f%%" % (delta*100))
print("VERDICT: %s" % ("inconclusive - the difference is inside the noise floor"
                       if abs(delta) <= floor else
                       "significant - the difference exceeds the noise floor"))
PY
fi

echo
echo "Per-path detail (current libs, one run):"
"$VM" --libs=./libs "$BENCH" 2>/dev/null | grep -E 'us/req'
