//! Ported subset of clap's tests/builder/require.rs — `required_if_eq` /
//! `_eq_any` / `_eq_all` (an arg becomes required when other args hold values).
//! The `ignore_case` variants are deferred (need case-insensitive matching).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/require.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const RequireIf = clap.RequireIf;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

const eq_extra_val = [_]RequireIf{.{ .target = "extra", .value = "val" }};
const eq_all = [_]RequireIf{ .{ .target = "extra", .value = "val" }, .{ .target = "option", .value = "spec" } };
const eq_any2 = [_]RequireIf{ .{ .target = "extra", .value = "val2" }, .{ .target = "option", .value = "spec2" } };

fn riApp(a: std.mem.Allocator) Command {
    return Command.init(a, "ri")
        .arg(Arg.new("cfg").requiredIfEqAny(&eq_extra_val).action(.set).long("config"))
        .arg(Arg.new("extra").action(.set).long("extra"));
}

test "required_if_val_present_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = riApp(a);
    try testing.expect(run(a, &cmd, &.{ "--extra", "val", "--config", "my.cfg" }) == .matches);
}

test "required_if_val_present_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = riApp(a);
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{ "--extra", "val" }).err.kind);
}

test "required_if_wrong_val" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = riApp(a);
    try testing.expect(run(a, &cmd, &.{ "--extra", "other" }) == .matches);
}

test "required_if_all_values_present_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ri")
        .arg(Arg.new("cfg").requiredIfEqAll(&eq_all).action(.set).long("config"))
        .arg(Arg.new("extra").action(.set).long("extra"))
        .arg(Arg.new("option").action(.set).long("option"));
    try testing.expect(run(a, &cmd, &.{ "--extra", "val", "--option", "spec", "--config", "my.cfg" }) == .matches);
}

test "required_if_some_values_present_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ri")
        .arg(Arg.new("cfg").requiredIfEqAll(&eq_all).action(.set).long("config"))
        .arg(Arg.new("extra").action(.set).long("extra"))
        .arg(Arg.new("option").action(.set).long("option"));
    try testing.expect(run(a, &cmd, &.{ "--extra", "val" }) == .matches);
}

test "required_if_all_values_present_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ri")
        .arg(Arg.new("cfg").requiredIfEqAll(&eq_all).action(.set).long("config"))
        .arg(Arg.new("extra").action(.set).long("extra"))
        .arg(Arg.new("option").action(.set).long("option"));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{ "--extra", "val", "--option", "spec" }).err.kind);
}

test "required_if_any_all_values_present_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ri")
        .arg(Arg.new("cfg").requiredIfEqAll(&eq_all).requiredIfEqAny(&eq_any2).action(.set).long("config"))
        .arg(Arg.new("extra").action(.set).long("extra"))
        .arg(Arg.new("option").action(.set).long("option"));
    try testing.expect(run(a, &cmd, &.{ "--extra", "val", "--option", "spec", "--config", "my.cfg" }) == .matches);
}

test "required_if_any_all_values_present_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ri")
        .arg(Arg.new("cfg").requiredIfEqAll(&eq_all).requiredIfEqAny(&eq_any2).action(.set).long("config"))
        .arg(Arg.new("extra").action(.set).long("extra"))
        .arg(Arg.new("option").action(.set).long("option"));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{ "--extra", "val", "--option", "spec" }).err.kind);
}

test "required_ifs_val_present_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ri")
        .arg(Arg.new("cfg").requiredIfEqAny(&.{ .{ .target = "extra", .value = "val" }, .{ .target = "option", .value = "spec" } }).action(.set).long("config"))
        .arg(Arg.new("option").action(.set).long("option"))
        .arg(Arg.new("extra").action(.set).long("extra"));
    try testing.expect(run(a, &cmd, &.{ "--option", "spec", "--config", "my.cfg" }) == .matches);
}

test "required_ifs_val_present_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ri")
        .arg(Arg.new("cfg").requiredIfEqAny(&.{ .{ .target = "extra", .value = "val" }, .{ .target = "option", .value = "spec" } }).action(.set).long("config"))
        .arg(Arg.new("extra").action(.set).long("extra"))
        .arg(Arg.new("option").action(.set).long("option"));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{ "--option", "spec" }).err.kind);
}

test "required_ifs_wrong_val" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ri")
        .arg(Arg.new("cfg").requiredIfEqAny(&.{ .{ .target = "extra", .value = "val" }, .{ .target = "option", .value = "spec" } }).action(.set).long("config"))
        .arg(Arg.new("extra").action(.set).long("extra"))
        .arg(Arg.new("option").action(.set).long("option"));
    try testing.expect(run(a, &cmd, &.{ "--option", "other" }) == .matches);
}

test "required_ifs_wrong_val_mult_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ri")
        .arg(Arg.new("cfg").requiredIfEqAny(&.{ .{ .target = "extra", .value = "val" }, .{ .target = "option", .value = "spec" } }).action(.set).long("config"))
        .arg(Arg.new("extra").action(.set).long("extra"))
        .arg(Arg.new("option").action(.set).long("option"));
    try testing.expect(run(a, &cmd, &.{ "--extra", "other", "--option", "spec" }) == .err);
}

test "required_if_val_present_fail_error_output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .version("1.0")
        .author("F0x06")
        .about("Arg test")
        .arg(Arg.new("target").action(.set).required(true).valueParser(&.{ "file", "stdout" }).long("target"))
        .arg(Arg.new("input").action(.set).required(true).long("input"))
        .arg(Arg.new("output").action(.set).requiredIfEqAny(&.{.{ .target = "target", .value = "file" }}).long("output"));
    const o = run(a, &cmd, &.{ "--input", "somepath", "--target", "file" });
    try testing.expectEqualStrings(
        "error: the following required arguments were not provided:\n" ++
            "  --output <output>\n\n" ++
            "Usage: test --target <target> --input <input> --output <output>\n\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, o.err),
    );
}
