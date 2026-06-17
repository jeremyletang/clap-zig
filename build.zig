const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const clap = b.addModule("clap", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_filter = b.option([]const u8, "test-filter", "Only run tests matching this filter");
    const tests = b.addTest(.{
        .root_module = clap,
        .filters = if (test_filter) |f| &.{f} else &.{},
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const git_mod = b.createModule(.{
        .root_source_file = b.path("examples/git.zig"),
        .target = target,
        .optimize = optimize,
    });
    git_mod.addImport("clap", clap);
    const git_exe = b.addExecutable(.{
        .name = "git",
        .root_module = git_mod,
    });
    b.installArtifact(git_exe);

    const run_git = b.addRunArtifact(git_exe);
    run_git.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_git.addArgs(args);
    const run_git_step = b.step("run-git", "Run the git example");
    run_git_step.dependOn(&run_git.step);
}
