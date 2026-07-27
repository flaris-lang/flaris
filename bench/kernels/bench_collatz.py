# bench_collatz.py - total Collatz steps for n=1..1,000,000
import time

def collatz_steps(n):
    steps = 0
    while n != 1:
        n = n * 3 + 1 if n & 1 else n >> 1
        steps += 1
    return steps

N = 1_000_000
t0 = time.monotonic()
total = sum(collatz_steps(i) for i in range(1, N + 1))
elapsed = int((time.monotonic() - t0) * 1000)
print(f"result: {total}")
print(f"elapsed: {elapsed} ms")
