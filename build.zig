const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zgsh_mod = b.addModule("zgsh", .{
        .root_source_file = b.path("src/zgsh.zig"),
        .target = target,
    });

    const zgsh_tests = b.addTest(.{
        .root_module = zgsh_mod,
    });

    const run_zgsh_tests = b.addRunArtifact(zgsh_tests);

    const tests_step = b.step("test", "Run the tests");
    tests_step.dependOn(&run_zgsh_tests.step);

    const exe = b.addExecutable(.{
        .name = "zgsh",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zgsh", .module = zgsh_mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
