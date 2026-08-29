// bench_collatz.cs - total Collatz steps for n=1..1,000,000
using System;
using System.Diagnostics;

static class Bench {
    static long CollatzSteps(long n) {
        long steps = 0;
        while (n != 1) {
            n = (n & 1) != 0 ? n * 3 + 1 : n >> 1;
            steps++;
        }
        return steps;
    }

    static void Main() {
        const long n = 1000000;
        var sw = Stopwatch.StartNew();
        long total = 0;
        for (long i = 1; i <= n; i++)
            total += CollatzSteps(i);
        sw.Stop();
        Console.WriteLine("result: " + total);
        Console.WriteLine("elapsed: " + sw.ElapsedMilliseconds + " ms");
    }
}
