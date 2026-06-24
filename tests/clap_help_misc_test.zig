//! Ported from clap's tests/builder/help.rs — dotted variadic positionals, the
//! `last` arg usage, an empty default value, and hidden args.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const range = clap.ValueRange;

fn helpText(a: std.mem.Allocator, cmd: *Command) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, &.{"--help"}).err);
}

const DOTTED =
    "Usage: test <foo>...\n\n" ++
    "Arguments:\n  <foo>...  \n\n" ++
    "Options:\n  -h, --help  Print help\n";

const DOTTED_NAMED =
    "Usage: test <BAR>...\n\n" ++
    "Arguments:\n  <BAR>...  \n\n" ++
    "Options:\n  -h, --help  Print help\n";

test "positional_multiple_values_is_dotted" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "test").arg(Arg.new("foo").required(true).action(.set).numArgs(range.atLeast(1)));
    try testing.expectEqualStrings(DOTTED, helpText(a, &c1));
    var c2 = Command.init(a, "test").arg(Arg.new("foo").required(true).action(.set).valueName("BAR").numArgs(range.atLeast(1)));
    try testing.expectEqualStrings(DOTTED_NAMED, helpText(a, &c2));
}

test "positional_multiple_occurrences_is_dotted" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "test").arg(Arg.new("foo").required(true).action(.append).numArgs(range.atLeast(1)));
    try testing.expectEqualStrings(DOTTED, helpText(a, &c1));
    var c2 = Command.init(a, "test").arg(Arg.new("foo").required(true).action(.append).valueName("BAR").numArgs(range.atLeast(1)));
    try testing.expectEqualStrings(DOTTED_NAMED, helpText(a, &c2));
}

test "args_with_last_usage" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flamegraph").version("0.1")
        .arg(Arg.new("verbose").help("Prints out more stuff.").short('v').long("verbose").action(.set_true))
        .arg(Arg.new("timeout").help("Timeout in seconds.").short('t').long("timeout").action(.set).valueName("SECONDS"))
        .arg(Arg.new("frequency").help("The sampling frequency.").short('f').long("frequency").action(.set).valueName("HERTZ"))
        .arg(Arg.new("binary path").help("The path of the binary to be profiled. for a binary.").valueName("BINFILE"))
        .arg(Arg.new("pass through args").help("Any arguments you wish to pass to the being profiled.").action(.set).numArgs(range.atLeast(1)).last(true).valueName("ARGS"));
    try testing.expectEqualStrings(
        "Usage: flamegraph [OPTIONS] [BINFILE] [-- <ARGS>...]\n\n" ++
            "Arguments:\n" ++
            "  [BINFILE]  The path of the binary to be profiled. for a binary.\n" ++
            "  [ARGS]...  Any arguments you wish to pass to the being profiled.\n\n" ++
            "Options:\n" ++
            "  -v, --verbose            Prints out more stuff.\n" ++
            "  -t, --timeout <SECONDS>  Timeout in seconds.\n" ++
            "  -f, --frequency <HERTZ>  The sampling frequency.\n" ++
            "  -h, --help               Print help\n" ++
            "  -V, --version            Print version\n",
        helpText(a, &cmd),
    );
}

test "empty_default_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "default").version("0.1").termWidth(120)
        .arg(Arg.new("argument").help("Pass an argument to the program.").long("arg").action(.set).defaultValue(""));
    try testing.expectEqualStrings(
        "Usage: default [OPTIONS]\n\n" ++
            "Options:\n" ++
            "      --arg <argument>  Pass an argument to the program. [default: \"\"]\n" ++
            "  -h, --help            Print help\n" ++
            "  -V, --version         Print version\n",
        helpText(a, &cmd),
    );
}

test "hide_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").version("1.0")
        .arg(Arg.new("flag").short('f').long("flag").action(.set_true).help("testing flags"))
        .arg(Arg.new("opt").short('o').long("opt").action(.set).valueName("FILE").help("tests options"))
        .arg(Arg.new("pos").hide(true));
    try testing.expectEqualStrings(
        "Usage: prog [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -f, --flag        testing flags\n" ++
            "  -o, --opt <FILE>  tests options\n" ++
            "  -h, --help        Print help\n" ++
            "  -V, --version     Print version\n",
        helpText(a, &cmd),
    );
}
