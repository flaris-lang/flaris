# Count lines and bytes, one line at a time. See bench_readlines.c for the
# result fold.
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
lines = 0
total = 0
File.open("io_input.txt", "rb") do |f|
  f.each_line do |line|
    lines += 1
    total += line.bytesize
  end
end
ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000
puts "result: #{lines * 100000000 + total}"
puts "elapsed: #{ms.to_i}"
