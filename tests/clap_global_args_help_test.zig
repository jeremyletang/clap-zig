//! Ported from clap's tests/builder/help.rs — global args appear in the help of
//! the command and every (nested) subcommand. (The `help help` case is out of
//! scope: it needs the synthetic help subcommand as a help target.)
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn build(a: std.mem.Allocator) Command {
    return Command.init(a, "myapp")
        .arg(Arg.new("someglobal").short('g').long("some-global").action(.set).global(true))
        .subcommand(Command.init(a, "subcmd").subcommand(Command.init(a, "multi").version("1.0")));
}

fn helpText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, argv).err);
}

test "global_args_should_show_on_toplevel_help_message" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = build(a);
    try testing.expectEqualStrings(
        "Usage: myapp [OPTIONS] [COMMAND]\n\n" ++
            "Commands:\n" ++
            "  subcmd  \n" ++
            "  help    Print this message or the help of the given subcommand(s)\n\n" ++
            "Options:\n" ++
            "  -g, --some-global <someglobal>  \n" ++
            "  -h, --help                      Print help\n",
        helpText(a, &cmd, &.{"help"}),
    );
}

test "global_args_should_show_on_help_message_for_subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = build(a);
    try testing.expectEqualStrings(
        "Usage: myapp subcmd [OPTIONS] [COMMAND]\n\n" ++
            "Commands:\n" ++
            "  multi  \n" ++
            "  help   Print this message or the help of the given subcommand(s)\n\n" ++
            "Options:\n" ++
            "  -g, --some-global <someglobal>  \n" ++
            "  -h, --help                      Print help\n",
        helpText(a, &cmd, &.{ "help", "subcmd" }),
    );
}

test "global_args_should_show_on_help_message_for_nested_subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = build(a);
    try testing.expectEqualStrings(
        "Usage: myapp subcmd multi [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -g, --some-global <someglobal>  \n" ++
            "  -h, --help                      Print help\n" ++
            "  -V, --version                   Print version\n",
        helpText(a, &cmd, &.{ "help", "subcmd", "multi" }),
    );
}
