//! Ported from clap's tests/builder/{app_settings,opts}.rs — `infer_subcommands`
//! and `infer_long_args`: an unambiguous prefix of a subcommand name (or `--long`
//! flag) resolves to the full form. Exact matches always win; ambiguous prefixes
//! fall to a positional value when one exists, else error.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/app_settings.rs
//! https://github.com/clap-rs/clap/blob/master/tests/builder/opts.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

// ----- infer_subcommands -----

test "infer_subcommands_fail_no_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test"))
        .subcommand(Command.init(a, "temp"));
    const o = run(a, &cmd, &.{"te"});
    try testing.expectEqual(clap.ErrorKind.invalid_subcommand, o.err.kind);
}

test "infer_subcommands_fail_with_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .arg(Arg.new("some"))
        .subcommand(Command.init(a, "test"))
        .subcommand(Command.init(a, "temp"));
    const m = run(a, &cmd, &.{"t"}).matches;
    try testing.expectEqualStrings("t", m.getOne([]const u8, "some").?);
}

test "infer_subcommands_fail_with_args2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .arg(Arg.new("some"))
        .subcommand(Command.init(a, "test"))
        .subcommand(Command.init(a, "temp"));
    const m = run(a, &cmd, &.{"te"}).matches;
    try testing.expectEqualStrings("te", m.getOne([]const u8, "some").?);
}

test "infer_subcommands_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test"));
    const m = run(a, &cmd, &.{"te"}).matches;
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "infer_subcommands_pass_close" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test"))
        .subcommand(Command.init(a, "temp"));
    const m = run(a, &cmd, &.{"tes"}).matches;
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "infer_subcommands_pass_exact_match" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test"))
        .subcommand(Command.init(a, "testa"))
        .subcommand(Command.init(a, "testb"));
    const m = run(a, &cmd, &.{"test"}).matches;
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "infer_subcommands_pass_conflicting_aliases" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test").aliases(&.{ "testa", "t", "testb" }));
    const m = run(a, &cmd, &.{"te"}).matches;
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "infer_long_flag_pass_conflicting_aliases" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "c").longFlag("test")
        .longFlagAliases(&.{ "testa", "t", "testb" }));
    const m = run(a, &cmd, &.{"--te"}).matches;
    try testing.expectEqualStrings("c", m.subcommand().?.name);
}

test "infer_long_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test").longFlag("testa"));
    const m = run(a, &cmd, &.{"--te"}).matches;
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "infer_subcommands_long_flag_fail_with_args2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "a").longFlag("test"))
        .subcommand(Command.init(a, "b").longFlag("temp"));
    const o = run(a, &cmd, &.{"--te"});
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}

test "infer_subcommands_fail_suggestions" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test"))
        .subcommand(Command.init(a, "temp"));
    const o = run(a, &cmd, &.{"temps"});
    try testing.expectEqual(clap.ErrorKind.invalid_subcommand, o.err.kind);
}

test "flag_subcommand_long_infer_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test").longFlag("test"));
    const m = run(a, &cmd, &.{"--te"}).matches;
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "flag_subcommand_long_infer_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test").longFlag("test"))
        .subcommand(Command.init(a, "temp").longFlag("temp"));
    const o = run(a, &cmd, &.{"--te"});
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}

test "flag_subcommand_long_infer_pass_close" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test").longFlag("test"))
        .subcommand(Command.init(a, "temp").longFlag("temp"));
    const m = run(a, &cmd, &.{"--tes"}).matches;
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "flag_subcommand_long_infer_exact_match" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").inferSubcommands(true)
        .subcommand(Command.init(a, "test").longFlag("test"))
        .subcommand(Command.init(a, "testa").longFlag("testa"))
        .subcommand(Command.init(a, "testb").longFlag("testb"));
    const m = run(a, &cmd, &.{"--test"}).matches;
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

// ----- infer_long_args -----

test "infer_long_arg_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").inferLongArgs(true)
        .arg(Arg.new("racetrack").long("racetrack").aliases(&.{"autobahn"}).action(.set_true))
        .arg(Arg.new("racecar").long("racecar").action(.set));

    const m1 = run(a, &cmd, &.{"--racec=hello"}).matches;
    try testing.expect(!m1.getFlag("racetrack"));
    try testing.expectEqualStrings("hello", m1.getOne([]const u8, "racecar").?);

    const m2 = run(a, &cmd, &.{"--racet"}).matches;
    try testing.expect(m2.getFlag("racetrack"));
    try testing.expect(m2.getOne([]const u8, "racecar") == null);

    const m3 = run(a, &cmd, &.{"--auto"}).matches;
    try testing.expect(m3.getFlag("racetrack"));
}

test "infer_long_arg_pass empty and single-letter" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").inferLongArgs(true)
        .arg(Arg.new("arg").long("arg").action(.set_true));

    const m1 = run(a, &cmd, &.{"--"}).matches;
    try testing.expect(!m1.getFlag("arg"));

    const m2 = run(a, &cmd, &.{"--a"}).matches;
    try testing.expect(m2.getFlag("arg"));
}

test "infer_long_arg_pass_conflicts_exact_match" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").inferLongArgs(true)
        .arg(Arg.new("arg").long("arg").action(.set_true))
        .arg(Arg.new("arg2").long("arg2").action(.set_true));

    const m1 = run(a, &cmd, &.{"--arg"}).matches;
    try testing.expect(m1.getFlag("arg"));

    const m2 = run(a, &cmd, &.{"--arg2"}).matches;
    try testing.expect(m2.getFlag("arg2"));
}

test "infer_long_arg_pass_conflicting_aliases" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").inferLongArgs(true)
        .arg(Arg.new("abc-123").long("abc-123").aliases(&.{ "a", "abc-xyz" }).action(.set_true));
    const m = run(a, &cmd, &.{"--ab"}).matches;
    try testing.expect(m.getFlag("abc-123"));
}

test "infer_long_arg_fail_conflicts" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").inferLongArgs(true)
        .arg(Arg.new("abc-123").long("abc-123").action(.set_true))
        .arg(Arg.new("abc-xyz").long("abc-xyz").action(.set_true));
    const o = run(a, &cmd, &.{"--abc"});
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}
