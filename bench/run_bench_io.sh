#!/usr/bin/env bash
# File I/O benchmarks: reading a file line by line, reading one whole, and
# writing one. Unlike the integer kernels and the builtin benchmarks, these
# spend their time moving bytes between a program and the filesystem - the part
# of a runtime that decides how a log processor, a build tool or a web server
# actually performs.
#
# Every language uses its own ordinary file API. No manual buffer sizing, no
# memory mapping, no tricks a reader would not write themselves. Where a
# language offers more than one way, the idiomatic one is used and the choice is
# named in the report.
#
# Normally invoked by run_bench.sh, which passes BENCH_REPORT/BENCH_APPEND so
# every half lands in one snapshot. Run it directly for an I/O-only snapshot.
set -euo pipefail
cd "$(dirname "$0")"
BENCH_ROOT="$PWD"
source ./lib.sh

resolve_all_tools || exit 1
[[ -n "${BENCH_APPEND:-}" ]] || report_missing_tools

BENCH_TMP=$(mktemp -d "${TMPDIR:-/tmp}/flaris_bench_io.XXXXXX")
trap 'rm -rf "$BENCH_TMP"' EXIT

mkdir -p "$BENCH_ROOT/results"
REPORT="${BENCH_REPORT:-$BENCH_ROOT/results/$(date +%Y-%m-%d)-$(machine_slug)-io.md}"

cd "$BENCH_ROOT/io"

# Who takes part in what is decided by the standard library, not by us. Luau
# and Duktape have no file API at all in their standalone runtimes and appear
# nowhere. Wren reads a file whole or by byte count and writes strings, but has
# no line reader. Squirrel reads blobs and writes only fixed-width numbers, so
# it can read a file whole and nothing else. Everyone else does all three.
READ_LANGS=(c rs go nim cs py mpy node js lua luajit php phpj rb rbj janet fls flsj)
SLURP_LANGS=(c rs go nim cs py mpy node js lua luajit php phpj rb rbj janet wren nut fls flsj)
WRITE_LANGS=(c rs go nim cs py mpy node js lua luajit php phpj rb rbj janet wren fls flsj)

# ── input data ───────────────────────────────────────────────────────────────
if [[ ! -f io_input.txt ]]; then
    [[ -n "$PYTHON" ]] || { warn "Python 3 is required to generate the benchmark input"; exit 1; }
    log "Generating benchmark input (~53 MB, deterministic)..."
    "$PYTHON" gen_io_data.py
fi

# ── compile ──────────────────────────────────────────────────────────────────
if [[ -n "$CC" ]]; then
    log "Compiling C (-O2)..."
    for b in readlines slurp write; do
        "$CC" -O2 -o "bench_${b}_c" "bench_${b}.c" 2>/dev/null || warn "C: $b failed to build"
    done
fi
if [[ -n "$RUSTC" ]]; then
    log "Compiling Rust (-O)..."
    for b in readlines slurp write; do
        "$RUSTC" -O -o "bench_${b}_rs" "bench_${b}.rs" 2>/dev/null || warn "Rust: $b failed to build"
    done
fi
if [[ -n "$GO" ]]; then
    log "Compiling Go..."
    for b in readlines slurp write; do
        "$GO" build -o "bench_${b}_go" "bench_${b}.go" || warn "Go: $b failed to build"
    done
fi
if [[ -n "$NIM" ]]; then
    log "Compiling Nim (-d:release --opt:speed -O3)..."
    for b in readlines slurp write; do
        "$NIM" c -d:release --opt:speed --passC:"-O3" --hints:off --warnings:off \
            -o:"bench_${b}_nim" "bench_${b}.nim" >/dev/null 2>&1 \
            || warn "Nim: $b failed to build"
    done
fi
if [[ -n "$DOTNET" ]]; then
    log "Compiling C# (dotnet publish -c Release, RyuJIT)..."
    for b in readlines slurp write; do
        "$DOTNET" publish "bench_${b}.cs" -c Release -o "csout_${b}" \
            -p:PublishAot=false >/dev/null 2>&1 || warn "C#: $b failed to build"
    done
fi

