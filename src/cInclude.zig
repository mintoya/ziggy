const std = @import("std");
const assert = std.debug.assert;

pub const c =
    @cImport({
        @cInclude("allocator.h");
        @cInclude("vason_arr.h");
    });
pub const cI = struct {
    pub const fptr = extern struct {
        width: usize,
        ptr: ?*u8,
    };
    pub fn fptr_fromStr(s: []const u8) fptr {
        return fptr{
            .ptr = @ptrCast(@constCast(s.ptr)),
            .width = s.len,
        };
    }
    pub fn slice_fromFptr(s: fptr) ?[]const u8 {
        if (null != s.ptr and s.width > 0)
            return @as(*[]u8, @ptrCast(@constCast(&.{ .ptr = s.ptr, .len = s.width }))).*;
        assert(s.width == 0);
        return null;
    }
    pub fn asFptr(comptime T: type, vp: *const T) fptr {
        return fptr{
            .ptr = @ptrCast(@alignCast(@constCast(vp))),
            .width = @sizeOf(T),
        };
    }
};

const Log = std.log.scoped(.my_alloc_zig);
const Allocator = std.mem.Allocator;
const My_allocator = c.My_allocator;

pub const Zallocator = struct {
    cAllocator: My_allocator = .{
        .alloc = c_alloc,
        .free = c_free,
        .resize = c_realloc,
        .size = c_size,
    },
    zAllocator: Allocator align(@alignOf(c.max_align_t)),
    fn getptr(ptr: *anyopaque) *const @This() {
        return @ptrCast(@alignCast(@constCast(ptr)));
    }
    pub fn allocatorPtr(self: *const @This()) [*c]const My_allocator {
        return @ptrCast(@constCast(self));
    }
    const C_Align = @alignOf(std.c.max_align_t);
    const Z_Align = std.mem.Alignment.fromByteUnits(C_Align);

    const HeaderSize = std.mem.alignForward(usize, @sizeOf(usize), C_Align);

    inline fn getSlice(mem: [*]u8) []u8 {
        const base_ptr = mem - HeaderSize;
        const size_ptr: *usize = @ptrCast(@alignCast(base_ptr));
        return base_ptr[0 .. size_ptr.* + HeaderSize];
    }

    inline fn getPtr(slice: []u8, requested_bytes: usize) [*]u8 {
        const size_ptr: *usize = @ptrCast(@alignCast(slice.ptr));
        size_ptr.* = requested_bytes;
        return slice.ptr + HeaderSize;
    }

    pub fn malloc(self: *const Zallocator, bytes: usize) callconv(.c) ?*anyopaque {
        const slice = self.zAllocator.alignedAlloc(u8, Z_Align, bytes + HeaderSize) catch |e| {
            std.log.scoped(.main).err("!malloc {s}\n", .{@errorName(e)});
            return null;
        };
        return @ptrCast(getPtr(slice, bytes));
    }

    pub fn realloc(self: *const Zallocator, memq: ?*anyopaque, bytes: usize) callconv(.c) ?*anyopaque {
        const mem: [*]u8 = @ptrCast(memq orelse return self.malloc(bytes));
        const old_slice = getSlice(mem);
        const new_slice = self.zAllocator.alignedAlloc(u8, Z_Align, bytes + HeaderSize) catch |e| {
            std.log.scoped(.main).err("!malloc {s}\n", .{@errorName(e)});
            return null;
        };

        @memcpy(new_slice, old_slice);
        self.zAllocator.free(old_slice);

        return @ptrCast(getPtr(new_slice, bytes));
    }

    pub fn free(self: *const Zallocator, memq: ?*anyopaque) callconv(.c) void {
        const mem: [*]u8 = @ptrCast(memq orelse return);
        const slice = getSlice(mem);
        self.zAllocator.rawFree(slice, Z_Align, @returnAddress());
    }

    fn c_alloc(
        allocator: [*c]const My_allocator,
        size: usize,
    ) callconv(.c) *anyopaque {
        var alloc = getSelf(@constCast(allocator));
        const mem = alloc.malloc(size) orelse unreachable;
        return @ptrCast(mem);
    }
    fn c_realloc(
        allocator: [*c]const My_allocator,
        mem: ?*anyopaque,
        size: usize,
    ) callconv(.c) ?*anyopaque {
        var alloc = getSelf(@constCast(allocator));
        const newmem = alloc.realloc(@ptrCast(mem), size) orelse return @as(?*anyopaque, @ptrFromInt(0));
        return @ptrCast(newmem);
    }

    fn c_free(
        allocator: [*c]const My_allocator,
        mem: ?*anyopaque,
    ) callconv(.c) void {
        var alloc = getSelf(@constCast(allocator));
        alloc.free(@ptrCast(mem));
    }

    fn c_size(
        _: [*c]const My_allocator,
        mem: ?*anyopaque,
    ) callconv(.c) usize {
        const ptr = mem orelse return 0;
        const slice: []u8 = getSlice(@ptrCast(ptr));
        return slice.len;
    }
};
