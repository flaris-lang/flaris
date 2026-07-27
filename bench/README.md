# Flaris benchmarks

Reproducible cross-language benchmarks for the Flaris VM, in two halves that
answer different questions.

**Integer kernels** (`kernels/`) are tight arithmetic and call-heavy loops with
no library work. They measure the VM's dispatch loop and its JIT backend, and
they are where an interpreted language is judged most harshly.

**Real-world builtins** (`realworld/`) exercise the library paths people
actually reach for - `Json.Parse`, string concatenation, `Regex.Matches`. Most
of that work happens inside Flaris's C builtins, so the results look quite
different from the kernels.

Both halves matter. A language that only publishes the flattering half is not
telling you much.

## Running them

The only hard requirement is the Flaris VM itself:

```bash
curl -fsSL https://www.flaris-lang.org/install.sh | sh
./run_bench.sh
```

`run_bench.sh` runs the kernels and then hands off to
`run_bench_realworld.sh`, writing both halves into one dated snapshot under
`results/`. Either script can also be run on its own.

Every other language is optional. Anything that is not installed is reported
once and left out of the tables - it is never reported as a zero or a failure.
So a machine with only Python and Flaris still produces a valid, smaller
report.

Runtimes are discovered on `PATH` and can each be overridden:

| Variable | Default search order |
| -------- | -------------------- |
| `FLARISVM` | `flarisvm` |
| `CC` | `clang`, `cc`, `gcc` |
| `GO` | `go` |
| `NIM` | `nim` |
| `PYTHON` | `python3`, `python` |
| `LUA` | `lua`, `lua5.4`, `lua5.3` |
| `LUAJIT` | `luajit` |
| `NODE` | `node`, `nodejs` |
| `QJS` | `qjs`, `quickjs` |
| `RUNS` | `3` (runs per benchmark; the median is reported) |

For example, to benchmark a local VM build against a Lua you compiled yourself:

```bash
FLARISVM=../flarisvm LUA=~/src/lua-5.4.7/src/lua RUNS=5 ./run_bench.sh
```

The real-world benchmarks need about 28 MB of generated input
(`realworld/bench_data.json`, `realworld/bench_corpus.txt`). It is created
automatically on first run by `realworld/gen_bench_data.py`, contains no
randomness, and is byte-identical on every machine, so results are comparable
across hosts. Both files are gitignored.

## Layout

```text
bench/
  run_bench.sh              integer kernels, then hands off to the real-world half
  run_bench_realworld.sh    JSON / string build / regex
  lib.sh                    runtime discovery, timing harness, host description
  kernels/                  fib, sieve, collatz - one source file per language
  realworld/                json, strbuild, regex + the input generator
  results/                  dated snapshots, one file per run
```

## What each benchmark measures

| Benchmark | Workload | What it stresses |
| --------- | -------- | ---------------- |
| `fib` | `fib(38)`, ~126 M recursive calls | function-call overhead, branch prediction |
| `sieve` | Sieve of Eratosthenes, N = 10 M | byte-array indexing, memory bandwidth |
| `collatz` | Collatz step counts, n = 1…1 M | integer arithmetic with irregular branching |
| `json` | parse an 18 MB / 300k-record array, 5× | JSON parser plus object materialisation |
| `strbuild` | grow a string by 1 M small appends | string append strategy |
| `regex` | scan a 9.8 MB corpus for dates, 5× | regex engine throughput |

Every language must produce the same `result:` integer for a given benchmark.
The runners cross-check this after each pass and warn loudly on any
disagreement, which is what catches a "fast" implementation that quietly does
less work.

## Timing and memory

Timings are wall-clock and are measured **inside** the program, so interpreter
startup and input reading are never counted. Each figure is the median of
`RUNS` runs.

Peak resident set size is measured **outside** the process with `time(1)`, so
unlike the timings it includes the runtime's own baseline: interpreter, JIT
code cache, allocator arenas, and the garbage-collector heap high-water mark
where there is one. Read that column with two caveats in mind:

- On the small kernels it mostly reports startup footprint. `fib` allocates
  essentially nothing, so the column is really "what does this runtime cost to
  have running at all".
- A tracing collector is measured at its high-water mark, which is partly a
  scheduling artefact - collecting less often looks worse without being less
  efficient. Flaris uses reference counting over pre-allocated SLAB pools with
  no tracing collector, so its figure tracks live data more directly than Go's
  or Node's do.

The JSON benchmark is the one where memory is genuinely informative: it
materialises 300k records as live objects, so the column reflects the cost of
each runtime's object representation rather than its startup cost.

