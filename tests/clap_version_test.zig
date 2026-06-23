//! Ported from clap's tests/builder/version.rs — the auto `-V`/`--version` flag,
//! `long_version`, and `propagate_version`. Rule: `-V` uses `version` (falling
//! back to `long_version`); `--version` uses `long_version` (falling back to
//! `version`); the flag exists when either is set.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/version.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn versionText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    const o = run(a, cmd, argv);
    return clap.renderError(a, o.err);
}

const FULL_TEMPLATE =
    "{before-help}{name} {version}\n" ++
    "{author-with-newline}{about-with-newline}\n" ++
    "{usage-heading} {usage}\n\n" ++
    "{all-args}{after-help}";

test "version_short_flag_no_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo");
    const o = run(a, &cmd, &.{"-V"});
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}

test "version_long_flag_no_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo");
    const o = run(a, &cmd, &.{"--version"});
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}

test "version_short_flag_with_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").version("3.0");
    try testing.expectEqualStrings("foo 3.0\n", versionText(a, &cmd, &.{"-V"}));
}

test "version_long_flag_with_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").version("3.0");
    try testing.expectEqualStrings("foo 3.0\n", versionText(a, &cmd, &.{"--version"}));
}

test "version_short_flag_with_long_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").longVersion("3.0 (abcdefg)");
    try testing.expectEqualStrings("foo 3.0 (abcdefg)\n", versionText(a, &cmd, &.{"-V"}));
}

test "version_long_flag_with_long_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").longVersion("3.0 (abcdefg)");
    try testing.expectEqualStrings("foo 3.0 (abcdefg)\n", versionText(a, &cmd, &.{"--version"}));
}

test "version_short_flag_with_both" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").version("3.0").longVersion("3.0 (abcdefg)");
    try testing.expectEqualStrings("foo 3.0\n", versionText(a, &cmd, &.{"-V"}));
}

test "version_long_flag_with_both" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").version("3.0").longVersion("3.0 (abcdefg)");
    try testing.expectEqualStrings("foo 3.0 (abcdefg)\n", versionText(a, &cmd, &.{"--version"}));
}

test "help_short_flag_no_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").helpTemplate(FULL_TEMPLATE);
    try testing.expectEqualStrings(
        "foo \n\nUsage: foo\n\nOptions:\n  -h, --help  Print help\n",
        versionText(a, &cmd, &.{"-h"}),
    );
}

test "help_short_flag_with_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").helpTemplate(FULL_TEMPLATE).version("3.0");
    try testing.expectEqualStrings(
        "foo 3.0\n\nUsage: foo\n\nOptions:\n  -h, --help     Print help\n  -V, --version  Print version\n",
        versionText(a, &cmd, &.{"-h"}),
    );
}

test "help_short_flag_with_long_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").helpTemplate(FULL_TEMPLATE).longVersion("3.0 (abcdefg)");
    try testing.expectEqualStrings(
        "foo 3.0 (abcdefg)\n\nUsage: foo\n\nOptions:\n  -h, --help     Print help\n  -V, --version  Print version\n",
        versionText(a, &cmd, &.{"-h"}),
    );
}

test "help_long_flag_with_both" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").helpTemplate(FULL_TEMPLATE).version("3.0").longVersion("3.0 (abcdefg)");
    try testing.expectEqualStrings(
        "foo 3.0\n\nUsage: foo\n\nOptions:\n  -h, --help     Print help\n  -V, --version  Print version\n",
        versionText(a, &cmd, &.{"--help"}),
    );
}

test "help_long_flag_no_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").helpTemplate(FULL_TEMPLATE);
    try testing.expectEqualStrings(
        "foo \n\nUsage: foo\n\nOptions:\n  -h, --help  Print help\n",
        versionText(a, &cmd, &.{"--help"}),
    );
}

test "help_long_flag_with_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").helpTemplate(FULL_TEMPLATE).version("3.0");
    try testing.expectEqualStrings(
        "foo 3.0\n\nUsage: foo\n\nOptions:\n  -h, --help     Print help\n  -V, --version  Print version\n",
        versionText(a, &cmd, &.{"--help"}),
    );
}

test "help_long_flag_with_long_version" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").helpTemplate(FULL_TEMPLATE).longVersion("3.0 (abcdefg)");
    try testing.expectEqualStrings(
        "foo 3.0 (abcdefg)\n\nUsage: foo\n\nOptions:\n  -h, --help     Print help\n  -V, --version  Print version\n",
        versionText(a, &cmd, &.{"--help"}),
    );
}

test "help_short_flag_with_both" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").helpTemplate(FULL_TEMPLATE).version("3.0").longVersion("3.0 (abcdefg)");
    try testing.expectEqualStrings(
        "foo 3.0\n\nUsage: foo\n\nOptions:\n  -h, --help     Print help\n  -V, --version  Print version\n",
        versionText(a, &cmd, &.{"-h"}),
    );
}

test "no_propagation_by_default_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").version("3.0")
        .subcommand(Command.init(a, "bar"));
    const o = run(a, &cmd, &.{ "bar", "--version" });
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}

test "no_propagation_by_default_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").version("3.0")
        .subcommand(Command.init(a, "bar"));
    const o = run(a, &cmd, &.{ "bar", "-V" });
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}

test "propagate_version_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").version("3.0").propagateVersion(true)
        .subcommand(Command.init(a, "bar"));
    const o = run(a, &cmd, &.{ "bar", "--version" });
    try testing.expectEqual(clap.ErrorKind.display_version, o.err.kind);
    try testing.expectEqualStrings("bar 3.0\n", clap.renderError(a, o.err));
}

test "propagate_version_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "foo").version("3.0").propagateVersion(true)
        .subcommand(Command.init(a, "bar"));
    const o = run(a, &cmd, &.{ "bar", "-V" });
    try testing.expectEqual(clap.ErrorKind.display_version, o.err.kind);
    try testing.expectEqualStrings("bar 3.0\n", clap.renderError(a, o.err));
}
