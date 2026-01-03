const std = @import("std");
const zig = @import("zig");

const cimports = @import("c_Imports");
const c = cimports.c;
const cI = cimports.cI;
const listTypes = @import("clist");

pub fn my_Hmap(comptime keyType: type, comptime valType: type) type {
    return struct {
        const Self = @This();
        pub const newArgs = struct {
            allocator: *const c.My_allocator,
            buckets: u32 = 32,
            from: []const struct { keyType, valType } = &.{},
        };
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
    };
}
pub fn my_Omap(comptime keyType: type, comptime valType: type) type {
    return struct {
        const Self = @This();
        pub const newArgs = struct {
            allocator: *const c.My_allocator,
            buckets: u32 = 32,
            from: []const struct { keyType, valType } = &.{},
        };
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
    };
}
pub fn my_HHmap(comptime keyType: type, comptime valType: type) type {
    return struct {
        const Self = @This();
        pub const newArgs = struct {
            allocator: *const c.My_allocator,
            buckets: u32 = 32,
            from: []const struct { keyType, valType } = &.{},
        };
        val: *cI.HHMap = undefined,
        pub fn new(args: newArgs) Self {
            var self: Self = undefined;
            self.val = cI.HHMap_new(
                @sizeOf(keyType),
                @sizeOf(valType),
                args.allocator,
                args.buckets,
            );
            for (args.from) |e| {
                self.set(e[0], e[1]);
            }
            return self;
        }
        pub const init = new;
        pub fn free(self: Self) void {
            cI.HHMap_free(self.val);
        }
        pub const deinit = free;
        pub fn set(self: Self, k: keyType, v: ?valType) void {
            cI.HHMap_fset(self.val, cI.asFptr(keyType, &k), @ptrCast(&v));
        }
        pub fn get(self: Self, k: keyType) ?valType {
            if (cI.HHMap_fget(self.val, cI.asFptr(keyType, &k))) |v| {
                var res: keyType = undefined;
                _ = c.memcpy(&res, v, @sizeOf(valType));
                return res;
            } else return null;
        }
        pub fn length(self: Self) u32 {
            return cI.HHMap_count(self.val);
        }
    };
}
