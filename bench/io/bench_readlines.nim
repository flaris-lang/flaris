# Count lines and bytes, one line at a time. See bench_readlines.c for the
# result fold. readLine strips the terminator, so it is added back.
import std/[times, strutils]

let t0 = epochTime()
var lines: int64 = 0
var total: int64 = 0
var f: File
if not open(f, "io_input.txt"):
  quit(1)
var line = ""
while f.readLine(line):
  lines += 1
  total += line.len + 1
close(f)
let ms = int((epochTime() - t0) * 1000)
echo "result: ", lines * 100000000 + total
echo "elapsed: ", ms
