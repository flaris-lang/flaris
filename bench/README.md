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
| `ZIG` | `zig` |
| `SWIFTC` | `swiftc` |
| `JAVAC`, `JAVA` | brew openjdk, then `javac`, `java` |
| `PYTHON` | the newest `python3.N`, then `python3`, `python` |
| `LUA` | `lua`, `lua5.4`, `lua5.3` |
| `LUAJIT` | `luajit` |
| `LUAU` | `luau` |
| `WREN` | `wren_cli`, `wren` |
| `JANET` | `janet` |
| `SQUIRREL` | `sq` |
| `DUK` | `duk` |
| `MICROPYTHON` | `micropython` |
| `RHAI` | `rhai-run` |
| `RUBY` | brew ruby, then `ruby` |
| `PHP` | `php` |
| `NODE` | `node`, `nodejs` |
| `QJS` | `qjs`, `quickjs` |
| `BUN` | `bun` |
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
[results/2026-11-15-apple-m5-arm64.md](results/2026-11-15-apple-m5-arm64.md)
(VM 1.1.0.0, Apple M5, CPython 3.14). The exact figures move between runs; the
shape does not.

**On integer kernels there are two very different answers.** With the JIT
enabled Flaris averages 1.7× C across the three kernels, which puts it in the
native-compiled tier: behind Go (1.4×), ahead of Swift and Nim (1.9×), Bun
(2.2×) and LuaJIT (3.7×). The plain bytecode VM averages 8.2× C, ahead of Lua
(13.1×), PHP (14.9×), Luau (16.1×), QuickJS (22.9×) and CPython (34.5×). The
honest summary is that Flaris's interpreter leads the interpreters, its JIT
reaches the compiled tier on code shaped like this, and you should know which
one you are running.

Three rows deserve care. **C# and Java are the closest architectural comparison
in the table** - statically typed managed runtimes whose method JITs are
expected to reach native speed, which is exactly what Flaris is attempting -
and at 1.3× and 1.2× they beat Go (1.4×). That is the bar for this design, and
Flaris's JIT is not at it yet. **Node/V8's 5.4× average is misleading on its
own**: it is dominated by collatz, where JavaScript's doubles cost it 12×,
while on fib and sieve V8 lands close to Flaris JIT (179 / 21 ms against
124 / 22 ms). Bun runs the same sources on JavaScriptCore at 2.2×.

Read those ×C ratios loosely. They divide by a C baseline measured in the same
run, and C's own numbers move a few percent between runs, which moves every
ratio with them. The absolute millisecond columns are the stable figures.

**On builtin-heavy work Flaris moves up a tier**, because that work happens in
C rather than in the dispatch loop. Parsing 18 MB of JSON (212 ms) it is behind
Bun, Node/V8 and Zig and ahead of Go's `encoding/json`, CPython, QuickJS, Nim's
`std/json` and Swift's `Codable`. The naive `s += piece` loop runs linearly
rather than quadratically, so it lands ahead of Node, Swift and Bun and behind
only the four languages that use a dedicated builder (Zig, Java, Go and Nim).
Scanning 9.8 MB for dates it is third (180 ms), behind the two JavaScript
engines, whose patterns are JIT-compiled to native code, and ahead of Java,
CPython, QuickJS, Nim, Go and Swift.

**File I/O puts it in the middle of the field.** Reading 2 million lines takes
72-74 ms: behind Go, Rust, C#, Node, C and PHP's JIT, ahead of Ruby, Nim,
CPython and both Luas. Reading a whole 53 MB file is a tie across the field at
about 5 ms. Writing a million formatted lines (74 ms) it is behind Rust and C#
and level with Go and C.

**The scenarios are where Flaris is weakest, and its JIT does not help there.**
Across the six program-shaped scenarios the JIT and interpreter lanes are within
noise of each other: the JIT that reaches 1.7× C on the kernels covers very
little of code shaped like this today. Against the other scripting runtimes it
holds up; against the two JavaScript JITs it does not:

- **Allocation churn is the weakest point.** Building and discarding 14.6 M
  tree nodes takes Flaris 826 ms, level with QuickJS and ahead only of Lua
  (1.3 s) and Rhai: CPython needs 0.69 s, Luau 0.62 s, LuaJIT 0.32 s and V8
  0.09 s. The time goes on creating and reclaiming each small object, which the
  JIT does not touch.
