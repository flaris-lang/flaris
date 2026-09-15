import time
n = 220
a = []; b = []
for i in range(n):
    a.append([(i + j) % 7 for j in range(n)])
    b.append([(i * j) % 5 for j in range(n)])
t0 = time.perf_counter()
total = 0
for i in range(n):
    ai = a[i]
    for j in range(n):
        s = 0
        for k in range(n): s += ai[k] * b[k][j]
        total += s
print("result: %d" % total)
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
