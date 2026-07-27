# bench_collatz.nim - total Collatz steps for n=1..1,000,000
import std/[monotimes, times, strformat]

proc collatzSteps(n: int64): int64 =
  var x = n
  var steps: int64 = 0
  while x != 1:
    x = if (x and 1) == 1: x * 3 + 1 else: x shr 1
    inc steps
  return steps

let N: int64 = 1_000_000
let t0 = getMonoTime()
var total: int64 = 0
for i in 1'i64..N:
  total += collatzSteps(i)
let elapsed = int((getMonoTime() - t0).inMilliseconds)
echo &"result: {total}"
echo &"elapsed: {elapsed} ms"
