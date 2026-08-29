# Flaris standard libraries

The standard libraries, examples, documentation and benchmarks for
**[Flaris](https://www.flaris-lang.org)** — a lightweight, fiber-based scripting
language that compiles to portable bytecode and runs on an embeddable C11 VM.

Everything here is MIT licensed and written in Flaris itself, so the libraries
double as a decent read if you want to see what the language looks like in
anger.

> The Flaris VM (`flarisvm`) is a separate, proprietary component distributed as
> a binary from [flaris-lang.org](https://www.flaris-lang.org). See
> [LICENSE](LICENSE) for what these terms do and do not cover.

## Getting started

Install the VM:

```bash
curl -fsSL https://www.flaris-lang.org/install.sh | sh
```

Then import a library by name — no path, no build step:

```js
import { CSV } from library("CSV", "1.0");

fn Main() {
    let rows = CSV.Parse("name,age\nada,36\nalan,41");
    Console.WriteLine(rows[0].name);   // ada
    return 0;
}
```

Libraries resolve from your per-user library folder (`~/.flaris/libs`, or
`%USERPROFILE%\.flaris\libs` on Windows), which the installer populates.

## Working on a library

The installer puts pre-built libraries in your per-user folder, so you only need
to rebuild one you have actually changed:

```bash
flarisvm --compile libs/CSV.fls ~/.flaris/libs/CSV.flx
flarisvm ./tests/test_csv.fls
```

Or keep your build local and point the VM at it, leaving the installed copies
untouched:

```bash
flarisvm --compile libs/CSV.fls ./CSV.flx
flarisvm --libs=. ./tests/test_csv.fls
```

`.flx` files are build artifacts and are not committed. Official releases are
Ed25519-signed; a locally compiled library is unsigned, which the VM accepts
unless it is run with `--require-signed`.

## Running the tests

Each library has a test in `tests/`, and every test file ends with a benchmark
section.

```bash
flarisvm ./tests/test_csv.fls
```

Three libraries bind native code through FFI and need the unsafe flag —
`SQLite`, `Postgres` and `Redis`. Every other library runs in the default
sandbox:

```bash
flarisvm ./tests/test_sqlite.fls --unsafe
```

## The libraries

43 libraries, all pure Flaris unless noted:

**Data & formats** — `CSV`, `XML`, `BinaryIO`, `BitConverter`, `Config`,
`Template`, `Lexer`

**Compression & archives** — `Deflate`, `Zip`

**Numbers** — `BigInt`, `Decimal`, `Complex`, `Numerics`

**Collections & structure** — `Linq`, `Graph`, `Treemap`, `Cache`,
`StringBuilder`

**Web & network** — `Http`, `Https`, `HttpServer`, `HttpUtil`, `Router`,
`WebSocket`, `Jwt`

**Data stores** — `SQLite`, `Postgres`, `Redis`

**System & tooling** — `Argparse`, `Process`, `Logger`, `Datetime`, `Promise`,
`Signals`, `ConsoleMenu`, `Test`, `Util`

**Serial & cellular** — `Modem` (AT transport plus 3GPP 27.007/27.005: SIM and
PIN, signal, registration, operator scan, SMS in PDU mode, data contexts, USSD
and call control)

**Media** — `Graphics`, `Audio`, `QRCode`, `Png`

**AI** — `AI` (Ollama client)

Only `SQLite`, `Postgres` and `Redis` require `--unsafe`, because they bind
their C client libraries through FFI. Every other library, `BinaryIO` and
`WebSocket` included, runs in the default sandbox.

## Native plugins (FFI)

`SQLite`, `Postgres` and `Redis` bind to their C client libraries through a
small shim, and `ffi/` holds the source for all three plus the plugin ABI
header:

```bash
gcc -shared -fPIC -I ffi -o sqlite_ffi.so ffi/sqlite_ffi.c -lsqlite3
```

Or use the helper script:

```bash
# system sqlite (default)
./ffi/build_sqlite_ffi.sh --system

# vendored sqlite amalgamation (no -lsqlite3 dependency)
./ffi/build_sqlite_ffi.sh --vendored --sqlite-dir third_party/sqlite
```

For vendored mode, place `sqlite3.c` and `sqlite3.h` from the open source
SQLite project (GitHub mirror or sqlite.org amalgamation release) in
`third_party/sqlite/`.

`ffi/ffi_object.h` is the only header a plugin needs to include - see the
[FFI guide](doc/ffi.md) for the marshalling rules and for writing your own.

## Performance

`bench/` holds a reproducible cross-language benchmark suite. Run `./run_bench.sh`
there; every language other than Flaris itself is optional and simply omitted if
it is not installed.

On integer kernels (fib, sieve, collatz) Flaris lands in two different tiers
depending on whether the JIT is on — averaged against C on an Apple M5,
VM 1.0.2.0:

| Runtime | avg ×C |
| ------- | -----: |
| C (clang -O2) | 1.0x |
| Rust (rustc -O) | 1.0x |
| C# (.NET, RyuJIT) | 1.4x |
| Go | 1.5x |
| Nim | 2.1x |
| **Flaris `--jit`** | **2.5x** |
| LuaJIT | 4.3x |
| Node/V8 | 5.7x |
| Lua | 14.7x |
| **Flaris** (bytecode VM) | **20.2x** |
| QuickJS | 25.8x |
| Python 3 | 65.7x |

Two rows in that table need a caveat. C# is the closest architectural
comparison here — a statically typed managed runtime whose method JIT is meant
to reach native speed, which is what Flaris `--jit` is attempting — and at 1.4×
it is ahead of Flaris and of both Go and Nim. And Node/V8's average is dragged
down almost entirely by collatz, where JavaScript's doubles cost it 12×; on fib
and sieve V8 runs level with Flaris `--jit`. Rust and C# take part in the
integer kernels only.

On workloads that spend their time in the C builtins the picture shifts up a
tier: parsing an 18 MB JSON document, Flaris is 1.5× behind Node/V8 and ahead of
Go, CPython and Nim; scanning 9.8 MB for dates with a regex it is second only to
V8, ahead of QuickJS, Nim, CPython and Go. Peak memory is measured too: 20 MB
for the string build against Node's 149 MB, 17 MB for the 10 M-element sieve
against Lua's 238 MB, and mid-field on large object graphs — 208 MB parsing that
JSON document, against Node's 216 MB and Go's 103 MB.

Full numbers, methodology and the caveats that matter are in
[bench/README.md](bench/README.md), with dated snapshots in
[bench/results/](bench/results/).

## Documentation

- [Language guide](doc/guide.md) — tutorial: syntax, types, classes, fibers,
  async, modules, debugging
- [Reference](doc/reference.md) — CLI flags, type system, builtins, stdlib API,
  VM limits
- [FFI guide](doc/ffi.md) — calling C, writing native plugins

## Contributing

Bug reports and library contributions are welcome. Good first contributions are
new libraries, tests and documentation for existing ones, or a benchmark result
from hardware we do not have.

Note that `doc/` is **published from the upstream repository**, not authored
here - it is overwritten on each release, so documentation fixes are best raised
as an issue or on Discord rather than as a pull request against those files.
Everything else in this repo takes PRs normally.

- Chat: [Discord](https://discord.gg/TxZK9eXn2c)
- A bug report is most useful with the output of `flarisvm --version`, your OS,
  and a minimal `.fls` script that reproduces it

## Licence

MIT — see [LICENSE](LICENSE). The Flaris VM itself is proprietary and licensed
separately.
