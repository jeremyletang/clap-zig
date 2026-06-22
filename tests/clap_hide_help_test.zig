//! Ported subset of clap's tests/builder/hidden_args.rs — `hide_short_help` /
//! `hide_long_help` (per-mode visibility; presence forces the long layout).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/hidden_args.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn helpText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, argv).err);
}

fn shortHideApp(a: std.mem.Allocator) Command {
    return Command.init(a, "test").about("hides short args").version("2.31.2")
        .arg(Arg.new("cfg").short('c').long("config").hideShortHelp(true).action(.set_true)
            .help("Some help text describing the --config arg"))
        .arg(Arg.new("visible").short('v').long("visible").action(.set_true)
        .help("This text should be visible"));
}

fn longHideApp(a: std.mem.Allocator) Command {
    return Command.init(a, "test").about("hides long args").version("2.31.2")
        .arg(Arg.new("cfg").short('c').long("config").hideLongHelp(true).action(.set_true)
            .help("Some help text describing the --config arg"))
        .arg(Arg.new("visible").short('v').long("visible").action(.set_true)
        .help("This text should be visible"));
}

test "hide_short_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = shortHideApp(a);
    try testing.expectEqualStrings(
        "hides short args\n\n" ++
            "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -v, --visible  This text should be visible\n" ++
            "  -h, --help     Print help (see more with '--help')\n" ++
            "  -V, --version  Print version\n",
        helpText(a, &cmd, &.{"-h"}),
    );
}

test "hide_short_args_long_help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = shortHideApp(a);
    try testing.expectEqualStrings(
        "hides short args\n\n" ++
            "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -c, --config\n          Some help text describing the --config arg\n\n" ++
            "  -v, --visible\n          This text should be visible\n\n" ++
            "  -h, --help\n          Print help (see a summary with '-h')\n\n" ++
            "  -V, --version\n          Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "hide_long_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = longHideApp(a);
    try testing.expectEqualStrings(
        "hides long args\n\n" ++
            "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -v, --visible\n          This text should be visible\n\n" ++
            "  -h, --help\n          Print help (see a summary with '-h')\n\n" ++
            "  -V, --version\n          Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "hide_long_args_short_help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = longHideApp(a);
    try testing.expectEqualStrings(
        "hides long args\n\n" ++
            "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -c, --config   Some help text describing the --config arg\n" ++
            "  -v, --visible  This text should be visible\n" ++
            "  -h, --help     Print help (see more with '--help')\n" ++
            "  -V, --version  Print version\n",
        helpText(a, &cmd, &.{"-h"}),
    );
}
