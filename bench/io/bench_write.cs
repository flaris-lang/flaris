// Write a million formatted lines. See bench_write.c for what this measures.
using System;
using System.Diagnostics;
using System.IO;

static class Bench {
    static void Main() {
        const int lines = 1000000;
        var sw = Stopwatch.StartNew();
        using (var w = new StreamWriter("io_out_cs.txt")) {
            for (long i = 0; i < lines; i++)
                w.Write(i + " payload " + (i * 7 % 9973) + "\n");
        }
        sw.Stop();
        long size = new FileInfo("io_out_cs.txt").Length;
        File.Delete("io_out_cs.txt");
        Console.WriteLine("result: " + size);
        Console.WriteLine("elapsed: " + sw.ElapsedMilliseconds + " ms");
    }
}
