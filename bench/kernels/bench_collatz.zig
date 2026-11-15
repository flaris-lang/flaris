// bench_collatz.zig - total Collatz steps for n=1..1,000,000
const std = @import("std");

fn collatzSteps(start: i64) i64 {
    var n = start;
    var steps: i64 = 0;
    while (n != 1) {
        n = if (n & 1 != 0) n * 3 + 1 else n >> 1;
        steps += 1;
    }
    return steps;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const n: i64 = 1_000_000;
    const t0 = std.Io.Timestamp.now(io, .awake);
    var total: i64 = 0;
    var i: i64 = 1;
    while (i <= n) : (i += 1) total += collatzSteps(i);
    const ms = t0.untilNow(io, .awake).toMilliseconds();
    var buf: [64]u8 = undefined;
    var out = std.Io.File.stdout().writer(io, &buf);
    try out.interface.print("result: {d}\nelapsed: {d} ms\n", .{ total, ms });
    try out.interface.flush();
}
