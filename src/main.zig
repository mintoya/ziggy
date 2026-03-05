const std = @import("std");
const c = @import("cInclude.zig");
const Allocator = std.mem.Allocator;

const Log = std.log.scoped(.main);
fn shortListLen(ptr: *anyopaque) usize {
    const tptr: [*]c.c.sList_header = @ptrCast(@alignCast(@constCast(ptr)));
    return (tptr - 1)[0].length;
}
pub const Vason = struct {
    const cVason: type = struct {
        on: c.c.vason_container,
        pub inline fn get(self: *const @This()) *c.c.vason_container {
            return @constCast(&self.on);
        }
        pub inline fn deInit(self: @This()) void {
            c.c.vason_container_free(self.on);
        }
        pub inline fn tables(self: @This()) []c.c.vason_span {
            const res: []c.c.vason_span = self.on.tables_strings[0..shortListLen(self.on.tables_strings)];
            return res;
        }
        pub inline fn text(self: @This()) []const u8 {
            const res: []u8 = self.on.text.ptr[0..self.on.text.len];
            return res;
        }
    };
    const cIndex: type = c.c.vason_index;
    origional: ?*cVason,
    place: c.c.vason_index,
    const parseArgs = struct { lazy: bool = false };
    pub fn parse(
        allocator: *const c.Zallocator,
        in: []const u8,
        args: parseArgs,
    ) cVason {
        const res: cVason =
            .{ .on = if (args.lazy)
                c.c.vason_parseString_Lazy(allocator.cPtr(), .{
                    .ptr = @ptrCast(@constCast(in.ptr)),
                    .len = in.len,
                })
            else
                c.c.vason_parseString(allocator.cPtr(), .{
                    .ptr = @ptrCast(@constCast(in.ptr)),
                    .len = in.len,
                }) };
        return res;
    }
    // extern _vason_container_printer

    pub inline fn toContainer(self: @This()) c.c.vason_container {
        return .{
            .current = self.place,
            .tags = @ptrCast(self.origional.?.tags),
            .tables_strings = self.origional.?.tables_strings,
            .text = @ptrCast(self.origional.?.text),
        };
    }
    pub inline fn fromContainer(container: *cVason) @This() {
        return .{
            .origional = container,
            .place = container.get().current,
        };
    }

    pub inline fn tag(self: @This()) c.c.vason_tag {
        if (self.origional) |orig| {
            if (self.place < c.c.msList_len(orig.get().tags)) {
                return orig.get().tags[self.place];
            }
        }
        return c.c.vason_INVALID;
    }

    pub inline fn countChildren(self: @This()) usize {
        if (self.tag() == c.c.vason_TABLE) {
            return self.origional.?.tables_strings[self.place].end - self.origional.?.tables_strings[self.place].start;
        }
        return 0;
    }

    pub inline fn asString(self: @This()) ?[]const u8 {
        if (self.tag() == c.c.vason_STRING) {
            const res: []const u8 = self.origional.?.text()[self.origional.?.tables()[self.place].start..self.origional.?.tables()[self.place].end];
            return res;
        }
        return null;
    }

    pub inline fn isValid(self: @This()) bool {
        return self.tag() != c.c.vason_INVALID;
    }

    pub inline fn get(self: @This(), item: anytype) @This() {
        const typeinfo = @typeInfo(@TypeOf(item));
        const typeErr = struct {
            fn terr() void {
                @compileError(std.fmt.comptimePrint("{} not supported\n", .{typeinfo}));
            }
        }.terr;
        switch (typeinfo) {
            .int => return .{
                .origional = self.origional,
                .place = c.c.vason_get_idx(self.origional.?, self.place, @intCast(item)),
            },
            .comptime_int => return .{
                .origional = self.origional,
                .place = c.c.vason_get_idx(self.origional.?.get(), self.place, item),
            },
            .array => {
                switch (typeinfo.array.child) {
                    u8 => {
                        return .{
                            .origional = self.origional,
                            .place = c.c.vason_get_str(self.origional.?.get(), self.place, c.c.fptr{
                                .ptr = @ptrCast(@constCast(&item)),
                                .width = item.len,
                            }),
                        };
                    },
                    else => typeErr(),
                }
            },
            .pointer => {
                if (typeinfo.pointer.size == .one and
                    @typeInfo(typeinfo.pointer.child) == .array)
                {
                    return self.get(item.*);
                } else typeErr();
            },
            else => typeErr(),
        }
    }
};
pub fn main() !void {
    var GPA = std.heap.DebugAllocator(.{}).init;
    const gpa: Allocator = GPA.allocator();
    const cAllocator = &c.Zallocator{ .zAllocator = gpa };
    defer std.debug.assert(GPA.deinit() == .ok);

    var top = Vason.parse(cAllocator, "{hello : {world : hello}}", .{ .lazy = true });
    defer top.deInit();

    const hello = Vason.fromContainer(&top).get("hello").get("world").asString();
    std.debug.print("{?s}\n", .{hello});
}
