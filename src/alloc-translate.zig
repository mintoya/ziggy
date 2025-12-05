const std = @import("std");
const c = @import("cInclude.zig").c;

const Log = std.log.scoped(.my_alloc_zig);
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const My_allocator = c.My_allocator;

// [copied from here](https://github.com/D-Berg/zalloc)
fn getSlice(ptr: [*]u8) []u8 {
    var slice: []u8 = undefined;
    slice.ptr = ptr - @sizeOf(usize);
    const len_of_allocation = std.mem.bytesToValue(usize, slice.ptr[0..@sizeOf(usize)]);
    slice.len = len_of_allocation + @sizeOf(usize);
    return slice;
}
fn getPtr(slice: []u8, size: usize) [*]u8 {
    @memcpy(slice[0..@sizeOf(usize)], std.mem.toBytes(size)[0..]);
    return slice.ptr + @sizeOf(usize);
}
pub fn Zallocator() type {
    return struct {
        zAllocator: Allocator,
        const Self: type = @This();
        pub fn new(zAllocator: Allocator) Self {
            return .{zAllocator};
        }
        pub fn translate(self: *Self) My_allocator {
            return .{
                .arb = self,
                .alloc = c_alloc,
                .free = c_free,
                .r_alloc = c_realloc,
            };
        }
        pub fn malloc(self: Self, bytes: usize) ?[*]u8 {
            const slice = self.zAllocator.alloc(u8, bytes + @sizeOf(usize)) catch |e| {
                Log.err("!malloc {s}\n", .{@errorName(e)});
                return null;
            };
            return getPtr(slice, bytes);
        }
        pub fn realloc(self: Self, memq: ?[*]u8, bytes: usize) ?[*]u8 {
            const mem = memq orelse return null;
            const slice: []u8 = getSlice(mem);
            const newSlice: []u8 = self.zAllocator.realloc(slice, bytes + @sizeOf(usize)) catch |e| {
                Log.err("!realloc {s}\n", .{@errorName(e)});
                return null;
            };
            return getPtr(newSlice, bytes);
        }
        pub fn free(self: Self, memq: ?[*]u8) void {
            const mem = memq orelse return;
            const sliceq: ?[]u8 = getSlice(mem);
            const slice = sliceq orelse return;
            self.zAllocator.free(slice);
        }

        pub fn c_alloc(
            allocator: [*c]const My_allocator,
            size: usize,
        ) callconv(.c) ?*anyopaque {
            var alloc = @as(*Self, @ptrCast(@alignCast(@constCast(allocator.*.arb))));
            const mem = alloc.malloc(size) orelse return @as(?*anyopaque, @ptrFromInt(0));
            return @ptrCast(mem);
        }

        pub fn c_realloc(
            allocator: [*c]const My_allocator,
            mem: ?*anyopaque,
            size: usize,
        ) callconv(.c) ?*anyopaque {
            var alloc = @as(*Self, @ptrCast(@alignCast(@constCast(allocator.*.arb))));
            const newmem = alloc.realloc(@ptrCast(mem), size) orelse return @as(?*anyopaque, @ptrFromInt(0));
            return @ptrCast(newmem);
        }
        pub fn c_free(
            allocator: [*c]const My_allocator,
            mem: ?*anyopaque,
        ) callconv(.c) void {
            var alloc = @as(*Self, @ptrCast(@alignCast(@constCast(allocator.*.arb))));
            alloc.free(@ptrCast(mem));
        }
    };
}
