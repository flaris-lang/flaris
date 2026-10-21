# Flaris benchmarks

Reproducible cross-language benchmarks for the Flaris VM, in four parts that
answer different questions.

**Integer kernels** (`kernels/`) are tight arithmetic and call-heavy loops with
no library work. They measure the VM's dispatch loop and its JIT backend, and
they are where an interpreted language is judged most harshly.

**Real-world builtins** (`realworld/`) exercise the library paths people
actually reach for - `Json.Parse`, string concatenation, `Regex.Matches`. Most
of that work happens inside Flaris's C builtins, so the results look quite
different from the kernels.

**File I/O** (`io/`) moves bytes between the program and the filesystem:
reading a file line by line, reading one whole, writing one. This is where a
log processor, a build tool or a web server spends its life, and it is the half
most language comparisons leave out entirely. It is also where the differences
between runtimes are least about clever compilation and most about whether the
basics - buffering, allocation, system-call count - were got right.

**Scenarios** (`interp/`) are small programs shaped like ordinary code:
building and discarding objects, walking a matrix, map lookups, method calls,
string routines, a sort through a comparator. They are the mix a real program
is made of, and they include the workloads where Flaris is weakest, which is
why they are here. Next to them run five **standard benchmarks** that this
project did not choose: nbody, spectral-norm, fannkuch-redux and k-nucleotide
from The Computer Language Benchmarks Game, and Martin Richards' scheduler
simulation.

All four matter. A language that only publishes the flattering half is not
telling you much.

## Running them

The only hard requirement is the Flaris VM itself:

```bash
curl -fsSL https://www.flaris-lang.org/install.sh | sh
./run_bench.sh
```

`run_bench.sh` runs the kernels and then hands off to
`run_bench_realworld.sh`, `run_bench_io.sh` and `run_bench_scenarios.sh`,
writing all four parts into one dated snapshot under `results/`. Any of them
can also be run on its own.

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
| `PYTHON` | the newest `python3.N`, then `python3`, `python` |
| `LUA` | `lua`, `lua5.4`, `lua5.3` |
| `LUAJIT` | `luajit` |
| `LUAU` | `luau` |
| `WREN` | `wren_cli`, `wren` |
| `JANET` | `janet` |
| `SQUIRREL` | `sq` |
| `DUK` | `duk` |
| `MICROPYTHON` | `micropython` |
| `RUBY` | brew ruby, then `ruby` |
| `PHP` | `php` |
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
  run_bench.sh              integer kernels, then hands off to the other parts
  run_bench_realworld.sh    JSON / string build / regex
  run_bench_io.sh           read lines / read whole file / write lines
  run_bench_scenarios.sh    the scenarios and standard benchmarks in interp/
  lib.sh                    runtime discovery, timing harness, host description
  kernels/                  fib, sieve, collatz, tailcall - one source file per language
  realworld/                json, strbuild, regex + the input generator
  io/                       readlines, slurp, write + the input generator
  interp/                   scenarios and standard benchmarks, plus run_interp.sh for a quick
                            interpreter-only table at the terminal
  results/                  dated snapshots, one file per run
