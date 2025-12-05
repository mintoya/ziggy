const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cModule = b.addModule("c_Imports", .{
        .root_source_file = b.path("src/cInclude.zig"),
        .target = target,
    });
    const listMod = b.addModule("clist", .{
        .root_source_file = b.path("src/my-list.zig"),
        .target = target,
    });
    const mapMod = b.addModule("cmap", .{
        .root_source_file = b.path("src/my-map.zig"),
        .target = target,
    });
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c_Imports", .module = cModule },
                .{ .name = "clist", .module = listMod },
                .{ .name = "cmap", .module = mapMod },
            },
        }),
    });
    exe.addObjectFile(.{ .cwd_relative = "wheels/build/wheels.o" });
    exe.linkLibC();
    exe.addIncludePath(b.path("wheels"));
    exe.addIncludePath(b.path("*"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const list_test = b.addTest(.{
        .name = "list tests",
        .root_module = listMod,
    });
    const map_test = b.addTest(.{
        .name = "map tests",
        .root_module = mapMod,
    });

    const run_list_tests = b.addRunArtifact(list_test);
    const run_map_tests = b.addRunArtifact(map_test);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_cmd.step);
    test_step.dependOn(&run_list_tests.step);
    test_step.dependOn(&run_map_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
