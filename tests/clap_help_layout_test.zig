//! Ported subset of clap's tests/builder/help.rs — before/after help, long_about
//! (template-independent help layout). Wrapping, headings, templates, color are
//! separate.
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

test "after_and_before_help_output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const expected =
        "some text that comes before the help\n\n" ++
        "tests clap library\n\n" ++
        "Usage: clap-test\n\n" ++
        "Options:\n" ++
        "  -h, --help     Print help\n" ++
        "  -V, --version  Print version\n\n" ++
        "some text that comes after the help\n";

    var c1 = Command.init(a, "clap-test").version("v1.4.8").about("tests clap library")
        .beforeHelp("some text that comes before the help")
        .afterHelp("some text that comes after the help");
    try testing.expectEqualStrings(expected, helpText(a, &c1, &.{"-h"}));

    var c2 = Command.init(a, "clap-test").version("v1.4.8").about("tests clap library")
        .beforeHelp("some text that comes before the help")
        .afterHelp("some text that comes after the help");
    try testing.expectEqualStrings(expected, helpText(a, &c2, &.{"--help"}));
}

test "after_and_before_long_help_output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var c1 = Command.init(a, "clap-test").version("v1.4.8").about("tests clap library")
        .beforeHelp("some text that comes before the help")
        .afterHelp("some text that comes after the help")
        .beforeLongHelp("some longer text that comes before the help")
        .afterLongHelp("some longer text that comes after the help");
    try testing.expectEqualStrings(
        "some longer text that comes before the help\n\n" ++
            "tests clap library\n\n" ++
            "Usage: clap-test\n\n" ++
            "Options:\n" ++
            "  -h, --help\n          Print help (see a summary with '-h')\n\n" ++
            "  -V, --version\n          Print version\n\n" ++
            "some longer text that comes after the help\n",
        helpText(a, &c1, &.{"--help"}),
    );

    var c2 = Command.init(a, "clap-test").version("v1.4.8").about("tests clap library")
        .beforeHelp("some text that comes before the help")
        .afterHelp("some text that comes after the help")
        .beforeLongHelp("some longer text that comes before the help")
        .afterLongHelp("some longer text that comes after the help");
    try testing.expectEqualStrings(
        "some text that comes before the help\n\n" ++
            "tests clap library\n\n" ++
            "Usage: clap-test\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help (see more with '--help')\n" ++
            "  -V, --version  Print version\n\n" ++
            "some text that comes after the help\n",
        helpText(a, &c2, &.{"-h"}),
    );
}

test "long_about" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myapp").version("1.0").about("bar")
        .longAbout("something really really long, with\nmultiple lines of text\nthat should be displayed")
        .arg(Arg.new("arg1").help("some option"));
    try testing.expectEqualStrings(
        "something really really long, with\nmultiple lines of text\nthat should be displayed\n\n" ++
            "Usage: myapp [arg1]\n\n" ++
            "Arguments:\n" ++
            "  [arg1]\n          some option\n\n" ++
            "Options:\n" ++
            "  -h, --help\n          Print help (see a summary with '-h')\n\n" ++
            "  -V, --version\n          Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "show_long_about_issue_897" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("0.1")
        .subcommand(Command.init(a, "foo").version("0.1").about("About foo").longAbout("Long about foo"));
    try testing.expectEqualStrings(
        "Long about foo\n\n" ++
            "Usage: ctest foo\n\n" ++
            "Options:\n" ++
            "  -h, --help\n          Print help (see a summary with '-h')\n\n" ++
            "  -V, --version\n          Print version\n",
        helpText(a, &cmd, &.{ "foo", "--help" }),
    );
}

test "show_short_about_issue_897" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("0.1")
        .subcommand(Command.init(a, "foo").version("0.1").about("About foo").longAbout("Long about foo"));
    try testing.expectEqualStrings(
        "About foo\n\n" ++
            "Usage: ctest foo\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help (see more with '--help')\n" ++
            "  -V, --version  Print version\n",
        helpText(a, &cmd, &.{ "foo", "-h" }),
    );
}

test "prefer_about_over_long_about_in_subcommands_list" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "about-in-subcommands-list")
        .subcommand(Command.init(a, "sub").longAbout("long about sub").about("short about sub"));
    try testing.expectEqualStrings(
        "Usage: about-in-subcommands-list [COMMAND]\n\n" ++
            "Commands:\n" ++
            "  sub   short about sub\n" ++
            "  help  Print this message or the help of the given subcommand(s)\n\n" ++
            "Options:\n" ++
            "  -h, --help  Print help\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "after_help_no_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myapp").version("1.0")
        .disableHelpFlag(true).disableVersionFlag(true)
        .afterHelp("This is after help.");
    cmd.buildTree();
    try testing.expectEqualStrings(
        "Usage: myapp\n\nThis is after help.\n",
        clap.renderHelp(a, &cmd),
    );
}
