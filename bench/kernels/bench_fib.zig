// bench_fib.zig - recursive Fibonacci, n=38
const std = @import("std");

fn fib(n: i32) i64 {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const n = 38;
    const t0 = std.Io.Timestamp.now(io, .awake);
    const result = fib(n);
    const ms = t0.untilNow(io, .awake).toMilliseconds();
    var buf: [64]u8 = undefined;
    var out = std.Io.File.stdout().writer(io, &buf);
    try out.interface.print("result: {d}\nelapsed: {d} ms\n", .{ result, ms });
    try out.interface.flush();
}
