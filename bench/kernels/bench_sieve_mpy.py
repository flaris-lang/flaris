# bench_sieve_mpy.py - Sieve of Eratosthenes, N=10,000,000 (MicroPython)
import time

def sieve(n):
    flags = bytearray(b"\x01" * (n + 1))
    flags[0] = 0
    flags[1] = 0
    p = 2
    while p * p <= n:
        if flags[p] == 1:
            i = p * p
            while i <= n:
                flags[i] = 0
                i += p
        p += 1
    count = 0
    i = 2
    while i <= n:
        if flags[i] == 1:
            count += 1
        i += 1
    return count

n = 10000000
t0 = time.ticks_ms()
result = sieve(n)
elapsed = time.ticks_diff(time.ticks_ms(), t0)
print("result: %d" % result)
print("elapsed: %d ms" % elapsed)
