# bench_collatz_mpy.py - total Collatz steps for n=1..1,000,000 (MicroPython)
import time

def collatz_steps(n):
    steps = 0
    while n != 1:
        n = n // 2 if n % 2 == 0 else n * 3 + 1
        steps += 1
    return steps

n = 1000000
t0 = time.ticks_ms()
total = 0
for i in range(1, n + 1):
    total += collatz_steps(i)
elapsed = time.ticks_diff(time.ticks_ms(), t0)
print("result: %d" % total)
print("elapsed: %d ms" % elapsed)
