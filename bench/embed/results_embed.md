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
| Lua 5.5 | 31 | 31.0 |
| Flaris (C host) | 33 | 33.0 |
| QuickJS | 53 | 53.0 |
| Duktape 2.7 | 121 | 121.0 |
| Wren 0.4 | 305 | 305.0 |
| Janet | 681 | 681.0 |

## 2. Calling a script function

Create and load once, then call `Update(i)` 1000000 times. What a per-frame
hook pays. The no-engine row is the same function in C, called directly.

| Host | total (ms) | per call (ns) |
| ---- | ---------: | ------------: |
| no engine (C call) | 0 | <1 |
| QuickJS | 10 | 10.0 |
| Wren 0.4 | 13 | 13.0 |
| Lua 5.5 | 17 | 17.0 |
| Flaris (C host) | 45 | 45.0 |
| Duktape 2.7 | 55 | 55.0 |
| Janet | 63 | 63.0 |
