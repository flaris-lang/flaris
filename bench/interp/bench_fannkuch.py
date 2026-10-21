# bench_fannkuch.py - fannkuch-redux over every permutation of 10 elements.
# Dominated by small integer-array reads, writes and swaps in short inner loops.
# Algorithm from The Computer Language Benchmarks Game: permutations in its
# rotation order, checksum = sum of the flip counts with the sign alternating per
# permutation index. result = checksum * 1000 + max flips.
import time

def fannkuch(n):
    perm1 = list(range(n))
    perm = [0] * n
    count = [0] * n
    max_flips = 0
    checksum = 0
    sign = 1
    r = n
    while True:
        while r != 1:
            count[r - 1] = r
            r -= 1
        for i in range(n):
            perm[i] = perm1[i]
        flips = 0
        k = perm[0]
        while k != 0:
            i = 0
            j = k
            while i < j:
                perm[i], perm[j] = perm[j], perm[i]
                i += 1
                j -= 1
            flips += 1
            k = perm[0]
        if flips > max_flips:
            max_flips = flips
        checksum += sign * flips
        sign = -sign
        # Next permutation: rotate the first r + 1 elements left by one; when that
        # brings a prefix back to its start, move on to a longer prefix.
        while True:
            if r == n:
                return checksum * 1000 + max_flips
            first = perm1[0]
            for i in range(r):
                perm1[i] = perm1[i + 1]
            perm1[r] = first
            count[r] -= 1
            if count[r] > 0:
                break
            r += 1

n = 10
t0 = time.perf_counter()
result = fannkuch(n)
print("result: %d" % result)
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
