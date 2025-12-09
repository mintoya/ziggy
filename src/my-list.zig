const std = @import("std");
const zig = @import("zig");

const cimports = @import("c_Imports");
const c = cimports.c;
const cI = cimports.cI;

pub fn Pair(keyType: type, valType: type) type {
    return struct { keyType, ?valType };
}
pub fn Iterator(comptime Self: type, comptime pairType: type, getN: fn (Self, u32) ?pairType) fn (
    self: Self,
    func: fn (pairType, context: anytype) void,
    context: anytype,
) void {
    return struct {
        pub fn each(
            self: Self,
            func: fn (item: pairType, context: anytype) void,
            context: anytype,
        ) void {
            var i: u32 = 0;
            while (i < self.length()) : (i += 1) {
                const item = getN(self, i) orelse unreachable;
                func(item, context);
            }
        }
    }.each;
}
pub fn my_List(comptime T: type) type {
    return struct {
        pub const err = error{
            List_outOfMemory,
            List_Unknown,
            List_InValid,
            List_OutOfBounds,
        };

        pub fn cConv(cError: u8) !void {
            if (cError == c.List_opErrorS.CantResize)
                return err.List_outOfMemory;
            // if (cError == c.List_opErrorS.Invalid)
            //     return err.List_Unknown;
            return;
        }
        const Self = @This();
        pub const PairType: type = Pair(u32, T);
        pub const each = Iterator(Self, PairType, getN);
        val: *c.List = undefined,
        pub const newArgs = struct {
            allocator: *const c.My_allocator,
            initial: u32 = 1,
            from: []const PairType = &[_]PairType{},
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
            return cConv(if (el) |e|
                c.List_append(self.val, &e)
            else
                c.List_append(self.val, null));
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
        pub fn get(self: Self, index: u32) !T {
            const resptr: ?*T =
                @ptrCast(@alignCast(c.List_getRef((self.val), index)));
            if (resptr) |p| {
                return p.*;
            } else {
                return Self.err.List_OutOfBounds;
            }
        }
        pub fn getN(self: Self, i: u32) ?PairType {
            const res: T = get(self, i) catch unreachable;
            return .{ i, res };
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
            return (cConv(c.List_insert((self.val), index, ref)));
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
    l.each(struct {
        fn do(e: Pair(u32, usize), vptr: anytype) void {
            const vp: *bool = vptr;
            vp.* = (e[0] == e[1] + 1) and vp.*;
        }
    }.do, &v);
    try expect(v);
}
