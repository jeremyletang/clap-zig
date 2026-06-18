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
    const test_step = b.step("test", "Run unit and integration tests");

    // unit tests (inline in src)
    const tests = b.addTest(.{
        .root_module = clap,
        .filters = if (test_filter) |f| &.{f} else &.{},
    });
    test_step.dependOn(&b.addRunArtifact(tests).step);

    // shared example glue (main boilerplate), available to every example module
    const harness = b.createModule(.{
        .root_source_file = b.path("examples/harness.zig"),
        .target = target,
        .optimize = optimize,
    });

    // examples are exposed as modules so the exes and the integration tests share them
    const git_mod = addExample(b, clap, harness, "git", "git", "examples/git.zig");
    const escaped_mod = addExample(b, clap, harness, "escaped-positional", "escaped_positional", "examples/escaped_positional.zig");
    const flag_bool_mod = addExample(b, clap, harness, "03_01_flag_bool", "flag_bool", "examples/03_01_flag_bool.zig");
    const flag_count_mod = addExample(b, clap, harness, "03_01_flag_count", "flag_count", "examples/03_01_flag_count.zig");
    const option_mod = addExample(b, clap, harness, "03_02_option", "option", "examples/03_02_option.zig");
    const default_values_mod = addExample(b, clap, harness, "03_05_default_values", "default_values", "examples/03_05_default_values.zig");
    const required_mod = addExample(b, clap, harness, "03_06_required", "required", "examples/03_06_required.zig");
    const possible_mod = addExample(b, clap, harness, "04_01_possible", "possible", "examples/04_01_possible.zig");
    const parse_mod = addExample(b, clap, harness, "04_02_parse", "parse", "examples/04_02_parse.zig");
    const validate_mod = addExample(b, clap, harness, "04_02_validate", "validate", "examples/04_02_validate.zig");
    const relations_mod = addExample(b, clap, harness, "04_03_relations", "relations", "examples/04_03_relations.zig");

    // integration tests (tests/) consume the public `clap` module + the example modules
    const tests_mod = b.createModule(.{
        .root_source_file = b.path("tests/all.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests_mod.addImport("clap", clap);
    tests_mod.addImport("git", git_mod);
    tests_mod.addImport("escaped_positional", escaped_mod);
    tests_mod.addImport("flag_bool", flag_bool_mod);
    tests_mod.addImport("flag_count", flag_count_mod);
    tests_mod.addImport("option", option_mod);
    tests_mod.addImport("default_values", default_values_mod);
    tests_mod.addImport("required", required_mod);
    tests_mod.addImport("possible", possible_mod);
    tests_mod.addImport("parse", parse_mod);
    tests_mod.addImport("validate", validate_mod);
    tests_mod.addImport("relations", relations_mod);
    const integration_tests = b.addTest(.{
        .root_module = tests_mod,
        .filters = if (test_filter) |f| &.{f} else &.{},
    });
    test_step.dependOn(&b.addRunArtifact(integration_tests).step);
}

/// Create an example module, build+install it as an executable, and add a
/// `run-<exe>` step. Returns the module so tests can import it too.
fn addExample(b: *std.Build, clap: *std.Build.Module, harness: *std.Build.Module, exe_name: []const u8, run_suffix: []const u8, path: []const u8) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path(path),
        .target = clap.resolved_target,
        .optimize = clap.optimize,
    });
    mod.addImport("clap", clap);
    mod.addImport("harness", harness);

    const exe = b.addExecutable(.{ .name = exe_name, .root_module = mod });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    if (b.args) |args| run.addArgs(args);
    const step_name = b.fmt("run-{s}", .{run_suffix});
    b.step(step_name, b.fmt("Run the {s} example", .{exe_name})).dependOn(&run.step);

    return mod;
}
