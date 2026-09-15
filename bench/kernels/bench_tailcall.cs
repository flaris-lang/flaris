// bench_tailcall.cs - self-recursive tail call, depth 2,000,000
//
// RyuJIT does not guarantee tail-call elimination for a plain recursive
// method, so this is expected to overflow the default thread stack rather
// than complete - that absence from the results table is itself the finding
// this benchmark is after, not a harness bug. See bench/README.md.
using System;
using System.Diagnostics;

static class Bench {
    static long TailSum(long n, long acc) {
        if (n == 0) return acc;
        return TailSum(n - 1, acc + n);
    }

    static void Main() {
        const long n = 2_000_000;
        var sw = Stopwatch.StartNew();
        long result = TailSum(n, 0);
        sw.Stop();
        Console.WriteLine("result: " + result);
        Console.WriteLine("elapsed: " + sw.ElapsedMilliseconds + " ms");
    }
}
