//! Ported subset of clap's tests/builder/indices.rs (cases not needing
//! multi-value options or value delimiters).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/indices.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn flagsCmd(a: std.mem.Allocator) Command {
    return Command.init(a, "ind")
        .argsOverrideSelf(true)
        .arg(Arg.new("exclude").short('e').action(.set_true))
        .arg(Arg.new("include").short('i').action(.set_true));
}

test "index_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = flagsCmd(a);
    const m = run(a, &cmd, &.{ "-e", "-i" }).matches;
    try testing.expectEqual(@as(?usize, 1), m.indexOf("exclude"));
    try testing.expectEqual(@as(?usize, 2), m.indexOf("include"));
}

test "index_flags (last occurrence wins under override)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = flagsCmd(a);
    const m = run(a, &cmd, &.{ "-e", "-i", "-e", "-e", "-i" }).matches;
    try testing.expectEqual(@as(?usize, 4), m.indexOf("exclude"));
    try testing.expectEqual(@as(?usize, 5), m.indexOf("include"));
}

test "indices_mult_flags" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = flagsCmd(a);
    const m = run(a, &cmd, &.{ "-e", "-i", "-e", "-e", "-i" }).matches;
    try testing.expectEqualSlices(usize, &.{4}, m.indicesOf("exclude").?);
    try testing.expectEqualSlices(usize, &.{5}, m.indicesOf("include").?);
}

test "indices_mult_flags_combined (-eieei)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = flagsCmd(a);
    const m = run(a, &cmd, &.{"-eieei"}).matches;
    try testing.expectEqualSlices(usize, &.{4}, m.indicesOf("exclude").?);
    try testing.expectEqualSlices(usize, &.{5}, m.indicesOf("include").?);
}

test "indices_mult_flags_opt_combined (-eieeio val)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = flagsCmd(a).arg(Arg.new("option").short('o').action(.set));
    const m = run(a, &cmd, &.{ "-eieeio", "val" }).matches;
    try testing.expectEqualSlices(usize, &.{4}, m.indicesOf("exclude").?);
    try testing.expectEqualSlices(usize, &.{5}, m.indicesOf("include").?);
    try testing.expectEqualSlices(usize, &.{7}, m.indicesOf("option").?);
}

test "indices_mult_flags_opt_combined_eq (-eieeio=val)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = flagsCmd(a).arg(Arg.new("option").short('o').action(.set));
    const m = run(a, &cmd, &.{"-eieeio=val"}).matches;
    try testing.expectEqualSlices(usize, &.{4}, m.indicesOf("exclude").?);
    try testing.expectEqualSlices(usize, &.{5}, m.indicesOf("include").?);
    try testing.expectEqualSlices(usize, &.{7}, m.indicesOf("option").?);
}

test "indices_mult_opt_mult_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myapp")
        .argsOverrideSelf(true)
        .arg(Arg.new("option").short('o').action(.append))
        .arg(Arg.new("flag").short('f').action(.set_true));
    const m = run(a, &cmd, &.{ "-o", "val1", "-f", "-o", "val2", "-f" }).matches;
    try testing.expectEqualSlices(usize, &.{ 2, 5 }, m.indicesOf("option").?);
    try testing.expectEqualSlices(usize, &.{6}, m.indicesOf("flag").?);
}
