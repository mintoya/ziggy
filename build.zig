const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cMod = b.addModule("c_Imports", .{
        .root_source_file = b.path("src/cInclude.zig"),
        .target = target,
        .optimize = optimize,
    });
    // cMod.addIncludePath(b.path("wheels"));

    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "c_Imports", .module = cMod },
            },
        }),
    });

    exe.root_module.addCSourceFile(.{
        .file = .{ .cwd_relative = "wheels/examples/includeAll.c" },
        .flags = &.{ "-std=c2y", "-fblocks","-lBlocksRuntime" },
        .language = .c,
    });
    exe.root_module.addIncludePath(b.path("wheels"));
    exe.root_module.linkSystemLibrary("BlocksRuntime", .{});

    b.installArtifact(exe);

    const check = b.step("check", "lsp check");
    check.dependOn(&exe.step);

    const run_step = b.step("run", "run");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args|
        run_cmd.addArgs(args);
}
