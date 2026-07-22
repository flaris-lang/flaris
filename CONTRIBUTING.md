# Contributing

Thanks for looking. This repository holds the Flaris standard libraries, their
tests, the examples, the FFI plugin sources and the documentation — all MIT
licensed. The Flaris VM itself is a separate, proprietary component; see
[LICENSE](LICENSE).

## What is most useful

- **New libraries.** Anything a scripting language ought to have and does not
  yet. Write it in Flaris, add a test, and it can ship with the next release.
- **Tests for existing libraries.** Several have thinner coverage than they
  deserve.
- **Bug fixes**, with a test that fails before the fix and passes after.

## Before you start something large

Open an issue or say hello on [Discord](https://discord.gg/TxZK9eXn2c) first.
It avoids the disappointing case where two people write the same library, or
where something is already half-built.

## Working on a library

You need the VM:

```bash
curl -fsSL https://www.flaris-lang.org/install.sh | sh
```

Then rebuild only the library you changed and run its test:

```bash
flarisvm --compile libs/CSV.fls ~/.flaris/libs/CSV.flx
flarisvm ./tests/test_csv.fls
```

Libraries that use FFI or raw memory need `--unsafe`:

```bash
flarisvm ./tests/test_sqlite.fls --unsafe
```

## House style

Existing libraries are the best reference, but broadly:

- Every library carries its documentation **in the `.fls` file itself**, as a
  header comment — that is where the reference for a library lives, not in
  `doc/`.
- Every library has a matching `tests/test_<name>.fls`, ending with a
  **benchmark section**.
- Comments describe what the code does now. No "phase 2" or "used to be"
  references — they stop being true and nobody deletes them.
- Prefer clarity over cleverness. These files double as worked examples of the
  language for people reading it for the first time.

## Pull requests

Fork, branch, and open a PR against `main`. Please say what the change does and
why, and mention how you tested it.

One exception: **`doc/` is published from the upstream repository** and is
overwritten on every release, so fixes there cannot be merged as PRs. Raise
documentation problems as an issue or on Discord instead and they will be fixed
at the source.

## Reporting a bug

The most useful reports include:

- the output of `flarisvm --version`
- your operating system and CPU architecture
- a minimal `.fls` script that reproduces it
- what you expected, and what happened instead

If the VM crashes rather than reporting an error, say so explicitly — that is a
different class of bug and gets priority.
