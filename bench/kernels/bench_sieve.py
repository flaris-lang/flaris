# bench_sieve.py - Sieve of Eratosthenes, N=10,000,000
import time, math

def sieve(N):
    flags = bytearray(b'\x01') * (N + 1)
    flags[0] = flags[1] = 0
    pMax = math.isqrt(N)
    for p in range(2, pMax + 1):
        if flags[p]:
            i = p * p
            while i <= N:
                flags[i] = 0
                i += p
    count = 0
    for i in range(2, N + 1):
        if flags[i]:
            count += 1
    return count

N = 10_000_000
t0 = time.monotonic()
count = sieve(N)
elapsed = int((time.monotonic() - t0) * 1000)
print(f"result: {count}")
print(f"elapsed: {elapsed} ms")
