//! Ported subset of clap's tests/builder/help.rs — `next_help_heading` /
//! `help_heading` (custom option/positional sections).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn help(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, argv).err);
}

test "short_with_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "demo")
        .arg(Arg.new("baz").short('z').valueName("BAZ").help("Short only").helpHeading("Baz"));
    try testing.expectEqualStrings(
        "Usage: demo [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -h, --help  Print help\n\n" ++
            "Baz:\n" ++
            "  -z <BAZ>  Short only\n",
        help(a, &cmd, &.{"-h"}),
    );
}

test "short_with_count" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "demo")
        .arg(Arg.new("baz").short('z').action(.count).help("Short only").helpHeading("Baz"));
    try testing.expectEqualStrings(
        "Usage: demo [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -h, --help  Print help\n\n" ++
            "Baz:\n" ++
            "  -z...  Short only\n",
        help(a, &cmd, &.{"-h"}),
    );
}

test "custom_heading_pos" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.4")
        .arg(Arg.new("gear").help("Which gear"))
        .nextHelpHeading("NETWORKING")
        .arg(Arg.new("speed").help("How fast"));
    try testing.expectEqualStrings(
        "Usage: test [gear] [speed]\n\n" ++
            "Arguments:\n" ++
            "  [gear]  Which gear\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n\n" ++
            "NETWORKING:\n" ++
            "  [speed]  How fast\n",
        help(a, &cmd, &.{"--help"}),
    );
}

test "custom_headers_with_default_options_first" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").about("does stuff").version("1.4")
        .nextHelpHeading("NETWORKING")
        .arg(Arg.new("no-proxy").short('n').long("no-proxy").action(.set_true).help("Do not use system proxy settings"))
        .arg(Arg.new("port").long("port").action(.set_true));
    try testing.expectEqualStrings(
        "does stuff\n\n" ++
            "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n\n" ++
            "NETWORKING:\n" ++
            "  -n, --no-proxy  Do not use system proxy settings\n" ++
            "      --port\n",
        help(a, &cmd, &.{"--help"}),
    );
}

test "custom_help_headers_hide_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").about("does stuff").version("1.4")
        .nextHelpHeading("NETWORKING")
        .arg(Arg.new("no-proxy").short('n').long("no-proxy").action(.set_true).help("Do not use system proxy settings").hideShortHelp(true))
        .nextHelpHeading("SPECIAL")
        .arg(Arg.fromUsage("-b --song <song>", "Change which song is played for birthdays").required(true).helpHeading("OVERRIDE SPECIAL"))
        .arg(Arg.fromUsage("-v --song-volume <volume>", "Change the volume of the birthday song").required(true))
        .nextHelpHeading(null)
        .arg(Arg.new("server-addr").short('a').long("server-addr").action(.set_true).help("Set server address").helpHeading("NETWORKING").hideShortHelp(true));
    try testing.expectEqualStrings(
        "does stuff\n\n" ++
            "Usage: test [OPTIONS] --song <song> --song-volume <volume>\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help (see more with '--help')\n" ++
            "  -V, --version  Print version\n\n" ++
            "OVERRIDE SPECIAL:\n" ++
            "  -b, --song <song>  Change which song is played for birthdays\n\n" ++
            "SPECIAL:\n" ++
            "  -v, --song-volume <volume>  Change the volume of the birthday song\n",
        help(a, &cmd, &.{"-h"}),
    );
}

test "custom_headers_headers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").about("does stuff").version("1.4")
        .arg(Arg.fromUsage("-f --fake <s>", "some help").required(true).valueNames(&.{ "some", "val" }).action(.set).valueDelimiter(':'))
        .nextHelpHeading("NETWORKING")
        .arg(Arg.new("no-proxy").short('n').long("no-proxy").action(.set_true).help("Do not use system proxy settings"))
        .arg(Arg.new("port").long("port").action(.set_true));
    try testing.expectEqualStrings(
        "does stuff\n\n" ++
            "Usage: test [OPTIONS] --fake <some> <val>\n\n" ++
            "Options:\n" ++
            "  -f, --fake <some> <val>  some help\n" ++
            "  -h, --help               Print help\n" ++
            "  -V, --version            Print version\n\n" ++
            "NETWORKING:\n" ++
            "  -n, --no-proxy  Do not use system proxy settings\n" ++
            "      --port\n",
        help(a, &cmd, &.{"--help"}),
    );
}

test "only_custom_heading_opts_no_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.4")
        .disableVersionFlag(true).disableHelpFlag(true)
        .arg(Arg.fromUsage("--help", null).action(.help).hide(true))
        .nextHelpHeading("NETWORKING")
        .arg(Arg.fromUsage("-s --speed <SPEED>", "How fast"));
    try testing.expectEqualStrings(
        "Usage: test [OPTIONS]\n\n" ++
            "NETWORKING:\n" ++
            "  -s, --speed <SPEED>  How fast\n",
        help(a, &cmd, &.{"--help"}),
    );
}
