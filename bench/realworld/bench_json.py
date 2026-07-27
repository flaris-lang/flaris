# bench_json.py - parse an 18 MB JSON array, ITERS times, summing value fields.
import json, time
with open("bench_data.json") as f:
    text = f.read()
ITERS = 5
t0 = time.monotonic()
total = 0
for _ in range(ITERS):
    arr = json.loads(text)
    for rec in arr:
        total += rec["value"]
elapsed = int((time.monotonic() - t0) * 1000)
print(f"result: {total}")
print(f"elapsed: {elapsed} ms")
