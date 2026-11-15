// bench_sieve.zig - Sieve of Eratosthenes, N=10,000,000
const std = @import("std");

fn sieve(gpa: std.mem.Allocator, n: usize) !u32 {
    const flags = try gpa.alloc(u8, n + 1);
    defer gpa.free(flags);
    @memset(flags, 1);
    flags[0] = 0;
    flags[1] = 0;
    var p: usize = 2;
    while (p * p <= n) : (p += 1) {
        if (flags[p] != 0) {
            var i = p * p;
            while (i <= n) : (i += p) flags[i] = 0;
        }
    }
    var count: u32 = 0;
    for (flags[2..]) |f| {
        if (f != 0) count += 1;
    }
    return count;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const n = 10_000_000;
    const t0 = std.Io.Timestamp.now(io, .awake);
    const count = try sieve(init.gpa, n);
    const ms = t0.untilNow(io, .awake).toMilliseconds();
    var buf: [64]u8 = undefined;
    var out = std.Io.File.stdout().writer(io, &buf);
    try out.interface.print("result: {d}\nelapsed: {d} ms\n", .{ count, ms });
    try out.interface.flush();
}
