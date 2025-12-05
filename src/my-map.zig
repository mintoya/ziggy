const std = @import("std");
const zig = @import("zig");
const c = @import("cInclude.zig").c;
const cI = @import("cInclude.zig").cI;
const listTypes = @import("my-list.zig");

pub const Pair = listTypes.Pair;
pub const Iterator = listTypes.Iterator;
pub fn my_Hmap(comptime keyType: type, comptime valType: type) type {
    return struct {
        const Self = @This();
        pub const newArgs = struct {
            allocator: *const c.My_allocator = &(c.defaultAllocator),
            buckets: u32 = 32,
            from: []const Pair(keyType, valType) = &[_]Pair(keyType, valType){},
        };
        pub const Iter = Iterator(Self, keyType, valType, getN);
        each: Iter = {},
        val: *cI.HMap = undefined,

        pub fn new(args: newArgs) Self {
            var self: Self = undefined;
            self.val = cI.HMap_new(args.allocator, args.buckets);
            for (args.from) |e| {
                self.set(e[0], e[1]);
            }
            return self;
        }
        pub const init = new;
        pub fn free(self: Self) void {
            cI.HMap_free(self.val);
        }
        pub const deinit = free;
        pub fn set(self: Self, k: keyType, v: ?valType) void {
            const keyValue: cI.fptr =
                switch (keyType) {
                    []const u8 => cI.fptr_fromStr(k),
                    cI.fptr => k,
                    else => cI.asFptr(keyType, &k),
                };
            var valValue: cI.fptr = cI.fptr{ .ptr = @as(?*u8, @ptrFromInt(0)), .width = 0 };
            if (v) |fp| {
                valValue = switch (valType) {
                    []const u8 => cI.fptr_fromStr(fp),
                    cI.fptr => fp,
                    else => cI.asFptr(valType, &fp),
                };
            }
            _ = cI.HMap_set(self.val, keyValue, valValue);
        }
        pub fn get(self: Self, k: keyType) ?valType {
            const res: cI.fptr = cI.HMap_get(self.val, switch (keyType) {
                []const u8 => cI.fptr_fromStr(k),
                cI.fptr => k,
                else => cI.asFptr(keyType, &k),
            });
            return switch (valType) {
                []const u8 => cI.slice_fromFptr(res),
                cI.fptr => res,
                else => cI.fromFptr(valType, res),
            };
        }
        pub fn length(self: Self) u32 {
            return cI.HMap_count(self.val);
        }
        pub fn getN(self: Self, i: u32) ?Pair(keyType, valType) {
            if (i >= self.length()) return null;
            const res = cI.HMap_getNth(self.val, i);
            return .{
                switch (keyType) {
                    []const u8 => cI.slice_fromFptr(res.key) orelse return null,
                    cI.fptr => res.key,
                    else => cI.fromFptr(valType, res.key) orelse return null,
                },
                switch (valType) {
                    []const u8 => cI.slice_fromFptr(res.val) orelse null,
                    cI.fptr => res.val,
                    else => cI.fromFptr(valType, res.val) orelse null,
                },
            };
        }
    };
}
pub fn my_Omap(comptime keyType: type, comptime valType: type) type {
    return struct {
        const Self = @This();
        pub const newArgs = struct {
            allocator: *const c.My_allocator = &(c.defaultAllocator),
            buckets: u32 = 32,
            from: []const Pair(keyType, valType) = &[_]Pair(keyType, valType){},
        };
        pub const each = Iterator(@This(), keyType, valType, getN);
        val: *cI.OMap = undefined,

        pub fn new(args: newArgs) Self {
            var self: Self = undefined;
            self.val = cI.OMap_new(args.allocator);
            for (args.from) |e| {
                self.set(e[0], e[1]);
            }
            return self;
        }
        pub const init = new;
        pub fn free(self: Self) void {
            cI.OMap_free(self.val);
        }
        pub const deinit = free;
        pub fn set(self: Self, k: keyType, v: ?valType) void {
            const keyValue: cI.fptr =
                switch (keyType) {
                    []const u8 => cI.fptr_fromStr(k),
                    cI.fptr => k,
                    else => cI.asFptr(keyType, &k),
                };
            var valValue: cI.fptr = cI.fptr{ .ptr = @as(?*u8, @ptrFromInt(0)), .width = 0 };
            if (v) |fp| {
                valValue = switch (valType) {
                    []const u8 => cI.fptr_fromStr(fp),
                    cI.fptr => fp,
                    else => cI.asFptr(valType, &fp),
                };
            }
            _ = cI.OMap_setRaw(self.val, keyValue, valValue);
        }
        pub fn get(self: Self, k: keyType) ?valType {
            const res: cI.fptr = cI.OMap_getRaw(self.val, switch (keyType) {
                []const u8 => cI.fptr_fromStr(k),
                cI.fptr => k,
                else => cI.asFptr(keyType, &k),
            });
            return switch (valType) {
                []const u8 => cI.slice_fromFptr(res),
                cI.fptr => res,
                else => cI.fromFptr(valType, res),
            };
        }
        pub fn length(self: Self) u32 {
            return cI.OMap_length(self.val);
        }
        pub fn getN(self: Self, i: u32) ?Pair(keyType, valType) {
            if (i >= self.length()) return null;
            const resultkey = cI.OMap_getKey(self.val, i);
            const resultval = cI.OMap_getVal(self.val, i);
            return .{
                switch (keyType) {
                    []const u8 => cI.slice_fromFptr(resultkey) orelse return null,
                    cI.fptr => resultkey,
                    else => cI.fromFptr(keyType, resultkey) orelse return null,
                },
                switch (valType) {
                    []const u8 => cI.slice_fromFptr(resultval) orelse null,
                    cI.fptr => resultval,
                    else => cI.fromFptr(valType, resultval) orelse null,
                },
            };
        }
    };
}
