// bench_tailcall.zig - self-recursive tail call, depth 2,000,000
const std = @import("std");

fn tailsum(n: i64, acc: i64) i64 {
    if (n == 0) return acc;
    return tailsum(n - 1, acc + n);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const n: i64 = 2_000_000;
    const t0 = std.Io.Timestamp.now(io, .awake);
    const result = tailsum(n, 0);
    const ms = t0.untilNow(io, .awake).toMilliseconds();
    var buf: [64]u8 = undefined;
    var out = std.Io.File.stdout().writer(io, &buf);
    try out.interface.print("result: {d}\nelapsed: {d} ms\n", .{ result, ms });
    try out.interface.flush();
}
