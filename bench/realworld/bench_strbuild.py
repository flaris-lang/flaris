# bench_strbuild.py - build a large string by naive s += piece, N times.
# The loop lives in a function: CPython's in-place s += optimization only fires
# reliably when the target is a fast local, so module-scope would be quadratic.
import time

def build(N):
    s = ""
    for i in range(N):
        s += "item_" + str(i) + ";"
    return len(s)

N = 1_000_000
t0 = time.monotonic()
result = build(N)
elapsed = int((time.monotonic() - t0) * 1000)
print(f"result: {result}")
print(f"elapsed: {elapsed} ms")
