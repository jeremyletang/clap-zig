//! Ported subset of clap's tests/builder/flag_subcommands.rs — subcommands
//! invoked via `short_flag`/`long_flag` (and their aliases), incl. short-cluster
//! chaining (`-SfpRfp`) and the `{name|--long|-short}` usage string. The
//! debug_assert conflict cases, infer_subcommands, and suggestions are deferred.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/flag_subcommands.rs

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

fn testArg() Arg {
    return Arg.new("test").short('t').long("test").help("testing testing").action(.set_true);
}

test "flag_subcommand_normal" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .subcommand(Command.init(a, "some").shortFlag('S').longFlag("some").arg(testArg()));
    const m = run(a, &cmd, &.{ "some", "--test" }).matches;
    const sub = m.subcommand().?;
    try testing.expectEqualStrings("some", sub.name);
    try testing.expect(sub.matches.getFlag("test"));
}

test "flag_subcommand_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .subcommand(Command.init(a, "some").shortFlag('S').arg(testArg()));
    const m = run(a, &cmd, &.{ "-S", "--test" }).matches;
    try testing.expectEqualStrings("some", m.subcommand().?.name);
    try testing.expect(m.subcommand().?.matches.getFlag("test"));
}

test "flag_subcommand_short_with_args (-St)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .subcommand(Command.init(a, "some").shortFlag('S').arg(testArg()));
    const m = run(a, &cmd, &.{"-St"}).matches;
    try testing.expectEqualStrings("some", m.subcommand().?.name);
    try testing.expect(m.subcommand().?.matches.getFlag("test"));
}

test "flag_subcommand_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .subcommand(Command.init(a, "some").longFlag("some").arg(testArg()));
    const m = run(a, &cmd, &.{ "--some", "--test" }).matches;
    try testing.expectEqualStrings("some", m.subcommand().?.name);
    try testing.expect(m.subcommand().?.matches.getFlag("test"));
}

test "flag_subcommand_short_with_alias" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    inline for (.{ "-S", "-M", "-B" }) |flag| {
        var cmd = Command.init(a, "test")
            .subcommand(Command.init(a, "some").shortFlag('S').arg(testArg()).shortFlagAliases("MB"));
        const m = run(a, &cmd, &.{ flag, "--test" }).matches;
        try testing.expectEqualStrings("some", m.subcommand().?.name);
        try testing.expect(m.subcommand().?.matches.getFlag("test"));
    }
}

test "flag_subcommand_long_with_aliases" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    inline for (.{ "--some", "--result", "--someall" }) |flag| {
        var cmd = Command.init(a, "test")
            .subcommand(Command.init(a, "some").longFlag("some").arg(testArg()).longFlagAliases(&.{ "result", "someall" }));
        const m = run(a, &cmd, &.{ flag, "--test" }).matches;
        try testing.expectEqualStrings("some", m.subcommand().?.name);
        try testing.expect(m.subcommand().?.matches.getFlag("test"));
    }
}

test "flag_subcommand_short_after_long_arg (-Sc)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "pacman")
        .subcommand(Command.init(a, "sync").shortFlag('S').arg(Arg.new("clean").short('c').action(.set_true)))
        .arg(Arg.new("arg").long("arg").action(.set));
    const m = run(a, &cmd, &.{ "--arg", "foo", "-Sc" }).matches;
    const sub = m.subcommand().?;
    try testing.expectEqualStrings("sync", sub.name);
    try testing.expect(sub.matches.getFlag("clean"));
}

test "flag_subcommand_multiple (-SfpRfp)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").subcommand(Command.init(a, "some")
        .shortFlag('S').longFlag("some")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.fromUsage("-p --print", "print something").action(.set_true))
        .subcommand(Command.init(a, "result").shortFlag('R').longFlag("result")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.fromUsage("-p --print", "print something").action(.set_true))));
    const m = run(a, &cmd, &.{"-SfpRfp"}).matches;
    const some = m.subcommand().?;
    try testing.expectEqualStrings("some", some.name);
    try testing.expect(some.matches.getFlag("flag"));
    try testing.expect(some.matches.getFlag("print"));
    const result = some.matches.subcommand().?;
    try testing.expectEqualStrings("result", result.name);
    try testing.expect(result.matches.getFlag("flag"));
    try testing.expect(result.matches.getFlag("print"));
}

// ----- usage string: `{name|--long|-short}` -----

fn pacmanQuery(a: std.mem.Allocator, short: bool, long: bool) Command {
    var q = Command.init(a, "query").about("Query the package database.")
        .arg(Arg.new("search").short('s').long("search").help("search locally installed packages for matching strings").conflictsWith(&.{"info"}).action(.set).numArgs(range.atLeast(1)))
        .arg(Arg.new("info").long("info").short('i').conflictsWith(&.{"search"}).help("view package information").action(.set).numArgs(range.atLeast(1)));
    if (short) q = q.shortFlag('Q');
    if (long) q = q.longFlag("query");
    return Command.init(a, "pacman").about("package manager utility").version("5.2.1")
        .subcommandRequired(true).author("Pacman Development Team").subcommand(q);
}

fn helpText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, argv).err);
}

const QUERY_OPTIONS =
    "Options:\n" ++
    "  -s, --search <search>...  search locally installed packages for matching strings\n" ++
    "  -i, --info <info>...      view package information\n" ++
    "  -h, --help                Print help\n";

test "flag_subcommand_long_short_normal_usage_string" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pacmanQuery(a, true, true);
    try testing.expectEqualStrings(
        "Query the package database.\n\n" ++
            "Usage: pacman {query|--query|-Q} [OPTIONS]\n\n" ++ QUERY_OPTIONS,
        helpText(a, &cmd, &.{ "-Q", "-h" }),
    );
}

test "flag_subcommand_long_normal_usage_string" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pacmanQuery(a, false, true);
    try testing.expectEqualStrings(
        "Query the package database.\n\n" ++
            "Usage: pacman {query|--query} [OPTIONS]\n\n" ++ QUERY_OPTIONS,
        helpText(a, &cmd, &.{ "query", "--help" }),
    );
}

test "flag_subcommand_short_normal_usage_string" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = pacmanQuery(a, true, false);
    try testing.expectEqualStrings(
        "Query the package database.\n\n" ++
            "Usage: pacman {query|-Q} [OPTIONS]\n\n" ++ QUERY_OPTIONS,
        helpText(a, &cmd, &.{ "-Q", "-h" }),
    );
}
