const std = @import("std");
const zig = @import("zig");
const ATran = @import("alloc-translate.zig");

const cimports = @import("c_Imports");
const c = cimports.c;
const cI = cimports.cI;

const cMap = @import("cmap");
const cList = @import("clist").my_List;
const hMap = cMap.my_Hmap;
const oMap = cMap.my_Omap;

const EqualityResult = enum { more, less, equal };
pub fn Equality(
    comptime T: type,
    comptime cmp: fn (a: T, b: T) i8,
) type {
    return struct {
        pub inline fn compare(a: T, b: T) EqualityResult {
            const comparison = cmp(a, b);
            if (comparison > 0) {
                return EqualityResult.more;
            } else if (comparison < 0) {
                return EqualityResult.less;
            } else {
                return EqualityResult.equal;
            }
        }
        pub inline fn equal(a: T, b: T) bool {
            return compare(a, b) == EqualityResult.equal;
        }
        pub inline fn moq(a: T, b: T) bool {
            const cr = compare(a, b);
            return cr == EqualityResult.more or cr == EqualityResult.equal;
        }
        pub inline fn leq(a: T, b: T) bool {
            const cr = compare(a, b);
            return cr == EqualityResult.less or cr == EqualityResult.equal;
        }
        pub inline fn less(a: T, b: T) bool {
            const cr = compare(a, b);
            return cr == EqualityResult.less;
        }
        pub inline fn more(a: T, b: T) bool {
            const cr = compare(a, b);
            return cr == EqualityResult.more;
        }
        pub inline fn allEqual(comptime input: anytype) bool {
            if (@typeInfo(@TypeOf(input)).@"struct".fields.len < 2) return true;
            const fields = @typeInfo(@TypeOf(input)).@"struct".fields;
            const ff: T = @field(input, fields[0].name);
            inline for (fields[1..]) |field_info| {
                const el: T = @field(input, field_info.name);
                const eq = compare(ff, el);
                if ((eq != EqualityResult.equal)) {
                    return false;
                }
            }
            return true;
        }
    };
}

pub fn main() !void {
    const print = std.debug.print;
    const list_usize = cList(usize);
    const hmap_i32 = hMap(i32, i32);
    const omap_i32 = oMap(i32, i32);

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer {
    //     const close = gpa.deinit();
    //     print("status:  {}\n", .{close});
    // }
    // const h = gpa.allocator();
    // var cTranslation = ATran.Zallocator().new(h).translate();

    const mainAllocator = c.arena_new();
    defer c.arena_cleanup(mainAllocator);

    // const mainAllocator = &(cTranslation);

    const resHmap = hmap_i32.new(.{
        .allocator = mainAllocator,
        .from = &[_]cMap.Pair(i32, i32){
            .{ 0, 7 },
            .{ 1, 8 },
            .{ 8, 9 },
        },
    });
    defer resHmap.free();

    const resOmap = omap_i32.new(.{
        .allocator = mainAllocator,
        .from = &[_]omap_i32.PairType{
            .{ 0, 7 },
            .{ 1, 8 },
            .{ 8, 9 },
        },
    });
    defer resOmap.free();

    const l = try list_usize.new(.{
        .allocator = mainAllocator,
        .from = &[_]list_usize.PairType{
            .{ 0, 7 },
            .{ 1, 8 },
            .{ 8, 9 },
        },
    });
    defer l.free();

    var v: bool = true;

    resHmap.each(struct {
        fn do(e: hmap_i32.PairType, vptr: anytype) void {
            const vp: *bool = vptr;
            print("Hmap: key={} value={?}\n", .{ e[0], e[1] });
            vp.* = vp.*;
        }
    }.do, &v);

    resOmap.each(struct {
        fn do(e: omap_i32.PairType, vptr: anytype) void {
            const vp: *bool = vptr;
            print("Omap: key={} value={?}\n", .{ e[0], e[1] });
            vp.* = vp.*;
        }
    }.do, &v);
    l.each(struct {
        fn do(e: list_usize.PairType, vptr: anytype) void {
            const vp: *bool = vptr;
            print("List: index={} value={?}\n", .{ e[0], e[1] });
            vp.* = vp.*;
        }
    }.do, &v);

    const charEquality = Equality(u8, struct {
        fn cmp(a: u8, b: u8) i8 {
            const ai: i16 = @intCast(a);
            const bi: i16 = @intCast(b);
            const result = ai - bi;
            if (result == 0) return 0;
            return if (result < 0) -1 else 1;
        }
    }.cmp);
    std.debug.print("cmp = {}\n", .{charEquality.allEqual(.{ '1', '2', '3' })});
    std.debug.print("cmp = {}\n", .{charEquality.allEqual(.{ '1', '1', '1' })});
    const sliceEquality = Equality([]u8, struct {
        fn cmp(a: []u8, b: []u8) i8 {
            if (a.len != b.len) {
                return if (a.len > b.len) 1 else -1;
            }
            for (0..a.len) |i| {
                const result = charEquality.compare(a.ptr[i], b.ptr[i]);
                switch (result) {
                    EqualityResult.less => return -1,
                    EqualityResult.more => return 1,
                    else => continue,
                }
            }
            return 0;
        }
    }.cmp);
    const s1: []u8 = @constCast("hello");
    const s2: []u8 = @constCast("hello");
    const s3: []u8 = @constCast("hello");
    const s4: []u8 = @constCast("hallo");
    print("cmp = {}\n", .{sliceEquality.allEqual(.{ s1, s2, s3 })});
    print("cmp = {}\n", .{sliceEquality.allEqual(.{ s1, s4, s3 })});
}
