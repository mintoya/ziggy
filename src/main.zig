const std = @import("std");
const c = @import("c_Imports").c;
const cHardMap = @import("cmap").my_HHmap;
const aTran = @import("alloc-translate.zig").Zallocator;
const Pair = @import("clist").Pair;
pub fn main() !void {
    var gpav = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpav.allocator();
    defer std.debug.assert(gpav.deinit() == .ok);

    const cver = c.arena_new_ext(
        &(aTran().new(gpa).translate()),
        1024,
    );
    defer c.arena_cleanup(cver);

    const Vector = struct {
        i: f64 = 0,
        j: f64 = 0,
        k: f64 = 0,
        pub fn @"=="(a: @This(), b: @This()) bool {
            return a.i == b.i and a.j == b.j and a.k == b.k;
        }
        pub fn @"+"(a: @This(), b: @This()) @This() {
            return .{ .i = a.i + b.i, .j = a.j + b.j, .k = a.k + b.k };
        }
        pub fn @"*"(self: @This(), sale: f64) @This() {
            return .{ .i = self.i * sale, .j = self.j * sale, .k = self.k * sale };
        }
        pub fn @"x*"(a: @This(), b: @This()) @This() {
            return .{
                .i = a.j * b.k - a.k * b.j,
                .j = a.i * b.k - a.k * b.i,
                .k = a.i * b.j - b.i * a.j,
            };
        }
    };

    const a: Vector = .{ .j = 1 };
    const b: Vector = .{ .j = -1 };
    std.debug.print("a x* b {}\n", .{a.@"x*"(b)});
}
