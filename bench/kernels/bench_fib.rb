# bench_fib.rb - recursive Fibonacci, n=38
def fib(n)
  n <= 1 ? n : fib(n - 1) + fib(n - 2)
end

t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
result = fib(38)
elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).to_i
puts "result: #{result}"
puts "elapsed: #{elapsed} ms"
