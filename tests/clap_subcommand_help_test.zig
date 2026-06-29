//! Ported from clap's tests/builder/help.rs — subcommand help dispatch
//! (`sub -h`/`--help`, `help sub`, nested `help sub multi`). The `help help`
//! cases need the synthetic help subcommand as a target and are out of scope.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");
const fixture = @import("complex_app.zig");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const range = clap.ValueRange;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

test "subcommand_short_help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = fixture.complexApp(a);
    try testing.expectEqual(clap.ErrorKind.display_help, run(a, &cmd, &.{ "subcmd", "-h" }).err.kind);
}

test "subcommand_long_help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = fixture.complexApp(a);
    try testing.expectEqual(clap.ErrorKind.display_help, run(a, &cmd, &.{ "subcmd", "--help" }).err.kind);
}

test "subcommand_help_rev" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = fixture.complexApp(a);
    try testing.expectEqual(clap.ErrorKind.display_help, run(a, &cmd, &.{ "help", "subcmd" }).err.kind);
}

test "multi_level_sc_help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").subcommand(
        Command.init(a, "subcmd").subcommand(
            Command.init(a, "multi").about("tests subcommands").author("Kevin K. <kbknapp@gmail.com>").version("0.1")
                .arg(Arg.new("flag").short('f').long("flag").action(.set_true).help("tests flags"))
                .arg(Arg.new("option").short('o').long("option").valueName("scoption").action(.append).numArgs(range.atLeast(1)).help("tests options")),
        ),
    );
    try testing.expectEqualStrings(
        "tests subcommands\n\n" ++
            "Usage: ctest subcmd multi [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -f, --flag                  tests flags\n" ++
            "  -o, --option <scoption>...  tests options\n" ++
            "  -h, --help                  Print help\n" ++
            "  -V, --version               Print version\n",
        clap.renderError(a, run(a, &cmd, &.{ "help", "subcmd", "multi" }).err),
    );
}
