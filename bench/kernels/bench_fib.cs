// bench_fib.cs - recursive Fibonacci, n=38
using System;
using System.Diagnostics;

static class Bench {
    static long Fib(int n) {
        if (n <= 1) return n;
        return Fib(n - 1) + Fib(n - 2);
    }

    static void Main() {
        const int n = 38;
        var sw = Stopwatch.StartNew();
        long result = Fib(n);
        sw.Stop();
        Console.WriteLine("result: " + result);
        Console.WriteLine("elapsed: " + sw.ElapsedMilliseconds + " ms");
    }
}
