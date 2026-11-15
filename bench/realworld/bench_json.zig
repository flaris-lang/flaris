// bench_json.zig - parse an 18 MB JSON array, ITERS times, summing value fields.
// std.json parses into the typed record, all four fields, like the Go port.
const std = @import("std");

const Rec = struct {
    id: i64,
    name: []const u8,
    value: i64,
    active: bool,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const data = try std.Io.Dir.cwd().readFileAlloc(io, "bench_data.json", gpa, .unlimited);
    defer gpa.free(data);
    const iters = 5;
    const t0 = std.Io.Timestamp.now(io, .awake);
    var total: i64 = 0;
    for (0..iters) |_| {
        const parsed = try std.json.parseFromSlice([]Rec, gpa, data, .{});
        defer parsed.deinit();
        for (parsed.value) |rec| total += rec.value;
    }
    const ms = t0.untilNow(io, .awake).toMilliseconds();
    var buf: [64]u8 = undefined;
    var out = std.Io.File.stdout().writer(io, &buf);
    try out.interface.print("result: {d}\nelapsed: {d} ms\n", .{ total, ms });
    try out.interface.flush();
}
