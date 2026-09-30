# Write a million formatted lines (MicroPython). See bench_write.c.
import os, time

LINES = 1000000
t0 = time.ticks_ms()
with open("io_out_mpy.txt", "w") as f:
    for i in range(LINES):
        f.write("%d payload %d\n" % (i, i * 7 % 9973))
elapsed = time.ticks_diff(time.ticks_ms(), t0)
size = os.stat("io_out_mpy.txt")[6]
os.remove("io_out_mpy.txt")
print("result: %d" % size)
print("elapsed: %d ms" % elapsed)
