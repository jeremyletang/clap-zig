//! Ported from clap's tests/builder/{multiple_values,positionals}.rs — `num_args`
//! enforcement on positionals. A fixed count over/under-fills to
//! WrongNumberOfValues; a range under-fills to TooFewValues and over-fills to
//! TooManyValues; an unbounded range accepts any count >= min.
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

fn errText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    return clap.renderError(a, run(a, cmd, argv).err);
}

fn pos(a: std.mem.Allocator, r: range) Command {
    return Command.init(a, "multiple_values").arg(Arg.new("pos").numArgs(r));
}

test "positional_exact_exact" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pos(a, range.between(3, 3));
    const vals = run(a, &cmd, &.{ "val1", "val2", "val3" }).matches.getMany([]const u8, "pos").?;
    try testing.expectEqual(@as(usize, 3), vals.len);
    try testing.expectEqualStrings("val1", vals[0]);
    try testing.expectEqualStrings("val3", vals[2]);
}

test "positional_exact_less" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pos(a, range.between(3, 3));
    try testing.expectEqualStrings(
        "error: 3 values required for '[pos] [pos] [pos]' but 2 were provided\n\n" ++
            "Usage: multiple_values [pos] [pos] [pos]\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{ "val1", "val2" }),
    );
}

test "positional_exact_more" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pos(a, range.between(3, 3));
    try testing.expectEqualStrings(
        "error: 3 values required for '[pos] [pos] [pos]' but 4 were provided\n\n" ++
            "Usage: multiple_values [pos] [pos] [pos]\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{ "val1", "val2", "val3", "val4" }),
    );
}

test "positional_min_exact" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pos(a, range.atLeast(3));
    const vals = run(a, &cmd, &.{ "val1", "val2", "val3" }).matches.getMany([]const u8, "pos").?;
    try testing.expectEqual(@as(usize, 3), vals.len);
}

test "positional_min_less" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pos(a, range.atLeast(3));
    try testing.expectEqualStrings(
        "error: 3 values required by '[pos] [pos] [pos]...'; only 2 were provided\n\n" ++
            "Usage: multiple_values [pos] [pos] [pos]...\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{ "val1", "val2" }),
    );
}

test "positional_min_more" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pos(a, range.atLeast(3));
    const vals = run(a, &cmd, &.{ "val1", "val2", "val3", "val4" }).matches.getMany([]const u8, "pos").?;
    try testing.expectEqual(@as(usize, 4), vals.len);
}

test "positional_max_exact" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pos(a, range.between(1, 3));
    const vals = run(a, &cmd, &.{ "val1", "val2", "val3" }).matches.getMany([]const u8, "pos").?;
    try testing.expectEqual(@as(usize, 3), vals.len);
}

test "positional_max_less" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pos(a, range.between(1, 3));
    const vals = run(a, &cmd, &.{ "val1", "val2" }).matches.getMany([]const u8, "pos").?;
    try testing.expectEqual(@as(usize, 2), vals.len);
}

test "positional_max_more" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pos(a, range.between(1, 3));
    try testing.expectEqualStrings(
        "error: unexpected value 'val4' for '[pos]...' found; no more were expected\n\n" ++
            "Usage: multiple_values [pos]...\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{ "val1", "val2", "val3", "val4" }),
    );
}
