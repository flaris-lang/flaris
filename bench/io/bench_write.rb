# Write a million formatted lines. See bench_write.c for what this measures.
LINES = 1000000
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
File.open("io_out_rb.txt", "wb") do |f|
  (0...LINES).each { |i| f.write("#{i} payload #{(i * 7) % 9973}\n") }
end
ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000
size = File.size("io_out_rb.txt")
File.delete("io_out_rb.txt")
puts "result: #{size}"
puts "elapsed: #{ms.to_i}"
