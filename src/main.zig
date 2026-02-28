const std = @import("std");
const c = @import("cInclude.zig");
const Allocator = std.mem.Allocator;

const Log = std.log.scoped(.main);
fn toC(s: []const u8) c.c.struct_slice_c8 {
    return .{
        .len = s.len,
        .ptr = @constCast(s.ptr),
    };
}
pub fn main() !void {
    var GPA = std.heap.DebugAllocator(.{}).init;
    const gpa: Allocator = GPA.allocator();
    const cAllocator = c.Zallocator{ .zAllocator = gpa };
    const vs = c.c.vason_parseString(cAllocator.getptr(), toC("hello world"));
}
