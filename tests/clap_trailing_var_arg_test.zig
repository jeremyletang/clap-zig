//! Ported from clap's tests/builder/app_settings.rs — `trailing_var_arg`: once a
//! variadic positional starts collecting, every later token (flags, `--`, hyphen
//! values) is captured as a literal value.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/app_settings.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const range = clap.ValueRange;

fn assertTrailing(input: []const []const u8, expected: []const []const u8, expected_flag: bool) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.new("prog").short('p').long("prog").action(.set_true))
        .arg(Arg.new("opt").action(.set).numArgs(range.atLeast(1)).trailingVarArg(true).allowHyphenValues(true));
    cmd.buildTree();
    const m = clap.getMatches(a, &cmd, input).matches;
    const vals = m.getMany([]const u8, "opt").?;
    try testing.expectEqual(expected.len, vals.len);
    for (expected, 0..) |e, i| try testing.expectEqualStrings(e, vals[i]);
    try testing.expectEqual(expected_flag, m.getFlag("prog"));
}

test "trailing_var_arg_with_hyphen_values_escape_first" {
    try assertTrailing(&.{ "--", "foo", "bar" }, &.{ "foo", "bar" }, false);
}

test "trailing_var_arg_with_hyphen_values_escape_middle" {
    try assertTrailing(&.{ "foo", "--", "bar" }, &.{ "foo", "--", "bar" }, false);
}

test "trailing_var_arg_with_hyphen_values_short_first" {
    try assertTrailing(&.{ "-p", "foo", "bar" }, &.{ "foo", "bar" }, true);
}

test "trailing_var_arg_with_hyphen_values_short_middle" {
    try assertTrailing(&.{ "foo", "-p", "bar" }, &.{ "foo", "-p", "bar" }, false);
}

test "trailing_var_arg_with_hyphen_values_long_first" {
    try assertTrailing(&.{ "--prog", "foo", "bar" }, &.{ "foo", "bar" }, true);
}

test "trailing_var_arg_with_hyphen_values_long_middle" {
    try assertTrailing(&.{ "foo", "--prog", "bar" }, &.{ "foo", "--prog", "bar" }, false);
}
