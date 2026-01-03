const std = @import("std");
const c = @import("c_Imports").c;
const cAllocator = @import("c_Imports").Zallocator;
const cHardMap = @import("cmap").my_HHmap;

pub fn main() !void {
    var gpav = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpav.allocator();
    defer std.debug.assert(gpav.deinit() == .ok);

    const allocator = &(cAllocator{ .zAllocator = gpa }).translate();

    const iterations = 1_000_000;

    var timer = try std.time.Timer.start();

    // ---------------- insert benchmark ----------------
    {
        const map = cHardMap(i64, i64).init(.{
            .allocator = allocator,
            .buckets =8192 ,
        });
        defer map.deinit();

        timer.reset();
        for (0..iterations) |i| {
            const v: i64 = @intCast(i);
            map.set(v, v * v);
        }
        const insert_ns = timer.read();

        std.debug.print(
            "insert: {d} ops in {d} ns ({d} ns/op)\n",
            .{ iterations, insert_ns, insert_ns / iterations },
        );

        // ---------------- lookup benchmark ----------------
        timer.reset();
        for (0..iterations) |i| {
            const v: i64 = @intCast(i);
            _ = map.get(v);
        }
        const lookup_ns = timer.read();

        std.debug.print(
            "lookup: {d} ops in {d} ns ({d} ns/op)\n",
            .{ iterations, lookup_ns, lookup_ns / iterations },
        );
    }
}

