//! Ported subset of clap's tests/builder/multiple_values.rs — multi-value option
//! and multi-value positional cases (no value_delimiter / allow_hyphen_values).
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

fn expectMany(m: *const clap.ArgMatches, id: []const u8, expected: []const []const u8) !void {
    const vals = m.getMany([]const u8, id).?;
    try testing.expectEqual(expected.len, vals.len);
    for (expected, vals) |e, v| try testing.expectEqualStrings(e, v);
}

test "option_long / option_short / option_mixed (num_args(1..) append)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "mv").arg(Arg.new("option").long("option").action(.append).numArgs(range.atLeast(1)));
    try expectMany(run(a, &c1, &.{ "--option", "val1", "--option", "val2", "--option", "val3" }).matches, "option", &.{ "val1", "val2", "val3" });

    var c2 = Command.init(a, "mv").arg(Arg.new("option").short('o').action(.append).numArgs(range.atLeast(1)));
    try expectMany(run(a, &c2, &.{ "-o", "val1", "-o", "val2", "-o", "val3" }).matches, "option", &.{ "val1", "val2", "val3" });

    var c3 = Command.init(a, "mv").arg(Arg.new("option").short('o').long("option").action(.append).numArgs(range.atLeast(1)));
    try expectMany(run(a, &c3, &.{ "-o", "val1", "--option", "val2", "--option", "val3", "-o", "val4" }).matches, "option", &.{ "val1", "val2", "val3", "val4" });
}

test "option_exact (num_args(3))" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "mv").arg(Arg.new("option").short('o').action(.append).numArgs(range.between(3, 3)));
    try expectMany(run(a, &c1, &.{ "-o", "val1", "val2", "val3", "-o", "val4", "val5", "val6" }).matches, "option", &.{ "val1", "val2", "val3", "val4", "val5", "val6" });
    var c2 = Command.init(a, "mv").arg(Arg.new("option").short('o').numArgs(range.between(3, 3)));
    try expectMany(run(a, &c2, &.{ "-o", "val1", "val2", "val3" }).matches, "option", &.{ "val1", "val2", "val3" });
}

test "option_min (num_args(3..)) greedy" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "mv").arg(Arg.new("option").short('o').action(.set).numArgs(range.atLeast(3)));
    try expectMany(run(a, &c1, &.{ "-o", "val1", "val2", "val3" }).matches, "option", &.{ "val1", "val2", "val3" });

    var c2 = Command.init(a, "mv")
        .arg(Arg.new("arg").required(true))
        .arg(Arg.new("option").short('o').action(.set).numArgs(range.atLeast(3)));
    const m = run(a, &c2, &.{ "pos", "-o", "val1", "val2", "val3", "val4" }).matches;
    try expectMany(m, "option", &.{ "val1", "val2", "val3", "val4" });
    try testing.expectEqualStrings("pos", m.getOne([]const u8, "arg").?);
}

test "option_max (num_args(1..=3))" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "mv").arg(Arg.new("option").short('o').action(.set).numArgs(range.between(1, 3)));
    try expectMany(run(a, &c1, &.{ "-o", "val1", "val2", "val3" }).matches, "option", &.{ "val1", "val2", "val3" });
    var c2 = Command.init(a, "mv").arg(Arg.new("option").short('o').action(.set).numArgs(range.between(1, 3)));
    try expectMany(run(a, &c2, &.{ "-o", "val1", "val2" }).matches, "option", &.{ "val1", "val2" });
    // `-o=` -> single empty value
    var c3 = Command.init(a, "mv").arg(Arg.new("option").short('o').action(.set).numArgs(range.between(1, 3)));
    try expectMany(run(a, &c3, &.{"-o="}).matches, "option", &.{""});
}

test "option_max_more -> unknown excess value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "multiple_values").arg(Arg.new("option").short('o').action(.set).numArgs(range.between(1, 3)));
    const o = run(a, &cmd, &.{ "-o", "val1", "val2", "val3", "val4" });
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}

