//! Ported from clap's tests/builder/occurrences.rs — `get_occurrences`: an arg's
//! values grouped by occurrence. Each option appearance is one group; contiguous
//! positional values form a group, split when interrupted by another arg.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/occurrences.rs

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

fn expectGroups(a: std.mem.Allocator, m: *const clap.ArgMatches, id: []const u8, expected: []const []const []const u8) !void {
    const got = m.getOccurrences(a, id) orelse return error.NoOccurrences;
    try testing.expectEqual(expected.len, got.len);
    for (expected, got) |exp_group, got_group| {
        try testing.expectEqual(exp_group.len, got_group.len);
        for (exp_group, got_group) |e, g| try testing.expectEqualStrings(e, g);
    }
}

test "grouped_value_works" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "cli")
        .arg(Arg.new("option").long("option").action(.append).numArgs(range.atLeast(1)));
    const m = run(a, &cmd, &.{
        "--option", "fr_FR:mon option 1", "en_US:my option 1",
        "--option", "fr_FR:mon option 2", "en_US:my option 2",
    }).matches;
    try expectGroups(a, m, "option", &.{
        &.{ "fr_FR:mon option 1", "en_US:my option 1" },
        &.{ "fr_FR:mon option 2", "en_US:my option 2" },
    });
}

test "issue_1026" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "cli")
        .arg(Arg.new("server").short('s').action(.set))
        .arg(Arg.new("user").short('u').action(.set))
        .arg(Arg.new("target").long("target").action(.append).numArgs(range.atLeast(1)));
    const m = run(a, &cmd, &.{
        "-s",    "server",   "-u",       "user",    "--target", "target1", "file1",
        "file2", "file3",    "--target", "target2", "file4",    "file5",   "file6",
        "file7", "--target", "target3",  "file8",
    }).matches;
    try expectGroups(a, m, "target", &.{
        &.{ "target1", "file1", "file2", "file3" },
        &.{ "target2", "file4", "file5", "file6", "file7" },
        &.{ "target3", "file8" },
    });
}

test "grouped_value_long_flag_delimiter" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myapp")
        .arg(Arg.new("option").long("option").valueDelimiter(',').action(.append).numArgs(range.atLeast(1)));
    const m = run(a, &cmd, &.{ "--option=hmm", "--option=val1,val2,val3", "--option", "alice,bob" }).matches;
    try expectGroups(a, m, "option", &.{
        &.{"hmm"},
        &.{ "val1", "val2", "val3" },
        &.{ "alice", "bob" },
    });
}

test "grouped_value_short_flag_delimiter" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myapp")
        .arg(Arg.new("option").short('o').valueDelimiter(',').action(.append).numArgs(range.atLeast(1)));
    const m = run(a, &cmd, &.{ "-o=foo", "-o=val1,val2,val3", "-o=bar" }).matches;
    try expectGroups(a, m, "option", &.{
        &.{"foo"},
        &.{ "val1", "val2", "val3" },
        &.{"bar"},
    });
}

test "grouped_value_positional_arg" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "multiple_values")
        .arg(Arg.new("pos").action(.set).numArgs(range.atLeast(1)));
    const m = run(a, &cmd, &.{ "val1", "val2", "val3", "val4", "val5", "val6" }).matches;
    try expectGroups(a, m, "pos", &.{
        &.{ "val1", "val2", "val3", "val4", "val5", "val6" },
    });
}

test "grouped_value_multiple_positional_arg" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "multiple_values")
        .arg(Arg.new("pos1"))
        .arg(Arg.new("pos2").action(.set).numArgs(range.atLeast(1)));
    const m = run(a, &cmd, &.{ "val1", "val2", "val3", "val4", "val5", "val6" }).matches;
    try expectGroups(a, m, "pos2", &.{
        &.{ "val2", "val3", "val4", "val5", "val6" },
    });
}

test "grouped_value_multiple_positional_arg_last_multiple" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "multiple_values")
        .arg(Arg.new("pos1"))
        .arg(Arg.new("pos2").action(.set).numArgs(range.atLeast(1)).last(true));
    const m = run(a, &cmd, &.{ "val1", "--", "val2", "val3", "val4", "val5", "val6" }).matches;
    try expectGroups(a, m, "pos2", &.{
        &.{ "val2", "val3", "val4", "val5", "val6" },
    });
}

test "grouped_interleaved_positional_values" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo")
        .arg(Arg.new("pos").numArgs(range.atLeast(1)))
        .arg(Arg.new("flag").short('f').long("flag").action(.append));
    const m = run(a, &cmd, &.{ "1", "2", "-f", "a", "3", "-f", "b", "4" }).matches;
    try expectGroups(a, m, "pos", &.{ &.{ "1", "2" }, &.{"3"}, &.{"4"} });
    try expectGroups(a, m, "flag", &.{ &.{"a"}, &.{"b"} });
}

test "grouped_interleaved_positional_occurrences" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo")
        .arg(Arg.new("pos").numArgs(range.atLeast(1)))
        .arg(Arg.new("flag").short('f').long("flag").action(.append));
    const m = run(a, &cmd, &.{ "1", "2", "-f", "a", "3", "-f", "b", "4" }).matches;
    try expectGroups(a, m, "pos", &.{ &.{ "1", "2" }, &.{"3"}, &.{"4"} });
    try expectGroups(a, m, "flag", &.{ &.{"a"}, &.{"b"} });
}
