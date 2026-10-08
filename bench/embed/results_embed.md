# Embedding benchmark

What a host pays to *use* an engine, rather than how fast the engine runs a
loop on its own. Every engine runs the same script; both results are checked
against a known value, and a lane whose answer disagrees is dropped.

Host: Darwin arm64, Apple M5. Best of 3.

## 1. Load and run to completion

1000 x (create the VM, load the script, run its top level to
completion, call one function, tear the VM down). What a plugin host pays
every time it spins a script up.

| Host | total (ms) | per cycle (us) |
| ---- | ---------: | -------------: |
| Lua 5.5 | 29 | 29.0 |
| Flaris (C host) | 38 | 38.0 |
| QuickJS | 51 | 51.0 |
| Duktape 2.7 | 118 | 118.0 |
| Wren 0.4 | 269 | 269.0 |
| Janet | 647 | 647.0 |

## 2. Calling a script function

Create and load once, then call `Update(i)` 1000000 times. What a per-frame
hook pays. The no-engine row is the same function in C, called directly.

| Host | total (ms) | per call (ns) |
| ---- | ---------: | ------------: |
| no engine (C call) | 0 | <1 |
| QuickJS | 9 | 9.0 |
| Wren 0.4 | 13 | 13.0 |
| Flaris (C host) | 14 | 14.0 |
| Lua 5.5 | 16 | 16.0 |
| Duktape 2.7 | 54 | 54.0 |
| Janet | 59 | 59.0 |
