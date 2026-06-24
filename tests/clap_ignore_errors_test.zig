//! Ported from clap's tests/builder/ignore_errors.rs — `ignore_errors(true)`
//! swallows recoverable parse errors (missing values, unknown args/subcommands)
//! and returns best-effort matches; help/version requests still display.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/ignore_errors.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn cfgCmd(a: std.mem.Allocator) Command {
    return Command.init(a, "cmd").ignoreErrors(true)
        .arg(Arg.new("config").short('c').long("config").action(.set))
        .arg(Arg.new("unset-flag").long("unset-flag").action(.set_true));
}

test "single_short_arg_without_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = cfgCmd(a);
    const m = run(a, &cmd, &.{"-c"}).matches;
    try testing.expect(m.contains("config"));
    try testing.expect(m.getOne([]const u8, "config") == null);
    try testing.expect(!m.getFlag("unset-flag"));
}

test "single_long_arg_without_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = cfgCmd(a);
    const m = run(a, &cmd, &.{"--config"}).matches;
    try testing.expect(m.contains("config"));
    try testing.expect(m.getOne([]const u8, "config") == null);
    try testing.expect(!m.getFlag("unset-flag"));
}

test "multiple_args_and_final_arg_without_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "cmd").ignoreErrors(true)
        .arg(Arg.new("config").short('c').long("config").action(.set))
        .arg(Arg.new("stuff").short('x').long("stuff").action(.set))
        .arg(Arg.new("f").short('f').action(.set_true))
        .arg(Arg.new("unset-flag").long("unset-flag").action(.set_true));
    const m = run(a, &cmd, &.{ "-c", "file", "-f", "-x" }).matches;
    try testing.expectEqualStrings("file", m.getOne([]const u8, "config").?);
    try testing.expect(m.getFlag("f"));
    try testing.expect(m.getOne([]const u8, "stuff") == null);
    try testing.expect(!m.getFlag("unset-flag"));
}

test "multiple_args_and_intermittent_arg_without_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "cmd").ignoreErrors(true)
        .arg(Arg.new("config").short('c').long("config").action(.set))
        .arg(Arg.new("stuff").short('x').long("stuff").action(.set))
        .arg(Arg.new("f").short('f').action(.set_true))
        .arg(Arg.new("unset-flag").long("unset-flag").action(.set_true));
    const m = run(a, &cmd, &.{ "-x", "-c", "file", "-f" }).matches;
    try testing.expectEqualStrings("file", m.getOne([]const u8, "config").?);
    try testing.expect(m.getFlag("f"));
    try testing.expect(m.getOne([]const u8, "stuff") == null);
    try testing.expect(!m.getFlag("unset-flag"));
}

test "unexpected_argument" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "cmd").ignoreErrors(true)
        .arg(Arg.new("config").short('c').long("config").action(.set).numArgs(clap.ValueRange.between(0, 1)))
        .arg(Arg.new("unset-flag").long("unset-flag").action(.set_true));
    const m = run(a, &cmd, &.{ "-c", "config file", "unexpected" }).matches;
    try testing.expect(m.contains("config"));
    try testing.expectEqualStrings("config file", m.getOne([]const u8, "config").?);
    try testing.expect(!m.getFlag("unset-flag"));
}

test "did_you_mean (ignored)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "cmd").ignoreErrors(true)
        .arg(Arg.new("ignore-immutable").long("ignore-immutable").action(.set_true));
    const m = run(a, &cmd, &.{"--ig"}).matches;
    try testing.expect(m.contains("ignore-immutable"));
    try testing.expectEqual(@as(?clap.ValueSource, .default_value), m.valueSource("ignore-immutable"));
}

test "subcommand (partial)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").ignoreErrors(true)
        .subcommand(Command.init(a, "some")
            .arg(Arg.new("test").short('t').long("test").action(.set))
            .arg(Arg.new("stuff").short('x').long("stuff").action(.set))
            .arg(Arg.new("unset-flag").long("unset-flag").action(.set_true)))
        .arg(Arg.new("other").long("other"))
        .arg(Arg.new("unset-flag").long("unset-flag").action(.set_true));
    const m = run(a, &cmd, &.{ "some", "--test", "-x", "some other val" }).matches;
    try testing.expectEqualStrings("some", m.subcommand().?.name);
    const sub = m.subcommand().?.matches;
    try testing.expect(sub.contains("test"));
    try testing.expect(sub.getOne([]const u8, "test") == null);
    try testing.expectEqualStrings("some other val", sub.getOne([]const u8, "stuff").?);
    try testing.expect(!sub.getFlag("unset-flag"));
    try testing.expect(!m.getFlag("unset-flag"));
}

test "help_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").ignoreErrors(true);
    const o = run(a, &cmd, &.{"--help"});
    try testing.expectEqual(clap.ErrorKind.display_help, o.err.kind);
    try testing.expectEqualStrings(
        "Usage: test\n\nOptions:\n  -h, --help  Print help\n",
        clap.renderError(a, o.err),
    );
}

test "help_flag_subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").subcommand(Command.init(a, "sub")).ignoreErrors(true);
    const o = run(a, &cmd, &.{ "sub", "--help" });
    try testing.expectEqual(clap.ErrorKind.display_help, o.err.kind);
    try testing.expectEqualStrings(
        "Usage: test sub\n\nOptions:\n  -h, --help  Print help\n",
        clap.renderError(a, o.err),
    );
}

test "version_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").ignoreErrors(true).version("0.1");
    const o = run(a, &cmd, &.{"--version"});
    try testing.expectEqual(clap.ErrorKind.display_version, o.err.kind);
    try testing.expectEqualStrings("test 0.1\n", clap.renderError(a, o.err));
}
