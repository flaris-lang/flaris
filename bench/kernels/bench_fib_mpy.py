# bench_fib_mpy.py - recursive Fibonacci, n=38 (MicroPython)
# MicroPython has no sys.setrecursionlimit and no time.monotonic; its unix
# port provides time.ticks_ms/ticks_diff, which is what an embedded target has.
import time

def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

n = 38
t0 = time.ticks_ms()
result = fib(n)
elapsed = time.ticks_diff(time.ticks_ms(), t0)
print("result: %d" % result)
print("elapsed: %d ms" % elapsed)
