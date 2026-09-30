# Read the whole file into memory. See bench_slurp.c for what this measures.
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
data = File.binread("io_input.txt")
ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000
puts "result: #{data.bytesize}"
puts "elapsed: #{ms.to_i}"
