# bench_regex.nim - scan a 9.8 MB corpus for YYYY-MM-DD dates, SCANS times.
# std/re is a PCRE binding.
import std/[re, times]

let text = readFile("bench_corpus.txt")
let scans = 5
let pat = re"\b\d{4}-\d{2}-\d{2}\b"
let t0 = epochTime()
var total = 0
for k in 0 ..< scans:
  total += findAll(text, pat).len
let elapsed = int((epochTime() - t0) * 1000)
echo "result: ", total
echo "elapsed: ", elapsed, " ms"
