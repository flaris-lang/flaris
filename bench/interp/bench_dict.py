import time
n = 200000
keys = ["key%d" % i for i in range(n)]
t0 = time.perf_counter()
m = {}
for i in range(n): m[keys[i]] = i
total = 0
for _ in range(3):
    for i in range(n): total += m[keys[i]]
print("result: %d" % total)
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
