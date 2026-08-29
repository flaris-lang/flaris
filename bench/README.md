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
| `RUSTC` | `rustc` |
| `GO` | `go` |
| `NIM` | `nim` |
| `DOTNET` | `dotnet` (SDK 10+) |
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
[results/2026-08-29-apple-m5-arm64.md](results/2026-08-29-apple-m5-arm64.md)
(VM 1.0.2.0, Apple M5). The shape has been stable across releases; the exact
figures move.

**On integer kernels there are two very different answers.** With the JIT
enabled Flaris averages 2.5× C across the three kernels, which puts it in the
native-compiled tier: just behind Nim (2.1×), ahead of LuaJIT (4.3×). The plain
bytecode VM averages 20.2× C, ahead of QuickJS (25.8×) and CPython (65.7×) but
behind Lua (14.7×). The honest summary is that Flaris's interpreter is a
competent bytecode VM around the Lua tier, its JIT reaches the compiled tier,
and you should know which one you are running.

Two rows deserve care. **C# is the closest architectural comparison in the
table** - a statically typed managed runtime whose method JIT is expected to
reach native speed, which is exactly what Flaris is attempting - and at 1.4× it
beats both Go (1.5×) and Nim (2.1×). That is the bar for this design, and
Flaris's JIT is not at it yet. **Node/V8's 5.7× average is misleading on its
own**: it is dominated by collatz, where JavaScript's doubles cost it 12×,
while on fib and sieve V8 lands level with Flaris JIT (183 / 23 ms against
181 / 29 ms). The two JavaScript engines differ by more than 4× on average,
which is why both are listed.

Read those ×C ratios loosely. They divide by a C baseline measured in the same
run, and C's own numbers move a few percent between runs, which moves every
ratio with them. The absolute millisecond columns are the stable figures.

**On builtin-heavy work Flaris moves up a tier**, because that work happens in
C rather than in the dispatch loop. Parsing 18 MB of JSON it is 1.5× behind
Node/V8 and ahead of Go's `encoding/json`, CPython and Nim's `std/json`. The
naive `s += piece` loop runs linearly rather than quadratically, so it lands
with the managed-runtime builders instead of blowing up. Scanning 9.8 MB for
dates it is second only to V8, ahead of QuickJS, Nim, CPython and Go - though
still 3.1× behind V8, whose patterns are JIT-compiled to native code.

**Memory splits the same way, but along a different seam.** Where the workload
is buffers or strings, Flaris sits far below the other managed runtimes: 17 MB
for the 10 M-element sieve against Lua's 238 MB and LuaJIT's 130 MB, and 20 MB
for the string build against Node's 149 MB and Lua's 107 MB. The AOT-compiled
lanes and QuickJS are lower still on the sieve, at 11-14 MB. On the JSON
benchmark, which materialises 300k records as live objects, it peaks at 208 MB
- third of the six runtimes, behind Go (103 MB) and QuickJS (165 MB) but ahead
of Node (216 MB), CPython (260 MB) and Nim (336 MB).

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

Baseline footprint is about 6.8 MB, above Lua (1.7 MB) and QuickJS (2.0 MB) and
below CPython (8.2 MB). That figure is mostly the pre-allocated SLAB pools, so
it is a fixed floor rather than something that grows with the program. The two
JIT-backed managed runtimes start an order of magnitude higher - C# at 39.6 MB
and Node at 46.9 MB on the same kernel - which is the trade that buys their
compile speed, and the reason Flaris's JIT tier is interesting at 7.0 MB.

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
- Flaris appears twice: the plain bytecode VM (`--jit-disable`), and the
  default build, which has the native JIT backend enabled.
- Rust and C# take part in the integer kernels only. Their real-world
  equivalents would pull in external packages - `serde_json`, the `regex`
  crate - and every other lane here builds from a single source file with no
  dependency fetch, which is what makes the suite reproducible offline.
  Extending them to the real-world half is a decision worth taking
  deliberately, not by accident: it would put Flaris's builtins against two of
  the fastest library implementations in existence.
- The C# lane runs on RyuJIT rather than native AOT. .NET 10 file-based apps
  publish AOT by default and the runner turns that off, because the point of
  the lane is the managed-runtime-with-a-JIT tier - the one Flaris itself is
  aiming at. Published as AOT it would just be a third entry in the compiled
  tier next to Go and Nim.
- JavaScript appears as two engines with very different answers, and the
  kernels are where they diverge most. QuickJS is a compact interpreter;
  V8 is a full optimising JIT. Reporting only one of them would misrepresent
  "JavaScript" by a wide margin.

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
`run_lang` in the runner. A compiled lane also needs a build step next to the
others and an entry in `.gitignore` for whatever it emits; `lib.sh` owns
discovery (`resolve_all_tools`, `report_missing_tools`) and the display names
(`lang_name`, `lang_detail`).

Lanes must stay optional. A language that is not installed is reported once and
skipped - never a zero, never a failed run - so that a machine with only
Python and Flaris still produces a valid, smaller report.
