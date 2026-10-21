# bench_spectralnorm.py - spectral norm of the infinite matrix A, size 800.
# Dominated by float multiply-adds in nested loops over float arrays, and the
# integer arithmetic that computes each element of A.
# Algorithm from The Computer Language Benchmarks Game, 10 power iterations of
# u = AtA v. result = round(sqrt(vBv / vv) * 1e9).
import time

def eval_a(i, j):
    return 1.0 / ((i + j) * (i + j + 1) // 2 + i + 1)

def mul_av(n, v, av):
    for i in range(n):
        s = 0.0
        for j in range(n):
            s += eval_a(i, j) * v[j]
        av[i] = s

def mul_atv(n, v, atv):
    for i in range(n):
        s = 0.0
        for j in range(n):
            s += eval_a(j, i) * v[j]
        atv[i] = s

def mul_atav(n, v, atav, tmp):
    mul_av(n, v, tmp)
    mul_atv(n, tmp, atav)

def spectral_norm(n):
    u = [1.0] * n
    v = [0.0] * n
    tmp = [0.0] * n
    for _ in range(10):
        mul_atav(n, u, v, tmp)
        mul_atav(n, v, u, tmp)
    vbv = 0.0
    vv = 0.0
    for i in range(n):
        vbv += u[i] * v[i]
        vv += v[i] * v[i]
    return (vbv / vv) ** 0.5

n = 800
t0 = time.perf_counter()
norm = spectral_norm(n)
print("result: %d" % round(norm * 1e9))
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
