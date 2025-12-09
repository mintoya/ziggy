const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cMod = b.addModule("c_Imports", .{
        .root_source_file = b.path("src/cInclude.zig"),
        .target = target,
        .optimize = optimize,
    });
    cMod.addIncludePath(b.path("wheels"));

    const listMod = b.addModule("clist", .{
        .root_source_file = b.path("src/my-list.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c_Imports", .module = cMod },
        },
    });

    const mapMod = b.addModule("cmap", .{
        .root_source_file = b.path("src/my-map.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "clist", .module = listMod },
            .{ .name = "c_Imports", .module = cMod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c_Imports", .module = cMod },
                .{ .name = "clist", .module = listMod },
                .{ .name = "cmap", .module = mapMod },
            },
        }),
    });

    exe.linkLibC();
    exe.addObjectFile(.{ .cwd_relative = "wheels/build/wheels.o" });
    exe.linkLibC();

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const test_step = b.step("test", "Run tests");

    const main_tests = b.addTest(.{
        .name = "main_tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c_Imports", .module = cMod },
                .{ .name = "clist", .module = listMod },
                .{ .name = "cmap", .module = mapMod },
            },
        }),
    });


    main_tests.root_module.addImport("c_Imports", cMod);
    main_tests.root_module.addImport("clist", listMod);
    main_tests.root_module.addImport("cmap", mapMod);

    main_tests.addObjectFile(.{ .cwd_relative = "wheels/build/wheels.o" });
    main_tests.linkLibC();

    const run_main_tests = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_tests.step);
}
