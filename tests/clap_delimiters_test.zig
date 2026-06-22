//! Ported subset of clap's tests/builder/delimiters.rs + the delimited-default
//! cases of default_vals.rs — `value_delimiter` splits one value token into
//! several. (The `require_value_delimiter` greedy-interaction cases are deferred.)
//! https://github.com/clap-rs/clap/blob/master/tests/builder/delimiters.rs

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

// Without a delimiter, a comma-laden value is kept whole.

test "opt_default_no_delim" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "no_delim").arg(Arg.new("option").long("option").action(.set));
    const m = run(a, &cmd, &.{ "--option", "val1,val2,val3" }).matches;
    try testing.expectEqualStrings("val1,val2,val3", m.getOne([]const u8, "option").?);
}

test "opt_eq_no_delim" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "no_delim").arg(Arg.new("option").long("option").action(.set));
    const m = run(a, &cmd, &.{"--option=val1,val2,val3"}).matches;
    try testing.expectEqualStrings("val1,val2,val3", m.getOne([]const u8, "option").?);
}

test "opt_s_eq_no_delim" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "no_delim").arg(Arg.new("option").short('o').action(.set));
    const m = run(a, &cmd, &.{"-o=val1,val2,val3"}).matches;
    try testing.expectEqualStrings("val1,val2,val3", m.getOne([]const u8, "option").?);
}

test "opt_s_default_no_delim" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "no_delim").arg(Arg.new("option").short('o').action(.set));
    const m = run(a, &cmd, &.{ "-o", "val1,val2,val3" }).matches;
    try testing.expectEqualStrings("val1,val2,val3", m.getOne([]const u8, "option").?);
}

test "opt_s_no_space_no_delim" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "no_delim").arg(Arg.new("option").short('o').action(.set));
    const m = run(a, &cmd, &.{ "-o", "val1,val2,val3" }).matches;
    try testing.expectEqualStrings("val1,val2,val3", m.getOne([]const u8, "option").?);
}

test "opt_s_no_space_mult_no_delim" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "no_delim").arg(Arg.new("option").short('o').action(.set).numArgs(range.atLeast(1)));
    const m = run(a, &cmd, &.{ "-o", "val1,val2,val3" }).matches;
    try testing.expectEqualStrings("val1,val2,val3", m.getOne([]const u8, "option").?);
}

// With a delimiter, the value is split.

test "opt_eq_mult_def_delim" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "no_delim")
        .arg(Arg.new("option").long("opt").action(.set).numArgs(range.atLeast(1)).valueDelimiter(','));
    const m = run(a, &cmd, &.{"--opt=val1,val2,val3"}).matches;
    const vals = m.getMany([]const u8, "option").?;
    try testing.expectEqual(@as(usize, 3), vals.len);
    try testing.expectEqualStrings("val1", vals[0]);
    try testing.expectEqualStrings("val2", vals[1]);
    try testing.expectEqualStrings("val3", vals[2]);
}

test "delim_on_separate_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "mvae")
        .arg(Arg.fromUsage("o: -o <opt>", "some opt").valueDelimiter(',').required(true))
        .arg(Arg.fromUsage("[file]", "some file"));
    const m = run(a, &cmd, &.{ "-o", "1,2", "some" }).matches;
    const vals = m.getMany([]const u8, "o").?;
    try testing.expectEqual(@as(usize, 2), vals.len);
    try testing.expectEqualStrings("1", vals[0]);
    try testing.expectEqualStrings("2", vals[1]);
    try testing.expectEqualStrings("some", m.getOne([]const u8, "file").?);
}

test "with_value_delimiter (default split)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "multiple_values")
        .arg(Arg.new("option").long("option").help("multiple options").valueDelimiter(';').defaultValue("first;second"));
    const vals = run(a, &cmd, &.{}).matches.getMany([]const u8, "option").?;
    try testing.expectEqual(@as(usize, 2), vals.len);
    try testing.expectEqualStrings("first", vals[0]);
    try testing.expectEqualStrings("second", vals[1]);
}