```

## What each benchmark measures

| Benchmark | Workload | What it stresses |
| --------- | -------- | ---------------- |
| `fib` | `fib(38)`, ~126 M recursive calls | function-call overhead, branch prediction |
| `sieve` | Sieve of Eratosthenes, N = 10 M | byte-array indexing, memory bandwidth |
| `collatz` | Collatz step counts, n = 1…1 M | integer arithmetic with irregular branching |
| `tailcall` | self-recursive `tailsum`, depth 2,000,000 | tail-call elimination - who has it, who doesn't |
| `json` | parse an 18 MB / 300k-record array, 5× | JSON parser plus object materialisation |
| `strbuild` | grow a string by 1 M small appends | string append strategy |
| `regex` | scan a 9.8 MB corpus for dates, 5× | regex engine throughput |
| `readlines` | read a 53 MB file line by line | buffering, per-line handoff |
| `slurp` | read the same file in one call | copying from the page cache |
| `write` | write 1 M formatted lines | formatting, write buffering |
| `binarytrees` | build and walk 14.6 M short-lived tree nodes | allocation and reclamation |
| `matmul` | 220 × 220 integer matrix multiply | nested loops, two-level indexing |
| `dict` | 200k string keys, inserted and looked up 3× | string hashing, map lookup |
| `method` | 6 M calls to two small methods | method lookup and call cost |
| `strops` | split, search and join a CSV line, 120k× | the standard string library |
| `sortcb` | sort 120k ints 6× through a user comparator | calls from the sort into user code |
| `nbody` | five bodies, 200,000 time steps | float arithmetic on object fields |
| `spectralnorm` | spectral norm at size 800 | float multiply-adds over float arrays |
| `fannkuch` | fannkuch-redux over 10 elements | small integer-array permutations |
| `richards` | Richards' scheduler simulation, 500 runs | method calls, links between small objects |
| `knucleotide` | k-mer counts over 2,000,000 bases | substrings, string hashing, map updates |

Every language must produce the same `result:` integer for a given benchmark.
The runners cross-check this after each pass and warn loudly on any
disagreement, which is what catches a "fast" implementation that quietly does
less work. `tailcall` is the one benchmark where a language can legitimately
be absent instead of disagreeing: a runtime with no tail-call elimination is
expected to exhaust its call stack before printing a result at all, and it is
then left out of that table exactly like a language that was never
installed - see the benchmark's own section in a results snapshot for which
languages that is expected to happen to.

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
[results/2026-10-13-apple-m5-arm64.md](results/2026-10-13-apple-m5-arm64.md)
(VM 1.0.5.0, Apple M5, CPython 3.14). The shape has been stable across
releases; the exact figures move.

**On integer kernels there are two very different answers.** With the JIT
enabled Flaris averages 1.9× C across the three kernels, which puts it in the
native-compiled tier: just ahead of Nim (2.1×), well ahead of LuaJIT (4.1×).
The plain bytecode VM averages 13.6× C, level with Lua (14.1×) and ahead of PHP
(16.3×), Luau (17.9×), QuickJS (25.3×) and CPython (36.0×). The honest summary
is that Flaris's interpreter is a competent bytecode VM in the Lua tier, its JIT
reaches the compiled tier on code shaped like this, and you should know which
one you are running.

Two rows deserve care. **C# is the closest architectural comparison in the
table** - a statically typed managed runtime whose method JIT is expected to
reach native speed, which is exactly what Flaris is attempting - and at 1.4× it
beats both Go (1.5×) and Nim (2.1×). That is the bar for this design, and
Flaris's JIT is not at it yet. **Node/V8's 5.6× average is misleading on its
own**: it is dominated by collatz, where JavaScript's doubles cost it 12×,
while on fib and sieve V8 lands close to Flaris JIT (176 / 22 ms against
122 / 22 ms). The two JavaScript engines differ by about 4.5× on average,
which is why both are listed.

Read those ×C ratios loosely. They divide by a C baseline measured in the same
run, and C's own numbers move a few percent between runs, which moves every
ratio with them. The absolute millisecond columns are the stable figures.

**On builtin-heavy work Flaris moves up a tier**, because that work happens in
C rather than in the dispatch loop. Parsing 18 MB of JSON it is 1.3× behind
Node/V8 and ahead of Go's `encoding/json`, CPython, QuickJS and Nim's
`std/json`. The naive `s += piece` loop runs linearly rather than
quadratically, so it lands level with Node and behind only the two languages
that use a dedicated builder. Scanning 9.8 MB for dates it is second only to
V8, ahead of CPython, QuickJS, Nim and Go - though still 2.6× behind V8, whose
patterns are JIT-compiled to native code.

**File I/O puts it in the middle of the field.** Reading 2 million lines takes
88 ms: behind the compiled languages, Node and PHP, ahead of Ruby, CPython and
both Luas. Reading a whole 53 MB file is a tie across the field at about 5 ms.
Writing a million formatted lines it is behind the five compiled languages and
ahead of QuickJS, CPython, Node and Lua.

**The scenarios are where Flaris is weakest, and its JIT barely helps there.**
Across the six program-shaped scenarios the JIT beats the interpreter on one,
method calls (149 against 193 ms); on the other five the two lanes are within
noise of each other. The JIT that reaches 1.9× C on the kernels covers very
little of code shaped like this today, and that is the gap that matters most.
Three results stand out:

- **Allocation churn is the weakest point.** Building and discarding 14.6 M
  tree nodes takes Flaris 1.2 s, slower than every runtime here except PUC
  Lua: CPython needs 0.69 s, Luau 0.62 s, LuaJIT 0.31 s and V8 0.09 s. The time
  goes on creating and reclaiming each small object, which the JIT does not
  touch.
- **Chained indexing** (`b[k][j]` in a matrix multiply) takes 143 ms, 2×
  behind Lua and Luau and 16× behind LuaJIT.
- **String routines are a tie with CPython**, 34 against 36 ms, both behind V8.

Elsewhere Flaris is mid-field: close to Lua and Luau on map lookups and on the
sort through a comparator, and ahead of CPython and QuickJS on method calls.

**The standard benchmarks give the least flattering picture, which is why
they are there.** nbody is Flaris's worst result in the whole suite: 765 ms,
last of nine, behind CPython (456 ms) and 76× behind V8. The interpreter boxes
most float results on the heap - about 33 million boxes in this run - and the
step function takes an array of objects, which the JIT does not compile, so the
JIT lane is no faster. Where the JIT does compile the hot loop it reaches the
top tier: fannkuch-redux is the fastest run in its table (141 ms, level with
V8's 144) and spectral-norm is third (33 ms) behind LuaJIT and V8. richards,
the object-and-method-call benchmark, lands mid-field at 547 ms - ahead of Lua,
Luau's interpreter, QuickJS and CPython, behind Luau's code generator, LuaJIT
and V8 - with 3 of its 21 functions JIT-compiled. k-nucleotide, where most
runtimes spend their time in map code written in C, puts Flaris level with Lua
(622 against 612 ms) and ahead of Node, CPython and QuickJS.

**Against CPython specifically**, since it is the most common point of
comparison: Flaris's interpreter is 2.2-3.0× ahead on the kernels, 1.5-2.6×
on the builtins, 1.3-2.1× on reading and writing lines, 1.6-4.5× on four of
the six scenarios and 1.4-2.1× on four of the five standard benchmarks. It
ties on string routines and reading a whole file, and CPython is 1.7× ahead on
allocation churn and on nbody.

**Memory splits the same way, but along a different seam.** Where the workload
is buffers or strings, Flaris sits far below the other managed runtimes: 16 MB
for the 10 M-element sieve against Lua's 239 MB and LuaJIT's 130 MB, and 20 MB
for the string build against Node's 149 MB and Lua's 99 MB. The AOT-compiled
lanes and QuickJS are lower still on the sieve, at 11-15 MB. On the JSON
benchmark, which materialises 300k records as live objects, it peaks at 123 MB
- second of the seven runtimes, behind Go (103 MB) and ahead of QuickJS
(165 MB), Node (215 MB), CPython (235 MB) and Nim (337 MB).

Baseline footprint is about 6.7 MB, above Lua (1.9 MB) and QuickJS (2.3 MB)
and below CPython (14.2 MB). That figure is mostly the pre-allocated SLAB
pools, so it is a fixed floor rather than something that grows with the
program. The two JIT-backed managed runtimes start an order of magnitude
higher - C# at 40.1 MB and Node at 46.5 MB on the same kernel - which is the
trade that buys their compile speed, and the reason Flaris's JIT tier is
interesting at 6.8 MB.

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
- CPython is the newest `python3.N` found on `PATH`, in its default
  configuration: the experimental JIT is off, as it is in standard builds. The
  version matters - on `fib`, 3.14 is about twice as fast as 3.9, which some
  systems still ship as `python3` - so check the toolchain table of a snapshot
  before comparing it with another.
- Rust and C# take part in the integer kernels and file I/O only. Their
  real-world equivalents would pull in external packages - `serde_json`, the `regex`
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
Drop the file in `kernels/`, `realworld/`, `io/` or `interp/` following the
existing naming (`bench_<name>.<ext>`, plus `bench_<name>_node.js` where Node
needs its own variant), then add the language to the relevant `*_LANGS` array and to
`run_lang` in the runner. A compiled lane also needs a build step next to the
others and an entry in `.gitignore` for whatever it emits; `lib.sh` owns
discovery (`resolve_all_tools`, `report_missing_tools`) and the display names
(`lang_name`, `lang_detail`).

Lanes must stay optional. A language that is not installed is reported once and
skipped - never a zero, never a failed run - so that a machine with only
Python and Flaris still produces a valid, smaller report.