If no external `time(1)` is available the memory columns are simply omitted.

## Where Flaris lands

Numbers below are from
[results/2026-07-27-apple-m2-arm64.md](results/2026-07-27-apple-m2-arm64.md)
(VM 1.0.0.9, Apple M2). The shape has been stable across releases; the exact
figures move.

**On integer kernels there are two very different answers.** With the JIT
enabled Flaris averages 2.7× C across the three kernels, which puts it between
Nim (2.1×) and LuaJIT (5.4×) - the native-compiled tier. The plain bytecode VM
averages 24.2× C, which is the Lua 5.4 tier (26.5×), ahead of CPython (43.7×)
and QuickJS (65.7×). The honest summary is that Flaris's interpreter is a
competent bytecode VM and its JIT is genuinely competitive with compiled
languages, and you should know which one you are running.

Read those ×C ratios loosely. They divide by a C baseline measured in the same
run, and C's own numbers move a few percent between runs, which moves every
ratio with them. The absolute millisecond columns are the stable figures.

**On builtin-heavy work Flaris moves up a tier**, because that work happens in
C rather than in the dispatch loop. Parsing 18 MB of JSON it is 1.4× behind
Node/V8 and ahead of Go's `encoding/json`, CPython and Nim's `std/json`. The
naive `s += piece` loop runs linearly rather than quadratically, so it lands
with the managed-runtime builders instead of blowing up. Regex is the weak
spot: on par with CPython, and 6× behind V8's JIT-compiled patterns.

**Memory splits the same way, but along a different seam.** Where the workload
is buffers or strings, Flaris is at or near the best in the field: 16 MB for
the 10 M-element sieve against Lua's 260 MB, and 20 MB for the string build
against Node's 124 MB. On the JSON benchmark, which materialises 300k records
as live objects, it peaks at 208 MB - third of the seven runtimes, behind Go
(100 MB) and QuickJS (149 MB) but ahead of Node (231 MB), CPython (236 MB) and
Nim (336 MB).

That figure used to be 375 MB, the worst in the field, for a reason worth
recording. A loop-scoped local was only released when it was overwritten, and
that happens *after* its replacement has been fully constructed - so a re-parse
loop kept two complete object trees alive at once. Peak doubled from one
iteration to two and then stayed flat however many more you ran. The VM now
releases a loop body's locals at the back-edge, and peak is flat from the first
iteration on.

What remains is the object representation itself: a parsed record costs about
508 bytes, of which 288 is a backing hashmap allocated eagerly at eight buckets
whatever the record's size and 128 is four key strings cloned per record rather
than shared - against roughly 40 bytes of actual payload. Class instances,
which store their fields in a slot array instead, cost about 188 bytes for the
same shape. That gap is the remaining opportunity, and the memory column is
published next to the timings so it stays visible rather than implied.

Baseline footprint is about 6.8 MB, above Lua (1.6 MB) and QuickJS (2.1 MB) and
below CPython (14.4 MB). That figure is mostly the pre-allocated SLAB pools, so
it is a fixed floor rather than something that grows with the program.

## Reading these honestly

A few things worth stating plainly, because benchmark pages usually do not:

- These are microbenchmarks. They predict the performance of code that looks
  like them, and nothing else.
- Single-machine, single-run-median numbers. Treat differences under roughly
  15% as noise, and differences between machines as meaningless.
- The comparison languages are used idiomatically but not tuned by an expert in
  each. Where an idiomatic choice differs - Go and Nim use their string
  builders in `strbuild` because naive concatenation is quadratic for them -
  it is documented in the snapshot rather than hidden.
- Every language must materialise the *same* data, which matters most in the
  JSON benchmark. Go decodes into a struct carrying all four fields; a struct
  with only the summed field would let `encoding/json` skip the rest of each
  record and would roughly halve both its time and its memory while appearing
  to measure the same thing. The cross-checked `result:` integer does not catch
  that class of mistake, because the sum comes out right either way.
- Flaris appears twice: the plain bytecode VM, and `--jit` with the native
  backend. Both are honest defaults; the JIT is not on by default.

## Adding a benchmark or a language

A benchmark program does exactly two things: run the workload, and print

```text
result: <integer>
elapsed: <milliseconds>
```

to stdout, timing only the workload itself with the language's monotonic clock.
Drop the file in `kernels/` or `realworld/` following the existing naming
(`bench_<name>.<ext>`, plus `bench_<name>_node.js` where Node needs its own
variant), then add the language to the relevant `*_LANGS` array and to
`run_lang` in the runner.
