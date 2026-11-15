// bench_strbuild.zig - build a large string, N times, in an ArrayList(u8)
// (amortised linear growth). result is the final byte length.
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const n = 1_000_000;
    const t0 = std.Io.Timestamp.now(io, .awake);
    var sb: std.ArrayList(u8) = .empty;
    defer sb.deinit(gpa);
    for (0..n) |i| {
        try sb.appendSlice(gpa, "item_");
        try sb.print(gpa, "{d}", .{i});
        try sb.append(gpa, ';');
    }
    const result = sb.items.len;
    const ms = t0.untilNow(io, .awake).toMilliseconds();
    var buf: [64]u8 = undefined;
    var out = std.Io.File.stdout().writer(io, &buf);
    try out.interface.print("result: {d}\nelapsed: {d} ms\n", .{ result, ms });
    try out.interface.flush();
}