test "option errors: exact/min/zero" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // exact: too few -> WrongNumberOfValues
    var c1 = Command.init(a, "multiple_values").arg(Arg.new("option").short('o').action(.append).numArgs(range.between(3, 3)));
    try testing.expectEqualStrings(
        "error: 3 values required for '-o <option> <option> <option>' but 1 was provided\n" ++
            "\nUsage: multiple_values [OPTIONS]\n\nFor more information, try '--help'.\n",
        clap.renderError(a, run(a, &c1, &.{ "-o", "val1", "-o", "val2" }).err),
    );

    // min range: too few -> TooFewValues
    var c2 = Command.init(a, "multiple_values").arg(Arg.new("option").short('o').action(.set).numArgs(range.atLeast(3)));
    try testing.expectEqualStrings(
        "error: 3 values required by '-o <option> <option> <option>...'; only 2 were provided\n" ++
            "\nUsage: multiple_values [OPTIONS]\n\nFor more information, try '--help'.\n",
        clap.renderError(a, run(a, &c2, &.{ "-o", "val1", "val2" }).err),
    );

    // none supplied -> InvalidValue "a value is required"
    var c3 = Command.init(a, "multiple_values").arg(Arg.new("option").short('o').action(.set).numArgs(range.between(1, 3)));
    try testing.expectEqualStrings(
        "error: a value is required for '-o <option>...' but none was supplied\n" ++
            "\nFor more information, try '--help'.\n",
        clap.renderError(a, run(a, &c3, &.{"-o"}).err),
    );
}

test "positional multi-value (num_args variants, OK)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "mv").arg(Arg.new("pos").action(.set).numArgs(range.atLeast(1)));
    try expectMany(run(a, &c1, &.{ "val1", "val2", "val3" }).matches, "pos", &.{ "val1", "val2", "val3" });
    var c2 = Command.init(a, "mv").arg(Arg.new("pos").numArgs(range.between(3, 3)));
    try expectMany(run(a, &c2, &.{ "val1", "val2", "val3" }).matches, "pos", &.{ "val1", "val2", "val3" });
    var c3 = Command.init(a, "mv").arg(Arg.new("pos").numArgs(range.atLeast(3)));
    try expectMany(run(a, &c3, &.{ "val1", "val2", "val3", "val4" }).matches, "pos", &.{ "val1", "val2", "val3", "val4" });
    var c4 = Command.init(a, "mv").arg(Arg.new("pos").numArgs(range.between(1, 3)));
    try expectMany(run(a, &c4, &.{ "val1", "val2" }).matches, "pos", &.{ "val1", "val2" });
}

test "optional_value (num_args(0..=1)) + help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var c1 = Command.init(a, "test").argsOverrideSelf(true).arg(Arg.new("port").short('p').valueName("NUM").numArgs(range.between(0, 1)));
    try testing.expectEqualStrings("42", run(a, &c1, &.{"-p42"}).matches.getOne([]const u8, "port").?);
    var c2 = Command.init(a, "test").argsOverrideSelf(true).arg(Arg.new("port").short('p').valueName("NUM").numArgs(range.between(0, 1)));
    const m2 = run(a, &c2, &.{"-p"}).matches;
    try testing.expect(m2.contains("port"));
    try testing.expect(m2.getOne([]const u8, "port") == null);
    var c3 = Command.init(a, "test").argsOverrideSelf(true).arg(Arg.new("port").short('p').valueName("NUM").numArgs(range.between(0, 1)));
    try testing.expectEqualStrings("42", run(a, &c3, &.{ "-p", "24", "-p", "42" }).matches.getOne([]const u8, "port").?);

    var c4 = Command.init(a, "test").argsOverrideSelf(true).arg(Arg.new("port").short('p').valueName("NUM").numArgs(range.between(0, 1)));
    c4.buildTree();
    try testing.expectEqualStrings(
        "Usage: test [OPTIONS]\n\nOptions:\n  -p [<NUM>]  \n  -h, --help  Print help\n",
        clap.renderHelp(a, &c4),
    );
}
