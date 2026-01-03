const std = @import("std");
const zig = @import("zig");

const cimports = @import("c_Imports");
const c = cimports.c;
const cI = cimports.cI;

pub fn my_List(comptime T: type) type {
    return struct {
        pub const err = error{
            List_outOfMemory,
            List_OutOfBounds,
        };

        // pub fn cConv(cError: u8) !void {
        //     if (cError == c.List_opErrorS.CantResize)
        //         return err.List_outOfMemory;
        //     return;
        // }
        const Self = @This();
        val: *c.List = undefined,
        pub const newArgs = struct {
            allocator: *const c.My_allocator,
            initial: u32 = 1,
            from: []const struct { u32, T } = &[_]struct { u32, T }{},
        };
        pub fn new(args: newArgs) !Self {
            var res: Self = undefined;
            res.val = c.List_new(args.allocator, @sizeOf(T));
            if (c.List_validState(res.val) != c.List_opErrorS.Ok) {
                return Self.err.List_Unknown;
            }
            if (c.List_resize(res.val, args.initial) != c.List_opErrorS.Ok) {
                return Self.err.List_outOfMemory;
            }
            for (args.from) |e| {
                while (res.length() < e[0] + 1) {
                    try res.push(null);
                }
                res.set(e[0], e[1]);
            }
            return res;
        }
        pub const init = new;
        pub fn push(self: Self, el: ?T) !void {
            if (el) |e| {
                c.List_append(self.val, &e);
            } else {
                c.List_append(self.val, null);
            }
        }
        pub inline fn length(self: Self) u32 {
            return c.List_length(self.val);
        }
        pub fn set(self: Self, index: u32, val: ?T) void {
            if (val) |v| {
                c.List_set(self.val, index, &v);
            } else {
                c.List_set(self.val, index, null);
            }
        }
        pub fn get(self: Self, index: u32) T {
            const resptr: ?*T =
                @ptrCast(@alignCast(c.List_getRef((self.val), index)));
            if (resptr) |p| {
                return p.*;
            } else {
                return Self.err.List_OutOfBounds;
            }
        }
        pub fn pop(self: Self) !T {
            if (self.length() == 0)
                return Self.err.List_OutOfBounds;
            const res: T = try self.get(self.length() - 1);
            self.val.length -= 1;
            return res;
        }
        pub fn insert(self: Self, el: T, index: u32) !void {
            const ref: *const anyopaque = @ptrCast(&el);
            return c.List_insert((self.val), index, ref);
        }
        pub fn remove(self: Self, index: u32) T {
            const res: T = self.get(index) catch undefined;
            c.List_remove(self.val, index);
            return res;
        }
        pub fn free(self: Self) void {
            c.List_free((self.val));
        }
        pub const deinit = free;
    };
}

test "zig c impl test list" {
    const expect = std.testing.expect;
    const l = try my_List(usize).new(.{});
    defer l.free();
    for (0..5) |i| {
        try l.push(i);
    }
    try expect(l.length() == 5);
    var v = true;
    l.each(struct {}.do, &v);
    try expect(v);
}
