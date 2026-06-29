//! Ported from clap's tests/builder/help.rs — a user-defined help flag overrides
//! the auto one: a non-Help-action `-h/--help` is just a flag (issue 1112), and a
//! custom Help-action flag drives help with its own name/description.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn setup1112(a: std.mem.Allocator) Command {
    return Command.init(a, "test").version("1.3").disableHelpFlag(true)
        .arg(Arg.new("help1").long("help").short('h').help("some help").action(.set_true))
        .subcommand(Command.init(a, "foo")
        .arg(Arg.new("help1").long("help").short('h').help("some help").action(.set_true)));
}

test "prefer_user_help_short_1112" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = setup1112(a);
    try testing.expect(run(a, &cmd, &.{"-h"}).matches.getFlag("help1"));
}

test "prefer_user_help_long_1112" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = setup1112(a);
    try testing.expect(run(a, &cmd, &.{"--help"}).matches.getFlag("help1"));
}

fn expectHelp(a: std.mem.Allocator, make: *const fn (std.mem.Allocator) Command, argv: []const []const u8, expected: []const u8) !void {
    var cmd = make(a);
    const o = run(a, &cmd, argv);
    try testing.expectEqual(clap.ErrorKind.display_help, o.err.kind);
    try testing.expectEqualStrings(expected, clap.renderError(a, o.err));
}

fn overrideShort(a: std.mem.Allocator) Command {
    return Command.init(a, "test").version("0.1").disableHelpFlag(true)
        .arg(Arg.new("help").short('H').long("help").action(.help).help("Print help"));
}

test "override_help_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const exp = "Usage: test\n\nOptions:\n  -H, --help     Print help\n  -V, --version  Print version\n";
    try expectHelp(a, overrideShort, &.{"--help"}, exp);
    try expectHelp(a, overrideShort, &.{"-H"}, exp);
}

fn overrideLong(a: std.mem.Allocator) Command {
    return Command.init(a, "test").version("0.1").disableHelpFlag(true)
        .arg(Arg.new("hell").short('h').long("hell").action(.help).help("Print help"));
}

test "override_help_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const exp = "Usage: test\n\nOptions:\n  -h, --hell     Print help\n  -V, --version  Print version\n";
    try expectHelp(a, overrideLong, &.{"--hell"}, exp);
    try expectHelp(a, overrideLong, &.{"-h"}, exp);
}

fn overrideAbout(a: std.mem.Allocator) Command {
    return Command.init(a, "test").version("0.1").disableHelpFlag(true)
        .arg(Arg.new("help").short('h').long("help").action(.help).help("Print custom help information"));
}

test "override_help_about" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const exp = "Usage: test\n\nOptions:\n  -h, --help     Print custom help information\n  -V, --version  Print version\n";
    try expectHelp(a, overrideAbout, &.{"--help"}, exp);
    try expectHelp(a, overrideAbout, &.{"-h"}, exp);
}
