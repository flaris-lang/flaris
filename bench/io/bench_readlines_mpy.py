# Count lines and bytes, one line at a time (MicroPython). See
# bench_readlines.c for the result fold.
import time

t0 = time.ticks_ms()
lines = 0
total = 0
with open("io_input.txt", "rb") as f:
    for line in f:
        lines += 1
        total += len(line)
elapsed = time.ticks_diff(time.ticks_ms(), t0)
print("result: %d" % (lines * 100000000 + total))
print("elapsed: %d ms" % elapsed)
