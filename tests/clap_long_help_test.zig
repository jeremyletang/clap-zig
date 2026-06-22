//! Ported subset of clap's tests/builder/help.rs — per-arg `long_help` (shown in
//! `--help`; falls back to `help`, and `-h` falls back to it). Multi-line long
//! help is re-indented under the help column.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn helpText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, argv).err);
}

test "issue_1642_long_help_spacing" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").arg(Arg.new("cfg").long("config").action(.set_true).longHelp(
        "The config file used by the myprog must be in JSON format\n" ++
            "with only valid keys and may not contain other nonsense\n" ++
            "that cannot be read by this program. Obviously I'm going on\n" ++
            "and on, so I'll stop now.",
    ));
    try testing.expectEqualStrings(
        "Usage: prog [OPTIONS]\n\n" ++
            "Options:\n" ++
            "      --config\n" ++
            "          The config file used by the myprog must be in JSON format\n" ++
            "          with only valid keys and may not contain other nonsense\n" ++
            "          that cannot be read by this program. Obviously I'm going on\n" ++
            "          and on, so I'll stop now.\n\n" ++
            "  -h, --help\n" ++
            "          Print help (see a summary with '-h')\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "long_help_falls_back_in_short" {
    // `-h` uses `help`; when only `long_help` is set, `-h` falls back to it.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("a").long("aaa").action(.set_true).help("short a").longHelp("long a"))
        .arg(Arg.new("b").long("bbb").action(.set_true).longHelp("only long b"));
    // -h shows short help for `a`, and `b` falls back to its long help.
    try testing.expectEqualStrings(
        "Usage: prog [OPTIONS]\n\n" ++
            "Options:\n" ++
            "      --aaa   short a\n" ++
            "      --bbb   only long b\n" ++
            "  -h, --help  Print help (see more with '--help')\n",
        helpText(a, &cmd, &.{"-h"}),
    );
}

test "long_help_shown_in_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("a").long("aaa").action(.set_true).help("short a").longHelp("long a"));
    // --help prefers long_help for `a`.
    try testing.expectEqualStrings(
        "Usage: prog [OPTIONS]\n\n" ++
            "Options:\n" ++
            "      --aaa\n          long a\n\n" ++
            "  -h, --help\n          Print help (see a summary with '-h')\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}