# ── run ──────────────────────────────────────────────────────────────────────
run_lang() {  # run_lang <bench> <lang>
    local b="$1" l="$2" f
    case "$l" in
      c)      f=$(bin_path "bench_${b}_c");   [[ -n "$f" ]] && run_one "$b" c   "$f" ;;
      cs)     f=$(bin_path "csout_${b}/bench_${b}"); [[ -n "$f" ]] && run_one "$b" cs "$f" ;;
      rs)     f=$(bin_path "bench_${b}_rs");  [[ -n "$f" ]] && run_one "$b" rs  "$f" ;;
      go)     f=$(bin_path "bench_${b}_go");  [[ -n "$f" ]] && run_one "$b" go  "$f" ;;
      nim)    f=$(bin_path "bench_${b}_nim"); [[ -n "$f" ]] && run_one "$b" nim "$f" ;;
      py)     run_one "$b" py     "$PYTHON" "bench_${b}.py" ;;
      mpy)    run_one "$b" mpy    "$MICROPYTHON" -X heapsize=64M "bench_${b}_mpy.py" ;;
      janet)  run_one "$b" janet  "$JANET"    "bench_${b}.janet" ;;
      wren)   run_one "$b" wren   "$WREN"     "bench_${b}.wren" ;;
      nut)    run_one "$b" nut    "$SQUIRREL" "bench_${b}.nut" ;;
      node)   run_one "$b" node   "$NODE"   "bench_${b}_node.js" ;;
      js)     run_one "$b" js     "$QJS"    --std "bench_${b}.js" ;;
      lua)    run_one "$b" lua    "$LUA"    "bench_${b}.lua" ;;
      luajit) run_one "$b" luajit "$LUAJIT" "bench_${b}.lua" ;;
      php)    run_one "$b" php    "$PHP"    "bench_${b}.php" ;;
      phpj)   run_one "$b" phpj   "$PHP" -d opcache.enable_cli=1 -d opcache.jit_buffer_size=64M \
                                         -d opcache.jit=tracing "bench_${b}.php" ;;
      rb)     run_one "$b" rb     "$RUBY"   "bench_${b}.rb" ;;
      rbj)    run_one "$b" rbj    "$RUBY" --yjit "bench_${b}.rb" ;;
      # The JIT is on by default, so the plain-VM lane has to switch it OFF.
      fls)    run_one "$b" fls    "$FLARISVM" --strip --jit-disable "bench_${b}.fls" ;;
      flsj)   run_one "$b" flsj   "$FLARISVM" --strip "bench_${b}.fls" ;;
    esac
    return 0
}

log "Running read lines (53 MB, 2,000,000 lines)..."
for l in "${READ_LANGS[@]}"; do run_lang readlines "$l"; done
log "Running read whole file (53 MB)..."
for l in "${SLURP_LANGS[@]}"; do run_lang slurp "$l"; done
log "Running write lines (1,000,000 lines)..."
for l in "${WRITE_LANGS[@]}"; do run_lang write "$l"; done

log "Checking result consistency..."
check_bench readlines "${READ_LANGS[@]}"
check_bench slurp     "${SLURP_LANGS[@]}"
check_bench write     "${WRITE_LANGS[@]}"

# ── report ───────────────────────────────────────────────────────────────────
READ_BASE=$(min_ms readlines "${READ_LANGS[@]}")
SLURP_BASE=$(min_ms slurp "${SLURP_LANGS[@]}")
WRITE_BASE=$(min_ms write "${WRITE_LANGS[@]}")

{
if [[ -z "${BENCH_APPEND:-}" ]]; then
cat <<HEADER
# Flaris file I/O benchmark results

**Date:** $(date +%Y-%m-%d)
**Machine:** $(cpu_name), $(os_name) ($(uname -m))
**Flaris VM:** $(flaris_version)

Generated by \`bench/run_bench_io.sh\`. Every number is $(runs_phrase),
measured inside the program. Lower is better.

HEADER
fi

cat <<'INTRO'
## File I/O

Moving bytes between a program and the filesystem. The kernels measure the
dispatch loop and the builtin benchmarks measure library code; this half
measures the part a log processor, a build tool or a web server spends its life
in, and it is the half most language comparisons leave out.

Every language reads and writes identical bytes and must return the same
result. Each uses its own ordinary file API - no manual buffer sizing, no
memory mapping. The input is generated deterministically from a fixed seed, so
a run on one machine is comparable with a run on another.

The file is in the page cache by the time these run, which is deliberate: the
comparison is between the runtimes, not between disks. A cold-cache run
measures the storage device and would tell you nothing about the language.

Who appears in which table is decided by each language's standard library.
Luau and Duktape have no file API at all in their standalone runtimes, so they
appear nowhere. Wren can read a file whole and write strings but has no line
reader; Squirrel can read a file whole and nothing else. That is worth knowing
if you are choosing an embeddable VM by benchmark tables alone: several of them
cannot open a file without help from their host.

### 1. Read lines - 53 MB, 2,000,000 lines

Iterate the file line by line, counting lines and bytes. This is the shape a
program takes when it processes a log, a CSV or any record-per-line format, and
it is dominated by how well the runtime buffers and how cheaply it hands each
line to the program. `result = 200,000,055,741,295` (line count and byte count
folded into one integer).

INTRO

emit_table readlines "$READ_BASE" "vs fastest" 1 "${READ_LANGS[@]}"

cat <<'SLURP'
### 2. Read whole file - 53 MB in one call

Read the entire file into memory in a single call, the way a program loads a
configuration file, a document or a template. Nothing is scanned afterwards -
that would measure each language's string search rather than its file reading.
`result = 55,741,295` bytes.

This one is close across the field, which is the point: at this size everyone is
essentially copying from the page cache, so a language that is slow here is slow
for a structural reason rather than an algorithmic one.

SLURP

emit_table slurp "$SLURP_BASE" "vs fastest" 1 "${SLURP_LANGS[@]}"

cat <<'WRITE'
### 3. Write lines - 1,000,000 formatted lines

Format a line and write it, a million times, then close the file. Formatting is
inside the measurement on purpose: a program writing a file always produces the
text as well as delivering it. Closing is inside it too, so a runtime that
defers its flush does not get to stop the clock early. `result = 19,777,571`
bytes.

This is the benchmark that separates runtimes which buffer their writes from
those which issue one system call per write. A million small writes against an
unbuffered stream is a million system calls, and no amount of fast bytecode
makes that back.

WRITE

emit_table write "$WRITE_BASE" "vs fastest" 1 "${WRITE_LANGS[@]}"

} >> "$REPORT"

log "Wrote $REPORT"
