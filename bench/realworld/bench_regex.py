# bench_regex.py - scan a 9.8 MB corpus for YYYY-MM-DD dates, SCANS times.
import re, time
with open("bench_corpus.txt") as f:
    text = f.read()
SCANS = 5
pat = re.compile(r"\b\d{4}-\d{2}-\d{2}\b")
t0 = time.monotonic()
total = 0
for _ in range(SCANS):
    total += len(pat.findall(text))
elapsed = int((time.monotonic() - t0) * 1000)
print(f"result: {total}")
print(f"elapsed: {elapsed} ms")
