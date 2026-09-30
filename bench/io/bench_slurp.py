# Read the whole file into memory. See bench_slurp.c for what this measures.
import time

t0 = time.monotonic()
with open("io_input.txt", "rb") as f:
    data = f.read()
elapsed = (time.monotonic() - t0) * 1000

print("result:", len(data))
print("elapsed:", int(elapsed))
