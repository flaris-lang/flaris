# Count lines and bytes, one line at a time. See bench_readlines.c for the
# result fold and what the benchmark is measuring.
import time

t0 = time.monotonic()
lines = 0
total = 0
with open("io_input.txt", "rb") as f:
    for line in f:
        lines += 1
        total += len(line)
elapsed = (time.monotonic() - t0) * 1000

print("result:", lines * 100000000 + total)
print("elapsed:", int(elapsed))
