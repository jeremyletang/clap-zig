//! Ported subset of clap's tests/builder/{app_settings,opts,positionals}.rs —
//! `allow_hyphen_values` and `allow_negative_numbers`. A defined flag still wins;
//! a hyphen/negative token fills a hyphen-accepting positional or option value.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/app_settings.rs

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

test "leading_hyphen_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "leadhy")
        .arg(Arg.new("some").allowHyphenValues(true))
        .arg(Arg.new("other").short('o').action(.set_true));
    const m = run(a, &cmd, &.{ "-bar", "-o" }).matches;
    try testing.expectEqualStrings("-bar", m.getOne([]const u8, "some").?);
    try testing.expect(m.getFlag("other"));
}

test "leading_hyphen_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "leadhy")
        .arg(Arg.new("some").allowHyphenValues(true))
        .arg(Arg.new("other").short('o').action(.set_true));
    const m = run(a, &cmd, &.{ "--bar", "-o" }).matches;
    try testing.expectEqualStrings("--bar", m.getOne([]const u8, "some").?);
    try testing.expect(m.getFlag("other"));
}

test "leading_hyphen_opt" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "leadhy")
        .arg(Arg.new("some").action(.set).long("opt").allowHyphenValues(true))
        .arg(Arg.new("other").short('o').action(.set_true));
    const m = run(a, &cmd, &.{ "--opt", "--bar", "-o" }).matches;
    try testing.expectEqualStrings("--bar", m.getOne([]const u8, "some").?);
    try testing.expect(m.getFlag("other"));
}

test "leading_hyphen_pass (multi-value option)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "mvae")
        .arg(Arg.fromUsage("o: -o <opt>", "some opt").required(true).numArgs(range.atLeast(1)).allowHyphenValues(true));
    const vals = run(a, &cmd, &.{ "-o", "-2", "3" }).matches.getMany([]const u8, "o").?;
    try testing.expectEqual(@as(usize, 2), vals.len);
    try testing.expectEqualStrings("-2", vals[0]);
    try testing.expectEqualStrings("3", vals[1]);
}

test "allow_hyphen_values_for_positional_arg" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").arg(Arg.new("pos").action(.set).allowHyphenValues(true));
    const m = run(a, &cmd, &.{"-file"}).matches;
    try testing.expectEqualStrings("-file", m.getOne([]const u8, "pos").?);
}

test "issue_946_allow_hyphen_with_defined_flag" {
    // a defined flag still parses as a flag even with a hyphen-accepting positional
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "compiletest")
        .arg(Arg.fromUsage("--exact", "filters match exactly").action(.set_true))
        .arg(Arg.new("filter").action(.set).allowHyphenValues(true).help("filters"));
    const m = run(a, &cmd, &.{"--exact"}).matches;
    try testing.expect(m.getFlag("exact"));
    try testing.expect(m.getOne([]const u8, "filter") == null);
}

test "allow_negative_numbers_success" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "negnum")
        .arg(Arg.new("panum").allowNegativeNumbers(true))
        .arg(Arg.new("onum").short('o').action(.set).allowNegativeNumbers(true));
    const m = run(a, &cmd, &.{ "-20", "-o", "-1.2" }).matches;
    try testing.expectEqualStrings("-20", m.getOne([]const u8, "panum").?);
    try testing.expectEqualStrings("-1.2", m.getOne([]const u8, "onum").?);
}

test "allow_negative_numbers_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "negnum")
        .arg(Arg.new("panum").allowNegativeNumbers(true))
        .arg(Arg.new("onum").short('o').action(.set).allowNegativeNumbers(true));
    const o = run(a, &cmd, &.{ "--foo", "-o", "-1.2" });
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}
