# bench_tailcall.py - self-recursive tail call, depth 2,000,000
#
# CPython has no tail-call elimination and a default recursion limit far
# below this depth, so this is expected to raise RecursionError rather than
# complete - see bench/README.md's tail-call section.
import time

def tailsum(n, acc):
    if n == 0:
        return acc
    return tailsum(n - 1, acc + n)

n = 2_000_000
t0 = time.monotonic()
result = tailsum(n, 0)
elapsed = int((time.monotonic() - t0) * 1000)
print(f"result: {result}")
print(f"elapsed: {elapsed} ms")
