const std = @import("std");

pub fn bufferedPrint() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush();
}

pub fn add(comptime T: type, a: T, b: T) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(i32, 3, 7) == 11);
}
