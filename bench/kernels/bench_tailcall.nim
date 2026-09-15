# bench_tailcall.nim - self-recursive tail call, depth 2,000,000
import std/[monotimes, times, strformat]

proc tailsum(n: int64, acc: int64): int64 =
  if n == 0: return acc
  return tailsum(n - 1, acc + n)

let n: int64 = 2_000_000
let t0 = getMonoTime()
let result = tailsum(n, 0)
let elapsed = int((getMonoTime() - t0).inMilliseconds)
echo &"result: {result}"
echo &"elapsed: {elapsed} ms"
