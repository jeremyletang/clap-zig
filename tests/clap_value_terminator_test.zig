//! Ported from clap's tests/builder/multiple_values.rs — `value_terminator`: a
//! token that ends value collection for a multi-value option/positional. The
//! terminator is consumed (not stored); later tokens fill the next arg. It takes
//! precedence over allow_hyphen_values.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/multiple_values.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const range = clap.ValueRange;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

test "multiple_value_terminator_option (immediate)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "lip")
        .arg(Arg.new("files").short('f').valueTerminator(";").action(.set).numArgs(range.atLeast(0)))
        .arg(Arg.new("other"))
        .arg(Arg.new("stop").short('X').action(.set_true));
    const m = run(a, &cmd, &.{ "-f", ";", "otherval" }).matches;
    try testing.expect(m.contains("files"));
    try testing.expect(m.getMany([]const u8, "files") == null); // present, no values
    try testing.expect(!m.getFlag("stop"));
    try testing.expectEqualStrings("otherval", m.getOne([]const u8, "other").?);
}

test "multiple_value_terminator_option (after values)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "lip")
        .arg(Arg.new("files").short('f').valueTerminator(";").action(.set).numArgs(range.atLeast(0)))
        .arg(Arg.new("other"))
        .arg(Arg.new("stop").short('X').action(.set_true));
    const m = run(a, &cmd, &.{ "-f", "val1", "val2", ";", "otherval" }).matches;
    const files = m.getMany([]const u8, "files").?;
    try testing.expectEqual(@as(usize, 2), files.len);
    try testing.expectEqualStrings("val1", files[0]);
    try testing.expectEqualStrings("val2", files[1]);
    try testing.expectEqualStrings("otherval", m.getOne([]const u8, "other").?);
}

test "multiple_value_terminator_positional (immediate)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "lip")
        .arg(Arg.new("files").valueTerminator(";").action(.set).numArgs(range.atLeast(0)))
        .arg(Arg.new("other"))
        .arg(Arg.new("stop").short('X').action(.set_true));
    const m = run(a, &cmd, &.{ ";", "otherval" }).matches;
    try testing.expect(!m.contains("files"));
    try testing.expectEqualStrings("otherval", m.getOne([]const u8, "other").?);
}

test "multiple_value_terminator_positional (after values)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "lip")
        .arg(Arg.new("files").valueTerminator(";").action(.set).numArgs(range.atLeast(0)))
        .arg(Arg.new("other"))
        .arg(Arg.new("stop").short('X').action(.set_true));
    const m = run(a, &cmd, &.{ "val1", "val2", ";", "otherval" }).matches;
    const files = m.getMany([]const u8, "files").?;
    try testing.expectEqual(@as(usize, 2), files.len);
    try testing.expectEqualStrings("val1", files[0]);
    try testing.expectEqualStrings("otherval", m.getOne([]const u8, "other").?);
}

test "value_terminator_has_higher_precedence_than_allow_hyphen_values" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "do")
        .arg(Arg.new("cmd1").action(.set).numArgs(range.atLeast(1)).allowHyphenValues(true).valueTerminator("--foo"))
        .arg(Arg.new("cmd2").action(.set).numArgs(range.atLeast(1)).allowHyphenValues(true).valueTerminator(";"));
    const m = run(a, &cmd, &.{ "find", "-type", "f", "-name", "special", "--foo", "/home/clap", "foo" }).matches;
    const cmd1 = m.getMany([]const u8, "cmd1").?;
    try testing.expectEqual(@as(usize, 5), cmd1.len);
    try testing.expectEqualStrings("find", cmd1[0]);
    try testing.expectEqualStrings("special", cmd1[4]);
    const cmd2 = m.getMany([]const u8, "cmd2").?;
    try testing.expectEqual(@as(usize, 2), cmd2.len);
    try testing.expectEqualStrings("/home/clap", cmd2[0]);
    try testing.expectEqualStrings("foo", cmd2[1]);
}
