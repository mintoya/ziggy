const std = @import("std");
const c = @import("c_Imports");
const cHardMap = @import("cmap").my_HHmap;
const aTran = @import("alloc-translate.zig").Zallocator;
const Pair = @import("clist").Pair;
pub fn main() !void {
    var gpav = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpav.allocator();
    defer std.debug.assert(gpav.deinit() == .ok);

    const cver = c.c.arena_new_ext(
        &(aTran().new(gpa).translate()),
        1024,
    );
    defer c.c.arena_cleanup(cver);

    const testMap = cHardMap([8]u8, i32).new(.{ .allocator = cver });

    defer testMap.free();
    testMap.set("hello wo".*, 2);
    testMap.set("hell owo".*, 2);
    testMap.set("hel lowo".*, 2);
    testMap.set("he llowo".*, 2);
    testMap.set("h ellowo".*, 7);

    testMap.each(struct {
        fn e(v: Pair([8]u8, i32), _: anytype) void {
            std.debug.print("{s} : {?}\n", .{ v.@"0", v.@"1" });
        }
    }.e, null);
}
