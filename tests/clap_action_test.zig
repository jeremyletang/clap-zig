//! Ported subset of clap's tests/builder/action.rs — the action semantics now
//! supported (Set/Append/SetTrue/SetFalse/Count + indices + args_override_self).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/action.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

test "set" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var c0 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set));
    const m0 = run(a, &c0, &.{}).matches;
    try testing.expect(m0.getOne([]const u8, "mammal") == null);
    try testing.expect(!m0.contains("mammal"));
    try testing.expectEqual(@as(?usize, null), m0.indexOf("mammal"));

    var c1 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set));
    const m1 = run(a, &c1, &.{ "--mammal", "dog" }).matches;
    try testing.expectEqualStrings("dog", m1.getOne([]const u8, "mammal").?);
    try testing.expect(m1.contains("mammal"));
    try testing.expectEqual(@as(?usize, 2), m1.indexOf("mammal"));

    var c2 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set));
    try testing.expectEqual(clap.ErrorKind.argument_conflict, run(a, &c2, &.{ "--mammal", "dog", "--mammal", "cat" }).err.kind);

    var c3 = Command.init(a, "test").argsOverrideSelf(true).arg(Arg.new("mammal").long("mammal").action(.set));
    const m3 = run(a, &c3, &.{ "--mammal", "dog", "--mammal", "cat" }).matches;
    try testing.expectEqualStrings("cat", m3.getOne([]const u8, "mammal").?);
    try testing.expectEqual(@as(?usize, 4), m3.indexOf("mammal"));
}

test "append" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var c0 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.append));
    try testing.expect(!run(a, &c0, &.{}).matches.contains("mammal"));

    var c1 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.append));
    try testing.expectEqualSlices(usize, &.{2}, run(a, &c1, &.{ "--mammal", "dog" }).matches.indicesOf("mammal").?);

    var c2 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.append));
    const m2 = run(a, &c2, &.{ "--mammal", "dog", "--mammal", "cat" }).matches;
    try testing.expectEqualSlices(usize, &.{ 2, 4 }, m2.indicesOf("mammal").?);
    const vals = m2.getMany([]const u8, "mammal").?;
    try testing.expectEqualStrings("dog", vals[0]);
    try testing.expectEqualStrings("cat", vals[1]);
}

test "set_true" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var c0 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set_true));
    const m0 = run(a, &c0, &.{}).matches;
    try testing.expect(!m0.getFlag("mammal"));
    try testing.expect(m0.contains("mammal"));
    try testing.expectEqual(@as(?usize, 1), m0.indexOf("mammal"));

    var c1 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set_true));
    try testing.expect(run(a, &c1, &.{"--mammal"}).matches.getFlag("mammal"));

    var c2 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set_true));
    try testing.expectEqual(clap.ErrorKind.argument_conflict, run(a, &c2, &.{ "--mammal", "--mammal" }).err.kind);

    var c3 = Command.init(a, "test").argsOverrideSelf(true).arg(Arg.new("mammal").long("mammal").action(.set_true));
    const m3 = run(a, &c3, &.{ "--mammal", "--mammal" }).matches;
    try testing.expect(m3.getFlag("mammal"));
    try testing.expectEqual(@as(?usize, 2), m3.indexOf("mammal"));
}

test "set_false" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var c0 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set_false));
    try testing.expect(run(a, &c0, &.{}).matches.getFlag("mammal")); // absent -> true
    var c1 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set_false));
    try testing.expect(!run(a, &c1, &.{"--mammal"}).matches.getFlag("mammal"));
    var c2 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set_false));
    try testing.expectEqual(clap.ErrorKind.argument_conflict, run(a, &c2, &.{ "--mammal", "--mammal" }).err.kind);
}

test "count" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var c0 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.count));
    const m0 = run(a, &c0, &.{}).matches;
    try testing.expectEqual(@as(usize, 0), m0.getCount("mammal"));
    try testing.expect(m0.contains("mammal"));
    try testing.expectEqual(@as(?usize, 1), m0.indexOf("mammal"));

    var c1 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.count));
    try testing.expectEqual(@as(usize, 1), run(a, &c1, &.{"--mammal"}).matches.getCount("mammal"));

    var c2 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.count));
    const m2 = run(a, &c2, &.{ "--mammal", "--mammal" }).matches;
    try testing.expectEqual(@as(usize, 2), m2.getCount("mammal"));
    try testing.expectEqual(@as(?usize, 2), m2.indexOf("mammal"));
}

test "set_true_with_explicit_default_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set_true).defaultValue("false"));
    try testing.expect(run(a, &c1, &.{"--mammal"}).matches.getFlag("mammal"));
    var c0 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set_true).defaultValue("false"));
    try testing.expect(!run(a, &c0, &.{}).matches.getFlag("mammal"));
}

test "set_false_with_explicit_default_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set_false).defaultValue("true"));
    try testing.expect(!run(a, &c1, &.{"--mammal"}).matches.getFlag("mammal"));
    var c0 = Command.init(a, "test").arg(Arg.new("mammal").long("mammal").action(.set_false).defaultValue("true"));
    try testing.expect(run(a, &c0, &.{}).matches.getFlag("mammal"));
}
