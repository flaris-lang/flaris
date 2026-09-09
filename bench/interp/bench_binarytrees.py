import sys, time
sys.setrecursionlimit(100000)
def bottom_up(d):
    if d <= 0: return (None, None)
    return (bottom_up(d-1), bottom_up(d-1))
def check(n):
    if n[0] is None: return 1
    return 1 + check(n[0]) + check(n[1])
max_depth = 16
t0 = time.perf_counter()
total = 0
d = 4
while d <= max_depth:
    iters = 1 << (max_depth - d + 4)
    for _ in range(iters): total += check(bottom_up(d))
    d += 2
print("result: %d" % total)
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
