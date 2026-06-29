//! Ported from clap's tests/builder/help.rs — disable_help_flag /
//! disable_help_subcommand, and overriding the help flag/subcommand with a
//! user-defined flag-subcommand or `help` subcommand.
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

test "disabled_help_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").subcommand(Command.init(a, "sub")).disableHelpFlag(true);
    try testing.expectEqual(clap.ErrorKind.invalid_subcommand, run(a, &cmd, &.{"a"}).err.kind);
}

test "disabled_help_flag_and_subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").subcommand(Command.init(a, "sub")).disableHelpFlag(true).disableHelpSubcommand(true);
    const o = run(a, &cmd, &.{"help"});
    try testing.expectEqual(clap.ErrorKind.invalid_subcommand, o.err.kind);
    const text = clap.renderError(a, o.err);
    try testing.expect(text.len > 0 and text[text.len - 1] == '\n');
}

test "override_help_flag_using_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo")
        .subcommand(Command.init(a, "help").longFlag("help"))
        .disableHelpFlag(true).disableHelpSubcommand(true);
    try testing.expectEqualStrings("help", run(a, &cmd, &.{"--help"}).matches.subcommand().?.name);
}

test "override_help_flag_using_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo")
        .disableHelpFlag(true).disableHelpSubcommand(true)
        .subcommand(Command.init(a, "help").shortFlag('h'));
    try testing.expectEqualStrings("help", run(a, &cmd, &.{"-h"}).matches.subcommand().?.name);
}

test "override_help_subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "bar")
        .subcommand(Command.init(a, "help").arg(Arg.new("arg").action(.set)))
        .subcommand(Command.init(a, "not_help").arg(Arg.new("arg").action(.set)))
        .disableHelpSubcommand(true);
    const m = run(a, &cmd, &.{ "help", "foo" }).matches;
    try testing.expectEqualStrings("foo", m.subcommand().?.matches.getOne([]const u8, "arg").?);
}
