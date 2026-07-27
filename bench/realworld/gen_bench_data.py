#!/usr/bin/env python3
# Generates the shared, deterministic input files used by the real-world
# benchmarks (JSON parse, regex match). No randomness - byte-identical every
# run, so every language parses exactly the same input and must agree on the
# result: integer that run_bench.sh cross-checks.
import sys, os

HERE = os.path.dirname(os.path.abspath(__file__))

# ---- JSON dataset -----------------------------------------------------------
# A compact JSON array of N records. value = i % 1000, so the per-parse sum of
# all value fields is deterministic and independent of record count details.
JSON_N = 300_000

def gen_json(path):
    parts = ["["]
    for i in range(JSON_N):
        if i:
            parts.append(",")
        name = "item_%06d" % i
        val = i % 1000
        active = "true" if (i % 2 == 0) else "false"
        parts.append('{"id":%d,"name":"%s","value":%d,"active":%s}'
                      % (i, name, val, active))
    parts.append("]")
    data = "".join(parts)
    with open(path, "w") as f:
        f.write(data)
    value_sum = sum(i % 1000 for i in range(JSON_N))
    return len(data), value_sum

# ---- Regex corpus -----------------------------------------------------------
# M lines. Every 3rd line carries a real YYYY-MM-DD date; the rest carry a
# near-miss decoy (single-digit month) that starts like a date but must NOT
# match \b\d{4}-\d{2}-\d{2}\b - this exercises the engine's advance/backtrack.
REGEX_M = 300_000

def gen_corpus(path):
    lines = []
    matches = 0
    for i in range(REGEX_M):
        year = 2000 + (i % 25)
        month = 1 + (i % 12)
        day = 1 + (i % 28)
        if i % 3 == 0:
            token = "%04d-%02d-%02d" % (year, month, day)   # real date, 2-digit month
            matches += 1
        else:
            decoy_month = 1 + (i % 9)                         # always 1..9, one digit
            token = "%04d-%d-%02d" % (year, decoy_month, day)  # near-miss: month too short
        lines.append("row_%d: %s end_%d" % (i, token, i))
    data = "\n".join(lines) + "\n"
    with open(path, "w") as f:
        f.write(data)
    return len(data), matches

if __name__ == "__main__":
    jpath = os.path.join(HERE, "bench_data.json")
    cpath = os.path.join(HERE, "bench_corpus.txt")
    jbytes, jsum = gen_json(jpath)
    cbytes, cmatch = gen_corpus(cpath)
    print("bench_data.json : %d records, %.1f MB, per-parse value sum = %d"
          % (JSON_N, jbytes / 1e6, jsum))
    print("bench_corpus.txt: %d lines,   %.1f MB, matches per scan   = %d"
          % (REGEX_M, cbytes / 1e6, cmatch))
