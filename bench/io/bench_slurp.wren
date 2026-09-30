// Read the whole file into memory. See bench_slurp.c for what this measures.
// Wren's io module reads a file whole or by byte count; it has no line reader,
// which is why Wren takes part here and in the write benchmark only.
import "io" for File
var t0 = System.clock
var data = File.read("io_input.txt")
var elapsed = ((System.clock - t0) * 1000).floor
System.print("result: %(data.bytes.count)")
System.print("elapsed: %(elapsed) ms")
