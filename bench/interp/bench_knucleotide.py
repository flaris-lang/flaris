# bench_knucleotide.py - k-nucleotide frequencies of a 2,000,000-base DNA string:
# every substring of length 1, 2, 3, 4, 6, 12 and 18 counted in a string-keyed
# map, then five fixed sequences looked up. Dominated by substring creation,
# string hashing and map update. Algorithm from The Computer Language
# Benchmarks Game; the input comes from an integer generator so that every
# language builds the same string.
# result = (r * 31 + v) % 1000000007 folded over the number of distinct keys
# for each length and the count of each fixed sequence.
import time

MOD = 1000000007


def dna(n):
    parts = []
    seed = 42
    for _ in range(n):
        seed = (seed * 3877 + 29573) % 139968
        parts.append("ACGT"[seed * 4 // 139968])
    return "".join(parts)


def count(seq, k):
    counts = {}
    for i in range(len(seq) - k + 1):
        key = seq[i:i + k]
        counts[key] = counts.get(key, 0) + 1
    return counts


seq = dna(2000000)
queries = ["GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"]
t0 = time.perf_counter()
r = 0
r = (r * 31 + len(count(seq, 1))) % MOD
r = (r * 31 + len(count(seq, 2))) % MOD
for q in queries:
    counts = count(seq, len(q))
    r = (r * 31 + len(counts)) % MOD
    r = (r * 31 + counts.get(q, 0)) % MOD
print("result: %d" % r)
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
