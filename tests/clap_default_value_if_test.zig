//! Ported subset of clap's tests/builder/default_vals.rs — `default_value_if(s)`
//! / `default_values_if(s)` (conditional defaults; first match wins, a null
//! value suppresses the regular default, user-supplied values always win).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/default_vals.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const DefaultValueIf = clap.DefaultValueIf;
const range = clap.ValueRange;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn one(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8, id: []const u8) ?[]const u8 {
    return run(a, cmd, argv).matches.getOne([]const u8, id);
}

test "default_if_arg_present_no_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg").required(true))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValueIfs(&.{.{ .arg = "opt", .value = &.{"default"} }}));
    try testing.expectEqualStrings("default", one(a, &cmd, &.{ "--opt", "some" }, "arg").?);
}

test "default_if_arg_present_no_default_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValueIfs(&.{.{ .arg = "opt", .value = &.{"default"} }}));
    try testing.expectEqualStrings("other", one(a, &cmd, &.{ "--opt", "some", "other" }, "arg").?);
}

test "default_if_arg_present_no_arg_with_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValue("first").defaultValueIfs(&.{.{ .arg = "opt", .value = &.{"default"} }}));
    try testing.expectEqualStrings("first", one(a, &cmd, &.{}, "arg").?);
}

test "default_if_arg_present_with_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValue("first").defaultValueIfs(&.{.{ .arg = "opt", .value = &.{"default"} }}));
    try testing.expectEqualStrings("default", one(a, &cmd, &.{ "--opt", "some" }, "arg").?);
}

test "default_if_arg_present_with_default_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValue("first").defaultValueIfs(&.{.{ .arg = "opt", .value = &.{"default"} }}));
    try testing.expectEqualStrings("other", one(a, &cmd, &.{ "--opt", "some", "other" }, "arg").?);
}

test "default_if_arg_present_no_arg_with_default_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValue("first").defaultValueIfs(&.{.{ .arg = "opt", .value = &.{"default"} }}));
    try testing.expectEqualStrings("other", one(a, &cmd, &.{"other"}, "arg").?);
}

test "default_if_arg_present_with_value_no_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValueIfs(&.{.{ .arg = "opt", .equals = "value", .value = &.{"default"} }}));
    try testing.expectEqualStrings("default", one(a, &cmd, &.{ "--opt", "value" }, "arg").?);
}

test "default_values_if_arg_present_with_value_no_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.new("args").long("args").numArgs(range.between(2, 2)).defaultValueIfs(&.{.{ .arg = "opt", .equals = "value", .value = &.{ "df1", "df2" } }}));
    const m = run(a, &cmd, &.{ "--opt", "value" }).matches;
    const vals = m.getMany([]const u8, "args").?;
    try testing.expectEqual(@as(usize, 2), vals.len);
    try testing.expectEqualStrings("df1", vals[0]);
    try testing.expectEqualStrings("df2", vals[1]);
}

test "default_if_arg_present_with_value_no_default_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValueIfs(&.{.{ .arg = "opt", .equals = "value", .value = &.{"default"} }}));
    const m = run(a, &cmd, &.{ "--opt", "other" }).matches;
    try testing.expect(!m.contains("arg"));
    try testing.expect(m.getOne([]const u8, "arg") == null);
}

test "no_default_if_arg_present_with_value_no_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValueIfs(&.{.{ .arg = "opt", .equals = "value", .value = null }}));
    try testing.expect(!run(a, &cmd, &.{ "--opt", "value" }).matches.contains("arg"));
}

test "no_default_if_arg_present_with_value_with_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValue("default").defaultValueIfs(&.{.{ .arg = "opt", .equals = "value", .value = null }}));
    const m = run(a, &cmd, &.{ "--opt", "value" }).matches;
    try testing.expect(!m.contains("arg"));
    try testing.expect(m.getOne([]const u8, "arg") == null);
}

test "no_default_if_arg_present_with_value_with_default_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValue("default").defaultValueIfs(&.{.{ .arg = "opt", .equals = "value", .value = null }}));
    try testing.expectEqualStrings("other", one(a, &cmd, &.{ "--opt", "value", "other" }, "arg").?);
}

test "no_default_if_arg_present_no_arg_with_value_with_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValue("default").defaultValueIfs(&.{.{ .arg = "opt", .equals = "value", .value = null }}));
    try testing.expectEqualStrings("default", one(a, &cmd, &.{ "--opt", "other" }, "arg").?);
}

test "default_ifs_arg_present" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("--flag", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValue("first").defaultValueIfs(&.{
        .{ .arg = "opt", .equals = "some", .value = &.{"default"} },
        .{ .arg = "flag", .value = &.{"flg"} },
    }));
    try testing.expectEqualStrings("flg", one(a, &cmd, &.{"--flag"}, "arg").?);
}

test "no_default_ifs_arg_present" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("--flag", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValue("first").defaultValueIfs(&.{
        .{ .arg = "opt", .equals = "some", .value = &.{"default"} },
        .{ .arg = "flag", .value = null },
    }));
    try testing.expect(!run(a, &cmd, &.{"--flag"}).matches.contains("arg"));
}

test "default_ifs_arg_present_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("--flag", "some arg"))
        .arg(Arg.fromUsage("[arg]", "some arg").defaultValue("first").defaultValueIfs(&.{
        .{ .arg = "opt", .equals = "some", .value = &.{"default"} },
        .{ .arg = "flag", .value = &.{"flg"} },
    }));
    try testing.expectEqualStrings("value", one(a, &cmd, &.{ "--flag", "value" }, "arg").?);
}

test "default_values_ifs_arg_present" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("--opt <FILE>", "some arg"))
        .arg(Arg.fromUsage("--flag", "some arg"))
        .arg(Arg.new("args").long("args").numArgs(range.between(2, 2)).defaultValueIfs(&.{
        .{ .arg = "opt", .equals = "some", .value = &.{ "d1", "d2" } },
        .{ .arg = "flag", .value = &.{ "d3", "d4" } },
    }));
    const vals = run(a, &cmd, &.{"--flag"}).matches.getMany([]const u8, "args").?;
    try testing.expectEqual(@as(usize, 2), vals.len);
    try testing.expectEqualStrings("d3", vals[0]);
    try testing.expectEqualStrings("d4", vals[1]);
}
