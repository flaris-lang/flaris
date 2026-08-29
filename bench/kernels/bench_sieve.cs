// bench_sieve.cs - Sieve of Eratosthenes, N=10,000,000
using System;
using System.Diagnostics;

static class Bench {
    static int Sieve(int n) {
        var flags = new byte[n + 1];
        Array.Fill(flags, (byte)1);
        flags[0] = 0;
        flags[1] = 0;
        for (int p = 2; (long)p * p <= n; p++) {
            if (flags[p] != 0) {
                for (int i = p * p; i <= n; i += p)
                    flags[i] = 0;
            }
        }
        int count = 0;
        for (int i = 2; i <= n; i++)
            if (flags[i] != 0) count++;
        return count;
    }

    static void Main() {
        const int n = 10000000;
        var sw = Stopwatch.StartNew();
        int count = Sieve(n);
        sw.Stop();
        Console.WriteLine("result: " + count);
        Console.WriteLine("elapsed: " + sw.ElapsedMilliseconds + " ms");
    }
}
