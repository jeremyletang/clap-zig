//! Ported from clap's tests/builder/utf8.rs — only the valid-UTF8 cases are
//! portable; clap-zig takes `[]const u8` byte slices with no UTF-8 strictness or
//! `OsString` duality, so the invalid-UTF8 / OsStr cases are out of scope.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/utf8.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

test "allow_validated_utf8_value_of" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").arg(Arg.new("name").long("name").action(.set));
    const m = run(a, &cmd, &.{ "--name", "me" }).matches;
    try testing.expectEqualStrings("me", m.getOne([]const u8, "name").?);
}

test "allow_validated_utf8_external_subcommand_values_of" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").allowExternalSubcommands(true);
    const m = run(a, &cmd, &.{ "cmd", "arg" }).matches;
    const sub = m.subcommand().?;
    try testing.expectEqualStrings("cmd", sub.name);
    const args = sub.matches.getMany([]const u8, "").?;
    try testing.expectEqual(@as(usize, 1), args.len);
    try testing.expectEqualStrings("arg", args[0]);
}
