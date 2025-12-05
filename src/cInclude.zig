const std = @import("std");
const assert = std.debug.assert;

pub const c =
    @cImport({
        @cInclude("../wheels/my-list.h");
        @cInclude("../wheels/allocator.h");
        @cInclude("../wheels/arenaAllocator.h");
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
    pub const List_opErrorS_Type = extern struct { // Define the TYPE
        Ok: u8,
        CantResize: u8,
        Invalid: u8,
    };
    pub extern const List_opErrorS: List_opErrorS_Type;
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
    pub extern fn OMap_getRaw(*OMap, fptr) fptr;
    pub extern fn OMap_setRaw(*OMap, key: fptr, val: fptr) c_uint;
    pub extern fn OMap_length(*const OMap) u32;
    pub extern fn OMap_getKey(*const OMap, u32) fptr;
    pub extern fn OMap_getVal(*const OMap, u32) fptr;
};
