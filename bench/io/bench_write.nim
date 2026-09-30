# Write a million formatted lines. See bench_write.c for what this measures.
import std/[times, os]

const LINES = 1000000
let t0 = epochTime()
var f: File
if not open(f, "io_out_nim.txt", fmWrite):
  quit(1)
for i in 0 ..< LINES:
  f.write($i & " payload " & $(i * 7 mod 9973) & "\n")
close(f)
let ms = int((epochTime() - t0) * 1000)

let size = getFileSize("io_out_nim.txt")
removeFile("io_out_nim.txt")
echo "result: ", size
echo "elapsed: ", ms