- **String routines and a sort through a comparator lead the scripting
  field**: 25 ms and 109 ms, against Luau's 81 and 230 and Lua's 113 and 280.
  Only V8 and Bun are faster at the string routines, and only Bun at the sort.
- **Chained indexing** (`b[k][j]` in a matrix multiply) takes 47 ms, ahead of
  Lua (71) and Luau (70), behind Luau's code generator (34), the JavaScript
  engines (15) and LuaJIT (9).

Elsewhere Flaris is level with Lua and Luau on map lookups (16 ms against 14
and 16) and ahead of both on method calls (103 ms against 201 and 202), behind
LuaJIT and the JavaScript engines.

**The standard benchmarks give the least flattering picture, which is why
they are there.** nbody is Flaris's worst result against the field: 334 ms,
behind Lua (211 ms), QuickJS (290) and Luau (127), and 30× behind LuaJIT and
Bun (11). Its step function works on the float fields of an array of objects,
which the JIT does not compile, so the JIT lane is no faster. Where the JIT does
compile the hot loop it reaches the top tier: fannkuch-redux takes 192 ms, ahead
of LuaJIT (202) and behind only Bun and V8, and spectral-norm 24 ms, level with
V8 and Bun and behind only LuaJIT (16). richards, the object-and-method-call
benchmark, lands at 443 ms - level with Luau's code generator, ahead of Lua,
Luau's interpreter, QuickJS and CPython, behind LuaJIT and the JavaScript
engines. k-nucleotide, where most runtimes spend their time in map code written
in C, puts Flaris at 558 ms, ahead of Lua (599), Node (635), CPython and
QuickJS, behind Luau and LuaJIT.

**Against CPython specifically**, since it is the most common point of
comparison: Flaris's interpreter is 3.7-4.7× ahead on the kernels, 1.7-2.5×
on the builtins, 2.0-2.6× on reading and writing lines, 1.6-16× on five of the
six scenarios and 1.3-4.5× on all five standard benchmarks. It ties on reading
a whole file, and CPython is 1.2× ahead on allocation churn.

**Memory splits the same way, but along a different seam.** Where the workload
is buffers or strings, Flaris sits far below the other managed runtimes: 16 MB
for the 10 M-element sieve against Lua's 239 MB, and 20 MB for the string build
against Node's 144 MB and Lua's 99 MB. The AOT-compiled lanes are lower still
on the sieve, at 11-15 MB. On the JSON benchmark, which materialises 300k
records as live objects, it peaks at 116 MB - behind Zig (38 MB), Go (105 MB)
and Swift (107 MB), ahead of QuickJS (165 MB), Node (181 MB), Bun (200 MB),
CPython (222 MB) and Nim (337 MB).

Baseline footprint is about 6.5 MB, above Lua (1.9 MB), QuickJS (2.3 MB) and
Luau (3.3 MB) and below CPython (13.0 MB). That figure is mostly the
pre-allocated SLAB pools, so it is a fixed floor rather than something that
grows with the program. The JIT-backed managed runtimes start several times
higher - Bun at 23.6 MB, Java at 39.4 MB, C# at 40.1 MB and Node at 42.0 MB on
the same kernel - while Flaris's JIT tier runs in 6.7 MB.

## Reading these honestly

A few things worth stating plainly, because benchmark pages usually do not:

- These are microbenchmarks. They predict the performance of code that looks
  like them, and nothing else.
- Single-machine, single-run-median numbers. Treat differences under roughly
  15% as noise, and differences between machines as meaningless.
- The comparison languages are used idiomatically but not tuned by an expert in
  each. Where an idiomatic choice differs - Go, Nim, Zig and Java use their
  string builders in `strbuild` because naive concatenation is quadratic for
  them - it is documented in the source rather than hidden. Swift's regex lane
  uses `NSRegularExpression`: the native `Regex` type gives the same answer
  about four times slower, and showing that would compare an engine, not the
  language.
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
  aiming at. Published as AOT it would just be another entry in the compiled
  tier next to Go and Nim.
- Zig's standard library has no regex and Java's no JSON parser, so those lanes
  are absent there. Rhai's command-line runner cannot read the input files, so
  Rhai takes part in the kernels, the string build and the scenarios only; it
  is here as the engine Rust programs usually embed.
- JavaScript appears as three engines with very different answers, and the
  kernels are where they diverge most. QuickJS is a compact interpreter; V8
  (Node) and JavaScriptCore (Bun) are full optimising JITs, and Bun runs the
  Node sources unchanged. Reporting only one of them would misrepresent
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
