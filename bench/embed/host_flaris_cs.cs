#:property AllowUnsafeBlocks=true
// host_flaris_cs.cs - the embedding benchmark with a C# host.
//
// The same two scenarios as the C hosts, but reaching libflaris through
// P/Invoke instead of linking it. This is the path doc/embedding.md section 10b
// describes; the difference against host_flaris is what managed interop costs.
using System.Diagnostics;
using System.Runtime.InteropServices;

internal static partial class Flaris
{
    private const string Lib = "flaris";

    [LibraryImport(Lib)] internal static partial int FlarisInitVM(IntPtr cfg);
    [LibraryImport(Lib)] internal static partial void FlarisShutdownVM(int code);
    [LibraryImport(Lib)] internal static partial void FlarisRunToCompletion();
    [LibraryImport(Lib)] internal static partial int FlarisCreateContext(IntPtr options, out IntPtr ctx);

    [LibraryImport(Lib, StringMarshalling = StringMarshalling.Utf8)]
    internal static partial int FlarisLoadSourceText(IntPtr ctx, string source, string name);

    [LibraryImport(Lib, StringMarshalling = StringMarshalling.Utf8)]
    internal static partial int FlarisCall(IntPtr ctx, string fnName, nuint[]? args, int argc,
                                           out nuint outResult, byte[]? errBuf, nuint errSize);

    [LibraryImport(Lib)] internal static partial nuint FlarisInt(long v);
    [LibraryImport(Lib)] internal static partial long FlarisAsInt(nuint v);
    [LibraryImport(Lib)] internal static partial void FlarisReleaseValue(nuint v);
}

internal static class Program
{
    private const int LoadCycles = 1000;
    private const int Calls = 1_000_000;

    private static int Main(string[] argv)
    {
        bool wantCall = argv.Length > 0 && argv[0] == "call";
        if (argv.Length == 0 || (argv[0] != "call" && argv[0] != "load"))
        {
            Console.Error.WriteLine("usage: host_flaris_cs load|call");
            return 2;
        }

        string src = File.ReadAllText("script.fls");
        long acc = 0;
        var sw = new Stopwatch();

        if (!wantCall)
        {
            sw.Start();
            for (int i = 0; i < LoadCycles; i++)
            {
                if (Flaris.FlarisInitVM(IntPtr.Zero) != 0) { Console.Error.WriteLine("init failed"); return 1; }
                if (Flaris.FlarisCreateContext(IntPtr.Zero, out IntPtr ctx) != 0) { Console.Error.WriteLine("ctx failed"); return 1; }
                if (Flaris.FlarisLoadSourceText(ctx, src, "script.fls") != 0) { Console.Error.WriteLine("load failed"); return 1; }
                Flaris.FlarisRunToCompletion();

                if (Flaris.FlarisCall(ctx, "Total", null, 0, out nuint outv, null, 0) != 0)
                { Console.Error.WriteLine("Total failed"); return 1; }
                acc += Flaris.FlarisAsInt(outv);
                Flaris.FlarisReleaseValue(outv);

                Flaris.FlarisShutdownVM(0);
            }
            sw.Stop();
            Console.WriteLine($"result: {acc}");
            Console.WriteLine($"elapsed: {sw.ElapsedMilliseconds} ms");
            return 0;
        }

        if (Flaris.FlarisInitVM(IntPtr.Zero) != 0) { Console.Error.WriteLine("init failed"); return 1; }
        Flaris.FlarisCreateContext(IntPtr.Zero, out IntPtr c);
        if (Flaris.FlarisLoadSourceText(c, src, "script.fls") != 0) { Console.Error.WriteLine("load failed"); return 1; }

        var args = new nuint[1];
        sw.Start();
        for (int i = 0; i < Calls; i++)
        {
            args[0] = Flaris.FlarisInt(i);
            if (Flaris.FlarisCall(c, "Update", args, 1, out nuint outv, null, 0) != 0)
            { Console.Error.WriteLine("Update failed"); return 1; }
            acc += Flaris.FlarisAsInt(outv);
            Flaris.FlarisReleaseValue(outv);
            Flaris.FlarisReleaseValue(args[0]);
        }
        sw.Stop();
        Flaris.FlarisShutdownVM(0);
        Console.WriteLine($"result: {acc}");
        Console.WriteLine($"elapsed: {sw.ElapsedMilliseconds} ms");
        return 0;
    }
}
