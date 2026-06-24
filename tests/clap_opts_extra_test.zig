//! Ported from clap's tests/builder/opts.rs — empty option values (issue 1105),
//! `=`-prefixed values, require_equals with min 0, default_missing_value, and
//! leading-hyphen value collection + next_help_heading keeping defaults.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/opts.rs

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

fn opts1105(a: std.mem.Allocator) Command {
    return Command.init(a, "opts")
        .arg(Arg.new("option").short('o').long("option").action(.set).required(true))
        .arg(Arg.new("flag").long("flag").action(.set_true));
}

test "issue_1105_empty_value_long_equals" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = opts1105(a);
    try testing.expectEqualStrings("", run(a, &cmd, &.{"--option="}).matches.getOne([]const u8, "option").?);
}

test "issue_1105_empty_value_long_explicit" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = opts1105(a);
    try testing.expectEqualStrings("", run(a, &cmd, &.{ "--option", "" }).matches.getOne([]const u8, "option").?);
}

test "issue_1105_empty_value_long_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = opts1105(a);
    try testing.expectEqual(clap.ErrorKind.invalid_value, run(a, &cmd, &.{ "--option", "--flag" }).err.kind);
}

test "issue_1105_empty_value_short_equals" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = opts1105(a);
    try testing.expectEqualStrings("", run(a, &cmd, &.{"-o="}).matches.getOne([]const u8, "option").?);
}

test "issue_1105_empty_value_short_explicit" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = opts1105(a);
    try testing.expectEqualStrings("", run(a, &cmd, &.{ "-o", "" }).matches.getOne([]const u8, "option").?);
}

test "issue_1105_empty_value_short_explicit_no_space" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = opts1105(a);
    try testing.expectEqualStrings("", run(a, &cmd, &.{ "-o", "" }).matches.getOne([]const u8, "option").?);
}

test "issue_1105_empty_value_short_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = opts1105(a);
    try testing.expectEqual(clap.ErrorKind.invalid_value, run(a, &cmd, &.{ "-o", "--flag" }).err.kind);
}

test "long_eq_val_starts_with_eq" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "cmd").arg(Arg.new("opt").long("foo").action(.set).required(true));
    try testing.expectEqualStrings("=value", run(a, &cmd, &.{"--foo==value"}).matches.getOne([]const u8, "opt").?);
}

test "short_eq_val_starts_with_eq" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "cmd").arg(Arg.new("opt").short('f').action(.set).required(true));
    try testing.expectEqualStrings("=value", run(a, &cmd, &.{"-f==value"}).matches.getOne([]const u8, "opt").?);
}

test "require_equals_min_values_zero" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("cfg").long("config").action(.set).requireEquals(true).numArgs(range.atLeast(0)))
        .arg(Arg.new("cmd"));
    const m = run(a, &cmd, &.{ "--config", "cmd" }).matches;
    try testing.expect(m.contains("cfg"));
    try testing.expectEqualStrings("cmd", m.getOne([]const u8, "cmd").?);
}

test "issue_1047_min_zero_vals_default_val" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo")
        .arg(Arg.new("del").short('d').long("del").action(.set).requireEquals(true).numArgs(range.atLeast(0)).defaultMissingValue("default"));
    try testing.expectEqualStrings("default", run(a, &cmd, &.{"-d"}).matches.getOne([]const u8, "del").?);
}

test "leading_hyphen_with_flag_after" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "mvae")
        .arg(Arg.new("o").short('o').action(.set).required(true).numArgs(range.atLeast(1)).allowHyphenValues(true))
        .arg(Arg.new("f").short('f').action(.set_true));
    const m = run(a, &cmd, &.{ "-o", "-2", "-f" }).matches;
    const o = m.getMany([]const u8, "o").?;
    try testing.expectEqual(@as(usize, 2), o.len);
    try testing.expectEqualStrings("-2", o[0]);
    try testing.expectEqualStrings("-f", o[1]);
    try testing.expect(!m.getFlag("f"));
}

test "leading_hyphen_with_flag_before" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "mvae")
        .arg(Arg.new("o").short('o').action(.set).numArgs(range.atLeast(0)).allowHyphenValues(true))
        .arg(Arg.new("f").short('f').action(.set_true));
    const m = run(a, &cmd, &.{ "-f", "-o", "-2" }).matches;
    const o = m.getMany([]const u8, "o").?;
    try testing.expectEqual(@as(usize, 1), o.len);
    try testing.expectEqualStrings("-2", o[0]);
    try testing.expect(m.getFlag("f"));
}

test "leading_hyphen_with_only_pos_follows" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "mvae")
        .arg(Arg.new("o").short('o').action(.set).numArgs(range.atLeast(0)).allowHyphenValues(true))
        .arg(Arg.new("arg"));
    const m = run(a, &cmd, &.{ "-o", "-2", "--", "val" }).matches;
    const o = m.getMany([]const u8, "o").?;
    try testing.expectEqual(@as(usize, 1), o.len);
    try testing.expectEqualStrings("-2", o[0]);
    try testing.expectEqualStrings("val", m.getOne([]const u8, "arg").?);
}

test "issue_2022_get_flags_misuse" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").nextHelpHeading("test")
        .arg(Arg.new("a").long("a").defaultValue("32"));
    try testing.expectEqualStrings("32", run(a, &cmd, &.{}).matches.getOne([]const u8, "a").?);
}

test "issue_2279" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var before = Command.init(a, "cmd")
        .arg(Arg.new("foo").short('f').defaultValue("bar"))
        .nextHelpHeading("This causes default_value to be ignored");
    try testing.expectEqualStrings("bar", run(a, &before, &.{}).matches.getOne([]const u8, "foo").?);

    var after = Command.init(a, "cmd").nextHelpHeading("This causes default_value to be ignored")
        .arg(Arg.new("foo").short('f').defaultValue("bar"));
    try testing.expectEqualStrings("bar", run(a, &after, &.{}).matches.getOne([]const u8, "foo").?);
}
