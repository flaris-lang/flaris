# Read the whole file into memory (MicroPython). See bench_slurp.c.
import time

t0 = time.ticks_ms()
with open("io_input.txt", "rb") as f:
    data = f.read()
elapsed = time.ticks_diff(time.ticks_ms(), t0)
print("result: %d" % len(data))
print("elapsed: %d ms" % elapsed)
