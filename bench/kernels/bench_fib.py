# bench_fib.py - recursive Fibonacci, n=38
import time, sys
sys.setrecursionlimit(100_000)

def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

n = 38
t0 = time.monotonic()
result = fib(n)
elapsed = int((time.monotonic() - t0) * 1000)
print(f"result: {result}")
print(f"elapsed: {elapsed} ms")
