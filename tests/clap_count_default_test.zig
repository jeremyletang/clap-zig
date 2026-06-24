//! Ported from clap's tests/builder/action.rs — `Count` action combined with
//! `default_value` / `default_value_if`. The count is the arg's value, so an
//! explicit or conditional default seeds it when the flag is absent.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/action.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.ArgMatches {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv).matches.*;
}

fn explicitDefault(a: std.mem.Allocator) Command {
    return Command.init(a, "test")
        .arg(Arg.new("mammal").long("mammal").action(.count).defaultValue("10"));
}

fn ifPresent(a: std.mem.Allocator) Command {
    return Command.init(a, "test")
        .arg(Arg.new("mammal").long("mammal").action(.count)
            .defaultValueIfs(&.{.{ .arg = "dog", .value = &.{"10"} }}))
        .arg(Arg.new("dog").long("dog").action(.count));
}

fn ifValue(a: std.mem.Allocator) Command {
    return Command.init(a, "test")
        .arg(Arg.new("mammal").long("mammal").action(.count)
            .defaultValueIfs(&.{.{ .arg = "dog", .equals = "2", .value = &.{"10"} }}))
        .arg(Arg.new("dog").long("dog").action(.count));
}

test "count_with_explicit_default_value (present)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = explicitDefault(a);
    const m = run(a, &cmd, &.{"--mammal"});
    try testing.expectEqual(@as(usize, 1), m.getCount("mammal"));
    try testing.expectEqual(@as(?u8, 1), m.getOne(u8, "mammal"));
}

test "count_with_explicit_default_value (absent)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = explicitDefault(a);
    const m = run(a, &cmd, &.{});
    try testing.expectEqual(@as(usize, 10), m.getCount("mammal"));
    try testing.expectEqual(@as(?u8, 10), m.getOne(u8, "mammal"));
}

test "count_with_default_value_if_present (none)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = ifPresent(a);
    const m = run(a, &cmd, &.{});
    try testing.expectEqual(@as(usize, 0), m.getCount("dog"));
    try testing.expectEqual(@as(usize, 0), m.getCount("mammal"));
}

test "count_with_default_value_if_present (dog)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = ifPresent(a);
    const m = run(a, &cmd, &.{"--dog"});
    try testing.expectEqual(@as(usize, 1), m.getCount("dog"));
    try testing.expectEqual(@as(usize, 10), m.getCount("mammal"));
}

test "count_with_default_value_if_present (mammal)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = ifPresent(a);
    const m = run(a, &cmd, &.{"--mammal"});
    try testing.expectEqual(@as(usize, 0), m.getCount("dog"));
    try testing.expectEqual(@as(usize, 1), m.getCount("mammal"));
}

test "count_with_default_value_if_value (none)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = ifValue(a);
    const m = run(a, &cmd, &.{});
    try testing.expectEqual(@as(usize, 0), m.getCount("mammal"));
}

test "count_with_default_value_if_value (dog once)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = ifValue(a);
    const m = run(a, &cmd, &.{"--dog"});
    try testing.expectEqual(@as(usize, 1), m.getCount("dog"));
    try testing.expectEqual(@as(usize, 0), m.getCount("mammal"));
}

test "count_with_default_value_if_value (dog twice)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = ifValue(a);
    const m = run(a, &cmd, &.{ "--dog", "--dog" });
    try testing.expectEqual(@as(usize, 2), m.getCount("dog"));
    try testing.expectEqual(@as(usize, 10), m.getCount("mammal"));
}

test "count_with_default_value_if_value (mammal)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = ifValue(a);
    const m = run(a, &cmd, &.{"--mammal"});
    try testing.expectEqual(@as(usize, 0), m.getCount("dog"));
    try testing.expectEqual(@as(usize, 1), m.getCount("mammal"));
}
