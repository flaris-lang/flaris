# bench_sieve.rb - Sieve of Eratosthenes, N=10,000,000
# Ruby has no bytearray; a String is its byte buffer, indexed with setbyte/getbyte.
def sieve(n)
  flags = "\x01" * (n + 1)
  flags.setbyte(0, 0)
  flags.setbyte(1, 0)
  p_max = Integer.sqrt(n)
  p = 2
  while p <= p_max
    if flags.getbyte(p) == 1
      i = p * p
      while i <= n
        flags.setbyte(i, 0)
        i += p
      end
    end
    p += 1
  end
  count = 0
  i = 2
  while i <= n
    count += 1 if flags.getbyte(i) == 1
    i += 1
  end
  count
end

n = 10_000_000
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
result = sieve(n)
elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).to_i
puts "result: #{result}"
puts "elapsed: #{elapsed} ms"
