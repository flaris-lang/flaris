# Read the whole file into memory. See bench_slurp.c for what this measures.
import std/times

let t0 = epochTime()
let data = readFile("io_input.txt")
let ms = int((epochTime() - t0) * 1000)
echo "result: ", data.len
echo "elapsed: ", ms
