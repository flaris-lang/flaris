import time
line = "alpha,beta,gamma,delta,epsilon,zeta,eta,theta"
n = 120000
t0 = time.perf_counter()
total = 0
for _ in range(n):
    parts = line.split(",")
    total += len(parts)
    if line.find("delta") >= 0: total += 1
    joined = "|".join(parts)
    total += len(joined)
print("result: %d" % total)
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
