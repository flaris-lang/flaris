# bench_strbuild.nim - build a large string, N times. Nim strings are mutable
# with spare capacity, so s.add is amortised linear. result is the byte length.
import std/times

let N = 1000000
let t0 = epochTime()
var s = ""
for i in 0 ..< N:
  s.add("item_")
  s.add($i)
  s.add(";")
let result = s.len
let elapsed = int((epochTime() - t0) * 1000)
echo "result: ", result
echo "elapsed: ", elapsed, " ms"
