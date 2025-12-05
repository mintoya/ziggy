const std = @import("std");
const zig = @import("zig");
const ATran = @import("alloc-translate.zig");

const c = @import("cInclude.zig").c;
const cI = @import("cInclude.zig").cI;

const clist = @import("my-list.zig");
const myMap = @import("my-map.zig");

test "zig c impl test list" {
    const expect = std.testing.expect;
    const l = try clist.my_List(usize).new(.{});
    defer l.free();
    for (0..5) |i| {
        try l.push(i);
    }
    try expect(l.length() == 5);
    var v = true;
    l.each(struct {
        fn do(e: clist.Pair(u32, usize), vptr: anytype) void {
            const vp: *bool = vptr;
            vp.* = (e[0] == e[1]) and vp.*;
        }
    }.do, &v);
    try expect(v);
}
test "zig c impl test omap" {
    const expect = std.testing.expect;
    // const localArena: *c.My_allocator = c.arena_new(1024);
    // defer c.arena_cleanup(localArena);

    const intHMap = myMap.my_Omap(i32, i32).new(.{});
    defer intHMap.free();

    for (0..5) |i| {
        const ii: i32 = @intCast(i);
        intHMap.set(ii, ii * ii);
    }
    for (0..5) |i| {
        const ii: i32 = @intCast(i);
        if (intHMap.get(ii)) |iii| {
            try expect(ii * ii == iii);
        } else {
            return error.notNull;
        }
    }
}

test "zig c impl test hmap" {
    const expect = std.testing.expect;
    // const localArena: *c.My_allocator = c.arena_new(1024);
    // defer c.arena_cleanup(localArena);

    const intHMap = myMap.my_Hmap(i32, i32).new(.{});
    defer intHMap.free();

    for (0..5) |i| {
        const ii: i32 = @intCast(i);
        intHMap.set(ii, ii * ii);
    }
    for (0..5) |i| {
        const ii: i32 = @intCast(i);
        if (intHMap.get(ii)) |iii| {
            try expect(ii * ii == iii);
        } else {
            return error.notNull;
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const close = gpa.deinit();
        std.debug.print("status:  {}\n", .{close});
    }
    const h = gpa.allocator();
    var cTranslation = ATran.Zallocator().new(h);

    const mainAllocator_h = cTranslation.translate();
    const mainAllocator = &(mainAllocator_h);

    // const cArena = c.arena_new_ext(&mainAllocator, 2048);
    // defer {
    //     std.debug.print("current block size  {} \n", .{c.arena_footprint(cArena)});
    //     c.arena_cleanup(cArena);
    // }

    const resHmap = myMap.my_Hmap(i32, i32).new(.{
        .allocator = mainAllocator,
        .from = &[_]myMap.Pair(i32, i32){
            .{ 0, 7 },
            .{ 1, 8 },
            .{ 8, 9 },
        },
    });
    defer resHmap.free();

    const resOmap = myMap.my_Omap(i32, i32).new(.{
        .allocator = mainAllocator,
        .from = &[_]myMap.Pair(i32, i32){
            .{ 0, 7 },
            .{ 1, 8 },
            .{ 8, 9 },
        },
    });
    defer resOmap.free();

    const l = try clist.my_List(usize).new(.{
        .allocator = mainAllocator,
        .from = &[_]clist.Pair(u32, usize){
            .{ 0, 7 },
            .{ 1, 8 },
            .{ 8, 9 },
        },
    });
    defer l.free();

    var v: bool = true;

    resHmap.each(struct {
        fn do(e: myMap.Pair(i32, i32), vptr: anytype) void {
            const vp: *bool = vptr;
            std.debug.print("Hmap: key={} value={?}\n", .{ e[0], e[1] });
            vp.* = vp.*;
        }
    }.do, &v);
    resOmap.each(struct {
        fn do(e: myMap.Pair(i32, i32), vptr: anytype) void {
            const vp: *bool = vptr;
            std.debug.print("Omap: key={} value={?}\n", .{ e[0], e[1] });
            vp.* = vp.*;
        }
    }.do, &v);
    l.each(struct {
        fn do(e: clist.Pair(u32, usize), vptr: anytype) void {
            const vp: *bool = vptr;
            std.debug.print("List: index={} value={?}\n", .{ e[0], e[1] });
            vp.* = vp.*;
        }
    }.do, &v);

    std.debug.print("bucketsLen {}\n", .{gpa.buckets.len});
}
