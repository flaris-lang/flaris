// Write a million formatted lines. See bench_write.c for what this measures.
import "io" for File
var LINES = 1000000
var t0 = System.clock
File.create("io_out_wren.txt") { |f|
  var i = 0
  while (i < LINES) {
    f.writeBytes("%(i) payload %((i * 7) % 9973)\n")
    i = i + 1
  }
}
var elapsed = ((System.clock - t0) * 1000).floor
var size = File.size("io_out_wren.txt")
File.delete("io_out_wren.txt")
System.print("result: %(size)")
System.print("elapsed: %(elapsed) ms")
