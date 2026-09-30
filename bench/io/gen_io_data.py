#!/usr/bin/env python3
"""Generate the deterministic input for the I/O benchmarks.

One file, plain ASCII, fixed seed, so every language reads identical bytes and
a run on one machine is comparable with a run on another. Lines vary in length
- a fixed-width file would let a reader cheat with arithmetic instead of
actually scanning for terminators.

Written by run_bench_io.sh on first use; not committed, since it is 47 MB.
"""
import random

LINES = 2_000_000
WORDS = ["alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf",
         "hotel", "india", "juliet", "kilo", "lima", "mike", "november"]

def main():
    rnd = random.Random(20260923)
    with open("io_input.txt", "w", newline="\n") as f:
        for i in range(LINES):
            n = rnd.randrange(1, 5)
            words = " ".join(rnd.choice(WORDS) for _ in range(n))
            f.write("%d %s %d\n" % (i, words, i * 7 % 9973))
    print("io_input.txt: %d lines" % LINES)

if __name__ == "__main__":
    main()
