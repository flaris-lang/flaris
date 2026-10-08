#:property AllowUnsafeBlocks=true
// host_flaris_cs.cs - the embedding benchmark with a C# host.
//
// The same two scenarios as the C hosts, but reaching libflaris through
// P/Invoke instead of linking it. This is the path doc/embedding.md section 14
// describes; the difference against host_flaris is what managed interop costs.
using System.Diagnostics;
using System.Runtime.InteropServices;

internal static partial class Flaris
{
    private const string Lib = "flaris";

    [LibraryImport(Lib)] internal static partial int FlarisHostCreate(IntPtr options, out IntPtr host);
    [LibraryImport(Lib)] internal static partial int FlarisHostDestroy(IntPtr host);

    [LibraryImport(Lib, StringMarshalling = StringMarshalling.Utf8)]
    internal static partial int FlarisHostLoadScript(IntPtr host, string source, string name);

    [LibraryImport(Lib, StringMarshalling = StringMarshalling.Utf8)]
    internal static partial IntPtr FlarisHostGetFunction(IntPtr host, string name);

    [LibraryImport(Lib)]
    internal static partial int FlarisFunctionCall(IntPtr fn, nuint[]? args, int argc,
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
                if (Flaris.FlarisHostCreate(IntPtr.Zero, out IntPtr host) != 0) { Console.Error.WriteLine("create failed"); return 1; }
                if (Flaris.FlarisHostLoadScript(host, src, "script.fls") != 0) { Console.Error.WriteLine("load failed"); return 1; }

                IntPtr total = Flaris.FlarisHostGetFunction(host, "Total");
                if (total == IntPtr.Zero || Flaris.FlarisFunctionCall(total, null, 0, out nuint outv, null, 0) != 0)
                { Console.Error.WriteLine("Total failed"); return 1; }
                acc += Flaris.FlarisAsInt(outv);
                Flaris.FlarisReleaseValue(outv);

                Flaris.FlarisHostDestroy(host);
            }
            sw.Stop();
            Console.WriteLine($"result: {acc}");
            Console.WriteLine($"elapsed: {sw.ElapsedMilliseconds} ms");
            return 0;
        }

        if (Flaris.FlarisHostCreate(IntPtr.Zero, out IntPtr h) != 0) { Console.Error.WriteLine("create failed"); return 1; }
        if (Flaris.FlarisHostLoadScript(h, src, "script.fls") != 0) { Console.Error.WriteLine("load failed"); return 1; }
        IntPtr update = Flaris.FlarisHostGetFunction(h, "Update");
        if (update == IntPtr.Zero) { Console.Error.WriteLine("no Update"); return 1; }

        var args = new nuint[1];
        sw.Start();
        for (int i = 0; i < Calls; i++)
        {
            args[0] = Flaris.FlarisInt(i);
            if (Flaris.FlarisFunctionCall(update, args, 1, out nuint outv, null, 0) != 0)
            { Console.Error.WriteLine("Update failed"); return 1; }
            acc += Flaris.FlarisAsInt(outv);
            Flaris.FlarisReleaseValue(outv);
            Flaris.FlarisReleaseValue(args[0]);
        }
        sw.Stop();
        Flaris.FlarisHostDestroy(h);
        Console.WriteLine($"result: {acc}");
        Console.WriteLine($"elapsed: {sw.ElapsedMilliseconds} ms");
        return 0;
    }
}
