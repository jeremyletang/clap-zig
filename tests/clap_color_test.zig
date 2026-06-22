//! ANSI styling snapshots (no clap builder test asserts styled bytes, so these
//! are our own). With `Styles.styled()`: headers/usage bold+underline
//! (`\x1b[1m\x1b[4m…\x1b[0m`), flag/subcommand literals bold (`\x1b[1m…\x1b[0m`),
//! the error prefix red+bold, placeholders/help text plain.

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

const H = "\x1b[1m\x1b[4m"; // header / usage (bold+underline)
const L = "\x1b[1m"; // literal (bold)
const E = "\x1b[1m\x1b[31m"; // error (bold+red)
const R = "\x1b[0m"; // reset

fn helpStyled(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    const styles = clap.Styles.styled();
    return clap.renderErrorStyled(a, clap.getMatches(a, cmd, argv).err, &styles);
}

test "color: help with subcommands and an option" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").about("does stuff").version("1.0")
        .arg(Arg.new("opt").short('o').long("opt").action(.set).help("an option"))
        .subcommand(Command.init(a, "run").about("run it"));
    try testing.expectEqualStrings(
        "does stuff\n\n" ++
            H ++ "Usage:" ++ R ++ " " ++ L ++ "prog" ++ R ++ " [OPTIONS] [COMMAND]\n\n" ++
            H ++ "Commands:" ++ R ++ "\n" ++
            "  " ++ L ++ "run" ++ R ++ "   run it\n" ++
            "  " ++ L ++ "help" ++ R ++ "  Print this message or the help of the given subcommand(s)\n\n" ++
            H ++ "Options:" ++ R ++ "\n" ++
            "  " ++ L ++ "-o" ++ R ++ ", " ++ L ++ "--opt" ++ R ++ " <opt>  an option\n" ++
            "  " ++ L ++ "-h" ++ R ++ ", " ++ L ++ "--help" ++ R ++ "       Print help\n" ++
            "  " ++ L ++ "-V" ++ R ++ ", " ++ L ++ "--version" ++ R ++ "    Print version\n",
        helpStyled(a, &cmd, &.{"--help"}),
    );
}

test "color: error prefix and usage" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("name").long("name").action(.set).required(true));
    // The error MESSAGE arg-displays are computed at parse time (styling
    // inactive) so they're plain; the `error:` prefix and the render-time usage
    // line are styled.
    try testing.expectEqualStrings(
        E ++ "error:" ++ R ++ " the following required arguments were not provided:\n" ++
            "  --name <name>\n\n" ++
            H ++ "Usage:" ++ R ++ " " ++ L ++ "prog" ++ R ++ " " ++ L ++ "--name" ++ R ++ " <name>\n\n" ++
            "For more information, try '--help'.\n",
        helpStyled(a, &cmd, &.{}),
    );
}

test "color_is_global" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog").color(.never).subcommand(Command.init(a, "foo"));
    cmd.buildTree();
    try testing.expectEqual(clap.ColorChoice.never, cmd.getColor());
    try testing.expectEqual(clap.ColorChoice.never, cmd.findSubcommand("foo").?.getColor());
}

test "color: disabled renders identical plain bytes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "prog").about("does stuff").version("1.0")
        .arg(Arg.new("opt").short('o').long("opt").action(.set).help("an option"));
    c1.buildTree();
    const plain_default = clap.renderError(a, clap.getMatches(a, &c1, &.{"--help"}).err);

    var c2 = Command.init(a, "prog").about("does stuff").version("1.0")
        .arg(Arg.new("opt").short('o').long("opt").action(.set).help("an option"));
    c2.buildTree();
    const styles = clap.Styles.plain();
    const plain_styled = clap.renderErrorStyled(a, clap.getMatches(a, &c2, &.{"--help"}).err, &styles);

    try testing.expectEqualStrings(plain_default, plain_styled);
    try testing.expect(std.mem.indexOfScalar(u8, plain_default, 0x1b) == null);
}
