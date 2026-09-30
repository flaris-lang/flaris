# Write a million formatted lines. See bench_write.c for what this measures.
import os, time

LINES = 1000000
t0 = time.monotonic()
with open("io_out_py.txt", "w") as f:
    for i in range(LINES):
        f.write("%d payload %d\n" % (i, i * 7 % 9973))
elapsed = (time.monotonic() - t0) * 1000

size = os.path.getsize("io_out_py.txt")
os.remove("io_out_py.txt")
print("result:", size)
print("elapsed:", int(elapsed))
