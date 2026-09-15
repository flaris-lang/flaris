# bench/interp — interpreters against interpreters

Small programs, written once per language, timed against each other. Flaris runs
with its JIT switched off (`--jit-disable`) so that this compares interpreted
execution with interpreted execution — see `bench/kernels` for the comparison
that includes compiled languages and JITs.

The three integer kernels are shared with `bench/kernels`; the six scenarios
here are new, and deliberately reach for what ordinary programs spend their time
on rather than for tight arithmetic.

| scenario | what it is dominated by |
| -------- | ----------------------- |
| `fib` | recursive function calls |
| `sieve` | byte-array writes in a tight loop |
| `collatz` | data-dependent branching |
| `binarytrees` | creating and discarding many short-lived objects |
| `matmul` | nested loops and two-dimensional indexing (`b[k][j]`) |
| `dict` | string hashing and map lookup, 200k keys |
| `method` | finding and calling a method on an instance |
| `strops` | the standard library's split / join / search routines |
| `sortcb` | a sort whose comparator is written in the language |

## Running it

```bash
./run_interp.sh
```

That is the whole thing. Every runtime it can find on `PATH` takes part; the
rest are skipped and shown as `-`, so a box with only Python and Lua still
produces a useful table.

```bash
RUNS=7 ./run_interp.sh                      # more repetitions, less noise
FLARISVM=/path/to/flarisvm ./run_interp.sh  # a specific build
BENCHES="matmul dict" ./run_interp.sh       # just some of the scenarios
KERNELS="" ./run_interp.sh                  # scenarios only, skip the kernels
```

The runner prints the resolved path and version of every interpreter before the
table. Check it: `flarisvm` on `PATH` is easily an older install than the build
you meant to measure.

Runtimes used, if you want the full set: `lua`, `luau`, `qjs` (QuickJS),
`python3`, and `flarisvm`.

## Reading the output

Times are milliseconds, the **minimum** of `RUNS` repetitions — for a
CPU-bound loop the distribution has a hard floor and a long upper tail, so the
minimum is the least noise-contaminated estimate.

The last column is the value every implementation must produce. The runner
cross-checks it and prints `MISMATCH` if any language disagrees, so a benchmark
that has quietly stopped doing the same work in each language shows up as a
wrong answer rather than a fast time.

Numbers are only comparable within one run on one machine. Nothing here is
pinned to a CPU model, so do not compare a table from your laptop against one
from someone else's.

## Adding a language

Add `bench_<scenario>.<ext>` for each scenario — in this directory, or in
`../kernels` for the three shared ones — and print the same two lines:

```
result: <integer>
elapsed: <milliseconds> ms
```

then add a case to `cmd_for` in `run_interp.sh`. Time from inside the program
with a monotonic clock so that interpreter startup is never counted.

Two portability traps that already caught this suite:

- **Luau has no `<<`.** It descends from Lua 5.1; use `2^n` and `math.floor`.
- **Doubles lose the low bits.** Luau and QuickJS carry every number as a
  double, so a random generator whose product passes 2^53 silently diverges
  from languages with 64-bit integers. `sortcb` uses a multiplier that stays
  under it on purpose. The `result:` cross-check is what caught this.
