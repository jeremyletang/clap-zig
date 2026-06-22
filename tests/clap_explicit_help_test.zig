//! Ported from clap's tests/builder/help.rs — `explicit_short_long_help`: custom
//! flags with the `HelpShort`/`HelpLong` actions drive the short vs long layout.
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

fn app(a: std.mem.Allocator) Command {
    return Command.init(a, "myapp").disableHelpFlag(true).version("1.0").author("foo").about("bar")
        .longAbout("something really really long, with\nmultiple lines of text\nthat should be displayed")
        .arg(Arg.new("arg1").help("some option"))
        .arg(Arg.new("short").short('?').action(.help_short))
        .arg(Arg.new("long").short('h').long("help").action(.help_long));
}

test "explicit_short_long_help (short)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = app(a);
    try testing.expectEqualStrings(
        "bar\n\n" ++
            "Usage: myapp [arg1]\n\n" ++
            "Arguments:\n" ++
            "  [arg1]  some option\n\n" ++
            "Options:\n" ++
            "  -?             \n" ++
            "  -h, --help     \n" ++
            "  -V, --version  Print version\n",
        helpText(a, &cmd, &.{"-?"}),
    );
}

test "explicit_short_long_help (long)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = app(a);
    try testing.expectEqualStrings(
        "something really really long, with\n" ++
            "multiple lines of text\n" ++
            "that should be displayed\n\n" ++
            "Usage: myapp [arg1]\n\n" ++
            "Arguments:\n" ++
            "  [arg1]\n          some option\n\n" ++
            "Options:\n" ++
            "  -?\n          \n\n" ++
            "  -h, --help\n          \n\n" ++
            "  -V, --version\n          Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}
