# bench_sieve.nim - Sieve of Eratosthenes, N=10,000,000
import std/[monotimes, times, math, strformat]

proc sieve(N: int): int =
  var flags = newSeq[uint8](N + 1)
  for i in 0..N: flags[i] = 1
  flags[0] = 0; flags[1] = 0
  let pMax = int(sqrt(float(N)))
  for p in 2..pMax:
    if flags[p] == 1:
      var i = p * p
      while i <= N:
        flags[i] = 0
        i += p
  result = 0
  for i in 2..N:
    if flags[i] == 1: inc result

let N = 10_000_000
let t0 = getMonoTime()
let count = sieve(N)
let elapsed = int((getMonoTime() - t0).inMilliseconds)
echo &"result: {count}"
echo &"elapsed: {elapsed} ms"
