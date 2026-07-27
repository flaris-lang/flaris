# bench_json.nim - parse an 18 MB JSON array, ITERS times, summing value fields.
import std/[json, times]

let text = readFile("bench_data.json")
let iters = 5
let t0 = epochTime()
var total: int64 = 0
for k in 0 ..< iters:
  let arr = parseJson(text)
  for rec in arr:
    total += rec["value"].getInt
let elapsed = int((epochTime() - t0) * 1000)
echo "result: ", total
echo "elapsed: ", elapsed, " ms"
