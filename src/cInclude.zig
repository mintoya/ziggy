const std = @import("std");
const assert = std.debug.assert;

pub const c =
    @cImport({
        @cInclude("my-list.h");
        @cInclude("allocator.h");
        @cInclude("arenaAllocator.h");
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
    pub fn fromFptr(comptime T: type, f: fptr) ?T {
        if (f.ptr != null and f.width > 0) {
            var res: T = undefined;
            assert(f.width >= @sizeOf(T));
            _ = c.memcpy(&res, f.ptr, f.width);
            return res;
        } else {
            assert(f.width == 0);
            return null;
        }
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

    pub const List = extern struct {};
    pub const HMap = extern struct {};
    pub const HMap_both = extern struct {
        key: fptr,
        val: fptr,
    };

    pub extern fn HMap_new(*const c.My_allocator, u32) *HMap;
    pub extern fn HMap_free(*HMap) void;
    pub extern fn HMap_remake(*HMap) void;
    pub extern fn HMap_get(*const HMap, fptr) fptr;
    pub extern fn HMap_set(*HMap, key: fptr, val: fptr) c_uint;
    pub extern fn HMap_count(*const HMap) u32;
    pub extern fn HMap_getNth(*const HMap, u32) HMap_both;

    pub const OMap = extern struct {};
    pub extern fn OMap_new(*const c.My_allocator) *OMap;
    pub extern fn OMap_free(*OMap) void;
    pub extern fn OMap_remake(*OMap) void;
    pub extern fn OMap_getRaw(*const OMap, fptr) fptr;
    pub extern fn OMap_setRaw(*OMap, key: fptr, val: fptr) c_uint;
    pub extern fn OMap_length(*const OMap) u32;
    pub extern fn OMap_getKey(*const OMap, u32) fptr;
    pub extern fn OMap_getVal(*const OMap, u32) fptr;

    pub const HHMap = extern struct {};
    pub extern fn HHMap_new(keysize: usize, valuesize: usize, *const c.My_allocator, buckets: u32) *HHMap;
    pub extern fn HHMap_free(map: *HHMap) void;
    pub extern fn HHmap_getSet(map: *HHMap, key: *const anyopaque, val: *void) bool;
    pub extern fn HHMap_set(map: *HHMap, key: *const anyopaque, val: ?*const anyopaque) void;
    pub extern fn HHMap_get(map: *const HHMap, key: *const anyopaque) ?*anyopaque;
    pub extern fn HHMap_getMetaSize(map: *const HHMap) u32;
    pub extern fn HHMap_count(map: *const HHMap) u32;
    pub extern fn HHMap_getKey(map: *const HHMap, idx: u32) *anyopaque;
    pub extern fn HHMap_getVal(map: *const HHMap, idx: u32) *anyopaque;
    pub extern fn HHMap_fset(map: *const HHMap, key: fptr, val: ?*const anyopaque) void;
    pub extern fn HHMap_fget(map: *const HHMap, key: fptr) ?*anyopaque;
};

const Log = std.log.scoped(.my_alloc_zig);
const Allocator = std.mem.Allocator;
const My_allocator = c.My_allocator;

// [thanks to](https://github.com/D-Berg/zalloc)
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
//

pub const Zallocator = struct {
    zAllocator: Allocator,
    const Self: type = @This();
    pub fn translate(self: *const Self) My_allocator {
        return .{
            .arb = @ptrCast(@constCast(self)),
            .alloc = c_alloc,
            .free = c_free,
            .ralloc = c_realloc,
            .size = null,
        };
    }
    fn malloc(self: Self, bytes: usize) ?[*]u8 {
        const slice = self.zAllocator.alloc(u8, bytes + @sizeOf(usize)) catch |e| {
            Log.err("!malloc {s}\n", .{@errorName(e)});
            return null;
        };
        return getPtr(slice, bytes);
    }
    fn realloc(self: Self, memq: ?[*]u8, bytes: usize) ?[*]u8 {
        const mem = memq orelse return null;
        const slice: []u8 = getSlice(mem);
        const newSlice: []u8 = self.zAllocator.realloc(slice, bytes + @sizeOf(usize)) catch |e| {
            Log.err("!realloc {s}\n", .{@errorName(e)});
            return null;
        };
        return getPtr(newSlice, bytes);
    }
    fn free(self: Self, memq: ?[*]u8) void {
        const mem = memq orelse return;
        const sliceq: ?[]u8 = getSlice(mem);
        const slice = sliceq orelse return;
        self.zAllocator.free(slice);
    }

    fn c_alloc(
        allocator: [*c]const My_allocator,
        size: usize,
    ) callconv(.c) ?*anyopaque {
        var alloc = @as(*Self, @ptrCast(@alignCast(@constCast(allocator.*.arb))));
        const mem = alloc.malloc(size) orelse return @as(?*anyopaque, @ptrFromInt(0));
        return @ptrCast(mem);
    }

    fn c_realloc(
        allocator: [*c]const My_allocator,
        mem: ?*anyopaque,
        size: usize,
    ) callconv(.c) ?*anyopaque {
        var alloc = @as(*Self, @ptrCast(@alignCast(@constCast(allocator.*.arb))));
        const newmem = alloc.realloc(@ptrCast(mem), size) orelse return @as(?*anyopaque, @ptrFromInt(0));
        return @ptrCast(newmem);
    }
    fn c_free(
        allocator: [*c]const My_allocator,
        mem: ?*anyopaque,
    ) callconv(.c) void {
        var alloc = @as(*Self, @ptrCast(@alignCast(@constCast(allocator.*.arb))));
        alloc.free(@ptrCast(mem));
    }
};
