// Read the whole file into memory. See bench_slurp.c for what this measures.
using System;
using System.Diagnostics;
using System.IO;

static class Bench {
    static void Main() {
        var sw = Stopwatch.StartNew();
        var data = File.ReadAllBytes("io_input.txt");
        sw.Stop();
        Console.WriteLine("result: " + data.Length);
        Console.WriteLine("elapsed: " + sw.ElapsedMilliseconds + " ms");
    }
}
