import time, functools
n = 120000
base = [0]*n
seed = 12345
for i in range(n):
    seed = (seed * 48271) % 2147483647
    base[i] = seed % 1000000
t0 = time.perf_counter()
total = 0
for _ in range(6):
    arr = list(base)
    arr.sort(key=functools.cmp_to_key(lambda a, b: -1 if a < b else (1 if a > b else 0)))
    total += arr[0] + arr[n-1]
print("result: %d" % total)
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
