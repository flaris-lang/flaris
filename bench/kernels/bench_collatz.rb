# bench_collatz.rb - total Collatz steps for n=1..1,000,000
def collatz_steps(n)
  steps = 0
  while n != 1
    n = n.even? ? n / 2 : n * 3 + 1
    steps += 1
  end
  steps
end

n = 1_000_000
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
total = 0
(1..n).each { |i| total += collatz_steps(i) }
elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).to_i
puts "result: #{total}"
puts "elapsed: #{elapsed} ms"
