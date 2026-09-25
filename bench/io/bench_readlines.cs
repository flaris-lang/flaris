// Count lines and bytes, one line at a time. See bench_readlines.c for the
// result fold. ReadLine strips the terminator, so it is added back.
using System;
using System.Diagnostics;
using System.IO;

static class Bench {
    static void Main() {
        var sw = Stopwatch.StartNew();
        long lines = 0, total = 0;
        using (var r = new StreamReader("io_input.txt")) {
            string line;
            while ((line = r.ReadLine()) != null) { lines++; total += line.Length + 1; }
        }
        sw.Stop();
        Console.WriteLine("result: " + (lines * 100000000L + total));
        Console.WriteLine("elapsed: " + sw.ElapsedMilliseconds + " ms");
    }
}
