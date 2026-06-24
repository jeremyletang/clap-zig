//! Ported from clap's tests/builder/subcommands.rs — `multicall`: dispatch on the
//! first argument as an applet name. Subcommands are top-level applets (bin_name
//! rooted at their own name) and the root's usage is just `<COMMAND>`.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/subcommands.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn busybox(a: std.mem.Allocator) Command {
    return Command.init(a, "busybox").multicall(true)
        .subcommand(Command.init(a, "busybox")
            .subcommand(Command.init(a, "true"))
            .subcommand(Command.init(a, "false")))
        .subcommand(Command.init(a, "true"))
        .subcommand(Command.init(a, "false"));
}

test "busybox_like_multicall (nested applet)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = busybox(a);
    const m = run(a, &cmd, &.{ "busybox", "true" }).matches;
    try testing.expectEqualStrings("busybox", m.subcommand().?.name);
    try testing.expectEqualStrings("true", m.subcommand().?.matches.subcommand().?.name);
}

test "busybox_like_multicall (direct applet)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = busybox(a);
    const m = run(a, &cmd, &.{"true"}).matches;
    try testing.expectEqualStrings("true", m.subcommand().?.name);
}

test "busybox_like_multicall (unknown applet)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = busybox(a);
    try testing.expectEqual(clap.ErrorKind.invalid_subcommand, run(a, &cmd, &.{"a.out"}).err.kind);
}

fn hostname(a: std.mem.Allocator) Command {
    return Command.init(a, "hostname").multicall(true)
        .subcommand(Command.init(a, "hostname"))
        .subcommand(Command.init(a, "dnsdomainname"));
}

test "hostname_like_multicall" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = hostname(a);
    try testing.expectEqualStrings("hostname", run(a, &c1, &.{"hostname"}).matches.subcommand().?.name);
    var c2 = hostname(a);
    try testing.expectEqualStrings("dnsdomainname", run(a, &c2, &.{"dnsdomainname"}).matches.subcommand().?.name);
    var c3 = hostname(a);
    try testing.expectEqual(clap.ErrorKind.invalid_subcommand, run(a, &c3, &.{"a.out"}).err.kind);
    var c4 = hostname(a);
    try testing.expectEqual(clap.ErrorKind.unknown_argument, run(a, &c4, &.{ "hostname", "hostname" }).err.kind);
    var c5 = hostname(a);
    try testing.expectEqual(clap.ErrorKind.unknown_argument, run(a, &c5, &.{ "hostname", "dnsdomainname" }).err.kind);
}

fn repl(a: std.mem.Allocator) Command {
    return Command.init(a, "repl").version("1.0.0").propagateVersion(true).multicall(true)
        .subcommand(Command.init(a, "foo"))
        .subcommand(Command.init(a, "bar"));
}

test "bad_multicall_command_error" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = repl(a);
    const o = run(a, &cmd, &.{"world"});
    try testing.expectEqual(clap.ErrorKind.invalid_subcommand, o.err.kind);
    try testing.expectEqualStrings(
        "error: unrecognized subcommand 'world'\n\n" ++
            "Usage: <COMMAND>\n\n" ++
            "For more information, try 'help'.\n",
        clap.renderError(a, o.err),
    );
}

test "bad_multicall_command_error (suggestion)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = repl(a);
    const o = run(a, &cmd, &.{"baz"});
    try testing.expectEqual(clap.ErrorKind.invalid_subcommand, o.err.kind);
    try testing.expectEqualStrings(
        "error: unrecognized subcommand 'baz'\n\n" ++
            "  tip: a similar subcommand exists: 'bar'\n\n" ++
            "Usage: <COMMAND>\n\n" ++
            "For more information, try 'help'.\n",
        clap.renderError(a, o.err),
    );
}

test "bad_multicall preserves --help and --version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = repl(a);
    try testing.expectEqual(clap.ErrorKind.display_help, run(a, &c1, &.{ "foo", "--help" }).err.kind);
    var c2 = repl(a);
    try testing.expectEqual(clap.ErrorKind.display_version, run(a, &c2, &.{ "foo", "--version" }).err.kind);
}

const HELP_EXPECTED =
    "Usage: foo bar [value]\n\n" ++
    "Arguments:\n  [value]  \n\n" ++
    "Options:\n  -h, --help     Print help\n  -V, --version  Print version\n";

fn replNested(a: std.mem.Allocator) Command {
    return Command.init(a, "repl").version("1.0.0").propagateVersion(true).multicall(true)
        .subcommand(Command.init(a, "foo")
        .subcommand(Command.init(a, "bar").arg(Arg.new("value"))));
}

test "multicall_help_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = replNested(a);
    const o = run(a, &cmd, &.{ "foo", "bar", "--help" });
    try testing.expectEqual(clap.ErrorKind.display_help, o.err.kind);
    try testing.expectEqualStrings(HELP_EXPECTED, clap.renderError(a, o.err));
}

test "multicall_help_subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = replNested(a);
    const o = run(a, &cmd, &.{ "help", "foo", "bar" });
    try testing.expectEqual(clap.ErrorKind.display_help, o.err.kind);
    try testing.expectEqualStrings(HELP_EXPECTED, clap.renderError(a, o.err));
}
