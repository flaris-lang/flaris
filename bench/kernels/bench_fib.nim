# bench_fib.nim - recursive Fibonacci, n=38
import std/[monotimes, times, strformat]

proc fib(n: int): int =
  if n <= 1: return n
  return fib(n - 1) + fib(n - 2)

let n = 38
let t0 = getMonoTime()
let result = fib(n)
let elapsed = int((getMonoTime() - t0).inMilliseconds)
echo &"result: {result}"
echo &"elapsed: {elapsed} ms"
