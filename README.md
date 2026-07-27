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

Libraries that use native bindings need the unsafe flag:

```bash
flarisvm ./tests/test_sqlite.fls --unsafe
```

## The libraries

37 libraries, all pure Flaris unless noted:

**Data & formats** — `CSV`, `XML`, `BinaryIO`, `BitConverter`, `Config`,
`Template`, `Lexer`

**Numbers** — `BigInt`, `Decimal`, `Complex`, `Numerics`

**Collections & structure** — `Linq`, `Graph`, `Treemap`, `Cache`,
`StringBuilder`

**Web & network** — `Http`, `Https`, `HttpServer`, `Router`, `WebSocket`, `Jwt`

**Data stores** — `SQLite`, `Postgres`, `Redis`

**System & tooling** — `Argparse`, `Process`, `Logger`, `Datetime`, `Promise`,
`Signals`, `ConsoleMenu`, `Test`

**Media** — `Graphics`, `Audio`, `QRCode`

**AI** — `AI` (Ollama client)

`BinaryIO`, `SQLite`, `Postgres`, `Redis` and `WebSocket` require `--unsafe`
because they use FFI or raw memory access.

## Native plugins (FFI)

`SQLite`, `Postgres` and `Redis` bind to their C client libraries through a
small shim, and `ffi/` holds the source for all three plus the plugin ABI
header:

```bash
gcc -shared -fPIC -I ffi -o sqlite_ffi.so ffi/sqlite_ffi.c -lsqlite3
```

`ffi/ffi_object.h` is the only header a plugin needs to include - see the
[FFI guide](doc/ffi.md) for the marshalling rules and for writing your own.

## Performance

`bench/` holds a reproducible cross-language benchmark suite. Run `./run_bench.sh`
there; every language other than Flaris itself is optional and simply omitted if
it is not installed.

On integer kernels (fib, sieve, collatz) Flaris lands in two different tiers
depending on whether the JIT is on — averaged against C on an Apple M2,
VM 1.0.0.9:

| Runtime | avg ×C |
| ------- | -----: |
| C (clang -O2) | 1.0x |
| Go | 1.4x |
| Nim | 2.0x |
| **Flaris `--jit`** | **2.6x** |
| LuaJIT 2.1 | 4.8x |
| **Flaris** (bytecode VM) | **23.5x** |
| Lua 5.4 | 24.5x |
| Python 3 | 43.5x |
| QuickJS | 60.4x |

On workloads that spend their time in the C builtins the picture shifts up a
tier: parsing an 18 MB JSON document, Flaris is 1.3× behind Node/V8 and ahead of
CPython, Go and Nim; scanning 9.8 MB for dates with a regex it is second only to
V8, ahead of Nim and CPython. Peak memory is measured too: best in the field on
buffers and strings, and mid-field on large object graphs — 208 MB parsing that
JSON document, against Node's 231 MB and Go's 100 MB.

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
