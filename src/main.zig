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


pub fn main() !void {
    const list_usize = cList(usize);
    const hmap_i32 = hMap(i32, i32);
    const omap_i32 = oMap(i32, i32);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const close = gpa.deinit();
        std.debug.print("status:  {}\n", .{close});
    }
    const h = gpa.allocator();
    var cTranslation = ATran.Zallocator().new(h);

    const mainAllocator_h = cTranslation.translate();
    const mainAllocator = &(mainAllocator_h);

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
            std.debug.print("Hmap: key={} value={?}\n", .{ e[0], e[1] });
            vp.* = vp.*;
        }
    }.do, &v);
    resOmap.each(struct {
        fn do(e: omap_i32.PairType, vptr: anytype) void {
            const vp: *bool = vptr;
            std.debug.print("Omap: key={} value={?}\n", .{ e[0], e[1] });
            vp.* = vp.*;
        }
    }.do, &v);
    l.each(struct {
        fn do(e: list_usize.PairType, vptr: anytype) void {
            const vp: *bool = vptr;
            std.debug.print("List: index={} value={?}\n", .{ e[0], e[1] });
            vp.* = vp.*;
        }
    }.do, &v);

    std.debug.print("bucketsLen {}\n", .{gpa.buckets.len});
}
